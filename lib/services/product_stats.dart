import '../models/produit.dart';
import '../models/vente.dart';

String normaliserNomProduit(String texte) {
  const accents = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ';
  const lettres = 'aaaaaaceeeeiiiinooooouuuuyy';
  var resultat = texte.toLowerCase().trim();
  for (var i = 0; i < accents.length; i++) {
    resultat = resultat.replaceAll(accents[i], lettres[i]);
  }
  return resultat.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

final _nomBoisson = RegExp(
  r'^(canettes?|boissons?|sodas?|eau|eaux|jus|bieres?|vins?|cafe|cafes|'
  r'thes?(?=$| (?:glace|chaud|vert|noir|a la menthe)(?: |$))|infusions?|limonades?|diabolos?|sirops?|cidres?|'
  r'champagnes?|cocktails?|aperitifs?|whisk(?:y|ies)|rhum|vodka|'
  r'bouteilles? (?:d |de )?(?:eau|biere|vin|soda|jus)|coca(?: cola)?|'
  r'pepsi|fanta|sprite|schweppes|orangina|oasis|ice tea|iced tea|'
  r'lipton|fuzetea|fuze tea|perrier|badoit|san pellegrino|'
  r'heineken|desperados|1664|kronenbourg|red bull)(?: |$)',
);

/// La catégorie enregistrée reste prioritaire. Pour les anciens imports
/// sans catégorie, utiliser le catalogue, puis les noms de boissons connus.
String categoriePourStatistiques({
  required String nom,
  String categorie = '',
  String categorieCatalogue = '',
}) {
  bool generique(String valeur) => const {
    '',
    'general',
    'produit',
    'produits',
    'libre',
    'non classe',
  }.contains(normaliserNomProduit(valeur));

  var effective = categorie.trim();
  if (generique(effective) && !generique(categorieCatalogue)) {
    effective = categorieCatalogue.trim();
  }
  final cat = normaliserNomProduit(effective);
  final nomNormalise = normaliserNomProduit(nom);
  if (cat.contains('suppl') || nomNormalise.contains('suppl')) {
    return 'Supplément';
  }
  if (cat.contains('boisson') ||
      _nomBoisson.hasMatch(cat) ||
      const {
        'alcool',
        'sans alcool',
        'soft',
        'softs',
        'drink',
        'drinks',
      }.contains(cat)) {
    return 'Boissons';
  }
  if (generique(effective) && _nomBoisson.hasMatch(nomNormalise)) {
    return 'Boissons';
  }
  return effective.isEmpty ? 'Non classé' : effective;
}

class StatProduit {
  final String nom;
  final String categorie;
  int quantite = 0;
  double chiffreAffaires = 0;

  StatProduit(this.nom, this.categorie);
}

List<StatProduit> statistiquesProduits(
  Iterable<Vente> ventes, {
  bool boissons = false,
  Iterable<Produit> produits = const [],
}) {
  final parId = {for (final p in produits) p.id: p};
  final parNomCatalogue = {
    for (final p in produits) normaliserNomProduit(p.nom): p,
  };
  final parNom = <String, StatProduit>{};
  for (final vente in ventes) {
    for (final item in vente.items) {
      // PayPal ajoute la variante au nom : "Coca (33 cl)".
      final nomSansVariante = item.nom.replaceFirst(
        RegExp(r'\s*\([^)]*\)$'),
        '',
      );
      final produit =
          (item.produitId.isEmpty ? null : parId[item.produitId]) ??
          parNomCatalogue[normaliserNomProduit(item.nom)] ??
          parNomCatalogue[normaliserNomProduit(nomSansVariante)];
      final categorie = categoriePourStatistiques(
        nom: item.nom,
        categorie: item.categorie,
        categorieCatalogue: produit?.categorie ?? '',
      );
      if (categorie == 'Supplément') continue;
      if ((categorie == 'Boissons') != boissons) continue;

      final ligne = parNom.putIfAbsent(
        item.nom,
        () => StatProduit(item.nom, categorie),
      );
      ligne.quantite += item.quantite;
      ligne.chiffreAffaires += item.sousTotal;
    }
  }
  return parNom.values.toList();
}
