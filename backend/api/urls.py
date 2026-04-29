from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from .views import (
    DashboardView,
    DevQuickLoginView,
    HealthView,
    InfoView,
    PublicTunisiaDashboardView,
    PredictionHistoryView,
    PredictBatchView,
    PredictView,
    RegisterView,
)

urlpatterns = [
    # Auth
    path("auth/login/", TokenObtainPairView.as_view(), name="login"),
    path("auth/register/", RegisterView.as_view(), name="register"),
    path("auth/refresh/", TokenRefreshView.as_view(), name="token-refresh"),
    path("auth/dev-quick-login/", DevQuickLoginView.as_view(), name="dev-quick-login"),
    # API
    path("health/", HealthView.as_view(), name="health"),
    path("info/", InfoView.as_view(), name="info"),
    path("public/tunisia-dashboard/", PublicTunisiaDashboardView.as_view(), name="public-tunisia-dashboard"),
    path("predict/", PredictView.as_view(), name="predict"),
    path("predict/batch/", PredictBatchView.as_view(), name="predict-batch"),
    path("predictions/history/", PredictionHistoryView.as_view(), name="prediction-history"),
    path("dashboard/", DashboardView.as_view(), name="dashboard"),
]
