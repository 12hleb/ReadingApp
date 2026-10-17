import SwiftUI

struct TextSelectionOverlay: View {
    let page: OCRPage
    let imageSize: CGSize
    let isFrozen: Bool
    let selected: Set<Int>
    let onSelection: (Int, Int, Bool) -> Void
    let onClear: () -> Void
    @State private var anchor: Int?
    @State private var focus: Int?

    var body: some View {
        GeometryReader { proxy in
            let geometry = ImageGeometry(imageSize: imageSize, viewport: proxy.size, scaling: isFrozen ? .fit : .fill)
            ZStack(alignment: .topLeading) {
                ForEach(page.words) { word in
                    let rect = geometry.viewRect(for: word.bounds)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(selected.contains(word.id) ? .orange.opacity(0.38) : .clear)
                        .overlay { RoundedRectangle(cornerRadius: 3).stroke(selected.contains(word.id) ? .orange : .white.opacity(0.35), lineWidth: selected.contains(word.id) ? 1.5 : 0.5) }
                        .frame(width: max(0, rect.width), height: max(0, rect.height))
                        .position(x: rect.midX, y: rect.midY)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    guard isFrozen else { return }
                    if anchor == nil { anchor = geometry.hitTest(value.startLocation, words: page.words) }
                    guard let anchor else { return }
                    if let hit = geometry.hitTest(value.location, words: page.words) { focus = hit }
                    onSelection(anchor, focus ?? anchor, false)
                }
                .onEnded { _ in
                    guard isFrozen else { return }
                    if let anchor { onSelection(anchor, focus ?? anchor, true) }
                    else { onClear() }
                    anchor = nil; focus = nil
                })
            .allowsHitTesting(isFrozen)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isFrozen ? "Scanned page. Use Choose Text for an accessible word list." : "Live text detection")
        }
        .clipped()
    }
}
