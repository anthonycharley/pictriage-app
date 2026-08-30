import SwiftUI

struct HomeView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            reviewCard
            sprintCard
            quickWinsSection
            Spacer(minLength: 0)
            ctaButton
            Color.clear.frame(height: 104)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(state.greetingLine)
                    .font(.heading(26))
                    .foregroundColor(Theme.textPrimary)
                Text("Let\u{2019}s clear some space today")
                    .font(.heading(14.5, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            HStack(spacing: 7) {
                Text("\u{1F525}")
                Text(state.sprintBadgeText)
                    .font(.heading(12.5))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.badgeBg)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .frame(maxWidth: 160)
        }
    }

    private var reviewCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Theme.ringTrack, lineWidth: 12)
                Circle()
                    .trim(from: 0, to: state.ringProgress)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(state.reviewed)")
                        .font(.heading(27))
                        .foregroundColor(Theme.textPrimary)
                    Text("of 25")
                        .font(.heading(11.5, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                }
            }
            .frame(width: 104, height: 104)

            Text(String(localized: "\(state.reviewed) of 25 photos reviewed today.\n\(state.goalTailText)"))
                .font(.heading(15, weight: .bold))
                .foregroundColor(Color(hex: "4a4038"))
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Theme.cardShadow.opacity(0.07), radius: 10, x: 0, y: 2)
    }

    private var sprintCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(state.sprintLineText)
                .font(.heading(13.5))
                .foregroundColor(Color.black.opacity(0.62))
            Text(String(localized: "\(state.freedGb.fixed(1)) GB cleaned so far"))
                .font(.heading(29))
                .foregroundColor(Color(hex: "221a12"))
            HStack(spacing: 5) {
                ForEach(0..<state.sprintDays, id: \.self) { i in
                    Capsule()
                        .fill(i < state.dayOf ? Color.black.opacity(0.55) : Color.white.opacity(0.45))
                        .frame(height: 6)
                }
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            LinearGradient(
                colors: [Theme.sprintStart, Theme.sprintMid, Theme.sprintEnd],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(alignment: .topTrailing) {
            Circle().fill(Color.white.opacity(0.5)).frame(width: 14, height: 14)
                .padding(.top, 16).padding(.trailing, 22)
        }
        .overlay(alignment: .topTrailing) {
            Circle().fill(Color.white.opacity(0.4)).frame(width: 7, height: 7)
                .padding(.top, 40).padding(.trailing, 56)
        }
        .overlay(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.35)).frame(width: 11, height: 11)
                .padding(.bottom, 14).padding(.trailing, 30)
        }
    }

    private var quickWinsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick wins")
                .font(.heading(18))
                .foregroundColor(Theme.textPrimary)
            VStack(spacing: 10) {
                ForEach(state.quickWins) { win in
                    Button {
                        state.go(.review, reviewKind: win.kind)
                    } label: {
                        HStack(spacing: 10) {
                            Circle().fill(win.dotColor).frame(width: 11, height: 11)
                            Text(String(localized: "\(win.label) \u{00B7} \(win.count)"))
                                .font(.heading(15.5))
                                .foregroundColor(Theme.textPrimary)
                            Spacer(minLength: 0)
                            Text(String(localized: "\(win.gb) GB"))
                                .font(.heading(15))
                                .foregroundColor(Theme.quickAmountText)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 4)
                                .background(Theme.quickAmountBg)
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(Color.white)
                        .overlay(Capsule().stroke(Theme.cardBorder, lineWidth: 1))
                        .clipShape(Capsule())
                        .shadow(color: Theme.cardShadow.opacity(0.06), radius: 6, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var ctaButton: some View {
        Button {
            state.go(.review, reviewKind: .duplicates)
        } label: {
            Text("Let\u{2019}s Clean!")
                .font(.heading(19.5))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 19)
                .background(
                    LinearGradient(
                        colors: [Theme.ctaStart, Theme.ctaMid, Theme.ctaEnd],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: Color(hex: "EA5A78").opacity(0.34), radius: 26, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}
