import WidgetKit
import SwiftUI
import AppIntents

struct SizeEntry: TimelineEntry {
  let date: Date
  let preset: SpeedPreset
}

struct SizeProvider: TimelineProvider {
  func placeholder(in context: Context) -> SizeEntry {
    SizeEntry(date: .now, preset: .default)
  }
  func getSnapshot(in context: Context, completion: @escaping (SizeEntry) -> Void) {
    completion(SizeEntry(date: .now, preset: .current))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<SizeEntry>) -> Void) {
    completion(Timeline(entries: [SizeEntry(date: .now, preset: .current)], policy: .never))
  }
}

// systemSmall (2x2). Three rows: row1 + row2 form a 3x2 grid of the six Roman
// numeral preset levels (I-VI); row3 holds action buttons (start / stop /
// toggle / open). Roman numerals already imply ordering, and the per-button
// font size grows with the level (I smallest, VI largest), reinforcing the
// "level" affordance visually.
struct SizeWidgetView: View {
  let entry: SizeEntry

  private static let row1: [SpeedPreset] = [.s4, .s5, .s6]
  private static let row2: [SpeedPreset] = [.s7, .s8, .s9]

  var body: some View {
    VStack(spacing: 4) {
      presetRow(Self.row1)
      presetRow(Self.row2)
      actionRow
    }
    .containerBackground(.background, for: .widget)
  }

  private func presetRow(_ presets: [SpeedPreset]) -> some View {
    HStack(spacing: 4) {
      ForEach(presets, id: \.rawValue) { preset in
        Button(intent: SetSpeedPresetIntent(preset: SpeedPresetParam(preset))) {
          Text(preset.displayLabel)
            .font(.system(
              size: CGFloat(preset.rawValue + 6),
              weight: .semibold,
              design: .serif
            ))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(preset == entry.preset ? Color.white : Color.primary)
            .background(
              preset == entry.preset
                ? Color.accentColor
                : Color.gray.opacity(0.18)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
      }
    }
  }

  // Four icon buttons on row 3: start PiP / stop PiP / toggle between the two
  // most recent levels / open the host app.
  // Each button must be wired to a concrete intent type — forwarding through a
  // helper that returns `some AppIntent` does not work, because the widget
  // runtime serializes the opaque type and perform is never dispatched.
  // Color coding: play = green, stop = red, toggle = orange, open = neutral,
  // so the action is recognizable at a glance from color alone.
  private var actionRow: some View {
    HStack(spacing: 4) {
      Button(intent: StartPiPIntent()) {
        iconLabel("play.fill", color: .green)
      }
      .buttonStyle(.plain)

      Button(intent: StopPiPIntent()) {
        iconLabel("stop.fill", color: .red)
      }
      .buttonStyle(.plain)

      Button(intent: ToggleRecentSpeedPresetIntent()) {
        iconLabel("arrow.left.arrow.right", color: .orange)
      }
      .buttonStyle(.plain)

      Button(intent: OpenAppIntent()) {
        iconLabel("arrow.up.forward.app.fill", color: .primary)
      }
      .buttonStyle(.plain)
    }
    // No fixed height — let the VStack split the available space evenly across
    // the three rows so the preset rows do not bloat and the action row does
    // not get squeezed.
  }

  private func iconLabel(_ systemImage: String, color: Color) -> some View {
    Image(systemName: systemImage)
      .font(.system(size: 18, weight: .semibold))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .foregroundStyle(color)
      .background(Color.gray.opacity(0.18))
      .clipShape(RoundedRectangle(cornerRadius: 6))
  }
}

struct SizeWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "SizeWidget", provider: SizeProvider()) { entry in
      SizeWidgetView(entry: entry)
    }
    .configurationDisplayName("PiP Level")
    .description("Tap a level to change the PiP overlay, or open the app")
    .supportedFamilies([.systemSmall])
  }
}
