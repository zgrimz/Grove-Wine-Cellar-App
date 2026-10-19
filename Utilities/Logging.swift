import Foundation
import os

/// Unified-logging categories, filterable in Console.app by subsystem and category.
///
/// Interpolated values are redacted in release logs unless marked `privacy: .public`; only mark
/// values public when they can't carry the user's data (status codes, provider names).
extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "GroveWineCellar"

    /// Requests to the AI providers.
    static let ai = Logger(subsystem: subsystem, category: "ai")
    /// The Core Data store and wine photos.
    static let data = Logger(subsystem: subsystem, category: "data")
    /// API keys in the Keychain.
    static let keychain = Logger(subsystem: subsystem, category: "keychain")
}
