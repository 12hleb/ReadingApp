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
