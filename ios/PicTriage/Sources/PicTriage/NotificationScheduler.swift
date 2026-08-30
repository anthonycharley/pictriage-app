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
    /// canonical day (see `AppState.canonicalWeekdayOrder`) and time of day
    /// (only `time`'s hour/minute components are used).
    static func scheduleWeekly(day: String, time: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard let weekdayIndex = AppState.canonicalWeekdayOrder.firstIndex(of: day) else { return }
        let timeComps = Calendar.current.dateComponents([.hour, .minute], from: time)
        guard let hour = timeComps.hour, let minute = timeComps.minute else { return }

        var dateComponents = DateComponents()
        dateComponents.weekday = weekdayIndex + 1 // Calendar weekday: Sunday = 1 ... Saturday = 7
        dateComponents.hour = hour
        dateComponents.minute = minute

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time for a cleanup sprint")
        content.body = String(localized: "A few minutes now keeps your library tidy. Pick up where you left off.")
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
