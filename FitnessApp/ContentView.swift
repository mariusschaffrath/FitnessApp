import SwiftUI
import HealthKit
import ActivityKit

struct DayActivity: Identifiable {
    let id = UUID()
    let date: Date
    let calories: Double
    let caloriesGoal: Double
    let exercise: Double
    let exerciseGoal: Double
    let stand: Double
    let standGoal: Double
    let hasWorkout: Bool
}

struct ContentView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @Environment(\.scenePhase) var scenePhase
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("userName") private var userName: String = ""
    
    @AppStorage("stepsGoal") var stepsGoal: Double = 10000
    @AppStorage("caloriesGoal") var caloriesGoal: Double = 500
    @AppStorage("exerciseGoal") var exerciseGoal: Double = 30
    @AppStorage("standGoal") var standGoal: Double = 12
    
    @State private var calendarDays: [DayActivity] = []
    @State private var selectedTab = 0
    
    @State private var showLogWater = false
    @State private var showEditGoals = false
    @State private var isLoading = true
    @State private var syncError: HealthKitError?
    
    init() {
        UITabBar.appearance().shadowImage = UIImage()
        UITabBar.appearance().backgroundImage = UIImage()
        UITabBar.appearance().backgroundColor = .clear
    }
    
    var body: some View {
        Group {
            if !hasCompletedOnboarding { 
                OnboardingView() 
            } else if isLoading {
                LoadingSplashView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation(.smooth) { 
                                isLoading = false
                                refreshData() 
                            }
                        }
                    }
            } else { 
                MainLayout 
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in 
            if newPhase == .active && !isLoading { 
                refreshData() 
            } 
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .alert(item: $syncError) { error in
            Alert(
                title: Text("HealthKit Status"),
                message: Text(error.errorDescription ?? "Unbekannter Fehler beim Laden der Daten."),
                dismissButton: .default(Text("Verstanden"))
            )
        }
    }
    
    var MainLayout: some View {
        TabView(selection: $selectedTab) {
            NavigationView { SummaryTab }.tag(0).tabItem { Label("Übersicht", systemImage: "sparkles") }
            WorkoutHistoryView().tag(1).tabItem { Label("Workouts", systemImage: "figure.run.circle.fill") }
            StatsView().tag(2).tabItem { Label("Trends", systemImage: "chart.line.uptrend.xyaxis") }
            NavigationView { AwardsView() }.tag(3).tabItem { Label("Erfolge", systemImage: "rosette") }
            NavigationView { SettingsView() }.tag(4).tabItem { Label("Profil", systemImage: "person.crop.circle.fill") }
        }
        .tint(AppleColors.ultraOrange)
    }
    
    var SummaryTab: some View {
        ZStack {
            BackgroundView()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    GreetingSection(name: userName, steps: healthKitManager.todaySteps, goal: stepsGoal, calories: healthKitManager.todayCalories, calGoal: caloriesGoal)
                    
                    LiveWorkoutCard()
                    
                    SyncStatusHeader()
                    
                    ActivityRingsHeader(calories: healthKitManager.todayCalories, calGoal: caloriesGoal, exercise: healthKitManager.todayExercise, exGoal: exerciseGoal, stand: healthKitManager.todayStand, standGoal: standGoal)
                    
                    CalendarActivityView(days: calendarDays)
                    
                    ActivityBreakdownCard(currentCalories: healthKitManager.todayCalories, caloriesGoal: caloriesGoal, currentExercise: healthKitManager.todayExercise, exerciseGoal: exerciseGoal, currentStand: healthKitManager.todayStand, standGoal: standGoal, currentSteps: healthKitManager.todaySteps, stepsGoal: stepsGoal, showEditGoals: $showEditGoals)
                    
                    ActionButton(title: "Wasser loggen", icon: "drop.fill", color: .blue) { showLogWater = true }.padding(.horizontal, 24)
                    
                    RecentWorkoutsSection(workouts: healthKitManager.recentWorkouts, selectedTab: $selectedTab)
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showLogWater) { LogWaterView() }
        .sheet(isPresented: $showEditGoals) { GoalSettingsView() }
        .onAppear { loadCalendarData(with: healthKitManager.recentWorkouts) }
        .onChange(of: healthKitManager.recentWorkouts) { oldVal, newVal in loadCalendarData(with: newVal) }
    }
    
    @ViewBuilder
    private func SyncStatusHeader() -> some View {
        if healthKitManager.isSyncing || healthKitManager.lastSyncDate != nil {
            HStack(spacing: 8) {
                if healthKitManager.isSyncing {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Daten werden aktualisiert...")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                } else if let lastSync = healthKitManager.lastSyncDate {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Zuletzt aktualisiert: \(lastSync.formatted(.dateTime.hour().minute()))")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    
    private func refreshData() {
        Task {
            await healthKitManager.refreshAllData()
        }
    }
    
    private func loadCalendarData(with workouts: [Workout]) {
        let calendar = Calendar.current
        var days: [DayActivity] = []
        let group = DispatchGroup()
        
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -6 + i, to: Date())!
            group.enter()
            healthKitManager.fetchActivityData(for: date) { steps, cal, ex, stand in
                let hasW = workouts.contains(where: { calendar.isDate($0.date, inSameDayAs: date) })
                let day = DayActivity(date: date, calories: cal, caloriesGoal: caloriesGoal, exercise: ex, exerciseGoal: exerciseGoal, stand: stand, standGoal: standGoal, hasWorkout: hasW)
                days.append(day)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.calendarDays = days.sorted { $0.date < $1.date }
        }
    }
}

// MARK: - Subsections

struct GreetingSection: View {
    let name: String; let steps: Double; let goal: Double; let calories: Double; let calGoal: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let hour = Calendar.current.component(.hour, from: Date())
            let greet = hour < 12 ? "Guten Morgen" : (hour < 18 ? "Guten Tag" : "Guten Abend")
            Text("\(greet)\(name.isEmpty ? "" : ", \(name)")").font(.system(size: 34, weight: .bold, design: .rounded))
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill").foregroundColor(AppleColors.ultraOrange)
                Text(getMotivation()).font(.system(.subheadline, design: .rounded)).foregroundColor(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.top, 20)
    }
    private func getMotivation() -> String {
        let progress = steps / goal
        if progress >= 1.0 { return "Großartig! Ziel erreicht. 🏆" }
        if progress >= 0.75 { return "Fast geschafft! Nur noch ein paar Schritte." }
        if progress >= 0.5 { return "Halbzeit! Du bist auf einem guten Weg." }
        if progress >= 0.25 { return "Guter Start! Bleib in Bewegung." }
        return "Jeder Schritt bringt dich näher ans Ziel."
    }
}

struct ActivityRingsHeader: View {
    let calories, calGoal, exercise, exGoal, stand, standGoal: Double
    var body: some View {
        HStack(spacing: 24) {
            ActivityRing(progress: calories / calGoal, color: AppleColors.move, icon: "flame.fill", size: 95)
            ActivityRing(progress: exercise / exGoal, color: AppleColors.exercise, icon: "timer", size: 95)
            ActivityRing(progress: stand / standGoal, color: AppleColors.stand, icon: "figure.stand", size: 95)
        }.padding(.vertical, 10)
    }
}

struct CalendarActivityView: View {
    let days: [DayActivity]
    let calendar = Calendar.current
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 15) {
                Text("Aktivität").font(.headline).bold()
                HStack(spacing: 0) {
                    ForEach(days) { day in
                        VStack(spacing: 8) {
                            Text(day.date.formatted(.dateTime.weekday(.narrow))).font(.caption2).foregroundColor(.secondary)
                            ZStack(alignment: .topTrailing) {
                                ActivityRingVisual(calories: day.calories, calGoal: day.caloriesGoal, exercise: day.exercise, exGoal: day.exerciseGoal, stand: day.stand, standGoal: day.standGoal, size: 32)
                                
                                if day.hasWorkout {
                                    Circle().fill(Color.yellow).frame(width: 7, height: 7).offset(x: 3, y: -3)
                                }
                            }
                            Text(day.date.formatted(.dateTime.day())).font(.system(size: 10, weight: .bold))
                        }.frame(maxWidth: .infinity)
                    }
                    if days.count < 7 {
                        ForEach(0..<(7-days.count), id: \.self) { _ in
                            Spacer().frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }.padding(.horizontal, 24)
    }
}

struct ActivityRingVisual: View {
    let calories, calGoal, exercise, exGoal, stand, standGoal: Double
    let size: CGFloat

    @State private var animMove: Double = 0
    @State private var animEx: Double = 0
    @State private var animStand: Double = 0

    var body: some View {
        ZStack {
            Circle().stroke(AppleColors.move.opacity(0.1), lineWidth: size * 0.12).frame(width: size)
            Circle().trim(from: 0, to: CGFloat(min(animMove, 1.0))).stroke(AppleColors.move, style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round)).frame(width: size).rotationEffect(.degrees(-90))

            Circle().stroke(AppleColors.exercise.opacity(0.1), lineWidth: size * 0.12).frame(width: size * 0.72)
            Circle().trim(from: 0, to: CGFloat(min(animEx, 1.0))).stroke(AppleColors.exercise, style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round)).frame(width: size * 0.72).rotationEffect(.degrees(-90))

            Circle().stroke(AppleColors.stand.opacity(0.1), lineWidth: size * 0.12).frame(width: size * 0.44)
            Circle().trim(from: 0, to: CGFloat(min(animStand, 1.0))).stroke(AppleColors.stand, style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round)).frame(width: size * 0.44).rotationEffect(.degrees(-90))
        }
        .onAppear {
            animate()
        }
        .onChange(of: calories) { oldValue, newValue in animate() }
    }

    private func animate() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0).delay(0.2)) {
            animMove = calories / calGoal
            animEx = exercise / exGoal
            animStand = stand / standGoal
        }
    }
}
struct ActivityBreakdownCard: View {
    let currentCalories, caloriesGoal, currentExercise, exerciseGoal, currentStand, standGoal, currentSteps, stepsGoal: Double
    @Binding var showEditGoals: Bool
    var body: some View {
        GlassCard {
            VStack(spacing: 24) {
                HStack {
                    Label("Details", systemImage: "list.bullet.circle.fill").font(.headline).bold()
                    Spacer()
                    Button { showEditGoals = true } label: { Image(systemName: "pencil.circle.fill").symbolRenderingMode(.hierarchical).font(.title2).foregroundColor(AppleColors.ultraOrange) }
                }
                VStack(spacing: 20) {
                    ProgressRow(label: "Bewegen", current: currentCalories, goal: caloriesGoal, unit: "kcal", color: AppleColors.move)
                    ProgressRow(label: "Training", current: currentExercise, goal: exerciseGoal, unit: "Min", color: AppleColors.exercise)
                    ProgressRow(label: "Stehen", current: currentStand, goal: standGoal, unit: "Std", color: AppleColors.stand)
                    Divider().padding(.vertical, 4).opacity(0.5)
                    HStack {
                        ActivityRing(progress: currentSteps / stepsGoal, color: AppleColors.steps, icon: "figure.walk", size: 55, showPercentage: false)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(currentSteps.formattedWithPoints(isInteger: true)) Schritte").font(.system(.title3, design: .rounded)).bold()
                            Text("Tagesziel: \(stepsGoal.formattedWithPoints(isInteger: true))").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }.padding(.horizontal, 24)
    }
}

struct RecentWorkoutsSection: View {
    let workouts: [Workout]
    @Binding var selectedTab: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Letzte Trainings").font(.system(.title2, design: .rounded)).bold()
                Spacer()
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    withAnimation { selectedTab = 1 }
                }) {
                    Text("Alle anzeigen")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundColor(AppleColors.ultraOrange)
                }
            }.padding(.horizontal, 24)
            
            if workouts.isEmpty {
                GlassCard {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "figure.walk.circle")
                                .font(.title)
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("Noch keine Trainings")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(Array(workouts.prefix(5))) { workout in
                        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                            WorkoutRow(workout: workout)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Helper UI Components

struct BackgroundView: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        ZStack {
            Color(colorScheme == .dark ? .black : .white).edgesIgnoringSafeArea(.all)
            MeshBlob(color: .blue.opacity(0.12), size: 400, offset: CGSize(width: -150, height: -350))
            MeshBlob(color: .orange.opacity(0.12), size: 350, offset: CGSize(width: 150, height: 100))
            MeshBlob(color: .green.opacity(0.08), size: 450, offset: CGSize(width: -50, height: 400))
        }
    }
}

struct MeshBlob: View {
    let color: Color; let size: CGFloat; let offset: CGSize
    var body: some View { Circle().fill(color).frame(width: size).blur(radius: 70).offset(offset) }
}

struct LoadingSplashView: View {
    var body: some View {
        ZStack {
            BackgroundView()
            VStack(spacing: 40) {
                FitnessLogo(size: 150).shadow(color: .black.opacity(0.1), radius: 20)
                VStack(spacing: 12) {
                    Text("FitnessApp").font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Version 0.1 beta").font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
                }
                ProgressView().tint(AppleColors.ultraOrange).padding(.top, 20)
            }
        }
    }
}

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("userName") private var userName: String = ""
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var currentPage = 0
    var body: some View {
        ZStack {
            BackgroundView()
            VStack {
                TabView(selection: $currentPage) {
                    OnboardingPage(title: "Willkommen", description: "Schön, dass du da bist! Wie dürfen wir dich nennen?", logoSize: 180) {
                        TextField("Dein Name", text: $userName).textFieldStyle(.plain).font(.system(size: 24, weight: .bold, design: .rounded)).multilineTextAlignment(.center).padding().background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 40)
                    }.tag(0)
                    OnboardingPage(title: "Aktivität", description: "Deine täglichen Ringe, perfekt visualisiert.", logoSize: 180) { EmptyView() }.tag(1)
                    OnboardingAuthPage().tag(2)
                }.tabViewStyle(PageTabViewStyle())
                if currentPage < 2 {
                    Button("Weiter") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        withAnimation { currentPage += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(AppleColors.ultraOrange)
                    .padding()
                    .disabled(currentPage == 0 && userName.isEmpty)
                }
            }
        }
    }
}

struct OnboardingPage<Content: View>: View {
    let title: String; let description: String; var logoSize: CGFloat; let extraContent: Content
    init(title: String, description: String, logoSize: CGFloat, @ViewBuilder extraContent: () -> Content) {
        self.title = title; self.description = description; self.logoSize = logoSize; self.extraContent = extraContent()
    }
    var body: some View {
        VStack(spacing: 40) { FitnessLogo(size: logoSize); VStack(spacing: 20) { Text(title).font(.system(size: 32, weight: .bold, design: .rounded)).multilineTextAlignment(.center); Text(description).font(.system(.body, design: .rounded)).multilineTextAlignment(.center).foregroundColor(.secondary).padding(.horizontal, 40); extraContent } }
    }
}

struct OnboardingAuthPage: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @State private var isRequesting = false
    var body: some View {
        VStack(spacing: 40) {
            ZStack { FitnessLogo(size: 150).opacity(0.3); Image(systemName: "lock.shield.fill").font(.system(size: 80)).foregroundColor(.blue) }
            VStack(spacing: 20) { Text("Privatsphäre").font(.system(size: 32, weight: .bold, design: .rounded)); Text("Deine Daten bleiben auf deinem Gerät. Wir benötigen nur den Lesezugriff.").font(.system(.body, design: .rounded)).multilineTextAlignment(.center).foregroundColor(.secondary).padding(.horizontal, 40) }
            Button(action: { isRequesting = true; healthKitManager.requestAuthorization { success in if success { hasCompletedOnboarding = true }; isRequesting = false } }) {
                if isRequesting { ProgressView() }
                else { Text("Zugriff erlauben").font(.headline).frame(maxWidth: .infinity).padding().background(AppleColors.ultraOrange.gradient).foregroundColor(.white).clipShape(Capsule()) }
            }.padding(.horizontal, 60)
        }
    }
}

struct LiveWorkoutCard: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var selectedWorkoutName = "Laufen"
    @State private var selectedWorkoutIcon = "figure.run"

    let availableWorkouts: [(name: String, icon: String)] = [
        ("Laufen", "figure.run"),
        ("Radfahren", "figure.outdoor.cycle"),
        ("Gehen", "figure.walk"),
        ("Krafttraining", "figure.strengthtraining.traditional"),
        ("Yoga", "figure.yoga")
    ]

    var body: some View {
        GlassCard {
            HStack(spacing: 20) {
                if healthKitManager.activeActivity == nil {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bereit für ein Training?").font(.headline).bold()

                        Menu {
                            ForEach(availableWorkouts, id: \.name) { workout in
                                Button(action: {
                                    HapticManager.shared.selection()
                                    selectedWorkoutName = workout.name
                                    selectedWorkoutIcon = workout.icon
                                }) {
                                    Label(workout.name, systemImage: workout.icon)
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedWorkoutIcon)
                                Text(selectedWorkoutName)
                                Image(systemName: "chevron.up.chevron.down").font(.caption)
                            }
                            .font(.subheadline)
                            .foregroundColor(AppleColors.ultraOrange)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(AppleColors.ultraOrange.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    Spacer()
                    Button(action: { 
                        HapticManager.shared.impact(style: .heavy)
                        withAnimation { healthKitManager.startLiveWorkout(name: selectedWorkoutName, icon: selectedWorkoutIcon) } 
                    }) {
                        Image(systemName: "play.circle.fill").font(.system(size: 44)).symbolRenderingMode(.hierarchical).foregroundColor(AppleColors.ultraOrange)
                    }
                } else {
                    HStack(spacing: 15) {
                        ZStack { Circle().fill(AppleColors.ultraOrange.opacity(0.2)).frame(width: 44, height: 44); Image(systemName: healthKitManager.activeActivity?.attributes.workoutIcon ?? "figure.run").foregroundColor(AppleColors.ultraOrange).scaleEffect(1.2) }
                        VStack(alignment: .leading, spacing: 2) { Text("Workout läuft").font(.headline).bold(); Text("Daten werden live übertragen...").font(.caption).foregroundColor(.secondary) }
                    }
                    Spacer()
                    Button(action: { 
                        HapticManager.shared.impact(style: .rigid)
                        withAnimation { healthKitManager.stopLiveWorkout() } 
                    }) {
                        Image(systemName: "stop.circle.fill").font(.system(size: 44)).symbolRenderingMode(.hierarchical).foregroundColor(.red)
                    }
                }
            }
        }.padding(.horizontal, 24)
    }
}
struct ActionButton: View {
    let title: String; let icon: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            action()
        }) {
            HStack {
                Image(systemName: icon).font(.headline)
                Text(title).font(.system(.subheadline, design: .rounded)).bold()
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16).background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 1))
        }.tint(AppleColors.ultraOrange)
    }
}

struct ProgressRow: View {
    let label: String; let current: Double; let goal: Double; let unit: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label).font(.system(.subheadline, design: .rounded)).foregroundColor(.secondary)
                Spacer()
                Text("\(current.formattedWithPoints(isInteger: true))").font(.system(.body, design: .rounded)).bold()
                Text("/ \(goal.formattedWithPoints(isInteger: true)) \(unit)").font(.system(.caption, design: .rounded)).foregroundColor(.secondary)
            }
            Capsule().fill(color.opacity(0.08)).frame(height: 10).overlay(
                GeometryReader { geo in
                    Capsule().fill(color.gradient).frame(width: geo.size.width * CGFloat(min(current / goal, 1.0)))
                        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                }
            )
        }
    }
}

struct WorkoutRow: View {
    let workout: Workout
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.gradient.opacity(0.12))
                    .frame(width: 54, height: 54)
                Image(systemName: workout.icon)
                    .font(.title3)
                    .foregroundStyle(Color.blue.gradient)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.activityName)
                    .font(.system(.headline, design: .rounded))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(.caption, design: .rounded))
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDuration(workout.duration))
                    .font(.system(.subheadline, design: .rounded))
                    .bold()
                
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                    Text("\(Int(workout.calories)) kcal")
                        .font(.system(.caption, design: .rounded))
                        .bold()
                }
                .foregroundColor(.orange)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary.opacity(0.4))
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(style: .light)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        return f.string(from: duration) ?? "0m"
    }
}

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("userName") private var userName: String = ""
    @State private var showResetAlert = false
    
    var body: some View {
        List {
            Section {
                HStack(spacing: 15) {
                    ZStack {
                        Circle()
                            .fill(AppleColors.ultraOrange.gradient)
                            .frame(width: 60, height: 60)
                        Text(userName.prefix(1).uppercased())
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Dein Name", text: $userName)
                            .font(.system(.headline, design: .rounded))
                        Text("Fitness-Profil")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Profil")
            }
            
            Section {
                Toggle(isOn: $isDarkMode) {
                    Label("Dark Mode", systemImage: "moon.fill")
                }
                .tint(AppleColors.ultraOrange)
                
                NavigationLink(destination: Text("Datenschutz-Bestimmungen")) {
                    Label("Datenschutz", systemImage: "hand.raised.fill")
                }
            } header: {
                Text("Erscheinungsbild & Sicherheit")
            }
            
            Section {
                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    Label("Setup zurücksetzen", systemImage: "arrow.counterclockwise")
                }
            } footer: {
                Text("Dies löscht deine App-Einstellungen, aber nicht deine Health-Daten.")
            }
            
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("FitnessApp").font(.headline).bold()
                        Text("Version 0.2.1 (Alpha)").font(.caption).monospaced()
                        Text("Made with ❤️ for Fitness").font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Einstellungen")
        .scrollContentBackground(.hidden)
        .background(BackgroundView())
        .alert("Setup zurücksetzen?", isPresented: $showResetAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Zurücksetzen", role: .destructive) {
                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                HapticManager.shared.notification(type: .success)
            }
        } message: {
            Text("Möchtest du das Onboarding wirklich erneut starten?")
        }
    }
}

extension HealthKitError: Identifiable {
    var id: String { self.localizedDescription }
}

struct Award: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isEarned: Bool
}

struct AwardsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @AppStorage("stepsGoal") var stepsGoal: Double = 10000

    var awards: [Award] {
        [
            Award(title: "Erster Schritt", description: "Absolviere dein erstes Workout.", icon: "figure.walk.circle.fill", color: .blue, isEarned: !healthKitManager.recentWorkouts.isEmpty),
            Award(title: "Schritt-Meister", description: "Erreiche 10.000 Schritte an einem Tag.", icon: "shoeprints.fill", color: .cyan, isEarned: healthKitManager.todaySteps >= 10000),
            Award(title: "Kalorien-Brenner", description: "Verbrenne über 500 kcal an einem Tag.", icon: "flame.fill", color: .orange, isEarned: healthKitManager.todayCalories >= 500),
            Award(title: "Dauerläufer", description: "Trainiere für mehr als 30 Minuten.", icon: "timer", color: .green, isEarned: healthKitManager.todayExercise >= 30)
        ]
    }

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            BackgroundView()
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(awards) { award in
                        AwardCard(award: award)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Erfolge")
    }
}

struct AwardCard: View {
    let award: Award
    
    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(award.isEarned ? award.color.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: award.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(award.isEarned ? award.color.gradient : Color.gray.gradient)
                }
                
                Text(award.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Text(award.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .opacity(award.isEarned ? 1.0 : 0.5)
        }
    }
}
