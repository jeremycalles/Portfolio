# Portfolio - Suivi de Portefeuille

[![Licence : PolyForm Noncommercial](https://img.shields.io/badge/License-PolyForm%20Noncommercial-blue.svg)](LICENSE)
[![Plateforme : iOS](https://img.shields.io/badge/Platform-iOS-blue)](https://developer.apple.com/ios/)
[![Plateforme : macOS](https://img.shields.io/badge/Platform-macOS-blue)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange)](https://swift.org)

**Portfolio** est un suivi de portefeuille axé sur la confidentialité pour actions, ETF, OPCVM, métaux précieux, cryptomonnaies et comptes bancaires—avec des applications natives iOS et macOS issues d’**un même code partagé**.

### L’essentiel

- **Vos données restent sur l’appareil** — SQLite local uniquement ; pas de backend ni de télémétrie. Sync iCloud optionnelle via votre compte Apple.
- **Un code, deux apps natives** — Logique partagée (modèles, services, view models, composants UI) dans `Shared/` ; chaque plateforme ajoute sa propre interface et son cycle de vie.
- **Données de marché publiques uniquement** — Les actualisations interrogent des API publiques (symboles/ISIN) ; aucun lien de compte ni donnée personnelle.

---

## Table des Matières

- [Aperçu](#aperçu)
- [Fonctionnalités Clés](#fonctionnalités-clés)
- [Types d'Actifs Supportés](#types-dactifs-supportés)
- [Pour Commencer](#pour-commencer)
- [Guide Utilisateur](#guide-utilisateur)
- [Sources de Données](#sources-de-données)
- [Confidentialité & Sécurité](#confidentialité--sécurité)
- [Automatisation](#automatisation)
- [Développement](#développement)
- [Licence](#licence)

---

## Aperçu

Consolidez tous vos actifs dans une seule vue : suivez actions, ETF, OPCVM, or, crypto et comptes bancaires avec des données précises (VL pour les fonds, primes de marché pour les métaux physiques), conversion multi-devises et consultation hors ligne.

### Captures d'écran

#### macOS

<img src="assets/screenshots/macos-dashboard.png" width="800" />

#### iOS

<p float="left">
  <img src="assets/screenshots/ios-1-dashboard.png" width="200" />
  <img src="assets/screenshots/ios-2-dashboard-quadrants.png" width="200" />
  <img src="assets/screenshots/ios-3-dashboard-accounts.png" width="200" />
  <img src="assets/screenshots/ios-4-quadrants.png" width="200" />
  <img src="assets/screenshots/ios-5-positions.png" width="200" />
</p>

---

## Fonctionnalités Clés

### Gestion de Portefeuille
- **Support Multi-Comptes** : Suivez vos positions sur plusieurs comptes bancaires et courtiers
- **Suivi du Prix de Revient** : Enregistrez les dates et prix d'achat pour des calculs précis de gains/pertes
- **Organisation par Quadrants** : Groupez les instruments par catégorie (Technologie, Métaux Précieux, Revenu Fixe, etc.)

### Analytique & Rapports
- **Comparaison de Performance** : Comparez votre portefeuille sur différentes périodes (1 jour, 1 semaine, 1 mois, 1 an, depuis le début de l'année)
- **Graphiques Interactifs** : Visualisez les tendances du portefeuille, la répartition et l'historique des prix des instruments individuels
- **Valorisation en Or** : Voyez la valeur de votre portefeuille en onces d'or pour une perspective ajustée à l'inflation

### Gestion des Données
- **Récupération Intelligente** : Sélectionne automatiquement la meilleure source de données pour chaque type d'instrument
- **Récupération d'Historique** : Importez des années de données historiques pour une analyse complète des tendances
- **Mises à jour en Arrière-plan** : Mises à jour automatiques des prix sur macOS et iOS

### Expérience Utilisateur
- **Mode Privé** : Masquez les valeurs sensibles (icône œil) ; les données restent locales
- **Protection Face ID / Touch ID (iOS et macOS)** : Exiger optionnellement Face ID, Touch ID ou mot de passe de l’appareil pour accéder au tableau de bord. Sur iOS l’app se verrouille aussi à la sortie ; sur les deux plateformes après 5 minutes d’inactivité. Réglage dans Paramètres.
- **Bilingue** : Anglais et français
- **SwiftUI natif** : Un code partagé pour iOS et macOS ; interface et navigation adaptées à chaque plateforme

---

## Types d'Actifs Supportés

| Type d'Actif | Exemples | Source de Données | Notes |
|------------|----------|-------------|-------|
| **Actions** | Apple (AAPL), Tesla (TSLA) | Yahoo Finance | Prix du marché en temps réel |
| **ETF** | MSCI World, S&P 500 | Yahoo Finance | Fonds négociés en bourse |
| **OPCVM (Fonds Mutuels)** | Amundi, Carmignac | Financial Times | VL précise via Morningstar |
| **Cryptomonnaies** | Bitcoin, Ethereum | Yahoo Finance | Paires crypto majeures |
| **Métaux Précieux** | Or, Argent | Veracash | Prix spot en EUR/gramme |
| **Pièces Or & Argent** | Napoléon, Vera Max | AuCOFFRE | Inclut les primes de marché |
| **Comptes Bancaires** | Saisie manuelle | N/A | Suivi de la position cash |

### Types d'Instruments Spéciaux

#### Métaux Précieux (Veracash)
Suivez les prix spot pour l'or et l'argent par gramme en EUR :
- `VERACASH:GOLD_SPOT` - Prix spot de l'or
- `VERACASH:GOLD_PREMIUM` - Prix de la prime or
- `VERACASH:SILVER_SPOT` - Prix spot de l'argent

#### Pièces Physiques (AuCOFFRE)
Les pièces physiques incluent des primes de marché qui varient selon la demande :
- `COIN:NAPOLEON_20F` - Napoléon 20F Marianne Coq (~5.8g or pur)
- `COIN:VERAMAX_GOLD_1/10OZ` - Vera Max 1/10 oz or
- `COIN:GECKO_SILVER_1OZ` - Vera Silver Gecko 1 oz (n’est plus au catalogue AuCOFFRE ; l’app utilise le prix **Vera Silver 1 once** comme estimation et affiche « (est. Vera Silver 1 oz) » dans l’interface)
- `COIN:GOLD_BAR_1OZ` - Lingot d'or 1 oz (estimation spot)

---

## Pour Commencer

### Application iOS & macOS

L'application native SwiftUI offre la meilleure expérience pour suivre votre portefeuille.

#### Prérequis Système
- **iOS** : iOS 17.0 ou ultérieur (iPhone et iPad)
- **macOS** : macOS 14.0 Sonoma ou ultérieur

#### Installation depuis Xcode

1. Clonez le dépôt :
   ```bash
   git clone https://github.com/jeremycalles/Portfolio.git
   cd Portfolio
   ```

2. Ouvrez le projet Xcode :
   ```bash
   open PortfolioMultiplatform.xcodeproj
   ```

3. Sélectionnez votre cible :
   - **Portfolio iOS** pour iPhone/iPad
   - **Portfolio macOS** pour Mac

4. Compilez et exécutez (`Cmd+R`)

#### Premier Lancement

Lors du premier lancement de Portfolio :
1. L'application crée une base de données SQLite locale pour vos données
2. Votre langue préférée est détectée à partir des paramètres système
3. Vous pouvez commencer à ajouter des instruments et des comptes bancaires immédiatement


## Guide Utilisateur

Toutes les actions décrites ci-dessous se font dans l’application iOS ou macOS.

### Tableau de Bord

Le Tableau de Bord est votre centre de commande, offrant un aperçu instantané de votre position financière.

#### Résumé du Portefeuille
En haut, vous verrez :
- **Valeur Totale du Portefeuille** : Somme de toutes les positions converties en EUR
- **Équivalent Or** : La valeur de votre portefeuille exprimée en onces d'or (utilisant le prix spot actuel)
- **Variation sur la Période** : Variation en pourcentage par rapport à votre période de comparaison sélectionnée

#### Périodes de Comparaison
Utilisez le sélecteur de période pour comparer votre portefeuille par rapport à :
- **1 Jour** : Valeurs de clôture d'hier
- **1 Semaine** : Valeurs d'il y a 7 jours
- **1 Mois** : Valeurs d'il y a 30 jours
- **1 An** : Valeurs d'il y a 365 jours
- **1er Janvier** : Valeurs depuis le début de l'année

#### Graphique du Portefeuille
Le graphique interactif montre la valeur de votre portefeuille dans le temps :
- **Graphique Linéaire** : Suivez la tendance de la valeur totale de votre portefeuille
- **Plages de Temps** : 1M, 3M, 6M, 1er Janv, 1A, 2A, Tout
- **Mode Or** : Basculez pour voir les valeurs en onces d'or au lieu de l'EUR

#### Vues de Répartition
Basculez entre différentes perspectives de répartition :
- **Par Quadrant** : Voyez comment votre portefeuille est distribué par catégorie d'actifs
- **Par Compte** : Visualisez la répartition entre vos comptes bancaires
- **Par Positions** : Détail par instrument individuel

#### Mode Privé
Basculez l'icône œil pour masquer les valeurs sensibles. L'application reste entièrement fonctionnelle mais affiche des valeurs masquées—utile lors de la consultation en public.

---

### Gestion des Instruments

Les instruments sont les actifs financiers que vous souhaitez suivre (actions, ETF, fonds, etc.).

#### Ajouter des Instruments

1. Ouvrez **Instruments** (barre latérale macOS ou onglet iOS), puis **+**.
2. Saisissez un **ISIN** (12 caractères), un **ticker** (ex. `AAPL`, `BTC-EUR`) ou une **clé spéciale** (ex. `VERACASH:GOLD_SPOT`, `COIN:NAPOLEON_20F`).

#### Voir les Détails de l'Instrument

Cliquez (macOS) ou appuyez (iOS) sur une ligne d’instrument pour ouvrir sa fiche. Sur iOS toute la ligne est cliquable. Vous pouvez ensuite voir :
- **Prix Actuel** : Dernier prix récupéré avec la devise
- **Historique des Prix** : Prix historiques en format tableau ou graphique
- **Quadrant Assigné** : Groupement par catégorie
- **Positions** : Quels comptes détiennent cet instrument
- **Modifier** : Utilisez le bouton Modifier (barre d’outils sur iOS, feuille sur macOS) pour changer le nom, le ticker ou la devise

#### Supprimer des Instruments

**Important :** Supprimer un instrument retire tout l'historique de prix et les positions associés.

1. Sélectionnez l'instrument
2. Cliquez/appuyez sur le bouton supprimer (icône poubelle)
3. Confirmez la suppression

---

### Comptes Bancaires & Positions

Suivez vos investissements sur plusieurs courtiers et comptes.

#### Ajouter des Comptes Bancaires

1. Ouvrez **Comptes**, **+**, puis saisissez le nom de la banque et du compte (ex. « TradeRepublic », « CTO »).

#### Ajouter des Positions

1. Ouvrez **Positions** (barre latérale macOS ou onglet **Positions** sur iOS), **+**, puis choisissez compte, instrument, quantité et éventuellement date/prix d’achat.

#### Modifier les Positions

Modifiez la quantité ou les infos d’achat d’une position :
- **iOS** : Appuyez sur une ligne de position dans l’écran **Positions**. Toute la ligne est cliquable ; l’écran d’édition s’ouvre (quantité et infos d’achat optionnelles). Enregistrer ou Annuler.
- **macOS** : Cliquez sur une ligne dans **Positions** ou **Toutes les Positions**. Un crayon à côté des unités indique que la ligne est modifiable. Une feuille « Modifier la position » s’ouvre ; modifiez la quantité et éventuellement la date/prix d’achat, puis Enregistrer (⌘↵) ou Annuler (Échap).

#### Voir les Positions

La vue Positions montre :
- **Groupé par Compte** : Voir tous les instruments dans chaque compte
- **Valeur Actuelle** : Quantité × prix actuel
- **Gain/Perte** : Si les données d'achat sont enregistrées, voir les gains latents

#### Vue Toutes les Positions

Accédez à la vue consolidée pour voir :
- Toutes les positions sur tous les comptes
- La valeur totale du portefeuille
- Sections de compte extensibles  
- **Modifier** : Cliquez (macOS) ou appuyez (iOS) sur une ligne pour ouvrir la même fenêtre d’édition de position que ci-dessus.

---

### Quadrants (Organisation du Portefeuille)

Les Quadrants vous aident à catégoriser et analyser votre portefeuille par type d'actif ou stratégie.

#### Créer des Quadrants

Catégories de quadrants suggérées :
- **Technologie** : Actions tech et ETF
- **Métaux Précieux** : Or, argent et pièces
- **Revenu Fixe** : Obligations et fonds monétaires
- **International** : Marchés émergents et actions étrangères
- **Immobilier** : REITs et fonds immobiliers

1. Ouvrez **Quadrants**, **+**, et saisissez un nom (ex. « Technologie », « Métaux précieux »).
2. Assignez les instruments depuis la fiche instrument : choisissez un quadrant dans le sélecteur.

#### Rapports par Quadrant

Voyez votre portefeuille groupé par quadrant :
- Valeur sous-totale par quadrant
- Pourcentage du portefeuille total
- Variation de performance par quadrant
- Visualisation en diagramme circulaire

---

### Rapports & Analytique

#### Rapport de Portefeuille

Le Rapport de Portefeuille montre une analyse détaillée de vos positions :

| Colonne | Description |
|--------|-------------|
| Instrument | Nom et identifiant |
| Quantité | Unités détenues |
| Prix Actuel | Dernier prix |
| Valeur Actuelle | Quantité × prix en EUR |
| Variation | Variation en pourcentage vs période de comparaison |

**Périodes de comparaison :** 1 Jour, 1 Semaine, 1 Mois, 1 An, 1er Janv.

#### Rapport par Quadrant

Portefeuille groupé par catégorie : sous-totaux par quadrant, variation en %, total général, instruments non assignés.

#### Graphiques de Prix

Graphiques interactifs pour les instruments individuels :
- **Plages de Temps** : 1M, 3M, 6M, 1er Janv, 1A, 2A, Tout
- **Statistiques** : Min, Max, Moyenne, Points de Données
- **Courbes Lisses** : Interpolation Catmull-Rom pour une meilleure visualisation

---

### Gestion des Prix

#### Mises à jour

- **Actualisation manuelle** : Paramètres → Mettre à jour tous les prix (ou barre d’outils sur macOS).
- **En arrière-plan** : Agent Launch (macOS) ou Background Tasks (iOS), voir [Automatisation](#automatisation).

#### Récupération d’historique

Paramètres → Récupérer l’historique ; choisir la période (1A, 2A, 5A). Sur macOS, les commandes de menu proposent aussi 1A/2A/5A.

#### Saisie Manuelle de Prix

Pour les instruments sans sources de données automatiques :
1. Naviguez vers **Historique des Prix**
2. Sélectionnez l'instrument
3. Cliquez/appuyez sur **+** pour ajouter un nouveau prix
4. Entrez la date et la valeur du prix

---

### Paramètres & Préférences

- **iOS** : Ouvrez l’onglet **Paramètres** dans la barre d’onglets.
- **macOS** : Utilisez le menu de l’application **Portfolio** → **Paramètres** (ou ⌘,). Toutes les préférences (Général, Langue, Base de données, Arrière-plan) se trouvent dans cette fenêtre ; il n’y a pas d’entrée Paramètres dans la barre latérale de la fenêtre principale.

#### Protection Face ID / Touch ID (iOS et macOS)

Dans **Paramètres** → **Protection Touch ID**, activez ou désactivez l’exigence de Face ID (iPhone/iPad), Touch ID ou mot de passe de l’appareil pour afficher le tableau de bord. Lorsqu’elle est activée, l’app affiche un écran de verrouillage au lancement. Sur iOS elle se verrouille aussi lorsque vous passez à une autre app ; sur les deux plateformes après 5 minutes d’inactivité.

#### Langue

Basculez entre Anglais et Français :
1. Allez dans **Paramètres**
2. Sélectionnez **Langue**
3. Choisissez votre langue préférée

L'application se met à jour immédiatement sans redémarrage.

#### Base de données et stockage

- **iOS** : Local ou iCloud optionnel (Paramètres → Stockage). iCloud nécessite un compte Apple Developer.
- **macOS** : Local ou iCloud ; vous pouvez ouvrir le dossier de la base depuis Paramètres.

#### Actualisation en Arrière-plan (macOS)

Au premier lancement, l'application propose d'activer les mises à jour automatiques des prix. Vous pouvez accepter, refuser, ou cocher **"Ne plus demander"** pour supprimer définitivement cette invite. Vous pouvez toujours activer ou désactiver l'actualisation automatique ultérieurement depuis les Paramètres.

Pour configurer manuellement :
1. Allez dans **Paramètres** → **Actualisation en Arrière-plan**
2. Choisissez un intervalle (1 heure, 3 heures, 6 heures ou 12 heures)
3. Cliquez sur **Activer** pour installer l'Agent de Lancement et démarrer le minuteur intégré

Le planificateur fonctionne de deux manières complémentaires :
- **Agent de Lancement** : Un plist `launchd` système (`~/Library/LaunchAgents/com.portfolio.app.pricerefresh.plist`) déclenche l'application via le schéma d'URL `portfolio://refresh` à l'intervalle configuré — même lorsque l'application n'est pas au premier plan.
- **Minuteur intégré** : Un minuteur répétitif actualise les prix pendant que l'application est en cours d'exécution, assurant des mises à jour fluides sans l'Agent de Lancement.

Les logs sont écrits dans `~/Library/Logs/PortfolioApp/refresh.log` et peuvent être consultés directement dans le panneau Paramètres ou ouverts dans le Finder.

#### Tâches en Arrière-plan (iOS)

iOS actualise automatiquement les prix en arrière-plan quand le système le permet. Voir l'historique d'actualisation dans les Paramètres pour surveiller le statut des mises à jour.

---

## Sources de Données

Portfolio utilise plusieurs sources de données pour assurer une tarification précise :

| Source | Actifs | Type de Données |
|--------|--------|-----------|
| **Yahoo Finance** | Actions, ETF, Crypto | Prix temps réel, données historiques |
| **Financial Times** | OPCVM | VL depuis Morningstar |
| **Veracash** | Or, Argent | Prix spot en EUR/gramme |
| **AuCOFFRE** | Pièces Physiques | Prix avec primes de marché |

### Pourquoi Plusieurs Sources ?

- **OPCVM** : Les prix de bourse sont souvent obsolètes en raison de la faible liquidité. Financial Times fournit la VL (Valeur Liquidative) précise depuis Morningstar.
- **Pièces Physiques** : Contrairement aux prix spot, les pièces s'échangent avec des primes qui varient selon la demande, la rareté et les conditions du marché. AuCOFFRE fournit les prix réels du marché incluant ces primes.

---

## Confidentialité & Sécurité

### Conception priorité confidentialité

Portfolio est conçu pour que **vos données ne quittent jamais votre contrôle** :

- **Aucun serveur pour vos données** : Il n’existe pas de backend ni de service cloud hébergeant votre portefeuille. Positions, comptes, instruments et historique des prix restent uniquement sur votre appareil (et, si vous l’activez, dans votre iCloud).
- **Aucune donnée personnelle envoyée** : L’application n’envoie aucune donnée personnelle identifiable ni contenu du portefeuille à un tiers. Pas de télémétrie, analytique ou rapport de plantage.
- **Stockage local uniquement** : Une base SQLite unique dans le conteneur de l’app (chemin affiché dans Paramètres). Les préférences (langue, stockage, mode privé) sont dans les `UserDefaults` sur l’appareil uniquement.
- **iCloud optionnel** : Si vous activez iCloud, le même fichier de base est synchronisé via votre compte Apple. Aucune donnée n’est envoyée au développeur de l’app ni à un autre serveur.

### Ce qui quitte votre appareil (données de marché uniquement)

Lors d’une actualisation des prix, l’app demande des **données de marché publiques** à des API publiques (Yahoo Finance, Financial Times, Veracash, AuCOFFRE). Seuls les identifiants d’instruments (symboles, codes ISIN) sont envoyés pour récupérer les prix ; ni structure du portefeuille, ni quantités détenues, ni informations personnelles. C’est équivalent à consulter un site financier dans un navigateur.

### Protection d’accès (iOS et macOS)

Sur **iOS** et **macOS**, vous pouvez activer la **Protection Touch ID** (Face ID sur iPhone/iPad) dans Paramètres pour que le tableau de bord reste masqué jusqu’à authentification. Sur iOS l’app se verrouille aussi lorsque vous la quittez ; sur les deux plateformes après 5 minutes d’inactivité. Activez ou désactivez dans **Paramètres** → **Protection Touch ID**.

### Données sous votre contrôle

- **Exporter, sauvegarder, supprimer** : Vous pouvez copier, déplacer ou supprimer le fichier de base à tout moment. Sur macOS vous pouvez choisir le chemin des données ; sur iOS la base se trouve dans le conteneur de l’app.
- **Mode privé** : Basculez avec l’icône œil pour masquer toutes les valeurs monétaires à l’écran ; l’état est stocké localement uniquement. Idéal pour une consultation en public.

---

## Automatisation

### Agent de Lancement macOS

L'application gère un Agent de Lancement pour les mises à jour automatiques en arrière-plan :
1. Ouvrez **Paramètres** → **Actualisation en Arrière-plan**
2. Sélectionnez votre intervalle préféré (1h, 3h, 6h ou 12h)
3. Cliquez sur **Activer** pour générer et installer le plist

L'Agent de Lancement exécute `/usr/bin/open -g portfolio://refresh` à l'intervalle configuré. Cela ouvre l'application en arrière-plan (ou envoie l'URL à l'instance en cours) et déclenche une actualisation complète des prix — instruments, taux de change et indices de référence (S&P 500, Or, MSCI World). Le plist est écrit dans `~/Library/LaunchAgents/com.portfolio.app.pricerefresh.plist` et géré via `launchctl`. Modifier l'intervalle réinstalle automatiquement l'agent avec le nouveau planning.

### Actualisation en Arrière-plan iOS

iOS utilise le framework Background Tasks du système :
- Intervalle minimum de 3 heures entre les mises à jour
- Le système détermine le moment réel basé sur les habitudes d'utilisation
- Voir l'historique d'actualisation dans les Paramètres

---

## Développement

### Structure du projet

La logique partagée est dans `Shared/` ; iOS et macOS ajoutent leurs vues et leur cycle de vie. Aucun backend — tout l’état est local.

```
PortfolioMultiplatform/
├── Shared/                       # Code partagé (les deux plateformes)
│   ├── Models/                   # Modèles de données (Instrument, Holding, etc.)
│   ├── Services/                 # Services principaux
│   │   ├── DatabaseService.swift
│   │   ├── MarketDataService.swift
│   │   ├── LanguageManager.swift
│   │   ├── PriceRefreshService.swift   # Logique de rafraîchissement partagée
│   │   ├── DemoModeManager.swift       # Mode démo/confidentialité
│   │   └── HapticService.swift         # Retour haptique multiplateforme
│   ├── ViewModels/               # AppViewModel et extensions
│   ├── Views/
│   │   ├── Charts/               # EnhancedTrendCard, AllocationRingChart, etc.
│   │   ├── Dashboard/            # Sections du tableau de bord (Quadrants, Positions, Comptes)
│   │   ├── Components/           # Composants UI partagés
│   │   │   ├── AddHoldingSheet.swift
│   │   │   ├── PriceEditorSheet.swift
│   │   │   ├── BackfillLogsSheet.swift
│   │   │   └── ChangeLabel.swift
│   │   ├── DashboardView.swift
│   │   ├── ReportsView.swift
│   │   └── EditHoldingView.swift
│   ├── Helpers/                  # Formatage, utilitaires de date
│   └── Resources/                # Localisation (en, fr)
├── iOS/                          # Code spécifique iOS
│   ├── iOSRootView.swift         # Point d'entrée iOS principal
│   ├── BackgroundTaskManager.swift
│   ├── IOSLockManager.swift
│   └── Views/                    # Vues spécifiques iOS
│       └── Components/           # Sélecteur de période, sélecteur de mode
├── macOS/                        # Code spécifique macOS
│   ├── MacOSSchedulerManager.swift
│   ├── MacOSLockManager.swift
│   └── Views/                    # Vues spécifiques macOS
│       ├── ContentView.swift     # Navigation principale macOS
│       ├── AccountsView.swift
│       ├── InstrumentsView.swift
│       └── MacOSSettingsViews.swift
├── PortfolioTests/
├── PortfolioMultiplatform.xcodeproj/
├── assets/screenshots/
└── README.md
```

### Points forts de l'architecture

- **Partage maximal du code** : Graphiques, composants du tableau de bord, feuilles et services sont partagés entre les plateformes
- **UI spécifique par plateforme** : Chaque plateforme a sa propre navigation et ses vues de paramètres optimisées pour l'expérience
- **Séparation claire** : Le code spécifique à chaque plateforme est clairement isolé dans les dossiers `iOS/` et `macOS/`
- **Services unifiés** : `PriceRefreshService`, `HapticService` et `DemoModeManager` assurent un comportement cohérent sur toutes les plateformes

### Exécution des Tests

**Depuis Xcode :**
- Appuyez sur `Cmd+U` pour lancer tous les tests
- Utilisez le Navigateur de Tests (`Cmd+6`) pour les tests individuels

**Depuis la Ligne de Commande :**
```bash
# Tests iOS
xcodebuild test \
  -project PortfolioMultiplatform.xcodeproj \
  -scheme "Portfolio iOS" \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Tests macOS
xcodebuild test \
  -project PortfolioMultiplatform.xcodeproj \
  -scheme "Portfolio macOS" \
  -destination 'platform=macOS'
```

### Structure des Tests

| Fichier | Objectif |
|------|---------|
| `PortfolioTests.swift` | Configuration de test basique |
| `CurrencyConversionTests.swift` | Logique de conversion de devises |
| `DashboardSnapshotTests.swift` | Tests snapshot UI |
| `TestFixtures.swift` | Données de test |
| `MockDatabaseService.swift` | Services simulés (mock) |

---

## Licence

Ce projet est sous licence [PolyForm Noncommercial License 1.0.0](LICENSE).

**Résumé :**
- ✅ **Gratuit pour usage non-commercial** — projets personnels, recherche, éducation, usage amateur
- ✅ **Modifications autorisées** — vous pouvez modifier et distribuer à des fins non-commerciales
- ❌ **Usage commercial nécessite permission** — contactez pour une licence commerciale

---

## Support

Pour des questions, problèmes, ou demandes de fonctionnalités, veuillez ouvrir un ticket sur GitHub.

---

*Fait avec SwiftUI · SQLite*
