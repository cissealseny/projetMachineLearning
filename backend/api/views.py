import os
import subprocess
import sys
import threading
from pathlib import Path

import requests
from django.conf import settings
from django.contrib.auth import get_user_model
from requests import RequestException
from rest_framework import permissions
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import CollectionPoint, GovernorateStat, PredictionLog
from .serializers import (
    BatchPredictRequestSerializer,
    PredictionLogSerializer,
    PredictRequestSerializer,
)

ML_API_BASE_URL = os.getenv("ML_API_BASE_URL", "http://127.0.0.1:8000")
REQUEST_TIMEOUT_SECONDS = float(os.getenv("ML_API_TIMEOUT", "15"))


def _run_retrain_job():
    root_dir = Path(settings.BASE_DIR).parent
    data_path = root_dir / "notebooks" / "dataset_ProjetML_2026.csv"
    scripts = [
        root_dir / "scripts" / "train.py",
        root_dir / "scripts" / "train_nlp.py",
    ]

    for script in scripts:
        subprocess.run(
            [sys.executable, str(script), "--data", str(data_path)],
            cwd=root_dir,
            check=True,
        )

    try:
        requests.post(f"{ML_API_BASE_URL}/reload", timeout=REQUEST_TIMEOUT_SECONDS)
    except RequestException:
        pass


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


class PublicTunisiaDashboardView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        points = list(
            CollectionPoint.objects.filter(is_active=True).values(
                "site", "governorate", "lat", "lng"
            )
        )
        governorates = list(
            GovernorateStat.objects.filter(is_active=True).values(
                "name", "monthly_tons", "recovery_rate"
            )
        )

        if not points:
            points = [
                {"site": "Tunis Centre", "governorate": "Tunis", "lat": 36.8065, "lng": 10.1815},
                {"site": "Lac 1", "governorate": "Tunis", "lat": 36.8453, "lng": 10.2729},
                {"site": "Sfax Ville", "governorate": "Sfax", "lat": 34.7406, "lng": 10.7603},
                {"site": "Sousse Medina", "governorate": "Sousse", "lat": 35.8256, "lng": 10.6084},
                {"site": "Bizerte Port", "governorate": "Bizerte", "lat": 37.2746, "lng": 9.8739},
                {"site": "Gabes Nord", "governorate": "Gabes", "lat": 33.8815, "lng": 10.0982},
            ]

        if not governorates:
            governorates = [
                {"name": "Tunis", "monthly_tons": 1280, "recovery_rate": 74},
                {"name": "Sfax", "monthly_tons": 1090, "recovery_rate": 69},
                {"name": "Sousse", "monthly_tons": 980, "recovery_rate": 66},
                {"name": "Nabeul", "monthly_tons": 860, "recovery_rate": 63},
                {"name": "Bizerte", "monthly_tons": 720, "recovery_rate": 58},
                {"name": "Gabes", "monthly_tons": 640, "recovery_rate": 55},
            ]

        payload = {
            "country": "Tunisia",
            "collection_points": points,
            "governorate_stats": governorates,
            "source": "ecosmart-public-api",
        }

        return Response(payload, status=status.HTTP_200_OK)


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


# ─── Vue NLP : classification par texte libre uniquement ─────────────────────
class PredictNlpView(APIView):
    """
    POST /api/predict/nlp/
    Body: { "rapport_collecte": "Ferraille et câbles électriques..." }

    Transmet au FastAPI ML l'endpoint /predict/nlp en injectant
    les médianes globales pour les features numériques.
    Le modèle ne se base donc que sur le texte pour prédire.
    """

    def post(self, request):
        rapport = (request.data.get("rapport_collecte") or "").strip()
        if not rapport:
            return Response(
                {"detail": "Le champ 'rapport_collecte' est requis et ne peut pas être vide."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Payload envoyé au FastAPI — médianes injectées côté Django
        # pour neutraliser les features numériques
        ml_payload = {
            "Poids": 25.0,
            "Volume": 50.0,
            "Conductivite": 3.5,
            "Opacite": 0.7,
            "Rigidite": 4.2,
            "Prix_Revente": 12.0,
            "Source": "NLP_only",
            "Rapport_Collecte": rapport,
        }

        try:
            ml_resp = requests.post(
                f"{ML_API_BASE_URL}/predict/nlp",
                json=ml_payload,
                timeout=REQUEST_TIMEOUT_SECONDS,
            )
            response_payload = ml_resp.json()

            # Log de la prédiction NLP
            PredictionLog.objects.create(
                user=request.user if request.user.is_authenticated else None,
                request_payload={"rapport_collecte": rapport, "mode": "nlp_only"},
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


class RegisterView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        username = request.data.get("username", "").strip()
        password = request.data.get("password", "").strip()
        email = request.data.get("email", "").strip()

        if not username or not password:
            return Response(
                {"detail": "Username et password requis."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user_model = get_user_model()
        if user_model.objects.filter(username=username).exists():
            return Response(
                {"detail": "Ce nom d'utilisateur existe déjà."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = user_model.objects.create_user(
            username=username, password=password, email=email
        )
        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "username": username,
            },
            status=status.HTTP_201_CREATED,
        )


class RetrainView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        if not settings.DEBUG:
            return Response(
                {"detail": "Retrain is disabled in production."},
                status=status.HTTP_403_FORBIDDEN,
            )

        thread = threading.Thread(target=_run_retrain_job, daemon=True)
        thread.start()

        return Response(
            {
                "detail": "Retrain started. Models will reload after training.",
            },
            status=status.HTTP_202_ACCEPTED,
        )
