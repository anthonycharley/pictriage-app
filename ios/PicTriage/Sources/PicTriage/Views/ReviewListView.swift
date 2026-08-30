import SwiftUI

struct ReviewListView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if state.currentGroups.isEmpty {
                emptyState
            }
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(state.currentGroups) { group in
                        ReviewRow(group: group)
                    }
                }
                .padding(.bottom, 120)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .overlay(alignment: .bottom) {
            reviewQueueButton
                .padding(.horizontal, 22)
                .padding(.bottom, 108)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            BackButton { state.go(.home) }
            VStack(alignment: .leading, spacing: 0) {
                Text(state.reviewKind == .duplicates ? String(localized: "Duplicates") : String(localized: "Screenshots"))
                    .font(.heading(22))
                    .foregroundColor(Theme.textPrimary)
                Text(headerMeta)
                    .font(.heading(13, weight: .bold))
                    .foregroundColor(Theme.textMuted)
            }
            Spacer(minLength: 0)
        }
    }

    private var headerMeta: String {
        if state.reviewKind == .duplicates {
            return String(localized: "\(state.duplicateCount) in \(state.duplicateGroups.count) groups \u{00B7} \(state.duplicateReclaimableGb.fixed(1)) GB")
        } else {
            return String(localized: "\(state.screenshotCount) screenshots \u{00B7} \(state.screenshotReclaimableGb.fixed(1)) GB")
        }
    }

    private var emptyStateText: String {
        if state.scanning {
            return String(localized: "Scanning your library\u{2026}")
        } else if state.authStatus == .notGranted {
            return String(localized: "No photo access yet.\nGrant it in Settings to scan your library.")
        } else {
            return String(localized: "Nothing here yet.\nTap Rescan in Settings, or pull to try again.")
        }
    }

    private var emptyState: some View {
        Text(emptyStateText)
            .multilineTextAlignment(.center)
            .font(.heading(14.5, weight: .bold))
            .foregroundColor(Theme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .padding(.horizontal, 20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .foregroundColor(Theme.dashedBorder)
            )
    }

    private var reviewQueueButton: some View {
        Button {
            state.go(.queue)
        } label: {
            Text(String(localized: "Review queue \u{00B7} \(state.queue.count) items \u{00B7} \(state.queueGb.fixed(2)) GB"))
                .font(.heading(16.5))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Theme.dark)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Theme.dark.opacity(0.28), radius: 24, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}

private struct ReviewRow: View {
    @EnvironmentObject var state: AppState
    let group: PhotoGroup

    private var queuedCount: Int { group.photos.filter { state.isQueued($0.id) }.count }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                state.openGroup(group)
            } label: {
                HStack(spacing: 14) {
                    PhotoThumbnailView(localIdentifier: group.thumbnailID, targetSize: CGSize(width: 128, height: 128))
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.title)
                            .font(.heading(15.5))
                            .foregroundColor(Theme.textPrimary)
                        Text(String(localized: "\(group.meta) \u{00B7} \(group.reclaimableGb.fixed(2)) GB"))
                            .font(.heading(13, weight: .bold))
                            .foregroundColor(Theme.textMuted)
                        Text("Review photos \u{203A}")
                            .font(.heading(12))
                            .foregroundColor(Theme.quickAmountText)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button {
                state.toggleAll(group)
            } label: {
                Text(queuedCount > 0 ? String(localized: "\(queuedCount) queued") : String(localized: "Queue all"))
                    .font(.heading(13.5))
                    .foregroundColor(queuedCount > 0 ? .white : Theme.textSecondary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(queuedCount > 0 ? Theme.accent : Theme.segmentBg)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(queuedCount > 0 ? Theme.accent : Theme.cardBorder, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
