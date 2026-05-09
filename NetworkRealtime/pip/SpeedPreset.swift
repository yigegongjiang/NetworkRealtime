import Foundation
import CoreGraphics

// PiP 浮窗字号档位. 每档预设了对应的 sampleBuffer 宽高比 (越小字号越扁的比例 → 浮窗高度越小).
enum SpeedPreset: Int, CaseIterable {
  case s4 = 4
  case s5 = 5
  case s6 = 6
  case s7 = 7
  case s8 = 8
  case s9 = 9
  case s10 = 10

  var fontSize: CGFloat { CGFloat(rawValue) }

  var frameSize: CGSize {
    switch self {
    case .s4:  return CGSize(width: 400, height: 8)
    case .s5:  return CGSize(width: 320, height: 10)
    case .s6:  return CGSize(width: 280, height: 12)
    case .s7:  return CGSize(width: 240, height: 14)
    case .s8:  return CGSize(width: 220, height: 16)
    case .s9:  return CGSize(width: 200, height: 18)
    case .s10: return CGSize(width: 200, height: 20)
    }
  }

  static let `default`: SpeedPreset = .s4

  private static let storageKey = "PiPSpeedPreset"

  static var current: SpeedPreset {
    get {
      let raw = UserDefaults.standard.integer(forKey: storageKey)
      return SpeedPreset(rawValue: raw) ?? .default
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
    }
  }
}
