import AppIntents
import WidgetKit

// AppEnum 是 AppIntent 参数对外可见的离散选项. 用于桌面 widget 6 档按钮各自的预设值.
enum SpeedPresetParam: String, AppEnum, CaseIterable {
  case s4, s5, s6, s7, s8, s9

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "PiP Font Size"
  static let caseDisplayRepresentations: [SpeedPresetParam: DisplayRepresentation] = [
    .s4: "4pt", .s5: "5pt", .s6: "6pt", .s7: "7pt", .s8: "8pt", .s9: "9pt"
  ]

  var preset: SpeedPreset {
    SpeedPreset(rawValue: Int(rawValue.dropFirst()) ?? SpeedPreset.default.rawValue) ?? .default
  }

  init(_ preset: SpeedPreset) {
    self = SpeedPresetParam(rawValue: "s\(preset.rawValue)") ?? .s4
  }
}

struct SetSpeedPresetIntent: AppIntent {
  static let title: LocalizedStringResource = "Set PiP Font Size"
  static let description = IntentDescription("Quickly change PiP overlay font size")

  @Parameter(title: "Size") var preset: SpeedPresetParam

  init() {}
  init(preset: SpeedPresetParam) { self.preset = preset }

  func perform() async throws -> some IntentResult {
    // reload widget / control 已统一到 SpeedPreset.switchTo 内.
    SpeedPreset.switchTo(preset.preset)
    return .result()
  }
}

// OpenAppIntent / StartPiPIntent / StopPiPIntent 已挪到 Shared/AppLaunchIntents.swift,
// 因为 openAppWhenRun=true 的 intent 必须主 App target 也编译, 系统才能在主 App 进程 dispatch perform.

// 桌面 widget 第三行的"切换最近两档"按钮.
// 用户最近两次的档位通常就是常用对照 (例: 普通看 5pt / 调试时 8pt), 一键来回切.
// 首次 previous == current (或都是 default) 时退化为推进一档, 让用户至少看到反应.
struct ToggleRecentSpeedPresetIntent: AppIntent {
  static let title: LocalizedStringResource = "Toggle Recent PiP Font Size"
  static let description = IntentDescription("Switch between the two most recent PiP overlay font sizes")

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
