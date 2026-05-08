import SwiftUI
import SwiftData

@main
struct PrayPlanApp: App {
    @State private var locationService     = LocationService()
    @State private var prayerTimeService   = PrayerTimeService()
    @State private var notificationService = NotificationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationService)
                .environment(prayerTimeService)
                .environment(notificationService)
                .task { await notificationService.requestPermission() }
        }
        .modelContainer(for: [
            UserTask.self,
            UserHabit.self,
            HabitCompletion.self,
            UserSettings.self
        ])
    }
}
