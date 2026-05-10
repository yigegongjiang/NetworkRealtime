import AppIntents

// These three intents rely on openAppWhenRun = true to launch the host app
// before they can complete their work. They must also be compiled into the
// host app target — otherwise, after the system brings the host app to the
// foreground, the AppIntent metadata bundle there does not contain the type
// and perform is never dispatched, leaving widget taps with no effect.
//
// Why not keep them only in the widget target: the widget extension's
// AppIntent metadata is registered in the widget process and is not read by
// the host app. Compiling these files into both targets ensures the host
// app's bundle also carries the metadata, so the system can dispatch perform
// in the host app process.

struct OpenAppIntent: AppIntent {
  static let title: LocalizedStringResource = "Open Speedo"
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
