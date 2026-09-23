import AVFoundation
import AppKit

guard CommandLine.arguments.count == 4 else {
    fatalError("Usage: swift render-walkthrough.swift <project> <native-discover.mov> <output.mp4>")
}

let project = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let recordingURL = URL(fileURLWithPath: CommandLine.arguments[2])
let output = URL(fileURLWithPath: CommandLine.arguments[3])
let screenshots = project.appendingPathComponent("apps/web/public/screenshots")

func image(at url: URL) -> CGImage {
    guard let source = NSImage(contentsOf: url),
          let result = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("Could not load \(url.path)")
    }
    return result
}

let background = image(at: project.appendingPathComponent("content/product-hunt/media/01-overview.png"))
let workspace = image(at: screenshots.appendingPathComponent("workspace.png"))
let providers = image(at: screenshots.appendingPathComponent("providers.png"))
let benchmarks = image(at: screenshots.appendingPathComponent("benchmarks.png"))

let recording = AVURLAsset(url: recordingURL)
let frameGenerator = AVAssetImageGenerator(asset: recording)
frameGenerator.appliesPreferredTrackTransform = true
frameGenerator.maximumSize = CGSize(width: 1_200, height: 800)
frameGenerator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 60)
frameGenerator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 60)
let recordingDuration = max(0.1, CMTimeGetSeconds(recording.duration) - 0.04)

let canvas = CGSize(width: 1_270, height: 760)
let appRect = CGRect(x: 220, y: -37, width: 830, height: 553)
let visibleAppClip = CGRect(x: 220, y: 60, width: 830, height: 456)
let fps: Int32 = 30
let discoverStart = 1.8
let providersStart = discoverStart + recordingDuration
let benchmarksStart = providersStart + 1.55
let duration = benchmarksStart + 2.0
let frameCount = Int(ceil(duration * Double(fps)))

func clamp(_ value: Double, _ low: Double = 0, _ high: Double = 1) -> Double {
    min(high, max(low, value))
}

func ease(_ value: Double) -> Double {
    let t = clamp(value)
    return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
}

func mix(_ a: CGFloat, _ b: CGFloat, _ progress: Double) -> CGFloat {
    a + (b - a) * CGFloat(progress)
}

func drawApp(_ image: CGImage, in context: CGContext, opacity: CGFloat = 1, overscan: CGFloat = 0) {
    context.saveGState()
    context.addPath(CGPath(roundedRect: visibleAppClip, cornerWidth: 10, cornerHeight: 10, transform: nil))
    context.clip()
    context.setAlpha(opacity)
    let rect = appRect.insetBy(dx: -overscan, dy: -(overscan * 2 / 3))
    context.draw(image, in: rect)
    context.restoreGState()
}

struct Click {
    let time: Double
    let point: CGPoint
}

let clicks = [
    Click(time: 1.58, point: CGPoint(x: 286, y: 384)),
    Click(time: discoverStart + 4.35, point: CGPoint(x: 578, y: 372)),
    Click(time: discoverStart + 7.55, point: CGPoint(x: 635, y: 372)),
    Click(time: providersStart + 0.22, point: CGPoint(x: 286, y: 493)),
    Click(time: benchmarksStart + 0.15, point: CGPoint(x: 286, y: 428))
]

func cursorPosition(at time: Double) -> CGPoint {
    let start = CGPoint(x: 925, y: 625)
    let content = CGPoint(x: 820, y: 560)
    let segments: [(Double, Double, CGPoint, CGPoint)] = [
        (0.55, 1.48, start, clicks[0].point),
        (2.20, 3.25, clicks[0].point, content),
        (discoverStart + 3.20, discoverStart + 4.25, content, clicks[1].point),
        (discoverStart + 4.90, discoverStart + 5.70, clicks[1].point, content),
        (discoverStart + 6.45, discoverStart + 7.45, content, clicks[2].point),
        (discoverStart + 8.10, discoverStart + 9.00, clicks[2].point, content),
        (providersStart - 0.80, providersStart + 0.12, content, clicks[3].point),
        (benchmarksStart - 0.70, benchmarksStart + 0.05, clicks[3].point, clicks[4].point)
    ]
    var point = start
    for segment in segments {
        if time < segment.0 { return point }
        if time <= segment.1 {
            let progress = ease((time - segment.0) / (segment.1 - segment.0))
            return CGPoint(
                x: mix(segment.2.x, segment.3.x, progress),
                y: mix(segment.2.y, segment.3.y, progress)
            )
        }
        point = segment.3
    }
    return point
}

func drawCursor(in context: CGContext, time: Double) {
    let top = cursorPosition(at: time)
    let point = CGPoint(x: top.x, y: canvas.height - top.y)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0.7, height: -1.2), blur: 1.6, color: NSColor.black.withAlphaComponent(0.25).cgColor)
    let pointer = CGMutablePath()
    pointer.move(to: point)
    pointer.addLine(to: CGPoint(x: point.x, y: point.y - 14))
    pointer.addLine(to: CGPoint(x: point.x + 3.8, y: point.y - 10.5))
    pointer.addLine(to: CGPoint(x: point.x + 6.7, y: point.y - 16.5))
    pointer.addLine(to: CGPoint(x: point.x + 9.0, y: point.y - 15.35))
    pointer.addLine(to: CGPoint(x: point.x + 6.1, y: point.y - 9.55))
    pointer.addLine(to: CGPoint(x: point.x + 11.0, y: point.y - 9.15))
    pointer.closeSubpath()
    context.addPath(pointer)
    context.setFillColor(NSColor.black.cgColor)
    context.fillPath()
    context.addPath(pointer)
    context.setStrokeColor(NSColor.white.cgColor)
    context.setLineWidth(1.15)
    context.setLineJoin(.round)
    context.strokePath()
    context.restoreGState()

    for click in clicks {
        let age = time - click.time
        guard age >= 0 && age <= 0.62 else { continue }
        let clickPoint = CGPoint(x: click.point.x, y: canvas.height - click.point.y)
        let progress = ease(age / 0.62)
        let radius = CGFloat(4 + progress * 15)
        context.saveGState()
        context.setStrokeColor(NSColor(red: 0.86, green: 0.28, blue: 0.10, alpha: 0.9 * (1 - progress)).cgColor)
        context.setLineWidth(1.6)
        context.strokeEllipse(in: CGRect(x: clickPoint.x - radius, y: clickPoint.y - radius, width: radius * 2, height: radius * 2))
        if age < 0.16 {
            context.setFillColor(NSColor(red: 0.86, green: 0.28, blue: 0.10, alpha: 0.75).cgColor)
            context.fillEllipse(in: CGRect(x: clickPoint.x - 2.5, y: clickPoint.y - 2.5, width: 5, height: 5))
        }
        context.restoreGState()
    }
}

try? FileManager.default.removeItem(at: output)
let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: canvas.width,
    AVVideoHeightKey: canvas.height,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 6_000_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
    ]
]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: canvas.width,
    kCVPixelBufferHeightKey as String: canvas.height
])
writer.add(input)
guard writer.startWriting() else { fatalError(writer.error?.localizedDescription ?? "Could not start writer") }
writer.startSession(atSourceTime: .zero)

var lastDiscoverFrame: CGImage?
for frame in 0..<frameCount {
    autoreleasepool {
        while !input.isReadyForMoreMediaData {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.002))
        }
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(canvas.width),
            Int(canvas.height),
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true
            ] as CFDictionary,
            &pixelBuffer
        )
        guard let pixelBuffer else { return }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(canvas.width),
            height: Int(canvas.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else { return }

        let time = Double(frame) / Double(fps)
        context.draw(background, in: CGRect(origin: .zero, size: canvas))

        if time < discoverStart {
            drawApp(workspace, in: context)
        } else if time < providersStart {
            let sourceTime = min(recordingDuration, max(0, time - discoverStart))
            let requested = CMTime(seconds: sourceTime, preferredTimescale: 600)
            if let next = try? frameGenerator.copyCGImage(at: requested, actualTime: nil) {
                lastDiscoverFrame = next
            }
            if let discover = lastDiscoverFrame { drawApp(discover, in: context, overscan: 6) }
        } else if time < benchmarksStart {
            drawApp(providers, in: context)
        } else {
            drawApp(benchmarks, in: context)
        }

        if time > 0.40 { drawCursor(in: context, time: time) }
        adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps))
    }
}

input.markAsFinished()
let completion = DispatchGroup()
completion.enter()
writer.finishWriting { completion.leave() }
completion.wait()
guard writer.status == .completed else { fatalError(writer.error?.localizedDescription ?? "Video export failed") }
print(output.path)
