import Photos
import UIKit

/// Maps `PHAuthorizationStatus` onto the three states the Settings screen shows.
enum LibraryAuthStatus: String, Equatable {
    case fullAccess = "Full Access"
    case limitedAccess = "Selected Photos"
    case notGranted = "Not Granted"

    init(_ status: PHAuthorizationStatus) {
        switch status {
        case .authorized: self = .fullAccess
        case .limited: self = .limitedAccess
        case .denied, .restricted, .notDetermined: self = .notGranted
        @unknown default: self = .notGranted
        }
    }
}

struct ScanResult {
    let duplicateGroups: [PhotoGroup]
    let screenshotGroups: [PhotoGroup]
}

/// The real on-device backend: reads the photo library via PhotosKit, groups
/// duplicates and screenshots, and performs deletions. Nothing here ever
/// leaves the device — there is no network layer, by design (see the product
/// spec's privacy-first / on-device positioning).
///
/// Duplicate grouping is a heuristic, not ML-based perceptual hashing: it
/// groups iOS's own burst identifiers, plus consecutive shots taken within a
/// few seconds of each other. That covers the common "accidentally took 6
/// photos of the same thing" case without pulling in Vision/CoreML.
actor PhotoLibraryService {
    static let shared = PhotoLibraryService()

    /// Locale-aware month+day formatting (e.g. "Jan 26" in English, "26 janv."
    /// in French) — adapts both the format and the field order per locale.
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    /// Consecutive non-burst shots taken within this many seconds of each
    /// other are treated as a near-duplicate cluster.
    private let nearDuplicateWindow: TimeInterval = 8

    // MARK: - Authorization

    nonisolated func currentStatus() -> LibraryAuthStatus {
        LibraryAuthStatus(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    nonisolated func isNotDetermined() -> Bool {
        PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined
    }

    func requestAccess() async -> LibraryAuthStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return LibraryAuthStatus(status)
    }

    /// iOS only lets an app prompt for Photos access once; after that the
    /// user has to change it from the Settings app, so this is how the
    /// Settings screen's access picker behaves once a decision has been made.
    nonisolated func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        Task { @MainActor in
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Storage

    nonisolated func deviceStorage() -> (freeGB: Double, totalGB: Double) {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ]) else {
            return (0, 0)
        }
        let free = Double(values.volumeAvailableCapacityForImportantUsage ?? 0) / 1_000_000_000
        let total = Double(values.volumeTotalCapacity ?? 0) / 1_000_000_000
        return (free, total)
    }

    // MARK: - Scan

    func scan() async -> ScanResult {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let assets = PHAsset.fetchAssets(with: .image, options: options)

        var screenshots: [PHAsset] = []
        var others: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            if asset.mediaSubtypes.contains(.photoScreenshot) {
                screenshots.append(asset)
            } else {
                others.append(asset)
            }
        }

        return ScanResult(
            duplicateGroups: groupDuplicates(others),
            screenshotGroups: groupScreenshotsByDay(screenshots)
        )
    }

    private func groupScreenshotsByDay(_ assets: [PHAsset]) -> [PhotoGroup] {
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: assets) { asset in
            calendar.startOfDay(for: asset.creationDate ?? .distantPast)
        }

        return byDay.keys.sorted(by: >).compactMap { day in
            guard let dayAssets = byDay[day], !dayAssets.isEmpty else { return nil }
            let photos = dayAssets.map { photo(from: $0) }
            let totalGb = photos.reduce(0) { $0 + $1.gb }
            let dateText = dayFormatter.string(from: day)
            let count = dayAssets.count
            let countText = count == 1 ? String(localized: "1 screenshot") : String(localized: "\(count) screenshots")
            return PhotoGroup(
                id: "shot-\(Int(day.timeIntervalSince1970))",
                title: String(localized: "\(dateText) screenshots"),
                meta: String(localized: "\(dateText) \u{00B7} \(countText)"),
                reclaimableGb: round2(totalGb),
                photos: photos
            )
        }
    }

    private enum DuplicateKind { case burst, similar }

    private func groupDuplicates(_ assets: [PHAsset]) -> [PhotoGroup] {
        var groups: [PhotoGroup] = []
        var handled = Set<String>()

        let burstBuckets = Dictionary(grouping: assets.filter { $0.burstIdentifier != nil }) { $0.burstIdentifier! }
        for (burstID, burstAssets) in burstBuckets where burstAssets.count > 1 {
            burstAssets.forEach { handled.insert($0.localIdentifier) }
            let best = burstAssets.first { $0.burstSelectionTypes.contains(.autoPick) }?.localIdentifier
                ?? burstAssets.first?.localIdentifier
            groups.append(makeGroup(id: "burst-\(burstID)", kind: .burst, assets: burstAssets, bestID: best))
        }

        let remaining = assets.filter { !handled.contains($0.localIdentifier) }
        var cluster: [PHAsset] = []
        func flushCluster() {
            if cluster.count > 1 {
                let anchorID = cluster[0].localIdentifier
                groups.append(makeGroup(id: "cluster-\(anchorID)", kind: .similar, assets: cluster, bestID: anchorID))
            }
            cluster = []
        }
        for asset in remaining {
            if let last = cluster.last,
               let lastDate = last.creationDate,
               let date = asset.creationDate,
               date.timeIntervalSince(lastDate) <= nearDuplicateWindow {
                cluster.append(asset)
            } else {
                flushCluster()
                cluster = [asset]
            }
        }
        flushCluster()

        return groups.sorted { $0.reclaimableGb > $1.reclaimableGb }
    }

    private func makeGroup(id: String, kind: DuplicateKind, assets: [PHAsset], bestID: String?) -> PhotoGroup {
        let sorted = assets.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        let photos = sorted.map { photo(from: $0, best: $0.localIdentifier == bestID) }
        let reclaimable = photos.filter { !$0.best }.reduce(0) { $0 + $1.gb }
        let dateText = dayFormatter.string(from: sorted.first?.creationDate ?? Date())
        let label = kind == .burst ? String(localized: "Burst") : String(localized: "Similar shots")
        let count = assets.count
        let shotsText = count == 1 ? String(localized: "1 shot") : String(localized: "\(count) shots")
        let photosText = count == 1 ? String(localized: "1 photo") : String(localized: "\(count) photos")
        return PhotoGroup(
            id: id,
            title: String(localized: "\(label) \u{00B7} \(shotsText)"),
            meta: String(localized: "\(dateText) \u{00B7} \(photosText)"),
            reclaimableGb: round2(reclaimable),
            photos: photos
        )
    }

    private func photo(from asset: PHAsset, best: Bool = false) -> Photo {
        Photo(
            id: asset.localIdentifier,
            title: asset.creationDate.map { timeFormatter.string(from: $0) } ?? String(localized: "Photo"),
            gb: Self.approximateFileSizeGB(for: asset),
            best: best,
            note: "\(asset.pixelWidth)\u{00D7}\(asset.pixelHeight)"
        )
    }

    private func round2(_ value: Double) -> Double { (value * 100).rounded() / 100 }

    /// Reads the asset resource's real byte size where the system exposes it,
    /// falling back to a rough estimate from pixel dimensions otherwise.
    nonisolated static func approximateFileSizeGB(for asset: PHAsset) -> Double {
        let resources = PHAssetResource.assetResources(for: asset)
        if let resource = resources.first,
           let size = (resource.value(forKey: "fileSize") as? NSNumber)?.doubleValue,
           size > 0 {
            return size / 1_000_000_000
        }
        let estimatedBytes = Double(asset.pixelWidth * asset.pixelHeight) * 1.8
        return estimatedBytes / 1_000_000_000
    }

    // MARK: - Delete

    /// Moves the given assets to Recently Deleted. iOS shows its own native
    /// confirmation before this actually happens — that's a real extra
    /// safety net on top of the in-app confirmation, not a bug.
    func delete(localIdentifiers: [String]) async throws {
        guard !localIdentifiers.isEmpty else { return }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }
}
