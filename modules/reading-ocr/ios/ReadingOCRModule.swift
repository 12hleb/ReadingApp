import ExpoModulesCore
import Vision
import ImageIO

public class ReadingOCRModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ReadingOCR")
    AsyncFunction("recognize") { (uri: String) throws -> [String: Any] in
      guard let url = URL(string: uri), url.isFileURL,
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw NSError(domain: "ReadingOCR", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Cannot open the captured page."])
      }
      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      request.recognitionLanguages = ["en-US"]
      request.usesLanguageCorrection = true
      // JS has already baked EXIF orientation into this full-resolution file.
      let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
      try handler.perform([request])
      let width = CGFloat(image.width)
      let height = CGFloat(image.height)
      // Vision observations are retained in document reading order; each is a line.
      let blocks: [[String: Any]] = try (request.results ?? []).compactMap { observation in
        guard let candidate = observation.topCandidates(1).first else { return nil }
        let text = candidate.string
        let regex = try NSRegularExpression(pattern: "\\S+")
        let elements: [[String: Any]] = try regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
          guard let range = Range(match.range, in: text),
                let rectangle = try candidate.boundingBox(for: range) else { return nil }
          // Vision's normalized bottom-left origin -> upright pixel top-left origin.
          let points = [rectangle.topLeft, rectangle.topRight, rectangle.bottomRight, rectangle.bottomLeft].map {
            ["x": $0.x * width, "y": (1 - $0.y) * height]
          }
          let box = rectangle.boundingBox
          return ["text": String(text[range]), "confidence": candidate.confidence,
                  "frame": ["left": box.minX * width, "top": (1 - box.maxY) * height,
                            "width": box.width * width, "height": box.height * height],
                  "cornerPoints": points]
        }
        return ["lines": [["elements": elements]]]
      }
      return ["blocks": blocks]
    }
  }
}
