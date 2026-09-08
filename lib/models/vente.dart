enum ModePaiement { especes, cb, cheque, wero, paypal, autre, ticketRestaurant }

extension ModePaiementX on ModePaiement {
  /// Préfixe utilisé dans le libellé (ex: "CB_26_07_2026_01")
  String get prefixe {
    switch (this) {
      case ModePaiement.especes:
        return "ESP";
      case ModePaiement.cb:
        return "CB";
      case ModePaiement.cheque:
        return "CHQ";
      case ModePaiement.wero:
        return "WERO";
      case ModePaiement.paypal:
        return "PAYPAL";
      case ModePaiement.autre:
        return "AUTRE";
      case ModePaiement.ticketRestaurant:
        return "TR";
    }
  }

  String get label {
    switch (this) {
      case ModePaiement.especes:
        return "Espèces";
      case ModePaiement.cb:
        return "Carte bleue";
      case ModePaiement.cheque:
        return "Chèque";
      case ModePaiement.wero:
        return "Wero";
      case ModePaiement.paypal:
        return "PayPal";
      case ModePaiement.autre:
        return "Autre";
      case ModePaiement.ticketRestaurant:
        return "Tickets restaurant";
    }
  }

  static ModePaiement fromPrefixe(String p) {
    switch (p) {
      case "ESP":
        return ModePaiement.especes;
      case "CB":
        return ModePaiement.cb;
      case "CHQ":
        return ModePaiement.cheque;
      case "WERO":
        return ModePaiement.wero;
      case "PAYPAL":
        return ModePaiement.paypal;
      case "AUTRE":
        return ModePaiement.autre;
      case "TR":
        return ModePaiement.ticketRestaurant;
      default:
        return ModePaiement.especes;
    }
  }
}

class VenteItem {
  String produitId;
  String nom;
  double prixUnitaire;
  int quantite;

  /// Nombre d'exemplaires offerts sur cette ligne (offre commerciale, ex :
  /// 1 pizza gratuite sur 2 commandées). `prixUnitaire` garde le prix carte
  /// d'origine pour garder une trace, mais seuls les exemplaires NON offerts
  /// sont comptés dans le sous-total (donc dans la recette comptabilisée).
  /// Toujours compris entre 0 et `quantite`.
  int quantiteOfferte;

  /// Catégorie du produit au moment de la vente (ex: "Pizza"), enregistrée
  /// telle quelle pour que les statistiques restent fiables même si le
  /// produit est ensuite renommé/supprimé de la carte.
  String categorie;

  VenteItem({
    required this.produitId,
    required this.nom,
    required this.prixUnitaire,
    required this.quantite,
    this.quantiteOfferte = 0,
    this.categorie = "",
  });

  /// Compat : true si au moins un exemplaire de la ligne est offert.
  bool get offert => quantiteOfferte > 0;

  double get sousTotal => prixUnitaire * (quantite - quantiteOfferte);

  Map<String, dynamic> toMap() => {
        "pid": produitId,
        "nom": nom,
        "pu": prixUnitaire,
        "q": quantite,
        "off": quantiteOfferte,
        "cat": categorie,
      };

  factory VenteItem.fromMap(Map<String, dynamic> m) {
    final quantite = (m["q"] as num?)?.toInt() ?? 1;
    final rawOff = m["off"];
    // Compat : les ventes créées avant ce changement stockaient un booléen
    // (toute la ligne offerte ou rien). On convertit "true" en "toute la
    // quantité offerte" pour ne pas modifier le total des ventes passées.
    final quantiteOfferte = (rawOff is bool)
        ? (rawOff ? quantite : 0)
        : (rawOff as num?)?.toInt() ?? 0;

    return VenteItem(
      produitId: m["pid"] ?? "",
      nom: m["nom"] ?? "",
      prixUnitaire: (m["pu"] as num?)?.toDouble() ?? 0,
      quantite: quantite,
      // clamp() plante si quantite est négatif (ex: un remboursement PayPal,
      // où Zettle renvoie une quantité négative) — on protège ce cas au lieu
      // de laisser toute l'appli planter au démarrage.
      quantiteOfferte: quantite <= 0 ? 0 : quantiteOfferte.clamp(0, quantite),
      categorie: m["cat"] ?? "",
    );
  }
}

class Vente {
  String id;
  DateTime date;
  ModePaiement mode;
  int numero;
  String label;
  List<VenteItem> items;
  double total;
  String banque;

  /// id de l'Operation (recette) liée dans le calendrier compta
  String? operationId;

  /// Origine de la vente : "manuel" (saisie dans l'app) ou "paypal" (import
  /// du rapport de caisse). Sert à afficher un badge et à filtrer.
  String source;

  /// Référence externe unique (ex: "paypal_4581" = n° de reçu PayPal) qui
  /// permet de détecter qu'un import a déjà été fait et d'éviter les doublons
  /// si le même rapport (ou une période qui se chevauche) est réimporté.
  String? refExterne;

  /// Remise totale appliquée sur cette vente (ex: offre commerciale). Les
  /// articles ([items]) gardent leur prix plein de carte ; [total] est ce
  /// qui a réellement été payé (= somme des articles - [remise]).
  double remise;

  Vente({
    required this.id,
    required this.date,
    required this.mode,
    required this.numero,
    required this.label,
    required this.items,
    required this.total,
    required this.banque,
    this.operationId,
    this.source = "manuel",
    this.refExterne,
    this.remise = 0,
  });

  Map<String, dynamic> toMap() => {
        "id": id,
        "dt": date.toIso8601String(),
        "mode": mode.index,
        "num": numero,
        "lbl": label,
        "items": items.map((e) => e.toMap()).toList(),
        "tot": total,
        "b": banque,
        "opid": operationId,
        "src": source,
        "ref": refExterne,
        "rem": remise,
      };

  factory Vente.fromMap(Map<String, dynamic> m) => Vente(
        id: m["id"] ?? "",
        date: DateTime.tryParse(m["dt"] ?? "") ?? DateTime.now(),
        mode: (m["mode"] is int &&
                m["mode"] >= 0 &&
                m["mode"] < ModePaiement.values.length)
            ? ModePaiement.values[m["mode"]]
            : ModePaiement.especes,
        numero: (m["num"] as num?)?.toInt() ?? 1,
        label: m["lbl"] ?? "",
        items: (m["items"] is List)
            ? (m["items"] as List)
                .whereType<Map>()
                .map((x) => VenteItem.fromMap(Map<String, dynamic>.from(x)))
                .toList()
            : [],
        total: (m["tot"] as num?)?.toDouble() ?? 0,
        banque: m["b"] ?? "",
        operationId: m["opid"],
        source: m["src"] ?? "manuel",
        refExterne: m["ref"],
        remise: (m["rem"] as num?)?.toDouble() ?? 0,
      );
}
