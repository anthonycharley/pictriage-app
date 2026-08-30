import SwiftUI

/// Full-screen photo preview shown when tapping a photo in `DetailGridView`.
/// Lets someone inspect a photo before it's queued (Keep / Queue for deletion),
/// with First/Last jump controls for long groups.
struct PreviewOverlayView: View {
    @EnvironmentObject var state: AppState
    let group: PhotoGroup

    private var index: Int { state.previewIndex ?? 0 }

    var body: some View {
        if let photo = state.previewPhoto {
            ZStack(alignment: .top) {
                Color.black.opacity(0.82)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { state.closePreview() }
                VStack(spacing: 0) {
                    Color.clear.frame(height: 34)
                    photoStrip
                        .padding(.vertical, 14)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(photo.title)
                            .font(.heading(19))
                            .foregroundColor(.white)
                        Text(metaText(photo))
                            .font(.heading(13, weight: .bold))
                            .foregroundColor(.white.opacity(0.62))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    actionRow(photo)
                        .padding(.top, 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 52)
                .padding(.bottom, 26)

                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 52)
            }
            .transition(.opacity)
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                state.closePreview()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Text(String(localized: "\(index + 1) of \(group.photos.count)"))
                .font(.heading(13))
                .foregroundColor(.white.opacity(0.7))

            Spacer(minLength: 0)

            HStack(spacing: 7) {
                pillButton(String(localized: "\u{21E4} First"), enabled: index > 0) { state.previewFirst() }
                pillButton(String(localized: "Last \u{21E5}"), enabled: index < group.photos.count - 1) { state.previewLast() }
            }
        }
    }

    private var photoStrip: some View {
        HStack(spacing: 10) {
            roundIconButton(systemName: "chevron.left") { state.previewPrev() }
                .opacity(index > 0 ? 1 : 0.3)
                .disabled(index == 0)

            PhotoThumbnailView(
                localIdentifier: state.previewPhoto?.id ?? "",
                targetSize: CGSize(width: 1200, height: 1200),
                contentMode: .fit
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))

            roundIconButton(systemName: "chevron.right") { state.previewNext() }
                .opacity(index < group.photos.count - 1 ? 1 : 0.3)
                .disabled(index == group.photos.count - 1)
        }
        .frame(maxHeight: .infinity)
    }

    private func pillButton(_ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.heading(12))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Color.white.opacity(0.16))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.3)
        .disabled(!enabled)
    }

    private func roundIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.16))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func metaText(_ photo: Photo) -> String {
        let base = String(localized: "\(photo.note) \u{00B7} \(photo.gb.fixed(2)) GB")
        guard photo.best else { return base }
        return base + String(localized: " \u{00B7} flagged as the best of this set")
    }

    private func actionRow(_ photo: Photo) -> some View {
        let inQueue = state.isQueued(photo.id)
        return HStack(spacing: 10) {
            Button {
                state.closePreview()
            } label: {
                Text("Keep")
                    .font(.heading(15.5))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.white.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            Button {
                state.toggle(photo)
            } label: {
                Text(inQueue ? String(localized: "Remove from queue") : String(localized: "Queue for deletion"))
                    .font(.heading(15.5))
                    .foregroundColor(inQueue ? Theme.textPrimary : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(inQueue ? Theme.segmentBg : Theme.red)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
    }
}
