from rest_framework import serializers

from .models import PredictionLog


class PredictRequestSerializer(serializers.Serializer):
    Poids = serializers.FloatField(min_value=0)
    Volume = serializers.FloatField(min_value=0)
    Conductivite = serializers.FloatField(min_value=0)
    Opacite = serializers.FloatField(min_value=0)
    Rigidite = serializers.FloatField(min_value=0)
    Prix_Revente = serializers.FloatField(min_value=0)
    Source = serializers.CharField(max_length=120)
    Rapport_Collecte = serializers.CharField(required=False, allow_blank=True)


class BatchPredictRequestSerializer(serializers.Serializer):
    observations = PredictRequestSerializer(many=True)

    def validate_observations(self, value):
        if len(value) > 100:
            raise serializers.ValidationError("Maximum 100 observations par requete.")
        return value


class PredictResponseSerializer(serializers.Serializer):
    categorie = serializers.CharField()
    probabilites = serializers.DictField(child=serializers.FloatField())
    texte_clean = serializers.CharField()


class PredictionLogSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source="user.username", read_only=True)

    class Meta:
        model = PredictionLog
        fields = (
            "id",
            "username",
            "request_payload",
            "response_payload",
            "ml_status_code",
            "created_at",
        )
