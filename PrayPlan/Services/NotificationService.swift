import Foundation
import UserNotifications

@Observable
final class NotificationService {
    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        _ = granted
    }

    func scheduleForWeek(schedules: [DailyPrayerSchedule], settings: UserSettings) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers:
            existingPrayerIdentifiers(from: schedules)
        )

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = .current

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for schedule in schedules {
            let dateStr = dateFormatter.string(from: schedule.date)
            for prayer in schedule.allPrayers where prayer.key != "sunrise" {
                guard settings.isPrayerEnabled(prayer.key) else { continue }
                guard prayer.time > Date() else { continue }

                let content = UNMutableNotificationContent()
                content.title = prayer.name
                content.body  = formatter.string(from: prayer.time)
                content.categoryIdentifier = "prayer"

                if let fileName = settings.azanSound.soundFileName {
                    content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: fileName))
                } else {
                    content.sound = nil
                }

                let dc = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: prayer.time
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "prayer_\(prayer.key)_\(dateStr)",
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        }
    }

    private func existingPrayerIdentifiers(from schedules: [DailyPrayerSchedule]) -> [String] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let keys = ["fajr", "dhuhr", "asr", "maghrib", "isha"]
        return schedules.flatMap { s in
            keys.map { "prayer_\($0)_\(dateFormatter.string(from: s.date))" }
        }
    }
}
