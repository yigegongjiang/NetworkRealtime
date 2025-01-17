//
//  LiveActivityWidgetLiveActivity.swift
//  LiveActivityWidget
//
//  Created by Hailv on 2025/01/14.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LiveActivityWidgetLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivityWidgetAttributes.self) { context in
      // lock screen/banner UI
      HStack(spacing: 4) {
        HStack(spacing: 2) {
          Image(systemName: "arrow.up")
            .font(.footnote)
          Text(context.state.USpeedText)
            .font(.footnote)
        }
        HStack(spacing: 2) {
          Image(systemName: "arrow.down")
            .font(.footnote)
          Text(context.state.DSpeedText)
            .font(.footnote)
        }
      }
    } dynamicIsland: { context in
      DynamicIsland {
        // expand UI with USpeed and DSpeed and icon
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: 4) {
            HStack(spacing: 2) {
              Image(systemName: "arrow.up")
                .font(.footnote)
              Text(context.state.USpeedText)
                .font(.footnote)
            }
            HStack(spacing: 2) {
              Image(systemName: "arrow.down")
                .font(.footnote)
              Text(context.state.DSpeedText)
                .font(.footnote)
            }
          }
        }
      } compactLeading: {
        // compact UI with USpeed and DSpeed
        VStack(alignment: .trailing, spacing: 1) {
          Text(context.state.USpeedText)
            .font(.system(size: 8))
            .lineLimit(1)
          Text(context.state.DSpeedText)
            .font(.system(size: 8))
            .lineLimit(1)
        }
        .frame(width: 26)
      } compactTrailing: {
        EmptyView()
      } minimal: {
        // minimal UI with DSpeed only
        Text(context.state.DSpeedText)
          .font(.system(size: 8))
          .lineLimit(1)
      }
    }
  }
}
