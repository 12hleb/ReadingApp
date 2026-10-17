import SwiftUI
import SwiftData
import PhotosUI

struct AddBookView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var model = AddBookViewModel()
    @State private var photo: PhotosPickerItem?
    @State private var importing = false
    @State private var importID = UUID()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Group {
                            if let cover = model.cover { Image(uiImage: cover).resizable().scaledToFit() }
                            else {
                                RoundedRectangle(cornerRadius: 14).fill(.orange.opacity(0.12))
                                    .overlay { Image(systemName: "book.closed").font(.system(size: 44)).foregroundStyle(.orange) }
                            }
                        }.frame(width: 150, height: 210).clipShape(RoundedRectangle(cornerRadius: 14))
                        Spacer()
                    }.listRowBackground(Color.clear)
                    Button("Take Cover Photo", systemImage: "camera") { Task { await model.requestCamera() } }
                    PhotosPicker(selection: $photo, matching: .images) { Label("Choose from Photos", systemImage: "photo.on.rectangle") }
                    if importing || model.isRecognizing { ProgressView(importing ? "Loading cover…" : "Reading the title…") }
                } footer: { Text("Your cover stays on this device. A photo is optional.") }
                Section("Book title") {
                    TextField("e.g. The Secret Garden", text: $model.title, axis: .vertical)
                        .font(.system(.title3, design: .serif))
                    if let hint = model.titleHint { Text(hint).font(.caption).foregroundStyle(.secondary) }
                }
                Section {
                    Button {
                        if model.save(context: context) { dismiss() }
                    } label: { Text("Create Book Album").frame(maxWidth: .infinity).padding(.vertical, 5) }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSaving || importing || model.isRecognizing)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Add Book").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .sheet(isPresented: $model.showingCamera) { CoverCameraPicker { model.useCover($0) }.ignoresSafeArea() }
            .task(id: photo) {
                guard let photo else { return }
                let id = UUID()
                importID = id
                importing = true
                defer { if importID == id { importing = false } }
                do {
                    guard let data = try await photo.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    guard !Task.isCancelled, importID == id else { return }
                    model.useCover(image)
                } catch {
                    if !Task.isCancelled, importID == id { model.error = "The photo couldn’t be loaded. Please choose another image." }
                }
            }
            .onDisappear { model.cancelRecognition() }
            .alert("Camera access is off", isPresented: $model.cameraDenied) {
                Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Allow camera access in Settings, or choose a cover with the Photos picker.") }
            .alert("Couldn’t add your book", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK") { model.error = nil }
            } message: { Text(model.error ?? "") }
        }
    }
}
