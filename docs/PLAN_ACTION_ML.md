# Plan d'action ML (ordre recommande)

## 1. Comprendre la consigne
- Lire le cahier des charges.
- Identifier la cible demandee:
  - `Categorie` -> classification
  - `Prix_Revente` -> regression
- Noter les livrables imposes (notebook, rapport, slides, etc.).

## 2. Inspection rapide des donnees
- Ouvrir `dataset_ProjetML_2026.csv`.
- Verifier:
  - dimensions (lignes, colonnes)
  - types de variables
  - taux de valeurs manquantes
  - classes de `Categorie` (si classification)

## 3. Nettoyage
- Uniformiser les valeurs manquantes.
- Imputer:
  - numeriques -> mediane
  - categorielle/texte -> valeur la plus frequente ou chaine vide
- Supprimer les lignes sans cible.

## 4. Preprocessing
- Numeriques: imputation + standardisation.
- Categorielle: OneHotEncoder.
- Texte `Rapport`: TF-IDF (optionnel mais recommande).

## 5. Separation train/test
- Faire un split 80/20.
- `stratify=y` si classification.
- Fixer `random_state` pour reproduire les resultats.

## 6. Baseline
- Classification:
  - Logistic Regression
  - Random Forest
- Regression:
  - Linear Regression
  - Random Forest Regressor

## 7. Evaluation
- Classification:
  - accuracy
  - f1 macro
  - matrice de confusion
- Regression:
  - MAE
  - RMSE
  - R2

## 8. Optimisation
- Faire un `GridSearchCV` sur le meilleur modele.
- Comparer avant/apres optimisation.

## 9. Interpretation
- Montrer les variables importantes.
- Expliquer les erreurs typiques.
- Donner les limites du modele.

## 10. Rendu final
- Notebook propre et execute.
- Rapport court:
  - objectif
  - methode
  - resultats
  - conclusion metier

---

## Checklist rapide
- [ ] Cible confirmee
- [ ] EDA faite
- [ ] Donnees nettoyees
- [ ] Baseline entrainee
- [ ] Metriques calculees
- [ ] Modele optimise
- [ ] Analyse des erreurs
- [ ] Notebook final propre
