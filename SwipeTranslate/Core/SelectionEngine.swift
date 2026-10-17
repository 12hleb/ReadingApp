import Foundation
import CoreGraphics

enum ImageScaling: Equatable { case fit, fill }

struct ImageGeometry {
    let imageSize: CGSize
    let viewport: CGSize
    let scaling: ImageScaling

    var imageRect: CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let x = viewport.width / imageSize.width
        let y = viewport.height / imageSize.height
        let scale = scaling == .fit ? min(x, y) : max(x, y)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (viewport.width - size.width) / 2, y: (viewport.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    func viewRect(for bounds: CGRect) -> CGRect {
        let frame = imageRect
        return CGRect(x: frame.minX + bounds.minX * frame.width,
                      y: frame.minY + (1 - bounds.maxY) * frame.height,
                      width: bounds.width * frame.width, height: bounds.height * frame.height)
    }

    func hitTest(_ point: CGPoint, words: [OCRWord], tolerance: CGFloat = 8) -> Int? {
        // Never select a cropped-off word or a word across a letterbox margin.
        guard CGRect(origin: .zero, size: viewport).contains(point), imageRect.contains(point) else { return nil }
        let nearby = words.filter { viewRect(for: $0.bounds).insetBy(dx: -tolerance, dy: -tolerance).contains(point) }
        return nearby.min { a, b in
            distance(point, to: viewRect(for: a.bounds)) < distance(point, to: viewRect(for: b.bounds))
        }?.id
    }

    private func distance(_ point: CGPoint, to rect: CGRect) -> CGFloat {
        let x = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let y = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return x * x + y * y
    }
}

struct TextSelection: Equatable {
    let wordIDs: Set<Int>
    let text: String
    let sentence: String?
}

enum SelectionEngine {
    static func select(from anchor: Int, through focus: Int, page: OCRPage) -> TextSelection? {
        guard page.words.indices.contains(anchor), page.words.indices.contains(focus) else { return nil }
        let lower = min(anchor, focus), upper = max(anchor, focus)
        let selected = page.words[lower...upper]
        let start = page.words[lower].range.location
        let end = NSMaxRange(page.words[upper].range)
        let span = NSRange(location: start, length: end - start)
        let source = page.text as NSString
        guard span.location >= 0, NSMaxRange(span) <= source.length else { return nil }
        let intersecting = page.sentenceRanges.filter { NSIntersectionRange($0, span).length > 0 }
        let sentence: String?
        if let first = intersecting.first, let last = intersecting.last,
           NSMaxRange(last) <= source.length {
            sentence = source.substring(with: NSRange(location: first.location, length: NSMaxRange(last) - first.location))
                .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        } else { sentence = nil }
        return TextSelection(wordIDs: Set(selected.map(\.id)),
            text: source.substring(with: span).split(whereSeparator: \.isWhitespace).joined(separator: " "), sentence: sentence)
    }
}
