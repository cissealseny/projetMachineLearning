class PredictRequest {
  PredictRequest({
    required this.poids,
    required this.volume,
    required this.conductivite,
    required this.opacite,
    required this.rigidite,
    required this.prixRevente,
    required this.source,
    required this.rapportCollecte,
  });

  final double poids;
  final double volume;
  final double conductivite;
  final double opacite;
  final double rigidite;
  final double prixRevente;
  final String source;
  final String rapportCollecte;

  Map<String, dynamic> toJson() {
    return {
      'Poids': poids,
      'Volume': volume,
      'Conductivite': conductivite,
      'Opacite': opacite,
      'Rigidite': rigidite,
      'Prix_Revente': prixRevente,
      'Source': source,
      'Rapport_Collecte': rapportCollecte,
    };
  }
}

class PredictResponse {
  PredictResponse({
    required this.categorie,
    required this.probabilites,
    required this.texteClean,
  });

  final String categorie;
  final Map<String, dynamic> probabilites;
  final String texteClean;

  factory PredictResponse.fromJson(Map<String, dynamic> json) {
    return PredictResponse(
      categorie: (json['categorie'] ?? '').toString(),
      probabilites: (json['probabilites'] as Map<String, dynamic>? ?? {}),
      texteClean: (json['texte_clean'] ?? '').toString(),
    );
  }
}
