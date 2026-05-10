import Foundation

// User-defined text segments for the PiP overlay. Singleton-backed by
// UserDefaults; the raw string is split into segments on commas (both ASCII
// `,` and full-width `，`).
final class CustomSegmentsStore {
  static let shared = CustomSegmentsStore()
  private static let storageKey = "PiPCustomSegments"

  private init() {}

  var raw: String {
    get { AppGroup.defaults.string(forKey: Self.storageKey) ?? "" }
    set { AppGroup.defaults.set(newValue, forKey: Self.storageKey) }
  }

  var segments: [String] {
    raw.split(whereSeparator: { $0 == "," || $0 == "，" })
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }
}
