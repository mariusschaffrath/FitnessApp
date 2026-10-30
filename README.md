# 🏃‍♂️ FitnessApp – Next-Gen BioMetrics & HealthKit Engine (iOS)

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Declarative%20UI-purple.svg)](https://developer.apple.com/xcode/swiftui/)
[![HealthKit](https://img.shields.io/badge/HealthKit-On--Device%20Source%20of%20Truth-red.svg)](https://developer.apple.com/documentation/healthkit)
[![ActivityKit](https://img.shields.io/badge/ActivityKit-Dynamic%20Island-black.svg)](https://developer.apple.com/documentation/activitykit)
[![CI](https://github.com/mariusschaffrath/FitnessApp/actions/workflows/ios-test.yml/badge.svg)](https://github.com/mariusschaffrath/FitnessApp/actions/workflows/ios-test.yml)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Eine hochmoderne, native iOS Fitness- & Biometrie-Zentrale im **Liquid Glassmorphism Design**. Entwickelt mit striktem **Privacy-First-Paradigma**, direkter HealthKit-Anbindung als einziger *Source of Truth*, interaktiven Swift Charts und nahtloser Integration in die **Dynamic Island** sowie **Live Activities**.

---

## 🌟 Hauptfunktionen (Features)

- ⭕ **Multidimensionale Aktivitätsringe:** Originalgetreue Vektordarstellung der Apple Activity-Ringe (*Bewegen, Trainieren, Stehen*) plus erweiterte Ringe für *Schritte* und *Hydrierung*.
- 📈 **Swift Charts & Trend-Analysen:** Interaktive Balken- und Flächendiagramme mit Zero-Fill-Algorithmus zur lückenlosen Darstellung von Tagen, Wochen, Monaten und Jahren mit haptischem Tap-to-Reveal.
- 🏋️ **Workout Hub mit 40+ Sportarten:** Automatische Synchronisation aller Apple Watch Trainings inklusive Herzfrequenzzonen, Kalorienverbrauch, Streckenmessung und Indoor/Outdoor-Klassifizierung.
- 🏝️ **Dynamic Island & Live Activities:** Echtheits-Tracking laufender Trainings mit animierter Herzfrequenz, Kalorienzähler und Stoppuhr direkt auf dem Sperrbildschirm und in der Dynamic Island.
- 🗺️ **MapKit Routen-Visualisierung:** Auslesen und interaktives Rendern von GPS-Workout-Routen aus `HKWorkoutRoute`.
- 🔒 **Absolute Privatsphäre:** Keine Cloud-Server, keine Werbetracker, keine Analyse-SDKs. Sämtliche biometrischen Daten verbleiben zu 100 % in der gesicherten Apple Health Sandbox auf dem Gerät.

---

## 🏗️ Systemarchitektur

```mermaid
graph TD
    subgraph AppleEcosystem ["Apple Health & Sensor Schicht"]
        HK["Apple HealthKit (HKHealthStore)"]
        WATCH["Apple Watch (Live Samples)"]
        GPS["CoreLocation (HKWorkoutRoute)"]
    end

    subgraph CoreManagers ["Manager & ViewModel Schicht (MVVM)"]
        HKM["HealthKitManager (ObservableObject)"]
        WM["WorkoutManager (Extension)"]
        SM["StatsManager (Swift Charts Pipeline)"]
        NM["NotificationManager (UNUserNotification)"]
        LAM["LiveActivityManager (ActivityKit)"]
    end

    subgraph PresentationLayer ["SwiftUI UI Schicht (Liquid Glass)"]
        CV["ContentView (Dashboard & Rings)"]
        SV["StatsView (Interactive Trends)"]
        WHV["WorkoutHistoryView & DetailView"]
        WLA["WorkoutLiveActivity (Dynamic Island)"]
        FW["FitnessWidget (WidgetKit)"]
    end

    WATCH --> HK
    GPS --> HK
    HK --> HKM

    HKM --> WM
    HKM --> SM
    HKM --> NM
    HKM --> LAM

    HKM --> CV
    SM --> SV
    WM --> WHV
    LAM --> WLA
    HKM --> FW
```

---

## 🎨 Apple Human Interface Guidelines (HIG) Compliance

Das Design folgt strikt den modernsten Apple Human Interface Guidelines:
- **Spatial Glassmorphism:** Verwendung von `.ultraThinMaterial` und abgestuften Kantenlichtern für natürliche Tiefenwirkung im Dark Mode.
- **Dynamic Color Harmony:** Mathematisch abgestimmte Verläufe basierend auf den kanonischen Apple Ring-Farben (*Ultra Orange, Move Red, Exercise Green, Stand Cyan*).
- **Haptic Engine:** Kontextsensitives taktiles Feedback via `UIImpactFeedbackGenerator` und `UINotificationFeedbackGenerator` bei Zielerreichung und Ring-Interaktionen.
- **Dynamic Island Adaptation:** Unterstützung für alle 4 Präsentationsmodi von ActivityKit:
  - *Compact Leading:* Dynamisches Sportarten-Icon.
  - *Compact Trailing:* Live-Herzfrequenzanzeige.
  - *Minimal:* Animierter Aktivitäts-Indikator.
  - *Expanded:* Vollständiges HUD mit Herzfrequenz, Kalorien und Laufzeit.

---

## 🛡️ HealthKit Permission & Privacy Model

Die App fordert ausschließlich granulare Berechtigungen an, die für die Visualisierung zwingend erforderlich sind:

```swift
// Angefragte HealthKit Quantity- & Category-Types
let typesToRead: Set = [
    HKQuantityType.quantityType(forIdentifier: .stepCount)!,
    HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
    HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!,
    HKQuantityType.quantityType(forIdentifier: .dietaryWater)!,
    HKQuantityType.quantityType(forIdentifier: .heartRate)!,
    HKCategoryType.categoryType(forIdentifier: .appleStandHour)!,
    HKSeriesType.workoutRoute(),
    HKObjectType.activitySummaryType(),
    HKObjectType.workoutType()
]
```

---

## 🚀 Entwicklung & Cloud CI

### Lokale Entwicklung (Xcode)
1. Repository klonen:
   ```bash
   git clone https://github.com/mariusschaffrath/FitnessApp.git
   ```
2. `FitnessApp.xcodeproj` in Xcode 15+ öffnen.
3. HealthKit Capability ist über `FitnessApp.entitlements` konfiguriert.
4. Auf Simulator (*iPhone 16 / iOS 17+*) oder physischem Testgerät ausführen.

### Automatisiertes CI/CD via GitHub Actions
Jeder Commit auf `main` wird automatisch in der Cloud gebaut und getestet:
```yaml
# Auszug aus .github/workflows/ios-test.yml
- name: Compile iOS App (Simulator Target)
  run: |
    xcodebuild \
      -project FitnessApp.xcodeproj \
      -scheme FitnessApp \
      -destination 'generic/platform=iOS Simulator' \
      -configuration Debug \
      CODE_SIGNING_ALLOWED=NO \
      build
```

---

## 📄 Lizenz
Lizenziert unter der **MIT-Lizenz** – siehe [LICENSE](file:///Users/mariusschaffrath/Desktop/FitnessApp/FitnessApp/LICENSE).
