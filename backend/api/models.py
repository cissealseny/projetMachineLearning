from django.conf import settings
from django.db import models


class PredictionLog(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="prediction_logs",
    )
    request_payload = models.JSONField()
    response_payload = models.JSONField()
    ml_status_code = models.PositiveSmallIntegerField(default=200)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"PredictionLog(id={self.id}, status={self.ml_status_code})"


class CollectionPoint(models.Model):
    site = models.CharField(max_length=120)
    governorate = models.CharField(max_length=120)
    lat = models.FloatField()
    lng = models.FloatField()
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["governorate", "site"]

    def __str__(self):
        return f"{self.site} ({self.governorate})"


class GovernorateStat(models.Model):
    name = models.CharField(max_length=120, unique=True)
    monthly_tons = models.PositiveIntegerField(default=0)
    recovery_rate = models.PositiveSmallIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-monthly_tons", "name"]

    def __str__(self):
        return f"{self.name}: {self.monthly_tons} t/mois"
