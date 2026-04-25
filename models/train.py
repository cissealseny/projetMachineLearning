"""
train.py — Entraîne le pipeline multimodal et sauvegarde le modèle.
Usage : python scripts/train.py --data dataset_ProjetML_2026.csv
"""
import argparse
import unicodedata
import joblib
import re
import string
from pathlib import Path

import numpy as np
import pandas as pd
import nltk
from nltk.corpus import stopwords
from nltk.stem.snowball import FrenchStemmer
from scipy.sparse import hstack, csr_matrix
from sklearn.experimental import enable_iterative_imputer  # noqa
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.impute import SimpleImputer, KNNImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import f1_score, accuracy_score, classification_report
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.ensemble import RandomForestClassifier

nltk.download("stopwords", quiet=True)

# ── Constantes ────────────────────────────────────────────────────────────────
RANDOM_STATE = 42
TRAIN_RATIO  = 0.70
TARGET       = "Categorie"
NUM_COLS     = ["Poids", "Volume", "Conductivite", "Opacite", "Rigidite", "Prix_Revente"]
CAT_COLS     = ["Source"]
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


# ── NLP ────────────────────────────────────────────────────────────────────────
def preprocess_text(text: str) -> str:
    """Pipeline NLP : minuscules → accents → ponctuation → stopwords → stemming."""
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


# ── Nettoyage ─────────────────────────────────────────────────────────────────
def clean_dataset(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    # Imputation KNN sur les colonnes numériques
    imp = KNNImputer(n_neighbors=5)
    df[NUM_COLS] = imp.fit_transform(df[NUM_COLS])
    # Winsorisation IQR
    for col in NUM_COLS:
        q1, q3 = df[col].quantile(0.25), df[col].quantile(0.75)
        iqr = q3 - q1
        df[col] = df[col].clip(q1 - 1.5 * iqr, q3 + 1.5 * iqr)
    return df


# ── Pipeline de features ───────────────────────────────────────────────────────
def build_feature_pipelines():
    num_pipe = Pipeline([
        ("imputer", SimpleImputer(strategy="median")),
        ("scaler",  StandardScaler()),
    ])
    cat_pipe = Pipeline([
        ("imputer", SimpleImputer(strategy="most_frequent")),
        ("onehot",  OneHotEncoder(handle_unknown="ignore", sparse_output=True)),
    ])
    tfidf = TfidfVectorizer(max_features=5000, ngram_range=(1, 2))
    return num_pipe, cat_pipe, tfidf


# ── Entraînement ──────────────────────────────────────────────────────────────
def train(data_path: str, model_dir: str = "models"):
    print(f"[train] Chargement de {data_path}")
    df = pd.read_csv(data_path, na_values=NA_VALUES)
    df = clean_dataset(df)

    # Garder uniquement les lignes avec une cible connue
    data = df.dropna(subset=[TARGET]).copy()
    data[TEXT_COL] = data[TEXT_COL].fillna("").apply(preprocess_text)

    X = data[NUM_COLS + CAT_COLS + [TEXT_COL]]
    y = data[TARGET].astype(str)

    # Split 70 / 15 / 15
    X_train, X_tmp, y_train, y_tmp = train_test_split(
        X, y, test_size=1 - TRAIN_RATIO, random_state=RANDOM_STATE, stratify=y
    )
    X_val, X_test, y_val, y_test = train_test_split(
        X_tmp, y_tmp, test_size=0.5, random_state=RANDOM_STATE, stratify=y_tmp
    )
    print(f"[train] Train={len(X_train)} | Val={len(X_val)} | Test={len(X_test)}")

    # Feature pipelines
    num_pipe, cat_pipe, tfidf = build_feature_pipelines()

    X_tr_num = num_pipe.fit_transform(X_train[NUM_COLS])
    X_va_num = num_pipe.transform(X_val[NUM_COLS])
    X_te_num = num_pipe.transform(X_test[NUM_COLS])

    X_tr_cat = cat_pipe.fit_transform(X_train[CAT_COLS])
    X_va_cat = cat_pipe.transform(X_val[CAT_COLS])
    X_te_cat = cat_pipe.transform(X_test[CAT_COLS])

    X_tr_txt = tfidf.fit_transform(X_train[TEXT_COL])
    X_va_txt = tfidf.transform(X_val[TEXT_COL])
    X_te_txt = tfidf.transform(X_test[TEXT_COL])

    X_tr = hstack([csr_matrix(X_tr_num), X_tr_cat, X_tr_txt])
    X_va = hstack([csr_matrix(X_va_num), X_va_cat, X_va_txt])
    X_te = hstack([csr_matrix(X_te_num), X_te_cat, X_te_txt])

    # Modèle
    clf = LogisticRegression(max_iter=2000, random_state=RANDOM_STATE, C=1.0)
    clf.fit(X_tr, y_train)

    f1_val  = f1_score(y_val,  clf.predict(X_va), average="macro")
    f1_test = f1_score(y_test, clf.predict(X_te), average="macro")
    acc     = accuracy_score(y_test, clf.predict(X_te))
    print(f"[train] F1 val={f1_val:.4f} | F1 test={f1_test:.4f} | Acc test={acc:.4f}")
    print(classification_report(y_test, clf.predict(X_te)))

    assert acc >= 0.70, f"Accuracy {acc:.4f} < seuil 0.70 requis"

    # Sauvegarde
    Path(model_dir).mkdir(exist_ok=True)
    bundle = {
        "clf":      clf,
        "num_pipe": num_pipe,
        "cat_pipe": cat_pipe,
        "tfidf":    tfidf,
        "num_cols": NUM_COLS,
        "cat_cols": CAT_COLS,
        "text_col": TEXT_COL,
        "classes":  list(clf.classes_),
        "metrics":  {"f1_val": f1_val, "f1_test": f1_test, "accuracy": acc},
    }
    out = Path(model_dir) / "pipeline.joblib"
    joblib.dump(bundle, out)
    print(f"[train] Modèle sauvegardé → {out}")
    return bundle


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--data",      default="dataset_ProjetML_2026.csv")
    parser.add_argument("--model-dir", default="models")
    args = parser.parse_args()
    train(args.data, args.model_dir)
