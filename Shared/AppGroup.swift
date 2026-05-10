import Foundation

// 主 App / Widget Extension 共享 UserDefaults. suiteName 必须和两 target entitlements 内
// com.apple.security.application-groups 完全一致, 否则返回的 UserDefaults 静默无效 (写入不持久, 读出永远默认值).
enum AppGroup {
  static let identifier = "group.jp.elestyle.NetworkRealtime"
  static let defaults = UserDefaults(suiteName: identifier)!
}

// widget 触发 PiP start/stop 时通过此 key 留指令, 主 App didBecomeActive 内消费.
enum PiPPendingAction {
  static let key = "pendingPiPAction"
  static let start = "start"
  static let stop = "stop"
}
