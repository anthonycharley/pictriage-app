import SwiftUI

/// A real, in-app privacy policy that needs no hosted URL. Content here
/// should stay accurate to what the app actually does; verified against the
/// codebase (no network calls, no analytics, no third-party SDKs) before writing this.
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Section {
        let title: String
        let body: String
    }

    private var sections: [Section] {
        [
            Section(
                title: String(localized: "Everything happens on your device"),
                body: String(localized: "PicTriage scans your photo library, finds duplicates and screenshots, and generates thumbnails entirely on your iPhone. Nothing gets uploaded. The app doesn't make network requests of any kind, so there's no server, no analytics, and no third-party tracking to worry about.")
            ),
            Section(
                title: String(localized: "What PicTriage can see"),
                body: String(localized: "With your permission, PicTriage reads your Photos library through Apple's PhotosKit framework to group similar and screenshot photos. If you choose \u{201C}Selected Photos\u{201D} access, PicTriage only ever sees the photos you've picked. You can change this anytime in iOS Settings \u{203A} Privacy \u{203A} Photos.")
            ),
            Section(
                title: String(localized: "Deleting photos"),
                body: String(localized: "When you queue photos for deletion, PicTriage moves them to your iPhone's Recently Deleted album, where iOS keeps them for 30 days before removing them for good. PicTriage never deletes a photo permanently, and never touches a photo you haven't explicitly queued.")
            ),
            Section(
                title: String(localized: "What's stored, and where"),
                body: String(localized: "Your cleanup streak, scan history, and settings are stored locally on your device using iOS's standard app storage. None of it is backed up to any service PicTriage controls. If you use iCloud or iTunes/Finder backups, that's just Apple's normal device backup doing its thing, not something PicTriage sets up on its own.")
            ),
            Section(
                title: String(localized: "Notifications"),
                body: String(localized: "If you turn on the weekly cleanup reminder, PicTriage schedules a local notification on your device using iOS's notification system. There's no push server involved. The reminder is set and delivered entirely on your device.")
            ),
            Section(
                title: String(localized: "Questions"),
                body: String(localized: "PicTriage is built by a solo developer with one rule: your photos are yours, and they stay on your phone. If anything here is unclear, that's a bug in this page, not in the app. The code itself has no network access to misuse, and you're welcome to check that yourself.")
            ),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Last updated \(Self.lastUpdated)")
                        .font(.heading(12.5, weight: .bold))
                        .foregroundColor(Theme.textMuted)

                    ForEach(sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.title)
                                .font(.heading(16.5))
                                .foregroundColor(Theme.textPrimary)
                            Text(section.body)
                                .font(.heading(14, weight: .medium))
                                .foregroundColor(Theme.textMuted)
                                .lineSpacing(4)
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationTitle(Text("Privacy policy"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
        }
    }

    private static var lastUpdated: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: DateComponents(calendar: .current, year: 2026, month: 8, day: 30).date ?? Date())
    }
}
