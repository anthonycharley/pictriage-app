import Foundation
import UserNotifications

/// Schedules (and cancels) the real weekly local notification behind Settings'
/// "Weekly cleanup reminder" toggle. Local notifications need no special
/// entitlement — just runtime authorization — so this is the whole
/// implementation; no Info.plist or capability changes required.
enum NotificationScheduler {
    static let identifier = "weekly-cleanup-reminder"

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Replaces any previously scheduled reminder with one for the given
    /// canonical day/time (see `AppState.canonicalWeekdayOrder` /
    /// `SettingsView.timeOptions` for the exact string formats expected).
    static func scheduleWeekly(day: String, time: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard let weekdayIndex = AppState.canonicalWeekdayOrder.firstIndex(of: day),
              let (hour, minute) = parseTime(time) else { return }

        var dateComponents = DateComponents()
        dateComponents.weekday = weekdayIndex + 1 // Calendar weekday: Sunday = 1 ... Saturday = 7
        dateComponents.hour = hour
        dateComponents.minute = minute

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time for a cleanup sprint")
        content.body = String(localized: "A few minutes now keeps your library tidy \u{2014} pick up where you left off.")
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    private static func parseTime(_ canonical: String) -> (hour: Int, minute: Int)? {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "h:mm a"
        guard let date = parser.date(from: canonical) else { return nil }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let hour = comps.hour, let minute = comps.minute else { return nil }
        return (hour, minute)
    }
}
