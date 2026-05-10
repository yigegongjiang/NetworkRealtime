import Foundation
import CoreGraphics
import WidgetKit

// PiP 浮窗字号档位. 每档预设了对应的 sampleBuffer 宽高比 (越小字号越扁的比例 → 浮窗高度越小).
enum SpeedPreset: Int, CaseIterable {
  case s4 = 4
  case s5 = 5
  case s6 = 6
  case s7 = 7
  case s8 = 8
  case s9 = 9

  var fontSize: CGFloat { CGFloat(rawValue) }

  // App 首页 segment / 桌面 widget / 控制中心通用展示. 阿拉伯 4-9 让人摸不着含义,
  // 统一用罗马 I-VI 直观传达"档位"语义, 三处视觉一致.
  var displayLabel: String {
    switch self {
    case .s4: return "I"
    case .s5: return "II"
    case .s6: return "III"
    case .s7: return "IV"
    case .s8: return "V"
    case .s9: return "VI"
    }
  }

  var frameSize: CGSize {
    switch self {
    case .s4: return CGSize(width: 400, height: 8)
    case .s5: return CGSize(width: 320, height: 10)
    case .s6: return CGSize(width: 280, height: 12)
    case .s7: return CGSize(width: 240, height: 14)
    case .s8: return CGSize(width: 220, height: 16)
    case .s9: return CGSize(width: 200, height: 18)
    }
  }

  static let `default`: SpeedPreset = .s4

  private static let storageKey = "PiPSpeedPreset"
  private static let previousKey = "PiPSpeedPresetPrev"

  static var current: SpeedPreset {
    get {
      let raw = AppGroup.defaults.integer(forKey: storageKey)
      return SpeedPreset(rawValue: raw) ?? .default
    }
    set {
      AppGroup.defaults.set(newValue.rawValue, forKey: storageKey)
    }
  }

  // 上一次 current 的快照. 控制中心 toggle 用它做"切回去". current==new 时不更新, 避免连点同档把 previous 也覆盖成自己.
  static var previous: SpeedPreset {
    get {
      let raw = AppGroup.defaults.integer(forKey: previousKey)
      return SpeedPreset(rawValue: raw) ?? .default
    }
    set {
      AppGroup.defaults.set(newValue.rawValue, forKey: previousKey)
    }
  }

  // 任何主动切档都走这里, 维护 previous → current 单向迁移.
  // PiPSpeedController.update 内的同步轮询不算切换源, 不调这里.
  static func switchTo(_ new: SpeedPreset) {
    let cur = current
    guard cur != new else { return }
    previous = cur
    current = new
    broadcastChange()
  }

  // 改档入口 (App segment / 桌面 widget 按钮 / widget toggle) 共用一份 reload 调用,
  // 主 App 进程 / widget extension 进程都生效, 不再让 caller 各自补写.
  // App 内 segment 的回写交给 ViewController.applicationDidBecomeActive 重读 current,
  // 实时 Darwin notification 在 PiP 已经轮询同步的前提下不划算.
  static func broadcastChange() {
    WidgetCenter.shared.reloadAllTimelines()
  }
}
