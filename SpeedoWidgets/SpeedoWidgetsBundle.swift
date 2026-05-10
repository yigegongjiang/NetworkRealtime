import WidgetKit
import SwiftUI

@main
struct SpeedoWidgetsBundle: WidgetBundle {
  @WidgetBundleBuilder
  var body: some Widget {
    SizeWidget()
  }
}
