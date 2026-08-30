import Foundation

extension Double {
    /// Locale-aware fixed-fraction formatting — e.g. "1.8" in English,
    /// "1,8" in German — for the GB values shown throughout the app.
    func fixed(_ digits: Int) -> String {
        self.formatted(.number.precision(.fractionLength(digits)).grouping(.never))
    }
}
