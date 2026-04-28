from django.contrib import admin
from django.contrib import messages

from .models import CollectionPoint, GovernorateStat, PredictionLog
from .public_data_sync import sync_public_data_from_csv


@admin.register(PredictionLog)
class PredictionLogAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "ml_status_code", "created_at")
    list_filter = ("ml_status_code", "created_at")
    search_fields = ("id", "user__username")
    readonly_fields = ("created_at",)


@admin.register(CollectionPoint)
class CollectionPointAdmin(admin.ModelAdmin):
    list_display = ("site", "governorate", "lat", "lng", "is_active")
    list_filter = ("governorate", "is_active")
    search_fields = ("site", "governorate")
    actions = ("sync_from_csv",)

    @admin.action(description="Synchroniser depuis le CSV projet")
    def sync_from_csv(self, request, queryset):
        result = sync_public_data_from_csv()
        self.message_user(
            request,
            (
                f"Synchronisation OK: gouvernorats={result['governorates']}, "
                f"points={result['collection_points']}"
            ),
            level=messages.SUCCESS,
        )


@admin.register(GovernorateStat)
class GovernorateStatAdmin(admin.ModelAdmin):
    list_display = ("name", "monthly_tons", "recovery_rate", "is_active", "updated_at")
    list_filter = ("is_active", "recovery_rate")
    search_fields = ("name",)
    readonly_fields = ("updated_at",)
    actions = ("sync_from_csv",)

    @admin.action(description="Synchroniser depuis le CSV projet")
    def sync_from_csv(self, request, queryset):
        result = sync_public_data_from_csv()
        self.message_user(
            request,
            (
                f"Synchronisation OK: gouvernorats={result['governorates']}, "
                f"points={result['collection_points']}"
            ),
            level=messages.SUCCESS,
        )
