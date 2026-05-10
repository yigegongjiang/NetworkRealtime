import UIKit
import AVFoundation
import CoreImage

// Renders an array of text segments into a single CMSampleBuffer for an
// AVSampleBufferDisplayLayer to consume. The caller (PiPSpeedController)
// assembles segments (network speeds plus user-defined text); this class is
// agnostic to their source. frameSize and fontSize are derived from preset;
// switching presets causes the next enqueued frame to reflow the overlay to
// the new aspect ratio automatically.
final class SpeedFrameRenderer {
  var preset: SpeedPreset
  private let ciContext = CIContext()
  private var counter: Int64 = 0

  init(preset: SpeedPreset) {
    self.preset = preset
  }

  func render(segments: [String]) -> CMSampleBuffer? {
    counter += 1
    let image = drawImage(segments: segments)
    guard let cgImage = image.cgImage else { return nil }
    return makeSampleBuffer(from: cgImage)
  }

  private func drawImage(segments: [String]) -> UIImage {
    let frameSize = preset.frameSize
    // PiP sampleBuffers must be opaque; disable alpha explicitly and fill black.
    let format = UIGraphicsImageRendererFormat()
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: frameSize, format: format)
    return renderer.image { ctx in
      UIColor.black.setFill()
      ctx.fill(CGRect(origin: .zero, size: frameSize))

      guard !segments.isEmpty else { return }

      let font = UIFont.monospacedDigitSystemFont(ofSize: preset.fontSize, weight: .medium)
      let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: UIColor.white
      ]
      let attrText = NSAttributedString(
        string: segments.joined(separator: "  "),
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
    // IOSurface backing is required by AVSampleBufferDisplayLayer; without it
    // every enqueue fails silently.
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
