# PROMPTS.md — Journal des interactions IA

Ce fichier est **obligatoire** selon la charte IA du projet.  
Il documente toutes les interactions avec des outils IA, avec justification des choix retenus et des modifications apportées.

---

## Format d'entrée

```
### [DATE] — [MODULE] — [OUTIL IA]
**Prompt :** ...
**Réponse retenue :** ...
**Modifications apportées :** ...
**Justification du choix :** ...
```

---

## Rappel de la charte

| Zone | Règle |
|------|-------|
| 🔴 Rouge | IA interdite : Tests unitaires, fonctions EDA de base, première implémentation du prétraitement NLP |
| 🟠 Orange | IA structuration seulement : Configuration DVC/MLflow, débogage de code existant |
| 🟢 Vert | IA libre : Optimisation, Dockerfile, CI/CD, Monitoring, API |

---

## Entrées

### [2026-04-23] — Module 6 MLOps — Claude (Anthropic)

**Zone :** 🟢 Vert (Dockerfile, CI/CD, API)

**Prompt :**
> Génère la structure complète du Module 6 MLOps pour le projet Eco-Smart Classifier : FastAPI, Dockerfile, docker-compose, GitHub Actions CI/CD, et tests pytest.

**Réponse retenue :** Structure complète avec `app/main.py`, `scripts/train.py`, `Dockerfile` multi-stage, `docker-compose.yml` avec MLflow, `tests/test_pipeline.py`, `.github/workflows/ci.yml`.

**Modifications apportées :**
- Adaptation des colonnes (`NUM_COLS`, `CAT_COLS`, `TEXT_COL`) au dataset réel `dataset_ProjetML_2026.csv`
- Ajout de la validation `ge=0` sur les champs numériques dans le schéma Pydantic
- Séparation stricte entre la fonction `preprocess_text` (🔴 zone rouge, écrite manuellement) et l'API (🟢 zone verte)

**Justification du choix :**
- Dockerfile multi-stage retenu pour réduire la taille de l'image finale (builder ≠ runtime)
- `LogisticRegression` choisi comme modèle de base de l'API (rapide, interprétable, bon F1 observé en Module 5)
- Tests API via `TestClient` FastAPI plutôt qu'un vrai serveur : plus rapide, pas de dépendance réseau

---

_(Ajouter une entrée par interaction IA significative)_
