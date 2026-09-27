import 'package:flutter/material.dart';
import '../theme.dart';

import '../services/store.dart';
import '../services/app_config.dart';
import '../services/carte_service.dart';
import '../models/carte_pizza.dart';
import '../models/vente.dart';
import 'produits_screen.dart';

/// Un article affichable dans la liste de vente : soit une pizza venant de
/// la carte en ligne (Google Sheet, partagé avec La Casita), soit un
/// produit géré à la main (boisson, supplément, ...).
class _ItemAffichable {
  final String id;
  final String nom;
  final double prix;
  final String categorie;
  final bool estCarte;
  final List<String> ingredients;

  const _ItemAffichable({
    required this.id,
    required this.nom,
    required this.prix,
    required this.categorie,
    required this.estCarte,
    this.ingredients = const [],
  });

  factory _ItemAffichable.fromVenteItem(VenteItem vi) => _ItemAffichable(
        id: vi.produitId,
        nom: vi.nom,
        prix: vi.prixUnitaire,
        categorie: vi.produitId.startsWith('carte_') ? 'Pizza' : 'Produit',
        estCarte: vi.produitId.startsWith('carte_'),
      );
}

/// Une ligne du panier en cours de constitution.
class _LigneVente {
  final _ItemAffichable item;
  int quantite;

  /// Nombre d'exemplaires offerts sur cette ligne (0..quantite).
  int quantiteOfferte;

  _LigneVente({
    required this.item,
    this.quantite = 0,
    this.quantiteOfferte = 0,
  });
}

class NouvelleVenteScreen extends StatefulWidget {
  final DateTime dateInitiale;

  /// Si renseigné, l'écran passe en mode modification d'une vente existante.
  final Vente? venteAModifier;

  const NouvelleVenteScreen({
    super.key,
    required this.dateInitiale,
    this.venteAModifier,
  });

  @override
  State<NouvelleVenteScreen> createState() => _NouvelleVenteScreenState();
}

class _NouvelleVenteScreenState extends State<NouvelleVenteScreen> {
  /// panier : id article -> ligne
  final Map<String, _LigneVente> _panier = {};
  String? _categorieFiltre;
  final _rechercheCtrl = TextEditingController();
  String _recherche = "";

  List<CartePizza> _pizzasCarte = [];
  bool _chargementCarte = true;

  bool get _modeEdition => widget.venteAModifier != null;

  @override
  void initState() {
    super.initState();
    if (widget.venteAModifier != null) {
      for (final vi in widget.venteAModifier!.items) {
        final item = _ItemAffichable.fromVenteItem(vi);
        _panier[item.id] = _LigneVente(
          item: item,
          quantite: vi.quantite,
          quantiteOfferte: vi.quantiteOfferte,
        );
      }
    }
    _chargerCarte();
  }

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

  Future<void> _chargerCarte() async {
    final pizzas = await CarteService.instance.fetchPizzas();
    if (!mounted) return;
    setState(() {
      _pizzasCarte = pizzas;
      _chargementCarte = false;
    });
  }

  List<_ItemAffichable> _tousLesItems(Store s) {
    final items = <_ItemAffichable>[
      for (final p in _pizzasCarte)
        _ItemAffichable(
          id: p.id,
          nom: p.nom,
          prix: p.prix,
          categorie: p.categorie,
          estCarte: true,
          ingredients: p.ingredients,
        ),
      for (final p in s.produits)
        _ItemAffichable(
          id: p.id,
          nom: p.nom,
          prix: p.prix,
          categorie: p.categorie,
          estCarte: false,
        ),
    ];

    // En édition, garder aussi les articles qui ne sont plus dans la carte.
    for (final ligne in _panier.values) {
      if (!items.any((it) => it.id == ligne.item.id)) {
        items.add(ligne.item);
      }
    }

    return items;
  }

  Color _couleurCategorie(String categorie) {
    switch (categorie.toLowerCase()) {
      case 'tomate':
        return Colors.red.shade700;
      case 'crème':
      case 'creme':
        return Colors.amber.shade600;
      case 'mixte':
        return Colors.orange.shade800;
      default:
        return Colors.blueGrey;
    }
  }

  void _incrementer(_ItemAffichable item) {
    setState(() {
      final existante = _panier[item.id];
      if (existante == null) {
        _panier[item.id] = _LigneVente(item: item, quantite: 1);
      } else {
        existante.quantite += 1;
      }
    });
  }

  void _decrementer(_ItemAffichable item, int qte) {
    setState(() {
      if (qte <= 1) {
        _panier.remove(item.id);
      } else {
        final ligne = _panier[item.id]!;
        ligne.quantite = qte - 1;
        if (ligne.quantiteOfferte > ligne.quantite) {
          ligne.quantiteOfferte = ligne.quantite;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = Store.I;
    final cfg = AppConfig.I;

    final tousLesItems = _tousLesItems(s);

    final categories = <String>{"Tous"};
    for (final it in tousLesItems) {
      categories.add(it.categorie);
    }

    final itemsAffiches = ((_categorieFiltre == null || _categorieFiltre == "Tous")
            ? tousLesItems
            : tousLesItems.where((it) => it.categorie == _categorieFiltre).toList())
        .where((it) =>
            _recherche.isEmpty ||
            it.nom.toLowerCase().contains(_recherche.toLowerCase()))
        .toList();

    final total = _panier.values.fold<double>(
      0,
      (sum, l) => sum + l.item.prix * (l.quantite - l.quantiteOfferte),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_modeEdition ? "Modifier la vente" : "Nouvelle vente"),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.price_change_outlined),
            tooltip: "Montant libre",
            onPressed: () => _ouvrirMontantLibre(context),
          ),
          IconButton(
            icon: Badge(
              label: Text("${_panier.values.fold<int>(0, (a, l) => a + l.quantite)}"),
              isLabelVisible: _panier.isNotEmpty,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            tooltip: "Voir le panier",
            onPressed: _panier.isEmpty ? null : () => _ouvrirPanier(context, s, cfg),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Rafraîchir la carte",
            onPressed: _chargementCarte
                ? null
                : () {
                    setState(() => _chargementCarte = true);
                    _chargerCarte();
                  },
          ),
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: "Gérer mes produits",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProduitsScreen()),
              ).then((_) => setState(() {}));
            },
          ),
        ],
      ),
      body: (tousLesItems.isEmpty && !_chargementCarte)
          ? _aucunProduit(context)
          : Column(
              children: [
                if (_chargementCarte)
                  const LinearProgressIndicator(minHeight: 2, color: kPrimary),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: TextField(
                    controller: _rechercheCtrl,
                    decoration: InputDecoration(
                      hintText: "Rechercher un article...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _recherche.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: "Effacer",
                              onPressed: () {
                                setState(() {
                                  _rechercheCtrl.clear();
                                  _recherche = "";
                                });
                              },
                            ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (v) => setState(() => _recherche = v),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    children: categories.map((c) {
                      final selected = (_categorieFiltre ?? "Tous") == c;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(c),
                          selected: selected,
                          selectedColor: kPrimary.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: selected ? kPrimary : null,
                            fontWeight: selected ? FontWeight.bold : null,
                          ),
                          onSelected: (_) => setState(() => _categorieFiltre = c),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    itemCount: itemsAffiches.length,
                    itemBuilder: (context, index) {
                      final item = itemsAffiches[index];
                      final ligne = _panier[item.id];
                      final qte = ligne?.quantite ?? 0;
                      final qteOfferte = ligne?.quantiteOfferte ?? 0;
                      final offert = qteOfferte > 0;
                      final touteOfferte = qte > 0 && qteOfferte == qte;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: qte > 0 ? 2 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: offert
                                ? Colors.orange
                                : (qte > 0 ? kPrimary : Colors.grey.shade200),
                            width: qte > 0 ? 2 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.nom,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _couleurCategorie(item.categorie),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            item.categorie.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (item.ingredients.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          item.ingredients.join(', '),
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    if (offert)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          touteOfferte
                                              ? (qte > 1
                                                  ? "Toutes offertes"
                                                  : "Offerte")
                                              : "$qteOfferte offerte${qteOfferte > 1 ? 's' : ''} sur $qte",
                                          style: const TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    touteOfferte
                                        ? "0.00 ${cfg.currency}"
                                        : "${item.prix.toStringAsFixed(2)} ${cfg.currency}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: offert ? Colors.orange : Colors.green,
                                      decoration: touteOfferte
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (qte > 0)
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          tooltip: touteOfferte
                                              ? "Annuler les offres"
                                              : (offert
                                                  ? "Offrir un exemplaire de plus"
                                                  : "Offrir un exemplaire"),
                                          icon: Icon(
                                            Icons.card_giftcard,
                                            size: 18,
                                            color: offert
                                                ? Colors.orange
                                                : Colors.grey.shade400,
                                          ),
                                          onPressed: () => setState(() {
                                            final ligne = _panier[item.id]!;
                                            if (ligne.quantiteOfferte >=
                                                ligne.quantite) {
                                              ligne.quantiteOfferte = 0;
                                            } else {
                                              ligne.quantiteOfferte += 1;
                                            }
                                          }),
                                        ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          Icons.remove_circle_outline,
                                          color: qte == 0
                                              ? Colors.grey.shade300
                                              : Colors.red,
                                        ),
                                        onPressed: qte == 0
                                            ? null
                                            : () => _decrementer(item, qte),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Text(
                                          "$qte",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: qte > 0
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: qte > 0 ? kPrimary : null,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(
                                          Icons.add_circle,
                                          color: kPrimary,
                                        ),
                                        onPressed: () => _incrementer(item),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _barrePanier(context, s, cfg, total),
              ],
            ),
    );
  }

  void _ouvrirPanier(BuildContext context, Store s, AppConfig cfg) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final lignes = _panier.values.toList();
            final total = _panier.values.fold<double>(
              0,
              (sum, l) => sum + l.item.prix * (l.quantite - l.quantiteOfferte),
            );

            void rafraichir(void Function() action) {
              setState(action);
              setSheetState(() {});
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (ctx, scrollController) {
                return SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Panier",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),
                      if (lignes.isEmpty)
                        const Expanded(
                          child: Center(child: Text("Panier vide")),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: lignes.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final ligne = lignes[index];
                              final item = ligne.item;
                              final qte = ligne.quantite;
                              final qteOfferte = ligne.quantiteOfferte;
                              final offert = qteOfferte > 0;
                              final touteOfferte = qte > 0 && qteOfferte == qte;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.nom,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            touteOfferte
                                                ? "0.00 ${cfg.currency}"
                                                : "${item.prix.toStringAsFixed(2)} ${cfg.currency} / unité",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: offert ? Colors.orange : Colors.grey.shade600,
                                            ),
                                          ),
                                          if (offert)
                                            Text(
                                              touteOfferte
                                                  ? (qte > 1 ? "Toutes offertes" : "Offerte")
                                                  : "$qteOfferte offerte${qteOfferte > 1 ? 's' : ''} sur $qte",
                                              style: const TextStyle(
                                                color: Colors.orange,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: touteOfferte
                                          ? "Annuler les offres"
                                          : (offert
                                              ? "Offrir un exemplaire de plus"
                                              : "Offrir un exemplaire"),
                                      icon: Icon(
                                        Icons.card_giftcard,
                                        size: 20,
                                        color: offert ? Colors.orange : Colors.grey.shade400,
                                      ),
                                      onPressed: () => rafraichir(() {
                                        if (ligne.quantiteOfferte >= ligne.quantite) {
                                          ligne.quantiteOfferte = 0;
                                        } else {
                                          ligne.quantiteOfferte += 1;
                                        }
                                      }),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                      onPressed: () => rafraichir(() => _decrementer(item, qte)),
                                    ),
                                    Text(
                                      "$qte",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle, color: kPrimary),
                                      onPressed: () => rafraichir(() => _incrementer(item)),
                                    ),
                                    IconButton(
                                      tooltip: "Retirer du panier",
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => rafraichir(() => _panier.remove(item.id)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.grey.shade300)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Total : ${total.toStringAsFixed(2)} ${cfg.currency}",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: lignes.isEmpty
                                  ? null
                                  : () {
                                      Navigator.pop(ctx);
                                      _ouvrirValidation(context, s);
                                    },
                              child: Text(_modeEdition ? "Enregistrer" : "Valider l'achat"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _ouvrirMontantLibre(BuildContext context) {
    final labelCtrl = TextEditingController();
    final montantCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Montant libre",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "Pour un article hors carte (ex: dépannage, produit ponctuel)",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: "Libellé (optionnel)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: montantCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: "Montant",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      final montant = double.tryParse(
                          montantCtrl.text.replaceAll(',', '.'));
                      if (montant == null || montant <= 0) return;

                      final label = labelCtrl.text.trim();
                      final id = "libre_${DateTime.now().millisecondsSinceEpoch}";

                      setState(() {
                        _panier[id] = _LigneVente(
                          item: _ItemAffichable(
                            id: id,
                            nom: label.isEmpty ? "Montant libre" : label,
                            prix: montant,
                            categorie: "Libre",
                            estCarte: false,
                          ),
                          quantite: 1,
                        );
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text("Ajouter au panier"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _aucunProduit(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "La carte est vide et vous n'avez pas encore de produit.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text("Ajouter mes produits"),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProduitsScreen()),
              ).then((_) => setState(() {}));
            },
          ),
        ],
      ),
    );
  }

  Widget _barrePanier(BuildContext context, Store s, AppConfig cfg, double total) {
    final nbArticles = _panier.values.fold<int>(0, (a, l) => a + l.quantite);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("$nbArticles article${nbArticles > 1 ? 's' : ''}"),
                  Text(
                    "${total.toStringAsFixed(2)} ${cfg.currency}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: (nbArticles == 0)
                  ? null
                  : () => _ouvrirValidation(context, s),
              child: Text(_modeEdition ? "Enregistrer" : "Valider l'achat"),
            ),
          ],
        ),
      ),
    );
  }

  void _ouvrirValidation(BuildContext context, Store s) {
    DateTime dateVente =
        widget.venteAModifier?.date ?? widget.dateInitiale;
    ModePaiement? mode = widget.venteAModifier?.mode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: bottomInset + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _modeEdition ? "Modifier la vente" : "Valider l'achat",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today, color: kPrimary),
                      title: Text(
                        "${dateVente.day.toString().padLeft(2, '0')}/"
                        "${dateVente.month.toString().padLeft(2, '0')}/"
                        "${dateVente.year}",
                      ),
                      subtitle: const Text("Date de la vente (modifiable)"),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: dateVente,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setSheetState(() => dateVente = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Mode de paiement",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ModePaiement.values.map((m) {
                        final selected = mode == m;
                        return ChoiceChip(
                          label: Text(m.label),
                          selected: selected,
                          selectedColor: kPrimary.withValues(alpha: 0.2),
                          onSelected: (_) => setSheetState(() => mode = m),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: mode == null
                            ? null
                            : () {
                                final items = _panier.values.map((l) {
                                  return VenteItem(
                                    produitId: l.item.id,
                                    nom: l.item.nom,
                                    prixUnitaire: l.item.prix,
                                    quantite: l.quantite,
                                    quantiteOfferte: l.quantiteOfferte,
                                    categorie: l.item.categorie,
                                  );
                                }).toList();

                                if (_modeEdition) {
                                  s.updateVente(
                                    vente: widget.venteAModifier!,
                                    date: dateVente,
                                    mode: mode!,
                                    items: items,
                                  );
                                  Navigator.pop(ctx);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Vente modifiée : ${widget.venteAModifier!.label}",
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  final vente = s.enregistrerVente(
                                    date: dateVente,
                                    mode: mode!,
                                    items: items,
                                  );
                                  Navigator.pop(ctx);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Vente enregistrée : ${vente.label}",
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                        child: const Text("Confirmer"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
