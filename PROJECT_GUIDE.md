# FitnessApp - Master Project Guide

## 📌 Projekt-Status
**Version:** 0.2.1 (Alpha)
**Lead Developer:** Gemini CLI / Marius
**Tech Stack:** SwiftUI, HealthKit, Swift Charts, WidgetKit, ActivityKit

## 🛠 Architektur-Entscheidungen
- **HealthKit Primary:** Die App vertraut ausschließlich auf HealthKit als "Source of Truth", um System-Konsistenz zu gewährleisten.
- **Modern Concurrency:** Umstellung auf `async/await` für alle Netzwerk- und Datenbank-Operationen zur Vermeidung von UI-Freezes.
- **Glassmorphism Design:** Nutzung von `.ultraThinMaterial` und Custom Gradients für einen modernen iOS-Look (Apple HIG konform).

## 📉 Roadmap
### Milestone 1: Connectivity & Presence (AKTUELL)
- [x] **WidgetKit Logic:** Basis-Datenstruktur für Homescreen-Widgets erstellt.
- [x] **Live Activities UI:** Design für Dynamic Island und Lockscreen implementiert.
- [ ] **Workout Trigger:** Logik zum Starten/Stoppen von Live Activities einbauen.
- [ ] **Widget UI:** Implementierung der Ring-Visualisierung für Small/Medium Widgets.

### Milestone 2: Engagement & Gamification
- [ ] **Awards System:** Logik für Meilensteine (10k Schritte, etc.) und 3D-Medaillen.
- [ ] **Social Sharing:** Generierung von Share-Bildern für Erfolge.

### Milestone 3: Intelligent Insights
- [ ] **MapKit Integration:** Visualisierung von Workout-Routen in der Detailansicht.
- [ ] **Trend-Analyse:** Algorithmus zur Erkennung von Aktivitäts-Mustern.

## 📝 Change Log & Iterationen

### [0.2.1] - 2026-03-10 (Aktueller Sprint)
- **Doc:** `PROJECT_GUIDE.md` als zentrale Dokumentation angelegt.
- **Feat:** WidgetKit-Basis (`FitnessWidget.swift`) vorbereitet.
- **Fix:** Kompilierfehler bei Enum-Vergleichen in `ContentView` behoben.

### [0.2.0] - 2026-03-10
- **Refactor:** `HealthKitManager` auf `async/await` umgestellt für stabilere Datenabfragen.
- **Feat:** Sync-Status Indikator (Capsule-Design) im Dashboard integriert.
- **Feat:** Professionelles Error-Handling mit nutzerfreundlichen Alerts bei fehlenden Rechten.
- **Fix:** Swift Charts Logik korrigiert (Zero-Fill), um lückenlose Zeitachsen anzuzeigen.

### [0.1.5] - Statistiken & Trends
- **Feat:** `StatsView` mit Swift Charts implementiert.
- **Feat:** Zeitfilter (Tag, Woche, Monat, Jahr) für alle Kernmetriken hinzugefügt.
- **Feat:** Interaktive Balken-Auswahl mit Detail-Annotationen.

### [0.1.2] - Visual Polish & Branding
- **UI:** `GlassCard` Komponente für den konsistenten Apple-Look erstellt.
- **UI:** Dynamische Mesh-Gradients als Hintergrund für das gesamte Dashboard.
- **Branding:** `AppleColors` und `FitnessLogo` (SFSymbols-basiert) definiert.

### [0.1.1] - Workout History
- **Feat:** `WorkoutManager` zum Auslesen von Trainingsdaten integriert.
- **Feat:** `WorkoutHistoryView` und `WorkoutDetailView` inkl. Herzfrequenz-Graphen erstellt.

### [0.1.0] - Core Foundation
- **Init:** Projektstruktur und SwiftUI App-Lifecycle aufgesetzt.
- **HealthKit:** Basis-Berechtigungs-Workflow und Activity-Ringe Logik implementiert.
