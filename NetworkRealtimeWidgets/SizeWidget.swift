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

// systemSmall (2x2). 3 行: row1+row2 6 档罗马 I-VI 网格, row3 是动作按钮 (start / stop / toggle / open).
// 罗马数字本身有阈值递进语义, 配合按钮文字字号自身渐变 (I 小 VI 大), 双重表达档位.
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

  // 第 3 行四个图标按钮: 启动 PiP / 停止 PiP / 在最近两档间 toggle / 打开 App.
  // 必须每个 Button 用具体 intent 类型 (不能 helper forwarding `some AppIntent`),
  // 否则 widget runtime 序列化拿到的是 opaque type, perform 不会被 dispatch.
  // 颜色编码: play 绿 / stop 红 / toggle 橙 / open 中性, 单看色块即可分辨动作.
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
    // 不固定高度: 让 VStack 把三行平分, preset row 不会过胖, action row 不会过瘦.
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
    .configurationDisplayName("PiP Font")
    .description("Tap a level to change PiP overlay font size, or open the app")
    .supportedFamilies([.systemSmall])
  }
}
