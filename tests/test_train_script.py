"""Tests dédiés à scripts/train.py pour augmenter la couverture."""

from __future__ import annotations

import importlib.util
from pathlib import Path

import numpy as np
import pandas as pd


def _load_train_module():
    script_path = Path(__file__).parents[1] / "scripts" / "train.py"
    spec = importlib.util.spec_from_file_location("train_module", script_path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


def _make_synthetic_dataset(n_per_class: int = 30) -> pd.DataFrame:
    classes = ["Metal", "Papier", "Plastique", "Verre"]
    rows: list[dict] = []

    for cls_idx, cls_name in enumerate(classes):
        source = f"Usine_{chr(65 + cls_idx)}"
        text = f"lot {cls_name.lower()} propre recycle"
        base = 10.0 + (cls_idx * 20.0)

        for i in range(n_per_class):
            rows.append(
                {
                    "Poids": base + (i % 5),
                    "Volume": base * 2 + (i % 7),
                    "Conductivite": 1.0 + cls_idx + (i % 3) * 0.1,
                    "Opacite": 0.2 + cls_idx * 0.15 + (i % 2) * 0.01,
                    "Rigidite": 2.0 + cls_idx + (i % 4) * 0.1,
                    "Prix_Revente": 5.0 + cls_idx * 3.0 + (i % 6) * 0.2,
                    "Source": source,
                    "Rapport_Collecte": text,
                    "Categorie": cls_name,
                }
            )

    df = pd.DataFrame(rows)

    # Introduit des NaN pour vérifier le nettoyage/imputation
    df.loc[0, "Poids"] = np.nan
    df.loc[10, "Volume"] = np.nan
    df.loc[20, "Conductivite"] = np.nan

    # Introduit un outlier pour tester le clipping IQR
    df.loc[1, "Prix_Revente"] = 9999.0
    return df


def test_preprocess_text_normalizes_french_text():
    train_module = _load_train_module()

    out = train_module.preprocess_text("Récupéré à l'Usine: plastiques 2026!")
    assert isinstance(out, str)
    assert "é" not in out
    assert "!" not in out
    assert "2026" not in out


def test_clean_dataset_imputes_and_clips_values():
    train_module = _load_train_module()
    df = _make_synthetic_dataset()

    cleaned = train_module.clean_dataset(df)
    assert cleaned[train_module.NUM_COLS].isna().sum().sum() == 0
    # L'outlier extrême doit être réduit par winsorisation
    assert cleaned["Prix_Revente"].max() < 9999.0


def test_train_saves_bundle_and_reaches_min_accuracy(tmp_path):
    train_module = _load_train_module()

    df = _make_synthetic_dataset(n_per_class=30)
    data_path = tmp_path / "synthetic_train.csv"
    model_dir = tmp_path / "models"
    df.to_csv(data_path, index=False)

    bundle = train_module.train(str(data_path), str(model_dir))
    model_path = model_dir / "pipeline.joblib"

    assert model_path.exists()
    assert "clf" in bundle
    assert "metrics" in bundle
    assert bundle["metrics"]["accuracy"] >= 0.70
