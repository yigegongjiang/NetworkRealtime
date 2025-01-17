//
//  LiveActivityWidgetAttributes.swift
//  NetworkRealtime
//
//  Created by Hailv on 2025/01/14.
//
import ActivityKit

struct LiveActivityWidgetAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var USpeed: Double
    var DSpeed: Double
    var USpeedText: String
    var DSpeedText: String
  }

  var name: String
}
