import Flutter
import UIKit
import Vision

/// Finds the subjects in a photo with Apple's Vision framework (iOS 17+),
/// for lib/services/cutout.dart.
///
/// Each subject comes back in the same shape ML Kit gives on Android: its
/// box in the photo (x, y, width, height) and, for every pixel of the box,
/// how sure Vision is (0 to 1) that the pixel belongs to it ("mask", a
/// Float32 list).
final class CutoutPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "findmyfit/cutout", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(CutoutPlugin(), channel: channel)
  }

  private let queue = DispatchQueue(label: "findmyfit.cutout", qos: .userInitiated)

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "subjects" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let path = (call.arguments as? [String: Any])?["path"] as? String else {
      result(FlutterError(code: "bad_args", message: "Missing photo path", details: nil))
      return
    }
    #if targetEnvironment(simulator)
      // Vision's subject lifting needs the Neural Engine, which the
      // Simulator lacks ("Could not create inference context").
      result(FlutterError(code: "unsupported", message: "Background removal doesn't run in the Simulator", details: nil))
      return
    #endif
    guard #available(iOS 17.0, *) else {
      result(FlutterError(code: "unsupported", message: "Background removal needs iOS 17", details: nil))
      return
    }
    queue.async {
      let reply: Any
      do {
        reply = try Self.subjects(at: path)
      } catch {
        reply = FlutterError(code: "vision", message: error.localizedDescription, details: nil)
      }
      DispatchQueue.main.async { result(reply) }
    }
  }

  @available(iOS 17.0, *)
  private static func subjects(at path: String) throws -> [[String: Any]] {
    // The Dart side has already turned the pixels upright.
    let handler = VNImageRequestHandler(url: URL(fileURLWithPath: path), orientation: .up, options: [:])
    let request = VNGenerateForegroundInstanceMaskRequest()
    try handler.perform([request])
    guard let observation = request.results?.first else { return [] }
    var subjects: [[String: Any]] = []
    for instance in observation.allInstances {
      // A soft mask the size of the photo, for this one subject.
      let mask = try observation.generateScaledMaskForImage(forInstances: IndexSet(integer: instance), from: handler)
      if let subject = subject(from: mask) { subjects.append(subject) }
    }
    return subjects
  }

  /// Crops a photo-sized mask to the box around its subject.
  private static func subject(from buffer: CVPixelBuffer) -> [String: Any]? {
    guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_OneComponent32Float else { return nil }
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
    let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
    func row(_ y: Int) -> UnsafePointer<Float32> {
      UnsafePointer(base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: Float32.self))
    }

    // The box around every pixel Vision is at all sure of.
    var minX = width, minY = height, maxX = -1, maxY = -1
    for y in 0..<height {
      let r = row(y)
      guard let first = (0..<width).first(where: { r[$0] > 0.05 }) else { continue }
      let last = (first..<width).last(where: { r[$0] > 0.05 })!
      minX = min(minX, first)
      maxX = max(maxX, last)
      minY = min(minY, y)
      maxY = y
    }
    guard maxX >= 0 else { return nil }

    let boxWidth = maxX - minX + 1, boxHeight = maxY - minY + 1
    var mask = [Float32](repeating: 0, count: boxWidth * boxHeight)
    for y in 0..<boxHeight {
      let r = row(minY + y)
      for x in 0..<boxWidth { mask[y * boxWidth + x] = r[minX + x] }
    }
    return [
      "x": minX,
      "y": minY,
      "width": boxWidth,
      "height": boxHeight,
      "mask": FlutterStandardTypedData(float32: mask.withUnsafeBufferPointer { Data(buffer: $0) }),
    ]
  }
}
