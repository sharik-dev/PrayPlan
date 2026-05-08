import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var settings: [UserSettings]
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label(String(localized: "tab.prayer",    defaultValue: "Prières"),    systemImage: "moon.stars.fill") }
            TasksView()
                .tabItem { Label(String(localized: "tab.tasks",     defaultValue: "Tâches"),     systemImage: "checklist") }
            HabitsView()
                .tabItem { Label(String(localized: "tab.habits",    defaultValue: "Habitudes"),  systemImage: "repeat.circle.fill") }
            QiblaView()
                .tabItem { Label(String(localized: "tab.qibla",     defaultValue: "Qibla"),      systemImage: "location.north.line.fill") }
            SettingsView()
                .tabItem { Label(String(localized: "tab.settings",  defaultValue: "Paramètres"), systemImage: "gearshape.fill") }
        }
        .tint(.brandGreen)
        .onAppear { ensureDefaultSettings() }
    }

    private func ensureDefaultSettings() {
        guard settings.isEmpty else { return }
        context.insert(UserSettings())
    }
}
