import SwiftUI
import SwiftData

@main
struct PrayPlanApp: App {
    @State private var locationService     = LocationService()
    @State private var prayerTimeService   = PrayerTimeService()
    @State private var notificationService = NotificationService()
    @State private var appBlockingService  = AppBlockingService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationService)
                .environment(prayerTimeService)
                .environment(notificationService)
                .environment(appBlockingService)
                .task { await notificationService.requestPermission() }
                .task { appBlockingService.checkStatus() }
        }
        .modelContainer(for: [
            UserTask.self,
            UserHabit.self,
            HabitCompletion.self,
            UserSettings.self,
            AppBlockingProfile.self,
            DayNote.self,
            SegmentGoal.self
        ])
    }
}
