import SwiftUI

/// The photo and word boxes share one zoomable canvas, including hit testing.
struct ZoomablePageView: UIViewRepresentable {
    let frame: CameraFrame
    let selected: Set<Int>
    let onSelection: (Int, Int, Bool) -> Void
    let onClear: () -> Void

    func makeUIView(context: Context) -> PageScrollView {
        let view = PageScrollView()
        view.setPhoto(frame)
        return view
    }

    func updateUIView(_ view: PageScrollView, context: Context) {
        view.onSelection = onSelection
        view.onClear = onClear
        view.setPhoto(frame)
        view.canvas.selected = selected
    }
}

final class PageScrollView: UIScrollView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    let canvas = PageCanvasView()
    var onSelection: ((Int, Int, Bool) -> Void)?
    var onClear: (() -> Void)?
    private var photoID: UUID?
    private var viewport = CGSize.zero
    private var needsFit = true
    private var anchor: Int?
    private var focus: Int?
    private lazy var selectionPan = UIPanGestureRecognizer(target: self, action: #selector(selectWords(_:)))
    private lazy var wordTap = UITapGestureRecognizer(target: self, action: #selector(tapWord(_:)))

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 6
        bouncesZoom = false
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        backgroundColor = .black
        // One finger selects; two fingers move the photo. Pinching always zooms.
        panGestureRecognizer.minimumNumberOfTouches = 2
        selectionPan.maximumNumberOfTouches = 1
        selectionPan.delegate = self
        wordTap.delegate = self
        addSubview(canvas)
        canvas.addGestureRecognizer(selectionPan)
        canvas.addGestureRecognizer(wordTap)
        wordTap.require(toFail: selectionPan)
        isAccessibilityElement = false
        canvas.isAccessibilityElement = true
        canvas.accessibilityLabel = "Book page with selectable words"
        canvas.accessibilityHint = "Use Choose Text to select words with VoiceOver."
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setPhoto(_ frame: CameraFrame) {
        guard photoID != frame.id else { return }
        photoID = frame.id
        canvas.imageView.image = UIImage(cgImage: frame.image)
        canvas.page = frame.page
        canvas.imageSize = frame.size
        canvas.selected = []
        anchor = nil
        focus = nil
        needsFit = true
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0, canvas.imageSize.width > 0 else { return }
        if needsFit || viewport != bounds.size {
            needsFit = false
            viewport = bounds.size
            setZoomScale(1, animated: false)
            canvas.transform = .identity
            let size = ImageGeometry(imageSize: canvas.imageSize, viewport: bounds.size, scaling: .fit).imageRect.size
            canvas.frame = CGRect(origin: .zero, size: size)
            contentSize = size
            contentOffset = .zero
        }
        centerCanvas()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { canvas }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerCanvas()
        canvas.displayScale = zoomScale
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        centerCanvas()
    }

    private func centerCanvas() {
        canvas.center = CGPoint(x: max(contentSize.width, bounds.width) / 2,
                                y: max(contentSize.height, bounds.height) / 2)
    }

    private func word(at point: CGPoint, inColumn column: Int? = nil) -> Int? {
        let words = column.map { column in canvas.page.words.filter { $0.columnIndex == column } } ?? canvas.page.words
        return canvas.geometry.hitTest(point, words: words, tolerance: 8 / zoomScale)
    }

    @objc private func tapWord(_ gesture: UITapGestureRecognizer) {
        guard let hit = word(at: gesture.location(in: canvas)) else { onClear?(); return }
        onSelection?(hit, hit, true)
    }

    @objc private func selectWords(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: canvas)
        switch gesture.state {
        case .began:
            // UIPan starts after movement; recover the original touch location.
            let delta = gesture.translation(in: canvas)
            anchor = word(at: CGPoint(x: location.x - delta.x, y: location.y - delta.y))
            if let anchor {
                focus = word(at: location, inColumn: canvas.page.words[anchor].columnIndex) ?? anchor
                onSelection?(anchor, focus ?? anchor, false)
            }
        case .changed:
            if let anchor {
                if let hit = word(at: location, inColumn: canvas.page.words[anchor].columnIndex) { focus = hit }
                onSelection?(anchor, focus ?? anchor, false)
            }
        case .ended:
            if let anchor { onSelection?(anchor, focus ?? anchor, true) }
            anchor = nil; focus = nil
        case .cancelled, .failed:
            anchor = nil; focus = nil
        default: break
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Let a second finger turn an unfinished selection drag into navigation.
        otherGestureRecognizer === pinchGestureRecognizer || otherGestureRecognizer === panGestureRecognizer
    }
}

final class PageCanvasView: UIView {
    let imageView = UIImageView()
    var imageSize = CGSize.zero
    var page = OCRPage.empty { didSet { setNeedsLayout() } }
    var selected: Set<Int> = [] { didSet { if selected != oldValue { setNeedsLayout() } } }
    var displayScale: CGFloat = 1 { didSet { updateLineWidths() } }
    private let wordsLayer = CAShapeLayer()
    private let selectionLayer = CAShapeLayer()
    var geometry: ImageGeometry { ImageGeometry(imageSize: imageSize, viewport: bounds.size, scaling: .fit) }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        layer.addSublayer(wordsLayer)
        layer.addSublayer(selectionLayer)
        wordsLayer.fillColor = UIColor.clear.cgColor
        wordsLayer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.65).cgColor
        selectionLayer.fillColor = UIColor.systemOrange.withAlphaComponent(0.35).cgColor
        selectionLayer.strokeColor = UIColor.systemOrange.cgColor
        updateLineWidths()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        let words = UIBezierPath()
        let selection = UIBezierPath()
        for word in page.words {
            let path = UIBezierPath(roundedRect: geometry.viewRect(for: word.bounds), cornerRadius: 2)
            if selected.contains(word.id) { selection.append(path) } else { words.append(path) }
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        wordsLayer.path = words.cgPath
        selectionLayer.path = selection.cgPath
        CATransaction.commit()
    }

    private func updateLineWidths() {
        wordsLayer.lineWidth = 0.8 / displayScale
        selectionLayer.lineWidth = 1.5 / displayScale
    }
}
