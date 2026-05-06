"""
main.py — API REST Eco-Smart Classifier
Endpoints :
  GET  /health          → statut du service
  GET  /info            → métadonnées du modèle
  POST /predict         → prédiction multimodale (numérique + texte)
  POST /predict/batch   → prédiction en lot (≤ 100)
  POST /predict/nlp     → prédiction texte uniquement (modèle NLP dédié)
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

# ── Chargement modèles ────────────────────────────────────────────────────────
MODEL_PATH     = Path(__file__).parent.parent / "models" / "pipeline.joblib"
MODEL_NLP_PATH = Path(__file__).parent.parent / "models" / "pipeline_nlp.joblib"

def _load(path: Path):
    if not path.exists():
        print(f"[WARNING] Modèle introuvable : {path}")
        return None
    return joblib.load(path)

BUNDLE     = _load(MODEL_PATH)
BUNDLE_NLP = _load(MODEL_NLP_PATH)

# ── NLP ───────────────────────────────────────────────────────────────────────
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


# ── Schémas ───────────────────────────────────────────────────────────────────
class PredictRequest(BaseModel):
    Poids:            float         = Field(..., ge=0, example=25.0)
    Volume:           float         = Field(..., ge=0, example=50.0)
    Conductivite:     float         = Field(..., ge=0, example=3.5)
    Opacite:          float         = Field(..., ge=0, example=0.7)
    Rigidite:         float         = Field(..., ge=0, example=4.2)
    Prix_Revente:     float         = Field(..., ge=0, example=12.0)
    Source:           str           = Field(...,       example="Usine_A")
    Rapport_Collecte: Optional[str] = Field(None,      example="Lot plastique récupéré.")

class NlpRequest(BaseModel):
    Rapport_Collecte: str = Field(
        ...,
        min_length=3,
        example="Fragments de métal rouillé collectés sur le chantier B.",
    )

class PredictResponse(BaseModel):
    categorie:    str
    probabilites: dict[str, float]
    texte_clean:  str

class NlpResponse(BaseModel):
    categorie:    str
    probabilites: dict[str, float]
    texte_clean:  str
    mode:         str = "nlp_only"
    tokens_count: int
    note:         str

class BatchRequest(BaseModel):
    observations: list[PredictRequest]

class HealthResponse(BaseModel):
    status:          str
    model_ready:     bool
    nlp_model_ready: bool

class InfoResponse(BaseModel):
    classes:  list[str]
    metrics:  dict
    features: dict


# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(title="Eco-Smart Classifier API", version="1.3.0")


def _predict_one(req: PredictRequest, bundle: dict) -> PredictResponse:
    import pandas as pd
    texte_clean = preprocess_text(req.Rapport_Collecte or "")
    num_data = pd.DataFrame([[
        req.Poids, req.Volume, req.Conductivite,
        req.Opacite, req.Rigidite, req.Prix_Revente,
    ]], columns=bundle["num_cols"])
    cat_data = pd.DataFrame([[req.Source]], columns=bundle["cat_cols"])
    X_num = bundle["num_pipe"].transform(num_data)
    X_cat = bundle["cat_pipe"].transform(cat_data)
    X_txt = bundle["tfidf"].transform([texte_clean])
    X     = hstack([csr_matrix(X_num), X_cat, X_txt])
    pred  = bundle["clf"].predict(X)[0]
    proba = bundle["clf"].predict_proba(X)[0]
    return PredictResponse(
        categorie=pred,
        probabilites={c: round(float(p), 4) for c, p in zip(bundle["clf"].classes_, proba)},
        texte_clean=texte_clean,
    )


@app.get("/health", response_model=HealthResponse, tags=["Monitoring"])
def health():
    return HealthResponse(
        status="ok",
        model_ready=BUNDLE is not None,
        nlp_model_ready=BUNDLE_NLP is not None,
    )

@app.get("/info", response_model=InfoResponse, tags=["Monitoring"])
def info():
    if BUNDLE is None:
        raise HTTPException(503, "Modèle multimodal non chargé")
    return InfoResponse(
        classes=BUNDLE["classes"],
        metrics=BUNDLE["metrics"],
        features={"numeriques": BUNDLE["num_cols"], "categorielles": BUNDLE["cat_cols"]},
    )

@app.post("/predict", response_model=PredictResponse, tags=["Prédiction"])
def predict(req: PredictRequest):
    if BUNDLE is None:
        raise HTTPException(503, "Modèle non chargé — lance scripts/train.py")
    try:
        return _predict_one(req, BUNDLE)
    except Exception as e:
        raise HTTPException(500, f"Erreur prédiction : {e}")

@app.post("/predict/nlp", response_model=NlpResponse, tags=["Prédiction"])
def predict_nlp(req: NlpRequest):
    """
    Prédiction NLP-only : modèle entraîné UNIQUEMENT sur le texte Rapport_Collecte.
    Lance d'abord : python scripts/train_nlp.py --data dataset_ProjetML_2026.csv
    """
    if BUNDLE_NLP is None:
        raise HTTPException(
            503,
            "Modèle NLP non chargé. Lance : "
            "python scripts/train_nlp.py --data dataset_ProjetML_2026.csv"
        )
    texte_clean = preprocess_text(req.Rapport_Collecte)
    if not texte_clean.strip():
        raise HTTPException(400, "Texte vide après prétraitement NLP.")
    try:
        pipeline = BUNDLE_NLP["pipeline"]
        pred     = pipeline.predict([texte_clean])[0]
        proba    = pipeline.predict_proba([texte_clean])[0]
        return NlpResponse(
            categorie=pred,
            probabilites={c: round(float(p), 4) for c, p in zip(pipeline.classes_, proba)},
            texte_clean=texte_clean,
            mode="nlp_only",
            tokens_count=len(texte_clean.split()),
            note="Prédiction basée uniquement sur le texte (modèle NLP dédié).",
        )
    except Exception as e:
        raise HTTPException(500, f"Erreur prédiction NLP : {e}")

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
