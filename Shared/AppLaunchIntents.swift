import AppIntents

// 这三个 intent 都靠 openAppWhenRun = true 拉起主 App 才能完成职责.
// 必须在主 App target 也编译, 否则系统拉起主 App 后在 AppIntent metadata 里找不到对应类型,
// perform 不会被 dispatch (这就是 widget tap 三按钮全无反应的根因).
//
// 为啥不放在 widget target: widget extension 的 AppIntent metadata 在 widget 进程注册,
// 主 App 进程不读它. 共享文件双 target 编译后, 主 App bundle 也含 metadata, 系统才能在主 App 内 dispatch.

struct OpenAppIntent: AppIntent {
  static let title: LocalizedStringResource = "Open NetworkRealtime"
  static let openAppWhenRun: Bool = true

  init() {}

  func perform() async throws -> some IntentResult { .result() }
}

struct StartPiPIntent: AppIntent {
  static let title: LocalizedStringResource = "Start PiP"
  static let description = IntentDescription("Start the PiP overlay")
  static let openAppWhenRun: Bool = true

  init() {}

  func perform() async throws -> some IntentResult {
    AppGroup.defaults.set(PiPPendingAction.start, forKey: PiPPendingAction.key)
    return .result()
  }
}

struct StopPiPIntent: AppIntent {
  static let title: LocalizedStringResource = "Stop PiP"
  static let description = IntentDescription("Stop the PiP overlay")
  static let openAppWhenRun: Bool = true

  init() {}

  func perform() async throws -> some IntentResult {
    AppGroup.defaults.set(PiPPendingAction.stop, forKey: PiPPendingAction.key)
    return .result()
  }
}
