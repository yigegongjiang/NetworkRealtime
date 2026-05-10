import UIKit
import AVKit
import AVFoundation

// Public entry point for the PiP overlay. Singleton mounted by ViewController.attach,
// driven by NetworkSpeedMonitor callbacks via update(uText:dText:).
// The overlay size is determined by the sampleBuffer aspect ratio (from SpeedPreset),
// not by the displayLayer's frame in the host view.
final class PiPSpeedController: NSObject {
  static let shared = PiPSpeedController()

  private let displayLayer = AVSampleBufferDisplayLayer()
  private let renderer = SpeedFrameRenderer(preset: .current)
  private var controller: AVPictureInPictureController?
  private var possibleObservation: NSKeyValueObservation?
  private var statusObservation: NSKeyValueObservation?

  // Cache of the most recent text; used to re-enqueue a frame after self-recovery
  // (post flush), otherwise the overlay would stay blank.
  private var lastUText = "0b"
  private var lastDText = "0b"

  override private init() { super.init() }

  func attach(to view: UIView) {
    guard controller == nil else { return }

    // Placeholder geometry inside the host app; unrelated to the PiP overlay size,
    // which is governed by the sampleBuffer aspect ratio. A tiny square in the
    // top-left corner satisfies PiP's requirement that the layer be in the view
    // tree with non-zero bounds, without obscuring the UI.
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

    // PiP requires at least one enqueued frame before isPictureInPicturePossible
    // can flip to true.
    update(uText: "0b", dText: "0b")
  }

  func start() {
    guard let controller else { return }
    if controller.isPictureInPicturePossible {
      controller.startPictureInPicture()
      return
    }
    // isPictureInPicturePossible flips to true only after the layer is ready;
    // observe via KVO and start once it does.
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
    // When the widget or Control Center mutates SpeedPreset.current from another
    // process, renderer.preset in the host app stays stale. Reconcile on every
    // 1 Hz callback so the overlay reflows naturally — no Darwin notification needed.
    let cur = SpeedPreset.current
    if renderer.preset != cur { renderer.preset = cur }
    let segments = ["↑\(uText)", "↓\(dText)"] + CustomSegmentsStore.shared.segments
    guard let buffer = renderer.render(segments: segments) else { return }
    // Lock screen or GPU resource reclaim drives the layer into .failed, after
    // which every enqueue is silently dropped. A flush is required before
    // enqueuing can resume (same pattern as WebKit Bug 181623).
    if displayLayer.status == .failed {
      displayLayer.flush()
    }
    displayLayer.enqueue(buffer)
  }

  // Re-enqueue a frame using the last known speeds — used after custom text
  // edits, instead of waiting for the next 1 Hz callback.
  func refresh() {
    update(uText: lastUText, dText: lastDText)
  }

  // Change the display level: persist, update the renderer, and push a frame
  // so the overlay reflows to the new aspect ratio immediately. switchTo
  // snapshots the outgoing current into previous, enabling Control Center
  // "toggle back".
  func setPreset(_ preset: SpeedPreset) {
    SpeedPreset.switchTo(preset)
    renderer.preset = preset
    refresh()
  }

  // MARK: - Recovery

  // Three recovery entry points all funnel into recoverIfNeeded:
  // 1. KVO status -> .failed (primary path, fires on system state change)
  // 2. failedToDecodeNotification (secondary channel via the decode pipeline)
  // 3. UIApplication.didBecomeActive (safety net when neither above fires)
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

  // The single recovery path. Acts only when status == .failed and reuses the
  // flush + enqueue logic in update() to avoid duplication. Hops to the main
  // thread because KVO and notification callbacks have undefined thread affinity.
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
