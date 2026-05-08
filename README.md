# Eco-Smart Classifier — MLOps Pipeline

Classifie des déchets en catégories et estime leur valeur de revente, à partir de features numériques, catégorielles et textuelles.

## Démarrage rapide (3 commandes)

```bash
# 1. Installer les dépendances
pip install -r requirements.txt

# 2. Entraîner le modèle
python scripts/train.py --data notebooks/dataset_ProjetML_2026.csv

# 3. Lancer l'API
uvicorn app.main:app --reload
```

L'API est disponible sur **http://localhost:8000**  
Documentation interactive : **http://localhost:8000/docs**

---

## Avec Docker

```bash
# Build + démarrage (API + MLflow UI)
docker-compose up --build

# API  → http://localhost:8000
# MLflow UI → http://localhost:5000
```

---

## Lancer les tests

```bash
pytest tests/ --cov=app --cov=scripts --cov-report=term-missing -v
```

---

## Pipeline DVC

```bash
# Initialiser DVC (une seule fois)
dvc init

# Rejouer le pipeline
dvc repro
```

---

## Structure du projet

```
ecosmart/
├── app/
│   └── main.py              # API FastAPI (/health, /info, /predict)
├── backend/                 # Passerelle Django pour Flutter
├── frontend_flutter/        # Application mobile Flutter
├── scripts/
│   └── train.py             # Script d'entraînement + sauvegarde modèle
├── tests/
│   ├── test_pipeline.py     # Tests pytest (schéma, imputation, NLP, API...)
│   └── test_train_script.py # Tests du script d'entraînement
├── models/
│   └── pipeline.joblib      # Modèle sérialisé (généré par train.py)
├── notebooks/
│   └── starter_ml_pipeline_cleanee.ipynb
├── docs/
│   ├── 2026-Cahier des Charges Projet ML_VF.pdf
│   └── PLAN_ACTION_ML.md
├── mlruns/                  # Expériences MLflow (généré automatiquement)
├── .github/workflows/
│   └── ci.yml               # CI/CD GitHub Actions
├── .gitignore
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
└── PROMPTS.md               # Journal des interactions IA (obligatoire)
```

---

## Endpoints API

| Méthode | Route | Description |
|---------|-------|-------------|
| GET | `/health` | Statut du service et du modèle |
| GET | `/info` | Classes, métriques, features |
| POST | `/predict` | Prédiction sur une observation |
| POST | `/predict/batch` | Prédiction en lot (≤ 100 obs.) |

### Exemple de requête `/predict`

```bash
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "Poids": 25.0,
    "Volume": 50.0,
    "Conductivite": 3.5,
    "Opacite": 0.7,
    "Rigidite": 4.2,
    "Prix_Revente": 12.0,
    "Source": "Usine_A",
    "Rapport_Collecte": "Lot de plastique récupéré à l Usine A."
  }'
```

### Réponse

```json
{
  "categorie": "Plastique",
  "probabilites": {
    "Carton": 0.04,
    "Metal": 0.08,
    "Plastique": 0.82,
    "Verre": 0.06
  },
  "texte_clean": "plast recuper"
}
```

---

## CI/CD

Le pipeline GitHub Actions (`.github/workflows/ci.yml`) déclenche à chaque push :
1. **Lint** : `black`, `flake8`, `isort`
2. **Tests** : pytest avec coverage ≥ 70%
3. **Docker** : build + test de l'endpoint `/health`
