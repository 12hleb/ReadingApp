import SwiftUI
import UIKit

/// Uses the same live preview and still-photo service as the text reader.
struct CoverCameraPicker: View {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var camera = CameraService()
    @State private var capturing = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Color.black
                    CameraPreview(session: camera.session)
                    if capturing || camera.status == .requesting {
                        ProgressView(capturing ? "Taking photo…" : "Starting camera…")
                            .padding().background(.regularMaterial, in: Capsule())
                    } else if camera.status != .running {
                        VStack(spacing: 16) {
                            Text(camera.status == .denied ? "Camera access is off" : "Camera unavailable")
                                .font(.headline)
                            if camera.status == .denied {
                                Button("Open Settings") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            } else {
                                Button("Retry") { Task { await camera.retry() } }
                            }
                            Text("You can also cancel and choose a cover from Photos.")
                                .font(.caption).multilineTextAlignment(.center)
                        }.padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)).padding()
                    }
                }.clipped()
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        CameraLightButton(camera: camera)
                        Button { Task { await takePhoto() } } label: {
                            Label("Take Photo", systemImage: "camera.fill").frame(maxWidth: .infinity)
                        }.buttonStyle(.borderedProminent).controlSize(.large)
                            .disabled(camera.status != .running)
                    }.disabled(capturing)
                    if let lightError = camera.lightError {
                        Text(lightError).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding()
            }
            .navigationTitle("Cover Photo").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { camera.stop(); dismiss() }
                }
            }
            .task { await camera.start() }
            .onDisappear { camera.stop() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { camera.stop() }
                else if !capturing { Task { await camera.start() } }
            }
            .alert("Couldn’t take photo", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } }
            )) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        }
    }

    @MainActor private func takePhoto() async {
        guard !capturing else { return }
        capturing = true
        defer { capturing = false }
        do {
            let data = try await camera.capturePhoto()
            guard let image = UIImage(data: data) else { throw CameraCaptureError.missingPhoto }
            camera.stop()
            onImage(image)
            dismiss()
        } catch is CancellationError {
            // Closing or backgrounding the camera cancels the pending capture.
        } catch { self.error = error.localizedDescription }
    }
}

struct CameraLightButton: View {
    let camera: CameraService

    var body: some View {
        if camera.supportsLight {
            Button { Task { await camera.toggleLight() } } label: {
                Label(camera.isLightOn ? "Light On" : "Light Off",
                      systemImage: camera.isLightOn ? "flashlight.on.fill" : "flashlight.off.fill")
            }
            .buttonStyle(.bordered).controlSize(.large)
            .disabled(camera.status != .running || camera.isChangingLight)
            .accessibilityLabel("Camera light")
            .accessibilityValue(camera.isLightOn ? "On" : "Off")
            .accessibilityHint("Turns the light on or off while framing your photo")
        }
    }
}
