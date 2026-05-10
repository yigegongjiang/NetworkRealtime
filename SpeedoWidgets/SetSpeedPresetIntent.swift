import AppIntents
import WidgetKit

// AppEnum exposes a discrete set of values to AppIntent parameters. Used as
// the per-level value for each of the six Home Screen widget preset buttons.
// The Roman-numeral case representations match what the user sees in the app,
// the widget, and Control Center, so Shortcuts/Siri stay visually consistent.
enum SpeedPresetParam: String, AppEnum, CaseIterable {
  case s4, s5, s6, s7, s8, s9

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "PiP Level"
  static let caseDisplayRepresentations: [SpeedPresetParam: DisplayRepresentation] = [
    .s4: "I", .s5: "II", .s6: "III", .s7: "IV", .s8: "V", .s9: "VI"
  ]

  var preset: SpeedPreset {
    SpeedPreset(rawValue: Int(rawValue.dropFirst()) ?? SpeedPreset.default.rawValue) ?? .default
  }

  init(_ preset: SpeedPreset) {
    self = SpeedPresetParam(rawValue: "s\(preset.rawValue)") ?? .s4
  }
}

struct SetSpeedPresetIntent: AppIntent {
  static let title: LocalizedStringResource = "Set PiP Level"
  static let description = IntentDescription("Quickly change the PiP overlay level")

  @Parameter(title: "Level") var preset: SpeedPresetParam

  init() {}
  init(preset: SpeedPresetParam) { self.preset = preset }

  func perform() async throws -> some IntentResult {
    // Widget and control reloads are centralized inside SpeedPreset.switchTo.
    SpeedPreset.switchTo(preset.preset)
    return .result()
  }
}

// OpenAppIntent / StartPiPIntent / StopPiPIntent live in
// Shared/AppLaunchIntents.swift: any intent with openAppWhenRun = true must be
// compiled into the host app target so the system can dispatch perform in the
// host app process.

// "Toggle between the two most recent levels" button on the third row of the
// Home Screen widget. The two most recently used levels typically form the
// user's everyday A/B pair (e.g. 5pt for normal viewing, 8pt while debugging),
// so a single tap switches between them. On the first invocation, when
// previous == current (both still at the default), it falls back to advancing
// one level so the action is never a no-op.
struct ToggleRecentSpeedPresetIntent: AppIntent {
  static let title: LocalizedStringResource = "Toggle Recent PiP Level"
  static let description = IntentDescription("Switch between the two most recent PiP overlay levels")

  init() {}

  func perform() async throws -> some IntentResult {
    let cur = SpeedPreset.current
    let prev = SpeedPreset.previous
    let next: SpeedPreset
    if prev != cur {
      next = prev
    } else {
      let all = SpeedPreset.allCases
      next = all[((all.firstIndex(of: cur) ?? 0) + 1) % all.count]
    }
    SpeedPreset.switchTo(next)
    return .result()
  }
}
