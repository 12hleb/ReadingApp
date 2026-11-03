import SwiftUI

struct BookCover: View {
    let book: Book
    var width: CGFloat = 64
    @State private var cover: UIImage?

    var body: some View {
        Group {
            if let cover {
                Image(uiImage: cover).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [.orange.opacity(0.25), .brown.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "book.closed").font(.title2).foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: width, height: width * 1.4)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .accessibilityHidden(true)
        .task(id: book.coverImagePath) { cover = ImageStorageService().load(book.coverImagePath) }
    }
}

struct BookAlbumRow: View {
    let book: Book
    var body: some View {
        HStack(spacing: 18) {
            BookCover(book: book)
            VStack(alignment: .leading, spacing: 7) {
                Text(book.title).font(.system(.headline, design: .serif)).foregroundStyle(.primary)
                Text("\(book.savedWords.count) saved \(book.savedWords.count == 1 ? "entry" : "entries")")
                    .font(.subheadline).foregroundStyle(.secondary)
                if let date = book.lastReadAt {
                    Text("Last read \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

/// Keep the revealed action open during confirmation. Native swipeActions close
/// after a button tap, which moves the row and loses the confirmation's anchor.
struct SwipeableBookRow: View {
    let book: Book
    @Binding var openBookID: UUID?
    let onOpen: () -> Void
    let onDelete: () -> Void
    @State private var confirmingDelete = false
    @GestureState private var dragOffset: CGFloat = 0
    private let actionWidth: CGFloat = 96

    private var isOpen: Bool { openBookID == book.id }
    private var offset: CGFloat { min(0, max(-actionWidth, (isOpen ? -actionWidth : 0) + dragOffset)) }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button("Delete") { confirmingDelete = true }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .frame(width: 80)
                .padding(.vertical, 24)
                .background(.red, in: RoundedRectangle(cornerRadius: 18))
                .opacity(-offset / actionWidth)
                .allowsHitTesting(isOpen && dragOffset == 0)
                .accessibilityHidden(!isOpen)
                .popover(isPresented: $confirmingDelete, attachmentAnchor: .rect(.bounds), arrowEdge: .trailing) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Delete “\(book.title)” and all its saved vocabulary?")
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Delete Book", role: .destructive) {
                            confirmingDelete = false
                            onDelete()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        Button("Cancel", role: .cancel) { confirmingDelete = false }
                            .buttonStyle(.bordered)
                    }
                    .padding(20)
                    .frame(width: 280)
                    .presentationCompactAdaptation(.popover)
                }

            HStack(spacing: 8) {
                BookAlbumRow(book: book)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                if isOpen { withAnimation { openBookID = nil } }
                else { onOpen() }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onOpen() }
            .accessibilityAction(named: "Delete book") {
                openBookID = book.id
                confirmingDelete = true
            }
            .offset(x: offset)
            .simultaneousGesture(DragGesture(minimumDistance: 20)
                .updating($dragOffset) { value, state, _ in
                    guard !confirmingDelete,
                          abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                    state = value.translation.width
                }
                .onEnded { value in
                    guard !confirmingDelete,
                          abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                    let end = (isOpen ? -actionWidth : 0) + value.predictedEndTranslation.width
                    withAnimation(.easeOut(duration: 0.2)) {
                        openBookID = end < -actionWidth / 2 ? book.id : nil
                    }
                })
        }
        .clipped()
        .onChange(of: openBookID) { _, id in
            if id != book.id { confirmingDelete = false }
        }
    }
}
