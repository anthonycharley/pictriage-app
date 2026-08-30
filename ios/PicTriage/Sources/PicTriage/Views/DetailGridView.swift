import SwiftUI

struct DetailGridView: View {
    @EnvironmentObject var state: AppState
    let group: PhotoGroup

    private var queuedCount: Int { group.photos.filter { state.isQueued($0.id) }.count }
    private var hasBest: Bool { group.photos.contains { $0.best } }
    private var nonBestAllQueued: Bool {
        let nonBest = group.photos.filter { !$0.best }
        return !nonBest.isEmpty && nonBest.allSatisfy { state.isQueued($0.id) }
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(group.photos.enumerated()), id: \.element.id) { index, photo in
                        DetailPhotoCard(photo: photo, index: index)
                    }
                }
                .padding(.bottom, 172)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .overlay(alignment: .bottom) {
            queueFooterButton
                .padding(.horizontal, 22)
                .padding(.bottom, 108)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            BackButton { state.closeDetail() }
            VStack(alignment: .leading, spacing: 0) {
                Text(group.title)
                    .font(.heading(21))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text(String(localized: "\(group.photos.count) photos \u{00B7} tap to preview, \u{FF0B} to queue"))
                    .font(.heading(12.5, weight: .bold))
                    .foregroundColor(Theme.textMuted)
            }
            Spacer(minLength: 0)
            Button {
                state.toggleAll(group)
            } label: {
                VStack(spacing: 2) {
                    Text(nonBestAllQueued ? String(localized: "Clear all") : String(localized: "Queue rest"))
                        .font(.heading(13))
                        .foregroundColor(.white)
                        .fixedSize()
                    Text(hasBest ? String(localized: "keeps the best shot") : String(localized: "queues every screenshot here"))
                        .font(.heading(9.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize()
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(Theme.dark)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }

    private var queueFooterButton: some View {
        Button {
            state.go(.queue)
        } label: {
            Text(String(localized: "\(queuedCount) queued here \u{00B7} \(state.queueGb.fixed(2)) GB total \u{203A}"))
                .font(.heading(14))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Theme.dark)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Theme.dark.opacity(0.24), radius: 20, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

private struct DetailPhotoCard: View {
    @EnvironmentObject var state: AppState
    let photo: Photo
    let index: Int

    private var inQueue: Bool { state.isQueued(photo.id) }
    private var badgeText: String { inQueue ? String(localized: "Queued") : (photo.best ? String(localized: "Keep \u{00B7} best") : String(localized: "Keep")) }
    private var badgeBg: Color { inQueue ? Theme.accent : (photo.best ? Theme.green : Theme.segmentBg) }
    private var badgeTextColor: Color { (inQueue || photo.best) ? .white : Theme.textSecondary }
    private var ringColor: Color { inQueue ? Theme.accent : (photo.best ? Theme.green : Theme.cardBorder) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                state.openPreview(at: index)
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    PhotoThumbnailView(localIdentifier: photo.id, targetSize: CGSize(width: 260, height: 260))
                        .opacity(inQueue ? 0.55 : 1)
                        .frame(height: 126)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .topTrailing) {
                        Text(badgeText)
                            .font(.heading(11))
                            .foregroundColor(badgeTextColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(badgeBg)
                            .clipShape(Capsule())
                            .padding(7)
                    }

                    Text(photo.title)
                        .font(.heading(13.5))
                        .foregroundColor(Theme.textPrimary)
                    Text(String(localized: "\(photo.note) \u{00B7} \(photo.gb.fixed(2)) GB"))
                        .font(.heading(11.5, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(9)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(ringColor, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(alignment: .topLeading) {
            Button {
                state.toggle(photo)
            } label: {
                Text(inQueue ? "\u{2713}" : "\u{FF0B}")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(inQueue ? Theme.accent : Theme.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.92))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .padding(16)
        }
    }
}
