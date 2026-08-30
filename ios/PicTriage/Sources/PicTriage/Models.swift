import SwiftUI

struct Photo: Identifiable, Hashable {
    let id: String
    let title: String
    let gb: Double
    var best: Bool = false
    let note: String
}

struct PhotoGroup: Identifiable, Hashable {
    let id: String
    let title: String
    let meta: String
    /// Storage reclaimed if every non-best photo in the group is deleted.
    let reclaimableGb: Double
    let photos: [Photo]

    /// The photo used for the group's row-level thumbnail: the flagged best
    /// shot if there is one, otherwise the first photo.
    var thumbnailID: String { (photos.first { $0.best } ?? photos.first)?.id ?? "" }
}

enum ReviewKind {
    case duplicates
    case screenshots
}

enum Tab {
    case home
    case review
    case queue
    case settings
}

struct QuickWin: Identifiable {
    var id: String { label }
    let label: String
    let count: Int
    let gb: String
    let dotColor: Color
    let kind: ReviewKind
}
