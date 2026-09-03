# Gestion Compta (com.tomtom.gestioncompta)

## 1. Créer le projet Flutter

Dans le terminal de VS Code, à l'endroit où tu veux créer le dossier du projet :

```
flutter create --org com.tomtom --project-name gestioncompta gestioncompta
```

Cela génère un projet complet (android/, ios/, etc.) avec le nom de package
`com.tomtom.gestioncompta`.

## 2. Copier les fichiers de ce zip

Une fois le projet généré, copie/écrase dans le dossier `gestioncompta` :

- `pubspec.yaml` (remplace celui généré par `flutter create`)
- le dossier `lib/` en entier (remplace celui généré par `flutter create`)

## 3. Installer les dépendances

```
cd gestioncompta
flutter pub get
```

## 4. Lancer sur ton téléphone

```
flutter run
```

## Fonctionnement de l'app

- **Onglet Calendrier** : identique à l'app "comptes" (solde réel, solde
  pointé, pointage par jour, opérations récurrentes...). Le bouton "+"
  propose soit une "Nouvelle vente" (panier de produits), soit une
  "Opération manuelle" (ex : courses chez Métro à 588,88 €).
- **Nouvelle vente** : grille d'articles façon "La Casita" (au lieu d'un
  panier envoyé par WhatsApp, on choisit une date — modifiable — et un mode
  de paiement (Espèces / CB / Chèque / Wero), puis on valide. Une recette
  est automatiquement créée dans le calendrier avec un libellé du type
  `CB_26_07_2026_01` (numéro incrémenté par mode de paiement et par jour).
- **Onglet Ventes** : récapitulatif de toutes les ventes ; cliquer sur une
  ligne (ex: `CB_26_07_2026_01`) ouvre le détail des articles achetés.
- **Réglages** : pointer le passé, ajuster le solde, gérer mes produits
  (nom + prix + catégorie), gérer les comptes (ex: Caisse / Banque), export
  et import JSON de toute la comptabilité (bouton "Exporter mes comptes").

## Remarques

- Pas de système de traduction (tout est en français), comme demandé.
- Pas de vérification "installé depuis le Play Store" (contrairement à
  "comptes") pour ne pas bloquer les tests via installation directe de l'APK.
- La première fois, ajoute un compte (ex: "Caisse") puis quelques produits
  dans Réglages > Mes produits avant de faire une vente.
- Icône de l'app : `flutter create` génère l'icône par défaut Flutter. Si tu
  veux ta propre icône, dis-le moi et je peux ajouter `flutter_launcher_icons`
  configuré avec ton image.
