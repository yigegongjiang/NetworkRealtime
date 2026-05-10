import Foundation

// Shared UserDefaults between the host app and the widget extension. The
// suiteName must match com.apple.security.application-groups in both targets'
// entitlements exactly; otherwise the returned UserDefaults is silently inert
// (writes are not persisted, reads always return defaults).
enum AppGroup {
  static let identifier = "group.jp.elestyle.Speedo"
  static let defaults = UserDefaults(suiteName: identifier)!
}

// Key used by the widget to leave PiP start/stop intent for the host app to
// consume in didBecomeActive.
enum PiPPendingAction {
  static let key = "pendingPiPAction"
  static let start = "start"
  static let stop = "stop"
}
