import SwiftUI

/// Mirrors the `Component` class's state and logic from `Photo Cleaner Dashboard.dc.html`,
/// now backed by a real on-device scan (`PhotoLibraryService`) instead of sample data.
@MainActor
final class AppState: ObservableObject {
    // Onboarding / identity — persisted locally, see `persistPrefs()`.
    @Published var userName: String = ""
    @Published var hasOnboarded: Bool = false

    // Navigation
    @Published var tab: Tab = .home
    @Published var reviewKind: ReviewKind = .duplicates
    @Published var selectedGroupID: String?
    @Published var previewIndex: Int?

    // Cleanup sprint / home — persisted locally, see `persistPrefs()`.
    @Published var reviewed: Int = 0
    @Published var dayOf: Int = 1
    @Published var sprintDays: Int = 7
    @Published var freedGb: Double = 0

    // Queue
    @Published var queue: [Photo] = []
    @Published var confirmed: Bool = false

    // Toast
    @Published var toast: String?
    private var toastTask: Task<Void, Never>?

    // Settings
    @Published var authStatus: LibraryAuthStatus = .notGranted
    @Published var scanning: Bool = false
    @Published var lastScanText: String = String(localized: "never")
    @Published var remindOn: Bool = false {
        didSet {
            persistPrefs()
            guard remindOn != oldValue else { return }
            if remindOn {
                Task { [weak self] in await self?.enableReminder() }
            } else {
                NotificationScheduler.cancel()
            }
        }
    }
    @Published var remindDay: String = "Sunday" {
        didSet {
            persistPrefs()
            if remindOn { NotificationScheduler.scheduleWeekly(day: remindDay, time: remindTime) }
        }
    }
    @Published var remindTime: Date = Calendar.current.date(from: DateComponents(hour: 10, minute: 0)) ?? Date() {
        didSet {
            persistPrefs()
            if remindOn { NotificationScheduler.scheduleWeekly(day: remindDay, time: remindTime) }
        }
    }
    @Published var scanCleared: Bool = false
    @Published var howDeleteOpen: Bool = false

    // Scan results — empty until a scan has run, which is the honest state
    // before the user has granted access or the first scan has completed.
    @Published var duplicateGroups: [PhotoGroup] = []
    @Published var screenshotGroups: [PhotoGroup] = []

    init() {
        loadPrefs()
        authStatus = PhotoLibraryService.shared.currentStatus()
        if authStatus != .notGranted {
            Task { await runScan() }
        }
        if remindOn {
            NotificationScheduler.scheduleWeekly(day: remindDay, time: remindTime)
        }
    }

    var access: String { authStatus.rawValue }

    var duplicateCount: Int { duplicateGroups.reduce(0) { $0 + $1.photos.count } }
    var duplicateReclaimableGb: Double { duplicateGroups.reduce(0) { $0 + $1.reclaimableGb } }
    var screenshotCount: Int { screenshotGroups.reduce(0) { $0 + $1.photos.count } }
    var screenshotReclaimableGb: Double { screenshotGroups.reduce(0) { $0 + $1.reclaimableGb } }

    var quickWins: [QuickWin] {
        [
            QuickWin(label: String(localized: "Duplicates"), count: duplicateCount, gb: duplicateReclaimableGb.fixed(1), dotColor: Theme.accent, kind: .duplicates),
            QuickWin(label: String(localized: "Screenshots"), count: screenshotCount, gb: screenshotReclaimableGb.fixed(1), dotColor: Color(hex: "D9722A"), kind: .screenshots)
        ]
    }

    // MARK: - Greeting

    private enum TimeOfDay { case morning, afternoon, evening }

    /// Uses the device's current time zone via `Calendar.current`, which
    /// follows the user's iOS Language & Region settings.
    private var timeOfDay: TimeOfDay {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        default: return .evening
        }
    }

    /// The greeting shown on Home: "Good morning, Priya" once a name has
    /// been given during onboarding, or just "Good morning!" otherwise.
    /// Each phrase is localized as a whole (not assembled from translated
    /// fragments) since punctuation around a greeting varies by language
    /// — e.g. Spanish wraps it in "¡...!" rather than appending "!".
    var greetingLine: String {
        if userName.isEmpty {
            switch timeOfDay {
            case .morning: return String(localized: "Good morning!")
            case .afternoon: return String(localized: "Good afternoon!")
            case .evening: return String(localized: "Good evening!")
            }
        } else {
            switch timeOfDay {
            case .morning: return String(localized: "Good morning, \(userName)")
            case .afternoon: return String(localized: "Good afternoon, \(userName)")
            case .evening: return String(localized: "Good evening, \(userName)")
            }
        }
    }

    func completeOnboarding(name: String) {
        userName = name
        hasOnboarded = true
        persistPrefs()
    }

    // MARK: - Derived

    var currentGroups: [PhotoGroup] { reviewKind == .duplicates ? duplicateGroups : screenshotGroups }

    var selectedGroup: PhotoGroup? {
        guard let id = selectedGroupID else { return nil }
        return currentGroups.first { $0.id == id }
    }

    var previewPhoto: Photo? {
        guard let group = selectedGroup, let index = previewIndex, group.photos.indices.contains(index) else { return nil }
        return group.photos[index]
    }

    var isHome: Bool { tab == .home }
    var isReview: Bool { tab == .review && selectedGroup == nil }
    var isDetail: Bool { tab == .review && selectedGroup != nil }
    var isQueue: Bool { tab == .queue }
    var isSettings: Bool { tab == .settings }

    var queueGb: Double { queue.reduce(0) { $0 + $1.gb } }

    var sprintBadgeText: String { String(localized: "Day \(dayOf) of your cleanup sprint") }
    var sprintLineText: String { String(localized: "Your \(sprintDays)-day cleanup sprint \u{00B7} Day \(dayOf) of \(sprintDays)") }
    var goalTailText: String {
        reviewed >= 25
            ? String(localized: "Today\u{2019}s goal is done — anything else is bonus.")
            : String(localized: "\(25 - reviewed) more and today\u{2019}s goal is done.")
    }
    var ringProgress: Double { min(Double(reviewed), 25) / 25 }

    /// Days are stored internally as fixed canonical English identifiers
    /// (for state comparison — see `SettingsView`'s day chips) and only
    /// localized for display, via this helper. Times are stored as a real
    /// `Date` (only its hour/minute matter) so the picker and notification
    /// scheduler both work in the device's actual locale/format directly.
    nonisolated static let canonicalWeekdayOrder = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    static func localizedWeekdayName(_ canonical: String, short: Bool = false) -> String {
        guard let index = canonicalWeekdayOrder.firstIndex(of: canonical) else { return canonical }
        let symbols = short ? Calendar.current.shortWeekdaySymbols : Calendar.current.weekdaySymbols
        return symbols.indices.contains(index) ? symbols[index] : canonical
    }

    var localizedRemindDayName: String { Self.localizedWeekdayName(remindDay) }

    private var localizedRemindTimeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: remindTime)
    }

    var remindHintText: String {
        remindOn
            ? String(localized: "Every \(localizedRemindDayName) at \(localizedRemindTimeText)")
            : String(localized: "Off — no nudges unless you turn this on")
    }

    var accessHintText: String {
        switch authStatus {
        case .limitedAccess: return String(localized: "Only the photos you picked are scanned. Tap Rescan after adding more.")
        case .notGranted: return String(localized: "No photos can be scanned. Grant access in iOS Settings \u{203A} Privacy \u{203A} Photos.")
        case .fullAccess: return String(localized: "PicTriage can scan your whole library for duplicates and screenshots.")
        }
    }

    // MARK: - Navigation

    func go(_ tab: Tab, reviewKind: ReviewKind? = nil) {
        self.tab = tab
        if let reviewKind { self.reviewKind = reviewKind }
        selectedGroupID = nil
        previewIndex = nil
        toast = nil
        confirmed = false
    }

    func openGroup(_ group: PhotoGroup) {
        selectedGroupID = group.id
        toast = nil
    }

    func closeDetail() {
        selectedGroupID = nil
        previewIndex = nil
    }

    // MARK: - Toast

    func flash(_ message: String) {
        toastTask?.cancel()
        toast = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    // MARK: - Queue

    func isQueued(_ id: String) -> Bool { queue.contains { $0.id == id } }

    func toggle(_ photo: Photo) {
        if isQueued(photo.id) {
            queue.removeAll { $0.id == photo.id }
        } else {
            queue.append(photo)
        }
        confirmed = false
    }

    /// Bulk-toggles a group's non-best photos (mirrors `toggleAll` in the prototype):
    /// clears *all* of the group's photos from the queue first (including a manually
    /// queued "best" shot), then re-adds every non-best photo unless they were all
    /// already queued, in which case it just clears them.
    func toggleAll(_ group: PhotoGroup) {
        let ids = Set(group.photos.filter { !$0.best }.map(\.id))
        let allIn = ids.allSatisfy { id in queue.contains { $0.id == id } }
        var rest = queue.filter { photo in !group.photos.contains { $0.id == photo.id } }
        if !allIn {
            rest.append(contentsOf: group.photos.filter { ids.contains($0.id) })
        }
        queue = rest
        confirmed = false
    }

    func confirmDelete() {
        guard !queue.isEmpty, !confirmed else { return }
        let idsToDelete = queue.map(\.id)
        let gb = queueGb
        let count = queue.count
        Task { [weak self] in
            guard let self else { return }
            do {
                try await PhotoLibraryService.shared.delete(localIdentifiers: idsToDelete)
                self.confirmed = true
                self.freedGb += gb
                self.reviewed += count
                self.queue = []
                self.persistPrefs()
                self.flash(String(localized: "\(gb.fixed(2)) GB cleaned — Day \(self.dayOf) is moving."))
                await self.runScan()
            } catch {
                self.flash(String(localized: "Couldn\u{2019}t delete — try again."))
            }
        }
    }

    // MARK: - Preview

    func openPreview(at index: Int) { previewIndex = index }
    func closePreview() { previewIndex = nil }
    func previewFirst() { previewIndex = 0 }
    func previewLast() { if let group = selectedGroup { previewIndex = group.photos.count - 1 } }
    func previewPrev() { if let i = previewIndex { previewIndex = max(0, i - 1) } }
    func previewNext() {
        if let i = previewIndex, let group = selectedGroup {
            previewIndex = min(group.photos.count - 1, i + 1)
        }
    }

    // MARK: - Settings

    /// Handles a tap on one of the three access segments. iOS only allows a
    /// single in-app permission prompt; once a decision has been made the
    /// only way to change it is the Settings app, so this either shows the
    /// real system prompt (first time) or deep-links there (every time after).
    func handleAccessTap() {
        if PhotoLibraryService.shared.isNotDetermined() {
            Task { await requestLibraryAccess() }
        } else {
            PhotoLibraryService.shared.openSystemSettings()
        }
    }

    func requestLibraryAccess() async {
        authStatus = await PhotoLibraryService.shared.requestAccess()
        if authStatus != .notGranted {
            await runScan()
        }
    }

    func runScan() async {
        guard !scanning else { return }
        scanning = true
        let result = await PhotoLibraryService.shared.scan()
        duplicateGroups = result.duplicateGroups
        screenshotGroups = result.screenshotGroups
        scanning = false
        scanCleared = false
        lastScanText = String(localized: "just now")
        persistPrefs()
    }

    func rescan() {
        guard authStatus != .notGranted else {
            flash(String(localized: "Grant photo access in Settings to scan your library."))
            return
        }
        guard !scanning else { return }
        Task { [weak self] in
            guard let self else { return }
            await self.runScan()
            self.flash(String(localized: "Library rescanned \u{00B7} \(self.duplicateGroups.count) duplicate groups, \(self.screenshotGroups.count) screenshot days found"))
        }
    }

    func clearScanData() {
        duplicateGroups = []
        screenshotGroups = []
        lastScanText = String(localized: "never")
        scanCleared = true
        persistPrefs()
        flash(String(localized: "Local scan index cleared. Your photos are untouched."))
    }

    private func enableReminder() async {
        let granted = await NotificationScheduler.requestAuthorization()
        if granted {
            NotificationScheduler.scheduleWeekly(day: remindDay, time: remindTime)
        } else {
            remindOn = false
            flash(String(localized: "Enable notifications for PicTriage in iOS Settings to turn this on."))
        }
    }

    // MARK: - Persistence

    /// `userName`/`hasOnboarded` were added after this was first shipped.
    /// A custom decoder (using `decodeIfPresent` with fallbacks for every
    /// field) means loading prefs saved before a future field is added
    /// degrades gracefully instead of failing entirely and silently
    /// resetting everything already persisted.
    private struct PersistedPrefs: Codable {
        var reviewed: Int
        var dayOf: Int
        var freedGb: Double
        var lastScanText: String
        var remindOn: Bool
        var remindDay: String
        var remindTime: Date
        var userName: String = ""
        var hasOnboarded: Bool = false

        init(reviewed: Int, dayOf: Int, freedGb: Double, lastScanText: String, remindOn: Bool, remindDay: String, remindTime: Date, userName: String, hasOnboarded: Bool) {
            self.reviewed = reviewed
            self.dayOf = dayOf
            self.freedGb = freedGb
            self.lastScanText = lastScanText
            self.remindOn = remindOn
            self.remindDay = remindDay
            self.remindTime = remindTime
            self.userName = userName
            self.hasOnboarded = hasOnboarded
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            reviewed = try c.decodeIfPresent(Int.self, forKey: .reviewed) ?? 0
            dayOf = try c.decodeIfPresent(Int.self, forKey: .dayOf) ?? 1
            freedGb = try c.decodeIfPresent(Double.self, forKey: .freedGb) ?? 0
            lastScanText = try c.decodeIfPresent(String.self, forKey: .lastScanText) ?? String(localized: "never")
            remindOn = try c.decodeIfPresent(Bool.self, forKey: .remindOn) ?? false
            remindDay = try c.decodeIfPresent(String.self, forKey: .remindDay) ?? "Sunday"
            let defaultTime = Calendar.current.date(from: DateComponents(hour: 10, minute: 0)) ?? Date()
            if let date = try? c.decode(Date.self, forKey: .remindTime) {
                // Current format: a real Date (only hour/minute are used).
                remindTime = date
            } else if let legacyLabel = try? c.decode(String.self, forKey: .remindTime) {
                // Pre-DatePicker format was a fixed string like "10:00 AM".
                let parser = DateFormatter()
                parser.locale = Locale(identifier: "en_US_POSIX")
                parser.dateFormat = "h:mm a"
                remindTime = parser.date(from: legacyLabel) ?? defaultTime
            } else {
                remindTime = defaultTime
            }
            userName = try c.decodeIfPresent(String.self, forKey: .userName) ?? ""
            hasOnboarded = try c.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? false
        }
    }

    private static let prefsKey = "com.pictriage.prefs.v1"

    private func persistPrefs() {
        let prefs = PersistedPrefs(
            reviewed: reviewed, dayOf: dayOf, freedGb: freedGb, lastScanText: lastScanText,
            remindOn: remindOn, remindDay: remindDay, remindTime: remindTime,
            userName: userName, hasOnboarded: hasOnboarded
        )
        guard let data = try? JSONEncoder().encode(prefs) else { return }
        UserDefaults.standard.set(data, forKey: Self.prefsKey)
    }

    private func loadPrefs() {
        guard let data = UserDefaults.standard.data(forKey: Self.prefsKey),
              let prefs = try? JSONDecoder().decode(PersistedPrefs.self, from: data) else { return }
        reviewed = prefs.reviewed
        dayOf = prefs.dayOf
        freedGb = prefs.freedGb
        lastScanText = prefs.lastScanText
        remindOn = prefs.remindOn
        remindDay = prefs.remindDay
        remindTime = prefs.remindTime
        userName = prefs.userName
        hasOnboarded = prefs.hasOnboarded
    }
}
