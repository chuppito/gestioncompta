class Produit {
  String id;
  String nom;
  double prix;
  String categorie;

  Produit({
    required this.id,
    required this.nom,
    required this.prix,
    this.categorie = "Général",
  });

  Map<String, dynamic> toMap() => {
        "id": id,
        "nom": nom,
        "prix": prix,
        "cat": categorie,
      };

  factory Produit.fromMap(Map<String, dynamic> m) {
    return Produit(
      id: m["id"] ?? "",
      nom: m["nom"] ?? "",
      prix: (m["prix"] as num?)?.toDouble() ?? 0,
      categorie: m["cat"] ?? "Général",
    );
  }
}
