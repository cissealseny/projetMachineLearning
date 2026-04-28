import argparse
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LinearRegression, LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    mean_absolute_error,
    mean_squared_error,
    r2_score,
)
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor


def build_preprocessor(df: pd.DataFrame, target_col: str) -> ColumnTransformer:
    text_col = "Rapport" if "Rapport" in df.columns else None

    feature_cols = [c for c in df.columns if c != target_col]
    numeric_cols = [c for c in feature_cols if pd.api.types.is_numeric_dtype(df[c])]
    categorical_cols = [
        c
        for c in feature_cols
        if c not in numeric_cols and c != text_col
    ]

    numeric_pipe = Pipeline(
        steps=[
            ("imputer", SimpleImputer(strategy="median")),
            ("scaler", StandardScaler()),
        ]
    )

    categorical_pipe = Pipeline(
        steps=[
            ("imputer", SimpleImputer(strategy="most_frequent")),
            ("onehot", OneHotEncoder(handle_unknown="ignore")),
        ]
    )

    transformers = [
        ("num", numeric_pipe, numeric_cols),
        ("cat", categorical_pipe, categorical_cols),
    ]

    if text_col:
        transformers.append(
            (
                "txt",
                Pipeline(
                    steps=[
                        ("imputer", SimpleImputer(strategy="constant", fill_value="")),
                        ("tfidf", TfidfVectorizer(max_features=1000, ngram_range=(1, 2))),
                    ]
                ),
                text_col,
            )
        )

    return ColumnTransformer(transformers=transformers)


def run_classification(df: pd.DataFrame, target_col: str) -> None:
    df = df.dropna(subset=[target_col]).copy()
    X = df.drop(columns=[target_col])
    y = df[target_col].astype(str)

    preprocessor = build_preprocessor(df, target_col)

    models = {
        "logreg": LogisticRegression(max_iter=2000),
        "rf": RandomForestClassifier(n_estimators=300, random_state=42),
    }

    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=0.2,
        random_state=42,
        stratify=y,
    )

    best_name = None
    best_f1 = -1.0

    for name, model in models.items():
        pipe = Pipeline(
            steps=[
                ("prep", preprocessor),
                ("model", model),
            ]
        )
        pipe.fit(X_train, y_train)
        pred = pipe.predict(X_test)

        acc = accuracy_score(y_test, pred)
        f1 = f1_score(y_test, pred, average="macro")

        print(f"\n=== {name} ===")
        print(f"Accuracy: {acc:.4f}")
        print(f"F1 macro: {f1:.4f}")
        print("Confusion matrix:")
        print(confusion_matrix(y_test, pred))
        print("Classification report:")
        print(classification_report(y_test, pred))

        if f1 > best_f1:
            best_f1 = f1
            best_name = name

    print(f"\nBest model (F1 macro): {best_name} -> {best_f1:.4f}")


def run_regression(df: pd.DataFrame, target_col: str) -> None:
    df = df.dropna(subset=[target_col]).copy()
    X = df.drop(columns=[target_col])
    y = pd.to_numeric(df[target_col], errors="coerce")

    mask = y.notna()
    X = X[mask]
    y = y[mask]

    preprocessor = build_preprocessor(df.loc[mask], target_col)

    models = {
        "linreg": LinearRegression(),
        "rf_reg": RandomForestRegressor(n_estimators=300, random_state=42),
    }

    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=0.2,
        random_state=42,
    )

    best_name = None
    best_rmse = np.inf

    for name, model in models.items():
        pipe = Pipeline(
            steps=[
                ("prep", preprocessor),
                ("model", model),
            ]
        )
        pipe.fit(X_train, y_train)
        pred = pipe.predict(X_test)

        mae = mean_absolute_error(y_test, pred)
        rmse = np.sqrt(mean_squared_error(y_test, pred))
        r2 = r2_score(y_test, pred)

        print(f"\n=== {name} ===")
        print(f"MAE: {mae:.4f}")
        print(f"RMSE: {rmse:.4f}")
        print(f"R2: {r2:.4f}")

        if rmse < best_rmse:
            best_rmse = rmse
            best_name = name

    print(f"\nBest model (RMSE): {best_name} -> {best_rmse:.4f}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Starter pipeline for Projet ML")
    parser.add_argument(
        "--data",
        type=str,
        default="dataset_ProjetML_2026.csv",
        help="Path to CSV dataset",
    )
    parser.add_argument(
        "--task",
        type=str,
        choices=["classification", "regression"],
        required=True,
        help="Task type",
    )
    parser.add_argument(
        "--target",
        type=str,
        required=True,
        help="Target column name",
    )
    args = parser.parse_args()

    data_path = Path(args.data)
    if not data_path.exists():
        raise FileNotFoundError(f"Dataset not found: {data_path}")

    df = pd.read_csv(
        data_path,
        na_values=["", " ", "NA", "N/A", "null", "None", "non mesure", "non mesure kg"],
    )

    if args.target not in df.columns:
        raise ValueError(f"Target '{args.target}' not found in columns: {list(df.columns)}")

    print(f"Dataset shape: {df.shape}")
    print(f"Task: {args.task}")
    print(f"Target: {args.target}")

    if args.task == "classification":
        run_classification(df, args.target)
    else:
        run_regression(df, args.target)


if __name__ == "__main__":
    main()
