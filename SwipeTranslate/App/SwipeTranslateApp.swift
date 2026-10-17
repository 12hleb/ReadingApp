import SwiftUI
import SwiftData

@main
struct SwipeTranslateApp: App {
    private let store: Result<ModelContainer, Error>

    init() {
        store = Result {
            try ModelContainer(for: Book.self, SavedWord.self)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch store {
            case .success(let container):
                LibraryView()
                    .modelContainer(container)
                    .tint(.accentColor)
            case .failure(let error):
                ContentUnavailableView {
                    Label("Library couldn’t open", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your stored library has not been erased. Close and reopen SwipeTranslate.\n\n\(error.localizedDescription)")
                }
            }
        }
    }
}
