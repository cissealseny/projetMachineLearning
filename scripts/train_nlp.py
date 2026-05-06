"""
train_nlp.py — Entraîne un pipeline NLP-only (texte uniquement).
Usage : python scripts/train_nlp.py --data dataset_ProjetML_2026.csv

Ce modèle est utilisé exclusivement par l'endpoint /predict/nlp.
Il n'utilise QUE la colonne Rapport_Collecte pour prédire la catégorie.
"""
import argparse
import unicodedata
import joblib
import re
import string
from pathlib import Path

import pandas as pd
import nltk
from nltk.corpus import stopwords
from nltk.stem.snowball import FrenchStemmer
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import f1_score, accuracy_score, classification_report
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline

nltk.download("stopwords", quiet=True)

# ── Constantes ────────────────────────────────────────────────────────────────
RANDOM_STATE = 42
TRAIN_RATIO  = 0.70
TARGET       = "Categorie"
TEXT_COL     = "Rapport_Collecte"
NA_VALUES    = ["", " ", "NA", "N/A", "null", "None", "non mesure", "non mesure kg"]

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


def train_nlp(data_path: str, model_dir: str = "models"):
    print(f"[train_nlp] Chargement de {data_path}")
    df = pd.read_csv(data_path, na_values=NA_VALUES)

    # Garder uniquement les lignes avec texte ET cible
    data = df.dropna(subset=[TARGET, TEXT_COL]).copy()
    data = data[data[TEXT_COL].str.strip() != ""]

    data["texte_clean"] = data[TEXT_COL].apply(preprocess_text)

    # Supprimer les lignes où le texte est vide après prétraitement
    data = data[data["texte_clean"].str.strip() != ""]

    X = data["texte_clean"]
    y = data[TARGET].astype(str)

    print(f"[train_nlp] Dataset NLP : {len(X)} lignes")
    print(f"[train_nlp] Distribution des classes :\n{y.value_counts()}")

    # Split 70 / 15 / 15
    X_train, X_tmp, y_train, y_tmp = train_test_split(
        X, y, test_size=1 - TRAIN_RATIO, random_state=RANDOM_STATE, stratify=y
    )
    X_val, X_test, y_val, y_test = train_test_split(
        X_tmp, y_tmp, test_size=0.5, random_state=RANDOM_STATE, stratify=y_tmp
    )
    print(f"[train_nlp] Train={len(X_train)} | Val={len(X_val)} | Test={len(X_test)}")

    # Pipeline NLP-only : TF-IDF → LogisticRegression
    nlp_pipeline = Pipeline([
        ("tfidf", TfidfVectorizer(
            max_features=8000,
            ngram_range=(1, 3),       # unigrammes + bigrammes + trigrammes
            sublinear_tf=True,        # log(tf) → réduit l'impact des mots très fréquents
            min_df=2,                 # ignorer les mots qui apparaissent < 2 fois
        )),
        ("clf", LogisticRegression(
            max_iter=3000,
            random_state=RANDOM_STATE,
            C=5.0,                    # plus de régularisation pour le texte seul
            class_weight="balanced",  # compense les classes déséquilibrées
            solver="lbfgs",
            multi_class="multinomial",
        )),
    ])

    nlp_pipeline.fit(X_train, y_train)

    f1_val  = f1_score(y_val,  nlp_pipeline.predict(X_val),  average="macro")
    f1_test = f1_score(y_test, nlp_pipeline.predict(X_test), average="macro")
    acc     = accuracy_score(y_test, nlp_pipeline.predict(X_test))

    print(f"[train_nlp] F1 val={f1_val:.4f} | F1 test={f1_test:.4f} | Acc={acc:.4f}")
    print(classification_report(y_test, nlp_pipeline.predict(X_test)))

    # Sauvegarde
    Path(model_dir).mkdir(exist_ok=True)
    bundle_nlp = {
        "pipeline":    nlp_pipeline,
        "classes":     list(nlp_pipeline.classes_),
        "metrics": {
            "f1_val":   f1_val,
            "f1_test":  f1_test,
            "accuracy": acc,
        },
    }
    out = Path(model_dir) / "pipeline_nlp.joblib"
    joblib.dump(bundle_nlp, out)
    print(f"[train_nlp] Modèle NLP sauvegardé → {out}")
    return bundle_nlp


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--data",      default="dataset_ProjetML_2026.csv")
    parser.add_argument("--model-dir", default="models")
    args = parser.parse_args()
    train_nlp(args.data, args.model_dir)
