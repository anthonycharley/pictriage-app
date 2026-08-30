import SwiftUI

struct QueueView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            heroCard
            if state.queue.isEmpty {
                emptyState
            }
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(state.queue) { item in
                        QueueRow(item: item)
                    }
                }
                .padding(.bottom, 180)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .overlay(alignment: .bottom) {
            confirmButton
                .padding(.horizontal, 22)
                .padding(.bottom, 108)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            BackButton { state.go(.home) }
            Text("Delete queue")
                .font(.heading(22))
                .foregroundColor(Theme.textPrimary)
            Spacer(minLength: 0)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ready to free")
                .font(.heading(13.5))
                .foregroundColor(Color(hex: "221a12").opacity(0.65))
            Text(String(localized: "\(state.queueGb.fixed(2)) GB"))
                .font(.heading(36))
                .foregroundColor(Color(hex: "221a12"))
            Text(String(localized: "\(state.queue.count) items \u{00B7} goes to Recently Deleted"))
                .font(.heading(13.5))
                .foregroundColor(Color(hex: "221a12").opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(colors: [Theme.sprintStart, Theme.sprintEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var emptyState: some View {
        Text("Nothing queued yet.\nPick items in Duplicates or Screenshots.")
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

    private var confirmButton: some View {
        Button {
            state.confirmDelete()
        } label: {
            Text(confirmLabel)
                .font(.heading(17.5))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(confirmBg)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Theme.red.opacity(0.25), radius: 24, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(state.queue.isEmpty || state.confirmed)
    }

    private var confirmLabel: String {
        if state.confirmed { return String(localized: "Deleted \u{2713}") }
        return state.queue.isEmpty ? String(localized: "Nothing to delete") : String(localized: "Delete \(state.queue.count) items")
    }

    private var confirmBg: Color {
        if state.confirmed { return Theme.green }
        return state.queue.isEmpty ? Theme.confirmIdleBg : Theme.red
    }
}

private struct QueueRow: View {
    @EnvironmentObject var state: AppState
    let item: Photo

    var body: some View {
        HStack(spacing: 12) {
            PhotoThumbnailView(localIdentifier: item.id, targetSize: CGSize(width: 92, height: 92))
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(.heading(15))
                    .foregroundColor(Theme.textPrimary)
                Text(String(localized: "\(item.gb.fixed(2)) GB"))
                    .font(.heading(12.5, weight: .bold))
                    .foregroundColor(Theme.textMuted)
            }
            Spacer(minLength: 0)
            Button {
                state.toggle(item)
            } label: {
                Text("Keep")
                    .font(.heading(13))
                    .foregroundColor(Theme.textMuted)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
