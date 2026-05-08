# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Open `PrayPlan.xcodeproj` in Xcode — Xcode resolves the Adhan-swift SPM package automatically on first open.

```bash
# Build (simulateur)
xcodebuild -project PrayPlan.xcodeproj -scheme PrayPlan \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Tests
xcodebuild -project PrayPlan.xcodeproj -scheme PrayPlan \
  -destination 'platform=iOS Simulator,name=iPhone 16' test

# Test unique
xcodebuild -project PrayPlan.xcodeproj -scheme PrayPlan \
  -destination 'platform=iOS Simulator,name=iPhone 16' test \
  -only-testing:PrayPlanTests/PrayPlanTests/example
```

Requirements: Xcode 15+, iOS 17+ deployment target.

## Architecture

### Flux de données central

`PrayPlanApp` instancie quatre services `@State` et les injecte via `.environment()` dans toute la hiérarchie de vues. Les vues consomment les services via `@Environment(ServiceType.self)` et les données persistées via `@Query` de SwiftData directement — il n'y a pas de couche ViewModel ou Repository.

```
PrayPlanApp
├── @State LocationService       → GPS + géocodage inverse
├── @State PrayerTimeService     → calcul horaires + countdown 1s
├── @State NotificationService   → planification 42 notifs (7j × 6 prières)
├── @State AppBlockingService    → FamilyControls + ManagedSettingsStore
└── .modelContainer([UserTask, UserHabit, HabitCompletion, UserSettings, AppBlockingProfile])
```

### `PrayerSegment` — concept clé transversal

`PrayerSegment` (enum, 6 cas) est l'unité organisationnelle centrale de toute l'app : les tâches, habitudes, règles de blocage d'apps, et l'UI de la Home sont tous structurés autour de ces blocs horaires. L'ordre naturel de la journée est : `fajrToSunrise → sunriseToDhuhr → dhuhrToAsr → asrToMaghrib → maghribToIsha → ishaTofajr`.

`DailyPrayerSchedule` (struct, valeur) encapsule les 6 horaires du jour et expose `currentSegment(at:)`, `progress(of:at:)`, `nextPrayer(after:)`.

### Calcul des horaires de prière

Double source :
- **Local (primaire)** : `PrayerTimeService` utilise le package SPM `Adhan-swift` (`Adhan.PrayerTimes`). C'est le chemin principal.
- **Réseau (secondaire)** : `PublicPrayerTimesAPI` interroge `api.aladhan.com/v1/timings/{date}` et retourne les mêmes `DailyPrayerSchedule`. Non branché par défaut dans le service principal.

`PrayerTimeService` calcule 7 jours dès la réception d'une localisation et lance un `Timer` à 1 seconde pour mettre à jour `currentSegment`, `nextPrayerName`, et `timeUntilNextPrayer`.

### Persistance SwiftData — pattern enum

SwiftData ne supporte pas les propriétés `enum` natives dans les `@Model`. Tous les enums sont stockés comme `String` avec un suffixe `Raw` et exposés via des propriétés calculées :

```swift
var segmentRaw: String = PrayerSegment.dhuhrToAsr.rawValue
var segment: PrayerSegment {
    get { PrayerSegment(rawValue: segmentRaw) ?? .dhuhrToAsr }
    set { segmentRaw = newValue.rawValue }
}
```

Ce pattern s'applique à : `UserTask` (segment, priority), `UserHabit` (segment, frequency), `AppBlockingProfile` (segment), `UserSettings` (calculationMethod, madhab, azanSound).

### Blocage d'apps (FamilyControls)

`AppBlockingService` utilise `ManagedSettingsStore` pour bloquer les apps sélectionnées. `AppBlockingProfile` stocke une `FamilyActivitySelection` encodée en JSON (`Data`). `ContentView` observe `prayerService.currentSegment` via `.onChange` et appelle `blockingService.applyBlocking(profile:)` à chaque changement de segment.

**Contrainte device** : FamilyControls ne fonctionne que sur un vrai iPhone, pas le simulateur. La capability `com.apple.developer.family-controls` est déclarée dans `PrayPlan/PrayPlan.entitlements`.

### Boussole Qibla

`QiblaViewModel` est un `NSObject` `@Observable` (requis pour `CLLocationManagerDelegate`). Il utilise `CLLocationManager.startUpdatingHeading()` et `Adhan.Qibla` pour calculer la direction. Démarré/arrêté dans `.onAppear`/`.onDisappear` de `QiblaView`.

### Widget (placeholder)

`PrayPlanWidgetExtension` contient uniquement le code boilerplate Xcode (emoji + heure). Il n'est pas encore branché aux données de prière.

## Localisation

Français par défaut. Toutes les chaînes UI utilisent `String(localized: "key", defaultValue: "Texte FR")`. Les régions `en`, `fr`, `ar` sont déclarées dans le pbxproj mais seul le français est complet.

## Azan

Les notifications utilisent `settings.azanSound.soundFileName` (optionnel). Les fichiers audio `azan.caf` et `beep.caf` doivent être ajoutés manuellement au bundle de l'app — ils ne sont pas inclus dans le repo.
