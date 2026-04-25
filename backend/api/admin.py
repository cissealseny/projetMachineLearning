from django.contrib import admin

from .models import PredictionLog


@admin.register(PredictionLog)
class PredictionLogAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "ml_status_code", "created_at")
    list_filter = ("ml_status_code", "created_at")
    search_fields = ("id", "user__username")
    readonly_fields = ("created_at",)
