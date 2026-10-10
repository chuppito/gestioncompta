// Vérifications autonomes : dart tool/check_product_stats.dart
import '../lib/models/produit.dart';
import '../lib/models/vente.dart';
import '../lib/services/product_stats.dart';

int _verifications = 0;

void verifier(bool condition, String message) {
  if (!condition) throw StateError(message);
  _verifications++;
}

VenteItem article(
  String nom, {
  String categorie = '',
  String id = '',
  int quantite = 1,
  double prix = 1,
  int offerts = 0,
}) => VenteItem(
  produitId: id,
  nom: nom,
  prixUnitaire: prix,
  quantite: quantite,
  quantiteOfferte: offerts,
  categorie: categorie,
);

Vente vente(List<VenteItem> items) => Vente(
  id: 'test',
  date: DateTime(2026, 10, 9),
  mode: ModePaiement.cb,
  numero: 1,
  label: 'Test',
  items: items,
  total: items.fold<double>(0, (total, item) => total + item.sousTotal),
  banque: 'Test',
);

void main() {
  for (final nom in [
    'Canette sans alcool',
    'CANETTE AVEC ALCOOL',
    'Canettes (33 cl)',
    'Coca-Cola zéro',
    'Eau pétillante',
    'Jus de pomme',
    'Bière blonde',
    'Vin rosé',
    'Café',
    'Thé glacé',
    'Orangina',
    'Ice tea pêche',
    'Perrier (50 cl)',
    'Bouteille de vin',
    'Cidre',
    'Cocktail maison',
  ]) {
    verifier(categoriePourStatistiques(nom: nom) == 'Boissons', nom);
  }
  for (final categorie in [
    'Boisson',
    'Boissons sans alcool',
    'Bières',
    'Sodas',
    'Vins',
  ]) {
    verifier(
      categoriePourStatistiques(nom: 'Maison', categorie: categorie) ==
          'Boissons',
      'Catégorie $categorie',
    );
  }
  for (final nom in [
    'Burger',
    '5 fromages',
    'Ravioles',
    'Chiquita',
    'Margherita',
    'Regina',
    'Vaison',
    'Pizza au vin',
    'The queen',
    'Oasis tropicale',
  ]) {
    // Un nom de pizza explicite ne doit jamais être remplacé par une
    // correspondance avec un nom de boisson.
    verifier(
      categoriePourStatistiques(nom: nom, categorie: 'Pizza') == 'Pizza',
      'Pizza $nom',
    );
  }
  verifier(
    categoriePourStatistiques(nom: 'Burger') != 'Boissons',
    'Burger sans catégorie',
  );
  verifier(
    categoriePourStatistiques(nom: 'The queen') != 'Boissons',
    'Nom ambigu sans catégorie',
  );

  final v = vente([
    article('5 fromages', quantite: 3, prix: 11),
    article('Canette sans alcool', quantite: 3, prix: 1.5),
    article('Supplément mozzarella', quantite: 2, prix: 1),
    article('Maison', categorie: 'Boissons', quantite: 2, prix: 3),
  ]);
  final pizzas = statistiquesProduits([v]);
  final boissons = statistiquesProduits([v], boissons: true);
  verifier(
    pizzas.length == 1 && pizzas.single.quantite == 3,
    'Les canettes et suppléments sont exclus des pizzas',
  );
  verifier(pizzas.single.chiffreAffaires == 33, 'CA pizzas');
  verifier(
    boissons.fold<int>(0, (total, ligne) => total + ligne.quantite) == 5,
    'Toutes les boissons sont comptées',
  );
  verifier(
    boissons.fold<double>(0, (total, ligne) => total + ligne.chiffreAffaires) ==
        10.5,
    'CA boissons',
  );
  verifier(
    v.total == 45.5 && v.items[1].categorie.isEmpty,
    'Le calcul ne modifie pas les ventes historiques',
  );

  final catalogue = [
    Produit(id: 'b1', nom: 'Spécial maison', prix: 2, categorie: 'Boissons'),
  ];
  final anciennes = vente([
    article('Ancien nom', id: 'b1', categorie: 'Produit'),
    article('SPECIAL MAISON (33 cl)'),
    article('Spécial maison', categorie: 'Pizza'),
  ]);
  verifier(
    statistiquesProduits(
          [anciennes],
          boissons: true,
          produits: catalogue,
        ).length ==
        2,
    'Classement par identifiant et par nom avec variante',
  );
  verifier(
    statistiquesProduits([anciennes], produits: catalogue).single.categorie ==
        'Pizza',
    'Une catégorie historique précise est conservée',
  );

  final mouvements = vente([
    article('Canette sans alcool', quantite: 3, offerts: 1, prix: 1.5),
    article('Canette sans alcool', quantite: -1, prix: 1.5),
  ]);
  final resultat = statistiquesProduits([mouvements], boissons: true).single;
  verifier(
    resultat.quantite == 2 && resultat.chiffreAffaires == 1.5,
    'Les cadeaux et remboursements gardent leur calcul',
  );
  verifier(statistiquesProduits([]).isEmpty, 'Période vide');
  final relu = Vente.fromMap(v.toMap());
  verifier(
    statistiquesProduits([relu], boissons: true).length == 2,
    'Les ventes relues depuis une sauvegarde sont corrigées',
  );
  print('$_verifications vérifications réussies.');
}
