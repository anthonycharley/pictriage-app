import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.requestReview) private var requestReview
    @State private var showPrivacyPolicy = false

    private static let accessOptions = ["Full Access", "Selected Photos", "Not Granted"]
    private static let dayOptions = AppState.canonicalWeekdayOrder

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.heading(26))
                    .foregroundColor(Theme.textPrimary)

                sectionLabel(String(localized: "PHOTO LIBRARY ACCESS"))
                accessCard

                sectionLabel(String(localized: "SCAN & CLEANUP"))
                scanCard

                sectionLabel(String(localized: "NOTIFICATIONS"))
                notificationsCard
                if state.remindOn {
                    reminderDetailCard
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                sectionLabel(String(localized: "PRIVACY"))
                privacyCard

                sectionLabel(String(localized: "SUPPORT"))
                supportCard
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 130)
            .animation(.easeOut(duration: 0.2), value: state.remindOn)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.heading(12))
            .tracking(1)
            .foregroundColor(Theme.labelMuted)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.cardBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: Access

    private var accessCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    ForEach(Self.accessOptions, id: \.self) { option in
                        let on = state.access == option
                        Button {
                            state.handleAccessTap()
                        } label: {
                            Text(NSLocalizedString(option, comment: "Photo library access level"))
                                .font(.heading(12.5))
                                .foregroundColor(on ? Theme.textPrimary : Theme.textMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(on ? Color.white : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                                .shadow(color: on ? Theme.cardShadow.opacity(0.18) : .clear, radius: 4, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(Theme.segmentBg)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Text(state.accessHintText)
                    .font(.heading(12.5, weight: .bold))
                    .foregroundColor(Theme.textMuted)
            }
            .padding(14)
        }
    }

    // MARK: Scan

    private var scanCard: some View {
        card {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Rescan library")
                        .font(.heading(15.5))
                        .foregroundColor(Theme.textPrimary)
                    Text(String(localized: "Last scan \(state.lastScanText)"))
                        .font(.heading(12.5, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                }
                Spacer(minLength: 0)
                Button {
                    state.rescan()
                } label: {
                    Text(state.scanning ? String(localized: "Scanning\u{2026}") : String(localized: "Rescan"))
                        .font(.heading(13.5))
                        .foregroundColor(.white)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 11)
                        .background(Theme.dark)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
        }
    }

    // MARK: Notifications

    private var notificationsCard: some View {
        card {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Weekly cleanup reminder")
                        .font(.heading(15.5))
                        .foregroundColor(Theme.textPrimary)
                    Text(state.remindHintText)
                        .font(.heading(12.5, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                }
                Spacer(minLength: 0)
                Button {
                    state.remindOn.toggle()
                } label: {
                    ZStack(alignment: state.remindOn ? .trailing : .leading) {
                        Capsule().fill(state.remindOn ? Theme.green : Theme.remindOffTrack)
                        Circle()
                            .fill(Color.white)
                            .padding(3)
                            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                    }
                    .frame(width: 52, height: 31)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
        }
    }

    private var reminderDetailCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "DAY"))
                        .font(.heading(12))
                        .tracking(0.6)
                        .foregroundColor(Theme.labelMuted)
                    HStack(spacing: 5) {
                        ForEach(Self.dayOptions, id: \.self) { day in
                            let on = state.remindDay == day
                            Button {
                                state.remindDay = day
                            } label: {
                                Text(AppState.localizedWeekdayName(day, short: true))
                                    .font(.heading(12))
                                    .foregroundColor(on ? .white : Theme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(on ? Theme.dark : Theme.segmentBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 11))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "TIME"))
                        .font(.heading(12))
                        .tracking(0.6)
                        .foregroundColor(Theme.labelMuted)
                    timePicker
                }
            }
            .padding(14)
        }
        .padding(.top, -6)
    }

    /// A real, scrollable time-of-day picker (tap to pop up the standard
    /// iOS wheel) instead of a fixed set of preset times.
    private var timePicker: some View {
        DatePicker(
            "",
            selection: $state.remindTime,
            displayedComponents: .hourAndMinute
        )
        .datePickerStyle(.compact)
        .labelsHidden()
        .tint(Theme.accent)
        .fixedSize()
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.cardBorder, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Privacy

    private var privacyCard: some View {
        card {
            VStack(spacing: 0) {
                Button {
                    showPrivacyPolicy = true
                } label: {
                    row(
                        title: String(localized: "Privacy policy"),
                        titleColor: Theme.textPrimary,
                        subtitle: String(localized: "Scanning happens on-device — nothing is uploaded"),
                        trailing: AnyView(Text("\u{203A}").font(.system(size: 15, weight: .heavy)).foregroundColor(Theme.chevron))
                    )
                }
                .buttonStyle(.plain)
                HairlineDivider()
                Button {
                    state.clearScanData()
                } label: {
                    row(
                        title: String(localized: "Clear local scan data"),
                        titleColor: Theme.red,
                        subtitle: String(localized: "Deletes the index only — never your photos"),
                        trailing: AnyView(
                            Text(state.scanCleared ? String(localized: "Cleared") : "\u{2014}")
                                .font(.heading(13))
                                .foregroundColor(Theme.textMuted)
                        )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Support

    private var supportCard: some View {
        card {
            VStack(spacing: 0) {
                Button {
                    state.howDeleteOpen.toggle()
                } label: {
                    row(
                        title: String(localized: "How deletion works"),
                        titleColor: Theme.textPrimary,
                        subtitle: String(localized: "Recently Deleted keeps everything for 30 days"),
                        trailing: AnyView(
                            Text(state.howDeleteOpen ? "\u{2303}" : "\u{2304}")
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundColor(Theme.chevron)
                        )
                    )
                }
                .buttonStyle(.plain)
                if state.howDeleteOpen {
                    Text("Queued photos move to your iPhone\u{2019}s Recently Deleted album, where iOS keeps them for 30 days before removing them. PicTriage never deletes permanently and never uploads a photo.")
                        .font(.heading(13, weight: .bold))
                        .foregroundColor(Color(hex: "8b7d6d"))
                        .lineSpacing(4)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 15)
                }
                HairlineDivider()
                Button {
                    requestReview()
                } label: {
                    row(
                        title: String(localized: "Rate PicTriage"),
                        titleColor: Theme.textPrimary,
                        subtitle: String(localized: "Takes 20 seconds \u{00B7} helps a lot"),
                        trailing: AnyView(Text("\u{203A}").font(.system(size: 15, weight: .heavy)).foregroundColor(Theme.chevron))
                    )
                }
                .buttonStyle(.plain)
                HairlineDivider()
                HStack {
                    Text("App version")
                        .font(.heading(15.5))
                        .foregroundColor(Theme.textPrimary)
                    Spacer(minLength: 0)
                    Text("1.0.0")
                        .font(.heading(14, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
            }
        }
    }

    private func row(title: String, titleColor: Color, subtitle: String, trailing: AnyView) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.heading(15.5)).foregroundColor(titleColor)
                Text(subtitle).font(.heading(12.5, weight: .bold)).foregroundColor(Theme.textMuted)
            }
            Spacer(minLength: 10)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
    }
}
