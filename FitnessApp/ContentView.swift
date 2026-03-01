import SwiftUI
import HealthKit

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
    
    @State private var currentSteps: Double = 0
    @State private var currentCalories: Double = 0
    @State private var currentExercise: Double = 0
    @State private var currentStand: Double = 0
    
    @State private var recentWorkouts: [Workout] = []
    @State private var showLogWater = false
    @State private var showEditGoals = false
    @State private var isLoading = true
    
    init() {
        // iOS 26 TabBar customization
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
        .onChange(of: scenePhase) {
            if scenePhase == .active && !isLoading { refreshData() }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
    
    var MainLayout: some View {
        ZStack(alignment: .bottom) {
            TabView {
                NavigationView { SummaryTab }.tabItem { Label("Übersicht", systemImage: "sparkles") }
                StatsView().tabItem { Label("Trends", systemImage: "chart.line.uptrend.xyaxis") }
                NavigationView { SettingsView() }.tabItem { Label("Profil", systemImage: "person.crop.circle.fill") }
            }
            .tint(.primary)
        }
    }
    
    var SummaryTab: some View {
        ZStack {
            BackgroundView()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    // Personalized Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text(getTimeBasedGreeting())
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill").foregroundColor(.orange)
                            Text(getMotivationText())
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    // Spatial Activity Hub
                    HStack(spacing: 24) {
                        ActivityRing(progress: currentCalories / caloriesGoal, color: AppleColors.move, icon: "flame.fill", size: 95)
                        ActivityRing(progress: currentExercise / exerciseGoal, color: AppleColors.exercise, icon: "timer", size: 95)
                        ActivityRing(progress: currentStand / standGoal, color: AppleColors.stand, icon: "figure.stand", size: 95)
                    }
                    .padding(.vertical, 10)
                    
                    // The "All-in-One" Progress Hub
                    GlassCard {
                        VStack(spacing: 24) {
                            HStack {
                                Label("Aktivität", systemImage: "activitylog.circle.fill")
                                    .font(.headline).bold()
                                Spacer()
                                Button { showEditGoals = true } label: {
                                    Image(systemName: "slider.horizontal.3")
                                        .foregroundStyle(.secondary)
                                        .padding(8)
                                        .background(.thinMaterial)
                                        .clipShape(Circle())
                                }
                            }
                            
                            VStack(spacing: 20) {
                                ProgressRow(label: "Bewegen", current: currentCalories, goal: caloriesGoal, unit: "kcal", color: AppleColors.move)
                                ProgressRow(label: "Training", current: currentExercise, goal: exerciseGoal, unit: "Min", color: AppleColors.exercise)
                                ProgressRow(label: "Stehen", current: currentStand, goal: standGoal, unit: "Std", color: AppleColors.stand)
                                
                                Divider().padding(.vertical, 4).opacity(0.5)
                                
                                HStack {
                                    ActivityRing(progress: currentSteps / stepsGoal, color: AppleColors.steps, icon: "figure.walk", size: 55)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(currentSteps.formattedWithPoints(isInteger: true)) Schritte")
                                            .font(.system(.title3, design: .rounded)).bold()
                                        Text("Tagesziel: \(stepsGoal.formattedWithPoints(isInteger: true))")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Quick Actions
                    HStack(spacing: 16) {
                        ActionButton(title: "Wasser", icon: "drop.fill", color: .blue) { showLogWater = true }
                        ActionButton(title: "Training", icon: "plus", color: .green) { /* Manual workout entry */ }
                    }
                    .padding(.horizontal, 24)
                    
                    // Recent Activities
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Letzte Trainings").font(.system(.title2, design: .rounded)).bold().padding(.horizontal, 24)
                        if recentWorkouts.isEmpty {
                            Text("Noch keine Trainingsdaten").foregroundColor(.secondary).padding()
                        } else {
                            VStack(spacing: 14) {
                                ForEach(recentWorkouts) { workout in
                                    NavigationLink(destination: WorkoutDetailView(workout: workout)) { WorkoutRow(workout: workout) }.buttonStyle(PlainButtonStyle())
                                }
                            }.padding(.horizontal, 24)
                        }
                    }
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
    
    private func getTimeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Guten Morgen" + (userName.isEmpty ? "" : ", \(userName)") }
        if hour < 18 { return "Guten Tag" + (userName.isEmpty ? "" : ", \(userName)") }
        return "Guten Abend" + (userName.isEmpty ? "" : ", \(userName)")
    }
    
    private func getMotivationText() -> String {
        if currentSteps / stepsGoal >= 1.0 { return "Ziel erreicht! Du bist heute unschlagbar." }
        if currentSteps / stepsGoal >= 0.5 { return "Halbzeit! Der Rest ist jetzt ein Kinderspiel." }
        return "Jeder Schritt bringt dich näher ans Ziel."
    }
    
    private func refreshData() {
        if healthKitManager.isAuthorized {
            healthKitManager.fetchTodayActivity { steps, calories, exercise, stand in
                withAnimation(.spring()) {
                    self.currentSteps = steps; self.currentCalories = calories; self.currentExercise = exercise; self.currentStand = stand
                }
            }
            healthKitManager.fetchRecentWorkouts { workouts in withAnimation { self.recentWorkouts = workouts } }
        }
    }
}

// MARK: - Reusable Components

struct ActionButton: View {
    let title: String; let icon: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).font(.headline)
                Text(title).font(.system(.subheadline, design: .rounded)).bold()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 1))
        }
        .tint(color)
    }
}

struct BackgroundView: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        ZStack {
            Color(colorScheme == .dark ? .black : .white).edgesIgnoringSafeArea(.all)
            // Floating Mesh Blobs
            MeshBlob(color: .blue.opacity(0.12), size: 400, offset: CGSize(width: -150, height: -350))
            MeshBlob(color: .orange.opacity(0.12), size: 350, offset: CGSize(width: 150, height: 100))
            MeshBlob(color: .green.opacity(0.08), size: 450, offset: CGSize(width: -50, height: 400))
        }
    }
}

struct MeshBlob: View {
    let color: Color; let size: CGFloat; let offset: CGSize
    var body: some View {
        Circle().fill(color).frame(width: size).blur(radius: 70).offset(offset)
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
                Circle().fill(Color.blue.gradient.opacity(0.15)).frame(width: 52, height: 52)
                Image(systemName: workout.icon).font(.title3).foregroundStyle(Color.blue.gradient)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.activityName).font(.system(.headline, design: .rounded))
                Text(workout.date.formatted(date: .abbreviated, time: .shortened)).font(.system(.caption, design: .rounded)).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDuration(workout.duration)).font(.system(.subheadline, design: .rounded)).bold()
                Text("\(Int(workout.calories)) kcal").font(.system(.caption, design: .rounded)).foregroundColor(.orange).bold()
            }
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary.opacity(0.5))
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.1), lineWidth: 0.5))
    }
    private func formatDuration(_ duration: TimeInterval) -> String {
        let f = DateComponentsFormatter(); f.allowedUnits = [.hour, .minute]; f.unitsStyle = .abbreviated; return f.string(from: duration) ?? ""
    }
}

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("userName") private var userName: String = ""
    var body: some View {
        List {
            Section("Benutzer") { TextField("Dein Name", text: $userName).font(.system(.body, design: .rounded)) }
            Section("Erscheinungsbild") { Toggle(isOn: $isDarkMode) { Label("Dark Mode", systemImage: "moon.fill") } }
            Section("Info") { HStack { Text("Version"); Spacer(); Text("0.1 beta").foregroundColor(.secondary) } }
            Section { Button("Setup zurücksetzen") { UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding") }.foregroundColor(.red) }
        }
        .background(Color.clear).scrollContentBackground(.hidden).navigationTitle("Einstellungen")
    }
}

// MARK: - Splash & Onboarding

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
                ProgressView().tint(.primary).padding(.top, 20)
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
                        TextField("Dein Name", text: $userName).textFieldStyle(.plain).font(.system(size: 24, weight: .bold, design: .rounded)).multilineTextAlignment(.center).padding()
                            .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 40)
                    }.tag(0)
                    OnboardingPage(title: "Aktivität", description: "Deine täglichen Ringe, perfekt visualisiert.", logoSize: 180) { EmptyView() }.tag(1)
                    OnboardingAuthPage().tag(2)
                }.tabViewStyle(PageTabViewStyle())
                if currentPage < 2 {
                    Button("Weiter") { withAnimation { currentPage += 1 } }.buttonStyle(.borderedProminent).controlSize(.large).padding().disabled(currentPage == 0 && userName.isEmpty)
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
        VStack(spacing: 40) {
            FitnessLogo(size: logoSize)
            VStack(spacing: 20) {
                Text(title).font(.system(size: 32, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
                Text(description).font(.system(.body, design: .rounded)).multilineTextAlignment(.center).foregroundColor(.secondary).padding(.horizontal, 40)
                extraContent
            }
        }
    }
}

struct OnboardingAuthPage: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @State private var isRequesting = false
    var body: some View {
        VStack(spacing: 40) {
            ZStack { FitnessLogo(size: 150).opacity(0.3); Image(systemName: "lock.shield.fill").font(.system(size: 80)).foregroundColor(.blue) }
            VStack(spacing: 20) {
                Text("Privatsphäre").font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Deine Daten bleiben auf deinem Gerät. Wir benötigen nur den Lesezugriff.").font(.system(.body, design: .rounded)).multilineTextAlignment(.center).foregroundColor(.secondary).padding(.horizontal, 40)
            }
            Button(action: {
                isRequesting = true
                healthKitManager.requestAuthorization { success in if success { hasCompletedOnboarding = true }; isRequesting = false }
            }) {
                if isRequesting { ProgressView() }
                else { Text("Zugriff erlauben").font(.headline).frame(maxWidth: .infinity).padding().background(Color.blue.gradient).foregroundColor(.white).clipShape(Capsule()) }
            }.padding(.horizontal, 60)
        }
    }
}
