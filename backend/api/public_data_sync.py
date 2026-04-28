import csv
from collections import defaultdict
from pathlib import Path

from django.conf import settings

from .models import CollectionPoint, GovernorateStat

# Mapping from dataset source labels to public governorate points.
SOURCE_MAP = {
    "usine_a": {
        "governorate": "Tunis",
        "site": "Tunis Centre",
        "lat": 36.8065,
        "lng": 10.1815,
    },
    "usine_b": {
        "governorate": "Sfax",
        "site": "Sfax Ville",
        "lat": 34.7406,
        "lng": 10.7603,
    },
    "centre_tri": {
        "governorate": "Sousse",
        "site": "Sousse Medina",
        "lat": 35.8256,
        "lng": 10.6084,
    },
    "collecte_citoyenne": {
        "governorate": "Nabeul",
        "site": "Nabeul Centre",
        "lat": 36.4513,
        "lng": 10.7359,
    },
    "non_renseigne": {
        "governorate": "Bizerte",
        "site": "Bizerte Port",
        "lat": 37.2746,
        "lng": 9.8739,
    },
}


def _normalize_source(value: str) -> str:
    raw = (value or "").strip()
    if not raw:
        return "non_renseigne"
    return raw.lower().replace(" ", "_")


def _safe_positive_float(value: str) -> float:
    try:
        parsed = float((value or "").strip())
        return parsed if parsed > 0 else 0.0
    except ValueError:
        return 0.0


def sync_public_data_from_csv(csv_path: str | None = None) -> dict:
    if csv_path is None:
        csv_file = settings.BASE_DIR.parent / "dataset_ProjetML_2026.csv"
    else:
        csv_file = Path(csv_path)

    if not csv_file.exists():
        raise FileNotFoundError(f"CSV introuvable: {csv_file}")

    by_governorate: dict[str, dict] = defaultdict(
        lambda: {"tons": 0.0, "rows": 0, "known_category": 0}
    )
    points_by_site: dict[tuple[str, str], dict] = {}

    with csv_file.open("r", encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            source_key = _normalize_source(row.get("Source") or "")
            mapped = SOURCE_MAP.get(source_key, SOURCE_MAP["non_renseigne"])
            governorate = mapped["governorate"]

            poids = _safe_positive_float(row.get("Poids") or "")
            category_known = 1 if (row.get("Categorie") or "").strip() else 0

            stats = by_governorate[governorate]
            stats["tons"] += poids
            stats["rows"] += 1
            stats["known_category"] += category_known

            site_key = (mapped["site"], mapped["governorate"])
            points_by_site[site_key] = mapped

    active_governorates = set()
    for governorate, stats in by_governorate.items():
        rows = max(stats["rows"], 1)
        recovery_rate = round((stats["known_category"] / rows) * 100)
        monthly_tons = int(round(stats["tons"]))

        GovernorateStat.objects.update_or_create(
            name=governorate,
            defaults={
                "monthly_tons": monthly_tons,
                "recovery_rate": max(0, min(100, recovery_rate)),
                "is_active": True,
            },
        )
        active_governorates.add(governorate)

    GovernorateStat.objects.exclude(name__in=active_governorates).update(is_active=False)

    active_points = set()
    for (site, governorate), mapped in points_by_site.items():
        CollectionPoint.objects.update_or_create(
            site=site,
            governorate=governorate,
            defaults={
                "lat": mapped["lat"],
                "lng": mapped["lng"],
                "is_active": True,
            },
        )
        active_points.add((site, governorate))

    # Disable points not present in latest CSV mapping.
    stale_points = CollectionPoint.objects.exclude(is_active=False)
    for point in stale_points:
        if (point.site, point.governorate) not in active_points:
            point.is_active = False
            point.save(update_fields=["is_active"])

    return {
        "csv_path": str(csv_file),
        "governorates": len(active_governorates),
        "collection_points": len(active_points),
    }
