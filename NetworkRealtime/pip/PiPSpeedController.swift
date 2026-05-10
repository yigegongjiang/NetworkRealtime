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
  private var statusObservation: NSKeyValueObservation?

  // 缓存最近一次文本; 自愈时 (flush 后) 用它重推一帧, 否则浮窗仍是空的.
  private var lastUText = "0b"
  private var lastDText = "0b"

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

    installRecoveryHooks()

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
    lastUText = uText
    lastDText = dText
    // Widget / 控制中心 跨进程改 SpeedPreset.current 后, 主 App 内 renderer.preset 还是旧值;
    // 每秒回调时比对一次, 不一致即同步, 实现自然 reflow, 无需 Darwin notification.
    let cur = SpeedPreset.current
    if renderer.preset != cur { renderer.preset = cur }
    let segments = ["↑\(uText)", "↓\(dText)"] + CustomSegmentsStore.shared.segments
    guard let buffer = renderer.render(segments: segments) else { return }
    // 锁屏 / GPU 资源回收会让 layer 进 .failed, 后续 enqueue 全部静默丢弃;
    // 必须先 flush 才能继续 enqueue (参见 WebKit Bug 181623 同模式).
    if displayLayer.status == .failed {
      displayLayer.flush()
    }
    displayLayer.enqueue(buffer)
  }

  // 自定义文字变更后用 last 网速重推一帧, 不等下一秒回调.
  func refresh() {
    update(uText: lastUText, dText: lastDText)
  }

  // 切换字号: 持久化 + 改 renderer + 立即推一帧让浮窗按新比例 reflow.
  // switchTo 在写 current 前把旧 current 存到 previous, 控制中心 toggle 才有"上一档"可切回.
  func setPreset(_ preset: SpeedPreset) {
    SpeedPreset.switchTo(preset)
    renderer.preset = preset
    refresh()
  }

  // MARK: - Recovery

  // 三处恢复入口都汇入 recoverIfNeeded:
  // 1. KVO status -> .failed (主路径, 系统状态变更立即触发)
  // 2. failedToDecodeNotification (decode 链路次级通道)
  // 3. UIApplication.didBecomeActive (主动兜底, 即便前两者未触发也能恢复)
  private func installRecoveryHooks() {
    statusObservation = displayLayer.observe(
      \.status,
      options: [.new]
    ) { [weak self] layer, _ in
      guard layer.status == .failed else { return }
      self?.recoverIfNeeded(reason: "kvo")
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleFailedToDecode),
      name: .AVSampleBufferDisplayLayerFailedToDecode,
      object: displayLayer
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  @objc private func handleFailedToDecode() {
    recoverIfNeeded(reason: "decode-failed")
  }

  @objc private func handleDidBecomeActive() {
    recoverIfNeeded(reason: "did-become-active")
  }

  // 唯一恢复路径: 仅在 status == .failed 时介入, 复用 update() 内的 flush + enqueue 逻辑,
  // 避免重复实现. 强制 main 线程, 因 KVO/通知回调线程不确定.
  private func recoverIfNeeded(reason: String) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      guard self.displayLayer.status == .failed else { return }
      log.warning("PiP layer recover: \(reason)")
      self.update(uText: self.lastUText, dText: self.lastDText)
    }
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
