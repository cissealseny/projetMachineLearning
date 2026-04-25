"""
main.py — API REST Eco-Smart Classifier
Endpoints :
  GET  /health       → statut du service
  GET  /info         → métadonnées du modèle (classes, métriques)
  POST /predict      → prédiction à partir des features
  POST /predict/batch → prédiction en lot (liste d'observations)
"""
import unicodedata
import re
import string
from pathlib import Path
from typing import Optional

import joblib
import nltk
import numpy as np
from nltk.corpus import stopwords
from nltk.stem.snowball import FrenchStemmer
from scipy.sparse import hstack, csr_matrix
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

nltk.download("stopwords", quiet=True)

# ── Chargement du modèle ──────────────────────────────────────────────────────
MODEL_PATH = Path(__file__).parent.parent / "models" / "pipeline.joblib"

def load_model():
    if not MODEL_PATH.exists():
        raise FileNotFoundError(
            f"Modèle introuvable : {MODEL_PATH}\n"
            "Lance d'abord : python scripts/train.py"
        )
    return joblib.load(MODEL_PATH)

try:
    BUNDLE = load_model()
except FileNotFoundError as e:
    print(f"[WARNING] {e}")
    BUNDLE = None

# ── NLP (identique au script d'entraînement) ──────────────────────────────────
STOPWORDS_FR     = set(stopwords.words("french"))
STOPWORDS_DOMAIN = {
    "lot", "collecte", "site", "materiau", "materiel", "type",
    "provenance", "volume", "poids", "kg", "litre", "unite",
    "usine", "centre", "tri", "dechets", "dechet", "rapport",
    "reference", "ref", "non", "renseigne", "mesure",
}
STOPWORDS_ALL = STOPWORDS_FR | STOPWORDS_DOMAIN
stemmer = FrenchStemmer()

def preprocess_text(text: str) -> str:
    if not isinstance(text, str):
        return ""
    text = text.lower()
    text = unicodedata.normalize("NFD", text)
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    text = re.sub(r"[" + re.escape(string.punctuation) + r"\d]", " ", text)
    tokens = text.split()
    tokens = [t for t in tokens if t not in STOPWORDS_ALL and len(t) > 2]
    tokens = [stemmer.stem(t) for t in tokens]
    return " ".join(tokens)


# ── Schémas Pydantic ──────────────────────────────────────────────────────────
class PredictRequest(BaseModel):
    Poids:            float          = Field(...,  ge=0,    example=25.0,   description="Poids en kg")
    Volume:           float          = Field(...,  ge=0,    example=50.0,   description="Volume en litres")
    Conductivite:     float          = Field(...,  ge=0,    example=3.5,    description="Conductivité électrique")
    Opacite:          float          = Field(...,  ge=0,    example=0.7,    description="Opacité (0-1)")
    Rigidite:         float          = Field(...,  ge=0,    example=4.2,    description="Rigidité mécanique")
    Prix_Revente:     float          = Field(...,  ge=0,    example=12.0,   description="Prix de revente estimé (€)")
    Source:           str            = Field(...,           example="Usine_A", description="Source de collecte")
    Rapport_Collecte: Optional[str]  = Field(None,          example="Lot plastique récupéré à l'Usine A.")

class PredictResponse(BaseModel):
    categorie:    str
    probabilites: dict[str, float]
    texte_clean:  str

class BatchRequest(BaseModel):
    observations: list[PredictRequest]

class HealthResponse(BaseModel):
    status:      str
    model_ready: bool

class InfoResponse(BaseModel):
    classes:  list[str]
    metrics:  dict
    features: dict


# ── Application ───────────────────────────────────────────────────────────────
app = FastAPI(
    title="Eco-Smart Classifier API",
    description="Classifie les déchets en catégories et estime leur valeur de revente.",
    version="1.0.0",
)


def _predict_one(req: PredictRequest, bundle: dict) -> PredictResponse:
    import pandas as pd

    num_pipe = bundle["num_pipe"]
    cat_pipe = bundle["cat_pipe"]
    tfidf    = bundle["tfidf"]
    clf      = bundle["clf"]

    texte_clean = preprocess_text(req.Rapport_Collecte or "")

    num_data = pd.DataFrame([[
        req.Poids, req.Volume, req.Conductivite,
        req.Opacite, req.Rigidite, req.Prix_Revente
    ]], columns=bundle["num_cols"])
    cat_data = pd.DataFrame([[req.Source]], columns=bundle["cat_cols"])

    X_num = num_pipe.transform(num_data)
    X_cat = cat_pipe.transform(cat_data)
    X_txt = tfidf.transform([texte_clean])
    X     = hstack([csr_matrix(X_num), X_cat, X_txt])

    pred  = clf.predict(X)[0]
    proba = clf.predict_proba(X)[0]

    return PredictResponse(
        categorie=pred,
        probabilites={cls: round(float(p), 4) for cls, p in zip(clf.classes_, proba)},
        texte_clean=texte_clean,
    )


# ── Routes ────────────────────────────────────────────────────────────────────
@app.get("/health", response_model=HealthResponse, tags=["Monitoring"])
def health():
    return HealthResponse(status="ok", model_ready=BUNDLE is not None)


@app.get("/info", response_model=InfoResponse, tags=["Monitoring"])
def info():
    if BUNDLE is None:
        raise HTTPException(503, "Modèle non chargé")
    return InfoResponse(
        classes=BUNDLE["classes"],
        metrics=BUNDLE["metrics"],
        features={"numeriques": BUNDLE["num_cols"], "categorielles": BUNDLE["cat_cols"]},
    )


@app.post("/predict", response_model=PredictResponse, tags=["Prédiction"])
def predict(req: PredictRequest):
    if BUNDLE is None:
        raise HTTPException(503, "Modèle non chargé — lance scripts/train.py d'abord")
    try:
        return _predict_one(req, BUNDLE)
    except Exception as e:
        raise HTTPException(500, f"Erreur de prédiction : {e}")


@app.post("/predict/batch", response_model=list[PredictResponse], tags=["Prédiction"])
def predict_batch(req: BatchRequest):
    if BUNDLE is None:
        raise HTTPException(503, "Modèle non chargé")
    if len(req.observations) > 100:
        raise HTTPException(400, "Maximum 100 observations par requête batch")
    try:
        return [_predict_one(obs, BUNDLE) for obs in req.observations]
    except Exception as e:
        raise HTTPException(500, f"Erreur batch : {e}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
