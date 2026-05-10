import Foundation
import CoreGraphics
import WidgetKit

// Font-size levels for the PiP overlay. Each level pairs with a fixed
// sampleBuffer aspect ratio — smaller fonts use a flatter ratio, yielding a
// shorter overlay.
enum SpeedPreset: Int, CaseIterable {
  case s4 = 4
  case s5 = 5
  case s6 = 6
  case s7 = 7
  case s8 = 8
  case s9 = 9

  var fontSize: CGFloat { CGFloat(rawValue) }

  // Shared label for the in-app segment, Home Screen widget, and Control
  // Center. Arabic 4-9 carries no intuitive ordering for the user; Roman
  // numerals I-VI clearly convey "level" semantics and keep all three surfaces
  // visually consistent.
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

  // Snapshot of the previous current value, used by Control Center "toggle
  // back". Skipping the write when current == new prevents repeated taps on
  // the same level from collapsing previous onto itself.
  static var previous: SpeedPreset {
    get {
      let raw = AppGroup.defaults.integer(forKey: previousKey)
      return SpeedPreset(rawValue: raw) ?? .default
    }
    set {
      AppGroup.defaults.set(newValue.rawValue, forKey: previousKey)
    }
  }

  // Single funnel for every explicit preset change; maintains the
  // previous → current single-direction handoff. The 1 Hz reconciliation in
  // PiPSpeedController.update is not a "switch" and must not call this.
  static func switchTo(_ new: SpeedPreset) {
    let cur = current
    guard cur != new else { return }
    previous = cur
    current = new
    broadcastChange()
  }

  // Centralized reload for every preset-change entry point (in-app segment,
  // Home Screen widget buttons, widget toggle). Works in both the host app
  // and the widget extension processes, so callers no longer reimplement it.
  // The in-app segment is reconciled instead by ViewController.applicationDidBecomeActive
  // re-reading current; a real-time Darwin notification would be redundant
  // given that the PiP path already reconciles on its 1 Hz tick.
  static func broadcastChange() {
    WidgetCenter.shared.reloadAllTimelines()
  }
}
