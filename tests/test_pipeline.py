"""
tests/test_pipeline.py
Couvre (selon cahier des charges) :
  ✅ Schéma des données
  ✅ Qualité post-imputation
  ✅ Pipeline NLP
  ✅ Vectorisation TF-IDF
  ✅ Prédictions du modèle (si modèle présent)
  ✅ Seuil de performance minimal (accuracy ≥ 0.70)
  ✅ Endpoint API /health et /predict

NOTE : les tests API utilisent TestClient (pas de serveur réel requis).
"""
import re
import unicodedata
import string
from pathlib import Path

import numpy as np
import pandas as pd
import pytest
from sklearn.impute import KNNImputer

# ─────────────────────────────────────────────────────────────────────────────
# Fixtures
# ─────────────────────────────────────────────────────────────────────────────
DATA_PATH  = Path(__file__).parents[1] / "dataset_ProjetML_2026.csv"
MODEL_PATH = Path(__file__).parents[1] / "models" / "pipeline.joblib"

NA_VALUES = ["", " ", "NA", "N/A", "null", "None", "non mesure", "non mesure kg"]
NUM_COLS  = ["Poids", "Volume", "Conductivite", "Opacite", "Rigidite", "Prix_Revente"]
CAT_COLS  = ["Source"]
TEXT_COL  = "Rapport_Collecte"
TARGET    = "Categorie"
ALL_COLS  = NUM_COLS + CAT_COLS + [TEXT_COL, TARGET]


@pytest.fixture(scope="session")
def raw_df():
    if not DATA_PATH.exists():
        pytest.skip(f"Dataset introuvable : {DATA_PATH}")
    return pd.read_csv(DATA_PATH, na_values=NA_VALUES)


@pytest.fixture(scope="session")
def bundle():
    if not MODEL_PATH.exists():
        pytest.skip("Modèle non entraîné — lance scripts/train.py")
    import joblib
    return joblib.load(MODEL_PATH)


# ─────────────────────────────────────────────────────────────────────────────
# 1. Schéma des données
# ─────────────────────────────────────────────────────────────────────────────
class TestDataSchema:
    def test_expected_columns_present(self, raw_df):
        """Toutes les colonnes attendues doivent être présentes."""
        for col in ALL_COLS:
            assert col in raw_df.columns, f"Colonne manquante : {col}"

    def test_numeric_columns_dtype(self, raw_df):
        """Les colonnes numériques doivent être de type float ou int."""
        for col in NUM_COLS:
            assert pd.api.types.is_numeric_dtype(raw_df[col]), \
                f"{col} n'est pas numérique (dtype={raw_df[col].dtype})"

    def test_dataset_min_size(self, raw_df):
        """Le dataset doit contenir au moins 500 lignes."""
        assert len(raw_df) >= 500, f"Dataset trop petit : {len(raw_df)} lignes"

    def test_target_not_all_nan(self, raw_df):
        """La cible ne doit pas être entièrement NaN."""
        assert raw_df[TARGET].notna().sum() > 0, "Toutes les cibles sont NaN"

    def test_target_categories(self, raw_df):
        """La cible doit avoir au moins 2 catégories distinctes."""
        cats = raw_df[TARGET].dropna().unique()
        assert len(cats) >= 2, f"Moins de 2 catégories dans {TARGET} : {cats}"


# ─────────────────────────────────────────────────────────────────────────────
# 2. Qualité post-imputation
# ─────────────────────────────────────────────────────────────────────────────
class TestImputation:
    def test_no_nan_after_knn_imputation(self, raw_df):
        """Après KNNImputer, aucun NaN ne doit rester sur les colonnes numériques."""
        imp = KNNImputer(n_neighbors=5)
        imputed = imp.fit_transform(raw_df[NUM_COLS])
        assert not np.isnan(imputed).any(), "NaN résiduels après imputation KNN"

    def test_imputation_preserves_shape(self, raw_df):
        """L'imputation ne doit pas changer le nombre de lignes ni de colonnes."""
        imp = KNNImputer(n_neighbors=5)
        imputed = imp.fit_transform(raw_df[NUM_COLS])
        assert imputed.shape == (len(raw_df), len(NUM_COLS))

    def test_imputed_values_in_range(self, raw_df):
        """Les valeurs imputées ne doivent pas dépasser les bornes originales."""
        imp = KNNImputer(n_neighbors=5)
        imputed = pd.DataFrame(imp.fit_transform(raw_df[NUM_COLS]), columns=NUM_COLS)
        for col in NUM_COLS:
            original_min = raw_df[col].min()
            original_max = raw_df[col].max()
            assert imputed[col].min() >= original_min - 1e-6
            assert imputed[col].max() <= original_max + 1e-6


# ─────────────────────────────────────────────────────────────────────────────
# 3. Pipeline NLP
# ─────────────────────────────────────────────────────────────────────────────
import sys
sys.path.insert(0, str(Path(__file__).parents[1]))
from app.main import preprocess_text  # réutilise la fonction de l'API


class TestNLPPipeline:
    def test_output_is_string(self):
        assert isinstance(preprocess_text("Lot de plastique"), str)

    def test_empty_string_input(self):
        assert preprocess_text("") == ""

    def test_none_input(self):
        assert preprocess_text(None) == ""

    def test_lowercase_output(self):
        result = preprocess_text("LOT DE PLASTIQUE")
        assert result == result.lower()

    def test_accents_removed(self):
        result = preprocess_text("récupéré à l'usine")
        assert "é" not in result and "à" not in result

    def test_stopwords_removed(self):
        result = preprocess_text("lot de dechets collecte usine")
        # Les stopwords métier doivent être supprimés
        for sw in ["lot", "collecte", "usine", "dechet"]:
            assert sw not in result.split(), f"Stopword '{sw}' non supprimé"

    def test_punctuation_removed(self):
        result = preprocess_text("plastique! volume: 50 L.")
        assert "!" not in result and "." not in result

    def test_stemming_applied(self):
        # "plastiques" doit être stemmatisé (racine différente de "plastiques")
        result = preprocess_text("plastiques recyclables")
        assert "plastiques" not in result  # stemming a tronqué le mot

    def test_real_example(self):
        text = "Lot de papier récupéré dans un site non renseigné."
        result = preprocess_text(text)
        assert len(result) > 0


# ─────────────────────────────────────────────────────────────────────────────
# 4. Vectorisation TF-IDF
# ─────────────────────────────────────────────────────────────────────────────
class TestVectorisation:
    def test_tfidf_output_shape(self, raw_df):
        from sklearn.feature_extraction.text import TfidfVectorizer
        texts = raw_df[TEXT_COL].fillna("").apply(preprocess_text)
        tfidf = TfidfVectorizer(max_features=500, ngram_range=(1, 2))
        X = tfidf.fit_transform(texts)
        assert X.shape[0] == len(raw_df)
        assert X.shape[1] <= 500

    def test_tfidf_no_negative_values(self, raw_df):
        from sklearn.feature_extraction.text import TfidfVectorizer
        texts = raw_df[TEXT_COL].fillna("").apply(preprocess_text)
        tfidf = TfidfVectorizer(max_features=100)
        X = tfidf.fit_transform(texts).toarray()
        assert (X >= 0).all(), "TF-IDF contient des valeurs négatives"


# ─────────────────────────────────────────────────────────────────────────────
# 5. Prédictions du modèle + seuil de performance
# ─────────────────────────────────────────────────────────────────────────────
class TestModel:
    def test_model_has_required_keys(self, bundle):
        for key in ["clf", "num_pipe", "cat_pipe", "tfidf", "classes", "metrics"]:
            assert key in bundle, f"Clé manquante dans le bundle : {key}"

    def test_classes_not_empty(self, bundle):
        assert len(bundle["classes"]) >= 2

    def test_accuracy_above_threshold(self, bundle):
        acc = bundle["metrics"]["accuracy"]
        assert acc >= 0.70, f"Accuracy {acc:.4f} < seuil minimal 0.70"

    def test_f1_test_positive(self, bundle):
        f1 = bundle["metrics"]["f1_test"]
        assert f1 > 0.0, "F1 test est nul"

    def test_prediction_returns_known_class(self, bundle, raw_df):
        """Une prédiction doit retourner une classe connue."""
        from scipy.sparse import hstack, csr_matrix

        sample = raw_df[NUM_COLS + CAT_COLS + [TEXT_COL]].dropna().iloc[:1].copy()
        sample[TEXT_COL] = sample[TEXT_COL].apply(preprocess_text)

        X_num = bundle["num_pipe"].transform(sample[NUM_COLS])
        X_cat = bundle["cat_pipe"].transform(sample[CAT_COLS])
        X_txt = bundle["tfidf"].transform(sample[TEXT_COL])
        X     = hstack([csr_matrix(X_num), X_cat, X_txt])

        pred = bundle["clf"].predict(X)[0]
        assert pred in bundle["classes"], f"Prédiction inconnue : {pred}"


# ─────────────────────────────────────────────────────────────────────────────
# 6. Endpoint API
# ─────────────────────────────────────────────────────────────────────────────
class TestAPI:
    @pytest.fixture(autouse=True)
    def client(self):
        """Crée un client de test FastAPI sans démarrer de serveur."""
        from fastapi.testclient import TestClient
        import importlib, sys
        # Recharger main pour prendre en compte le bundle (si disponible)
        if "app.main" in sys.modules:
            mod = importlib.reload(sys.modules["app.main"])
        else:
            from app import main as mod
        self.client = TestClient(mod.app)

    def test_health_returns_200(self):
        r = self.client.get("/health")
        assert r.status_code == 200

    def test_health_response_structure(self):
        r = self.client.get("/health")
        body = r.json()
        assert "status" in body
        assert "model_ready" in body
        assert body["status"] == "ok"

    def test_predict_valid_input(self):
        payload = {
            "Poids": 20.0,
            "Volume": 40.0,
            "Conductivite": 3.0,
            "Opacite": 0.6,
            "Rigidite": 4.0,
            "Prix_Revente": 10.0,
            "Source": "Usine_A",
            "Rapport_Collecte": "Lot de plastique récupéré à l'Usine A.",
        }
        r = self.client.post("/predict", json=payload)
        # 200 si modèle chargé, 503 si pas encore entraîné
        assert r.status_code in (200, 503)

    def test_predict_response_structure(self):
        """Si le modèle est dispo, la réponse doit avoir les bons champs."""
        payload = {
            "Poids": 20.0, "Volume": 40.0, "Conductivite": 3.0,
            "Opacite": 0.6, "Rigidite": 4.0, "Prix_Revente": 10.0,
            "Source": "Usine_A",
            "Rapport_Collecte": "Lot de plastique",
        }
        r = self.client.post("/predict", json=payload)
        if r.status_code == 200:
            body = r.json()
            assert "categorie" in body
            assert "probabilites" in body
            assert "texte_clean" in body

    def test_predict_missing_required_field(self):
        """Un champ requis manquant doit retourner 422."""
        r = self.client.post("/predict", json={"Poids": 20.0})
        assert r.status_code == 422

    def test_predict_negative_poids(self):
        """Un Poids négatif doit être rejeté (ge=0 dans le schéma)."""
        payload = {
            "Poids": -5.0, "Volume": 40.0, "Conductivite": 3.0,
            "Opacite": 0.6, "Rigidite": 4.0, "Prix_Revente": 10.0,
            "Source": "Usine_A",
        }
        r = self.client.post("/predict", json=payload)
        assert r.status_code == 422
