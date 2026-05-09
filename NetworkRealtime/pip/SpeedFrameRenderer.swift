import UIKit
import AVFoundation
import CoreImage

// 把网速文本 (uText, dText) 渲染成单帧 CMSampleBuffer, 供 AVSampleBufferDisplayLayer 消费.
// frameSize / fontSize 由 preset 决定; 切换 preset 后下一帧 enqueue 时浮窗自动按新比例 reflow.
final class SpeedFrameRenderer {
  var preset: SpeedPreset
  private let ciContext = CIContext()
  private var counter: Int64 = 0

  init(preset: SpeedPreset) {
    self.preset = preset
  }

  func render(uText: String, dText: String) -> CMSampleBuffer? {
    counter += 1
    let image = drawImage(uText: uText, dText: dText)
    guard let cgImage = image.cgImage else { return nil }
    return makeSampleBuffer(from: cgImage)
  }

  private func drawImage(uText: String, dText: String) -> UIImage {
    let frameSize = preset.frameSize
    // PiP sampleBuffer 必须不透明; 显式禁 alpha 并填黑底.
    let format = UIGraphicsImageRendererFormat()
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: frameSize, format: format)
    return renderer.image { ctx in
      UIColor.black.setFill()
      ctx.fill(CGRect(origin: .zero, size: frameSize))

      let font = UIFont.monospacedDigitSystemFont(ofSize: preset.fontSize, weight: .medium)
      let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: UIColor.white
      ]
      let attrText = NSAttributedString(
        string: "↑\(uText)  ↓\(dText)",
        attributes: attrs
      )
      let textSize = attrText.size()
      attrText.draw(at: CGPoint(
        x: max(2, (frameSize.width - textSize.width) / 2),
        y: max(0, (frameSize.height - textSize.height) / 2)
      ))
    }
  }

  private func makeSampleBuffer(from cgImage: CGImage) -> CMSampleBuffer? {
    var pixelBuffer: CVPixelBuffer?
    // IOSurface backing 是 AVSampleBufferDisplayLayer 渲染的前提; 缺它 enqueue 静默失败.
    let attrs: [String: Any] = [
      kCVPixelBufferCGImageCompatibilityKey as String: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
      kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary
    ]
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      cgImage.width,
      cgImage.height,
      kCVPixelFormatType_32BGRA,
      attrs as CFDictionary,
      &pixelBuffer
    )
    guard status == kCVReturnSuccess, let pb = pixelBuffer else { return nil }

    ciContext.render(CIImage(cgImage: cgImage), to: pb)

    var formatDesc: CMVideoFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(
      allocator: kCFAllocatorDefault,
      imageBuffer: pb,
      formatDescriptionOut: &formatDesc
    )
    guard let format = formatDesc else { return nil }

    var timing = CMSampleTimingInfo(
      duration: .invalid,
      presentationTimeStamp: CMTimeMake(value: counter, timescale: 1),
      decodeTimeStamp: .invalid
    )

    var buffer: CMSampleBuffer?
    CMSampleBufferCreateReadyWithImageBuffer(
      allocator: kCFAllocatorDefault,
      imageBuffer: pb,
      formatDescription: format,
      sampleTiming: &timing,
      sampleBufferOut: &buffer
    )
    return buffer
  }
}
