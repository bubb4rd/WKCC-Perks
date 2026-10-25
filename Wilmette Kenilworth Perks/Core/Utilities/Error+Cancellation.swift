import Foundation

extension Error {
    /// True for task cancellation and cancelled `URLSession` requests — e.g. when SwiftUI
    /// cancels a `.refreshable` or `.task` — which shouldn't be surfaced to the user as a failure.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let urlError = self as? URLError, urlError.code == .cancelled { return true }
        return false
    }
}
