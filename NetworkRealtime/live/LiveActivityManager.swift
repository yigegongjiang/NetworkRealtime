import Foundation
import ActivityKit

final class LiveActivityManager {
  // MARK: - Properties

  static let shared = LiveActivityManager()
  private var activity: Activity<LiveActivityWidgetAttributes>?

  // MARK: - Constants

  private enum Constants {
    static let defaultSpeed = 0.0
    static let defaultSpeedText = "0m"
    static let defaultName = "NetworkSpeed"
  }

  // MARK: - Initialization

  private init() {
  }

  // MARK: - Public Methods

  func startLiveActivity() {
    detroy()

    Task {
      do {
        let attributes = LiveActivityWidgetAttributes(name: Constants.defaultName)
        let initialState = createContentState(
          uSpeed: Constants.defaultSpeed,
          dSpeed: Constants.defaultSpeed,
          uSpeedText: Constants.defaultSpeedText,
          dSpeedText: Constants.defaultSpeedText
        )

        activity = try Activity<LiveActivityWidgetAttributes>.request(
          attributes: attributes,
          content: .init(state: initialState, staleDate: nil),
          pushType: nil
        )
      } catch {
        handleActivityError(error)
      }
    }
  }

  func updateLiveActivity(dSpeed: Double, dUnit: String, uSpeed: Double, uUnit: String) {
    Task {
      let state = createContentState(
        uSpeed: uSpeed,
        dSpeed: dSpeed,
        uSpeedText: "\(formatSpeedText(uSpeed))\(uUnit)",
        dSpeedText: "\(formatSpeedText(dSpeed))\(dUnit)"
      )
      await activity?.update(ActivityContent(state: state, staleDate: nil))
    }
  }

  func stopLiveActivity() {
    Task {
      let finalState = activity?.content.state ?? createDefaultContentState()
      await activity?.end(
        ActivityContent(state: finalState, staleDate: nil),
        dismissalPolicy: .immediate
      )
    }
  }

  func detroy() {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
      for activity in Activity<LiveActivityWidgetAttributes>.activities {
        await activity.end(
          ActivityContent(state: activity.content.state, staleDate: nil),
          dismissalPolicy: .immediate
        )
      }
      semaphore.signal()
    }
    semaphore.wait()
  }

  // MARK: - Private Methods

  private func formatSpeedText(_ speed: Double) -> String {
    speed.truncatingRemainder(dividingBy: 1) == 0
      ? "\(Int(speed))"
      : String(format: "%.1f", speed)
  }

  private func createContentState(
    uSpeed: Double,
    dSpeed: Double,
    uSpeedText: String,
    dSpeedText: String
  ) -> LiveActivityWidgetAttributes.ContentState {
    .init(
      USpeed: uSpeed,
      DSpeed: dSpeed,
      USpeedText: uSpeedText,
      DSpeedText: dSpeedText
    )
  }

  private func createDefaultContentState() -> LiveActivityWidgetAttributes.ContentState {
    createContentState(
      uSpeed: Constants.defaultSpeed,
      dSpeed: Constants.defaultSpeed,
      uSpeedText: Constants.defaultSpeedText,
      dSpeedText: Constants.defaultSpeedText
    )
  }

  private func handleActivityError(_ error: Error) {
    #if DEBUG
    log.error("Error starting live activity: \(error.localizedDescription)")
    #endif
  }
}
