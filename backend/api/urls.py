from django.urls import path

from .views import (
    DashboardView,
    DevQuickLoginView,
    HealthView,
    InfoView,
    PredictionHistoryView,
    PredictBatchView,
    PredictView,
)

urlpatterns = [
    path("auth/dev-quick-login/", DevQuickLoginView.as_view(), name="dev-quick-login"),
    path("health/", HealthView.as_view(), name="health"),
    path("info/", InfoView.as_view(), name="info"),
    path("predict/", PredictView.as_view(), name="predict"),
    path("predict/batch/", PredictBatchView.as_view(), name="predict-batch"),
    path("predictions/history/", PredictionHistoryView.as_view(), name="prediction-history"),
    path("dashboard/", DashboardView.as_view(), name="dashboard"),
]
