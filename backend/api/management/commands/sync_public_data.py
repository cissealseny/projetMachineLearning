from django.core.management.base import BaseCommand, CommandError

from api.public_data_sync import sync_public_data_from_csv


class Command(BaseCommand):
    help = "Synchronise les données publiques (points + gouvernorats) depuis le CSV projet"

    def add_arguments(self, parser):
        parser.add_argument(
            "--csv",
            dest="csv_path",
            default=None,
            help="Chemin CSV explicite (optionnel)",
        )

    def handle(self, *args, **options):
        csv_path = options.get("csv_path")
        try:
            result = sync_public_data_from_csv(csv_path)
        except FileNotFoundError as exc:
            raise CommandError(str(exc)) from exc

        self.stdout.write(
            self.style.SUCCESS(
                "Sync terminée: "
                f"gouvernorats={result['governorates']}, "
                f"points={result['collection_points']}, "
                f"csv={result['csv_path']}"
            )
        )
