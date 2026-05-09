import UIKit
import AVKit
import AVFoundation

// 网速 PiP 浮窗的对外入口. 单例, 由 ViewController.attach 挂载,
// 由 NetworkSpeedMonitor 回调驱动 update(uText:dText:).
// 浮窗大小不取决于 displayLayer 在主视图里的 frame, 而是 sampleBuffer 比例 (由 SpeedPreset 决定).
final class PiPSpeedController: NSObject {
  static let shared = PiPSpeedController()

  private let displayLayer = AVSampleBufferDisplayLayer()
  private let renderer = SpeedFrameRenderer(preset: .current)
  private var controller: AVPictureInPictureController?
  private var possibleObservation: NSKeyValueObservation?

  override private init() { super.init() }

  func attach(to view: UIView) {
    guard controller == nil else { return }

    // 主 App 内占位用; PiP 浮窗大小与此无关 (取决于 sampleBuffer 比例).
    // 放屏幕左上角小方块, 满足 PiP 启动需 layer 在视图树且 bounds 非零的条件, 不挡 UI.
    displayLayer.frame = CGRect(x: 8, y: 60, width: 10, height: 10)
    displayLayer.videoGravity = .resizeAspect
    displayLayer.backgroundColor = UIColor.black.cgColor
    view.layer.addSublayer(displayLayer)

    let source = AVPictureInPictureController.ContentSource(
      sampleBufferDisplayLayer: displayLayer,
      playbackDelegate: self
    )
    let pip = AVPictureInPictureController(contentSource: source)
    pip.delegate = self
    controller = pip

    // PiP 启动前需 layer 已有帧, 否则 isPictureInPicturePossible 一直为 false.
    update(uText: "0b", dText: "0b")
  }

  func start() {
    guard let controller else { return }
    if controller.isPictureInPicturePossible {
      controller.startPictureInPicture()
      return
    }
    // isPictureInPicturePossible 在 layer ready 后才置 true; KVO 等到位再启动.
    possibleObservation = controller.observe(
      \.isPictureInPicturePossible,
      options: [.new]
    ) { [weak self] obs, change in
      guard change.newValue == true else { return }
      obs.startPictureInPicture()
      self?.possibleObservation = nil
    }
  }

  func stop() {
    controller?.stopPictureInPicture()
    possibleObservation = nil
  }

  func update(uText: String, dText: String) {
    guard let buffer = renderer.render(uText: uText, dText: dText) else { return }
    displayLayer.enqueue(buffer)
  }

  // 切换字号: 持久化 + 改 renderer + 立即推一帧让浮窗按新比例 reflow.
  func setPreset(_ preset: SpeedPreset) {
    SpeedPreset.current = preset
    renderer.preset = preset
    update(uText: "0b", dText: "0b")
  }
}

// MARK: AVPictureInPictureSampleBufferPlaybackDelegate

extension PiPSpeedController: AVPictureInPictureSampleBufferPlaybackDelegate {
  func pictureInPictureController(_: AVPictureInPictureController, setPlaying: Bool) {}

  func pictureInPictureControllerTimeRangeForPlayback(_: AVPictureInPictureController) -> CMTimeRange {
    CMTimeRange(start: .negativeInfinity, end: .positiveInfinity)
  }

  func pictureInPictureControllerIsPlaybackPaused(_: AVPictureInPictureController) -> Bool {
    false
  }

  func pictureInPictureController(_: AVPictureInPictureController, didTransitionToRenderSize: CMVideoDimensions) {}

  func pictureInPictureController(
    _: AVPictureInPictureController,
    skipByInterval: CMTime,
    completion: @escaping () -> Void
  ) {
    completion()
  }
}

// MARK: AVPictureInPictureControllerDelegate

extension PiPSpeedController: AVPictureInPictureControllerDelegate {
  func pictureInPictureControllerDidStartPictureInPicture(_: AVPictureInPictureController) {
    log.info("PiP started")
  }

  func pictureInPictureController(
    _: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: any Error
  ) {
    log.error("PiP failed to start: \(error.localizedDescription)")
  }

  func pictureInPictureControllerDidStopPictureInPicture(_: AVPictureInPictureController) {
    log.info("PiP stopped")
  }
}
