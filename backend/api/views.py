import os

import requests
from django.conf import settings
from django.contrib.auth import get_user_model
from requests import RequestException
from rest_framework import permissions
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import PredictionLog
from .serializers import (
    BatchPredictRequestSerializer,
    PredictionLogSerializer,
    PredictRequestSerializer,
)

ML_API_BASE_URL = os.getenv("ML_API_BASE_URL", "http://127.0.0.1:8000")
REQUEST_TIMEOUT_SECONDS = float(os.getenv("ML_API_TIMEOUT", "15"))


class HealthView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        payload = {"status": "ok", "service": "django-backend"}
        try:
            ml_resp = requests.get(
                f"{ML_API_BASE_URL}/health", timeout=REQUEST_TIMEOUT_SECONDS
            )
            payload["ml_api"] = {
                "reachable": ml_resp.ok,
                "status_code": ml_resp.status_code,
                "body": ml_resp.json() if ml_resp.headers.get("content-type", "").startswith("application/json") else {},
            }
            return Response(payload, status=status.HTTP_200_OK)
        except RequestException as exc:
            payload["ml_api"] = {"reachable": False, "error": str(exc)}
            return Response(payload, status=status.HTTP_200_OK)


class InfoView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        try:
            ml_resp = requests.get(
                f"{ML_API_BASE_URL}/info", timeout=REQUEST_TIMEOUT_SECONDS
            )
            return Response(ml_resp.json(), status=ml_resp.status_code)
        except RequestException as exc:
            return Response(
                {"detail": f"ML API unreachable: {exc}"},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )


class PredictView(APIView):
    def post(self, request):
        serializer = PredictRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            ml_resp = requests.post(
                f"{ML_API_BASE_URL}/predict",
                json=serializer.validated_data,
                timeout=REQUEST_TIMEOUT_SECONDS,
            )
            response_payload = ml_resp.json()

            PredictionLog.objects.create(
                user=request.user if request.user.is_authenticated else None,
                request_payload=serializer.validated_data,
                response_payload=response_payload,
                ml_status_code=ml_resp.status_code,
            )

            return Response(response_payload, status=ml_resp.status_code)
        except RequestException as exc:
            return Response(
                {"detail": f"ML API unreachable: {exc}"},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )


class PredictBatchView(APIView):
    def post(self, request):
        serializer = BatchPredictRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            ml_resp = requests.post(
                f"{ML_API_BASE_URL}/predict/batch",
                json=serializer.validated_data,
                timeout=REQUEST_TIMEOUT_SECONDS,
            )
            response_payload = ml_resp.json()

            PredictionLog.objects.create(
                user=request.user if request.user.is_authenticated else None,
                request_payload=serializer.validated_data,
                response_payload=response_payload,
                ml_status_code=ml_resp.status_code,
            )

            return Response(response_payload, status=ml_resp.status_code)
        except RequestException as exc:
            return Response(
                {"detail": f"ML API unreachable: {exc}"},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )


class PredictionHistoryView(APIView):
    def get(self, request):
        logs = PredictionLog.objects.filter(user=request.user)[:50]
        serializer = PredictionLogSerializer(logs, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)


class DashboardView(APIView):
    def get(self, request):
        logs = PredictionLog.objects.filter(user=request.user)
        recent_logs = logs[:10]
        recent_serializer = PredictionLogSerializer(recent_logs, many=True)

        success_count = logs.filter(ml_status_code__gte=200, ml_status_code__lt=300).count()
        total_count = logs.count()

        health_data = {}
        info_data = {}

        try:
            health_resp = requests.get(
                f"{ML_API_BASE_URL}/health", timeout=REQUEST_TIMEOUT_SECONDS
            )
            health_data = health_resp.json() if health_resp.ok else {}
        except RequestException:
            health_data = {"model_ready": False}

        try:
            info_resp = requests.get(
                f"{ML_API_BASE_URL}/info", timeout=REQUEST_TIMEOUT_SECONDS
            )
            info_data = info_resp.json() if info_resp.ok else {}
        except RequestException:
            info_data = {}

        payload = {
            "user": {
                "id": request.user.id,
                "username": request.user.username,
            },
            "summary": {
                "predictions_count": total_count,
                "success_rate": round((success_count / total_count) * 100, 2)
                if total_count > 0
                else 0.0,
                "last_prediction_at": recent_logs[0].created_at if recent_logs else None,
            },
            "ml": {
                "model_ready": health_data.get("model_ready", False),
                "classes": info_data.get("classes", []),
                "metrics": info_data.get("metrics", {}),
            },
            "recent_predictions": recent_serializer.data,
        }

        return Response(payload, status=status.HTTP_200_OK)


class DevQuickLoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        if not settings.DEBUG:
            return Response(
                {"detail": "Dev quick login is disabled in production."},
                status=status.HTTP_403_FORBIDDEN,
            )

        username = (request.data.get("username") or "demo").strip()
        password = request.data.get("password") or "Demo12345!"

        user_model = get_user_model()
        user, created = user_model.objects.get_or_create(
            username=username,
            defaults={"is_active": True},
        )

        if created or not user.check_password(password):
            user.set_password(password)
            user.save(update_fields=["password"])

        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "username": username,
                "password": password,
            },
            status=status.HTTP_200_OK,
        )
