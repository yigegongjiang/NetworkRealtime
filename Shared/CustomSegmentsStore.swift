import Foundation

// PiP 浮窗用户自定义文字片段. 单例, UserDefaults 存原始字符串, segments 按 [,，] 切分.
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
