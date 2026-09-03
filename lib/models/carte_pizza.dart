/// Une pizza telle que publiée sur la carte (Google Sheet partagé avec
/// l'app La Casita). Contrairement à [Produit], ce n'est pas géré à la main
/// dans Gestion Compta : c'est une simple lecture de la carte en ligne.
class CartePizza {
  final String id;
  final String nom;
  final String categorie;
  final List<String> ingredients;
  final double prix;

  const CartePizza({
    required this.id,
    required this.nom,
    required this.categorie,
    this.ingredients = const [],
    required this.prix,
  });

  Map<String, dynamic> toJson() => {
        "id": id,
        "nom": nom,
        "categorie": categorie,
        "ingredients": ingredients,
        "prix": prix,
      };

  factory CartePizza.fromJson(Map<String, dynamic> json) => CartePizza(
        id: json["id"] as String,
        nom: json["nom"] as String,
        categorie: json["categorie"] as String,
        ingredients: (json["ingredients"] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        prix: (json["prix"] as num).toDouble(),
      );
}
