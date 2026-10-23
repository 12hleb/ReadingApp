import AVFoundation
import CoreGraphics
import Observation

struct CameraFrame {
    let id = UUID()
    let image: CGImage
    let page: OCRPage
    var size: CGSize { CGSize(width: CGFloat(image.width), height: CGFloat(image.height)) }
}

enum CameraStatus: Equatable {
    case idle, requesting, running, denied, unavailable
    case interrupted(String), failed(String)
}

enum CameraCaptureError: LocalizedError {
    case notReady, missingPhoto
    var errorDescription: String? {
        switch self {
        case .notReady: "The camera isn’t ready. Please try again."
        case .missingPhoto: "The photo couldn’t be captured. Please try again."
        }
    }
}

@MainActor @Observable
final class CameraService {
    private(set) var status: CameraStatus = .idle
    private(set) var supportsLight = false
    private(set) var isLightOn = false
    private(set) var isChangingLight = false
    var lightError: String?
    @ObservationIgnored private let worker = CameraWorker()
    @ObservationIgnored private var wantsCamera = false
    @ObservationIgnored private var generation = 0
    var session: AVCaptureSession { worker.session }

    init() {
        worker.onLightSupport = { [weak self] supported, generation in
            Task { @MainActor in
                guard let self, self.wantsCamera, self.generation == generation else { return }
                self.supportsLight = supported
            }
        }
        worker.onStatus = { [weak self] status, generation in
            Task { @MainActor in
                guard let self, self.wantsCamera, self.generation == generation else { return }
                self.status = status
                if status != .running { self.isLightOn = false }
            }
        }
    }

    func start() async {
        guard !wantsCamera else { return }
        wantsCamera = true
        generation += 1
        let requestGeneration = generation
        status = .requesting
        let authorization = AVCaptureDevice.authorizationStatus(for: .video)
        let allowed: Bool
        if authorization == .notDetermined { allowed = await AVCaptureDevice.requestAccess(for: .video) }
        else { allowed = authorization == .authorized }
        guard wantsCamera, requestGeneration == generation else { return }
        guard allowed else { status = .denied; wantsCamera = false; return }
        worker.start(generation: generation)
    }

    func capturePhoto() async throws -> Data {
        guard wantsCamera, status == .running else { throw CameraCaptureError.notReady }
        let captureGeneration = generation
        let data: Data = try await withCheckedThrowingContinuation { continuation in
            worker.capturePhoto() { continuation.resume(with: $0) }
        }
        try Task.checkCancellation()
        guard wantsCamera, generation == captureGeneration else { throw CancellationError() }
        return data
    }

    func toggleLight() async {
        guard wantsCamera, status == .running, supportsLight, !isChangingLight else { return }
        let requestGeneration = generation
        let enabled = !isLightOn
        isChangingLight = true
        lightError = nil
        let result: Result<Bool, Error> = await withCheckedContinuation { continuation in
            worker.setLight(enabled) { continuation.resume(returning: $0) }
        }
        guard generation == requestGeneration else { return }
        isChangingLight = false
        switch result {
        case .success(let enabled): isLightOn = enabled
        case .failure: lightError = "The camera light is unavailable. Please try again."
        }
    }

    func stop() {
        wantsCamera = false
        isLightOn = false
        isChangingLight = false
        supportsLight = false
        lightError = nil
        generation += 1
        worker.stop()
        if status == .running || status == .requesting { status = .idle }
    }

    func retry() async { stop(); await start() }
}

/// All session changes and capture completion bookkeeping run on controlQueue.
/// The live camera only previews; text recognition starts after a still photo is captured.
private final class CameraWorker: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    var onLightSupport: ((Bool, Int) -> Void)?
    private var device: AVCaptureDevice?
    var onStatus: ((CameraStatus, Int) -> Void)?
    private let controlQueue = DispatchQueue(label: "SwipeTranslate.camera.control")
    private let photoOutput = AVCapturePhotoOutput()
    private var configured = false
    private var activeGeneration = 0
    private var captureID: Int64?
    private var captureResult: Result<Data, Error>?
    private var completion: ((Result<Data, Error>) -> Void)?
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        observers.append(NotificationCenter.default.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil) { [weak self] _ in
            self?.report(.interrupted("The camera is temporarily in use or unavailable. Tap Retry when you’re ready."))
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil) { [weak self] _ in
            self?.report(.failed("The camera stopped unexpectedly. Tap Retry to restart it."))
        })
    }

    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }

    private func report(_ status: CameraStatus) {
        controlQueue.async { [weak self] in
            guard let self else { return }
            try? self.applyLight(false)
            self.finishCapture(.failure(CameraCaptureError.notReady))
            self.onStatus?(status, self.activeGeneration)
        }
    }

    func start(generation: Int) {
        controlQueue.async { [weak self] in
            guard let self else { return }
            self.activeGeneration = generation
            do {
                if !self.configured { try self.configure() }
                if !self.session.isRunning { self.session.startRunning() }
                self.onLightSupport?(self.device?.hasTorch == true, generation)
                self.onStatus?(self.session.isRunning ? .running : .failed("The camera couldn’t start. Tap Retry."), generation)
            } catch { self.onStatus?(.unavailable, generation) }
        }
    }

    func stop() {
        controlQueue.async { [weak self] in
            guard let self else { return }
            try? self.applyLight(false)
            self.finishCapture(.failure(CancellationError()))
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func setLight(_ enabled: Bool, completion: @escaping (Result<Bool, Error>) -> Void) {
        controlQueue.async {
            do {
                guard self.session.isRunning else { throw CameraCaptureError.notReady }
                try self.applyLight(enabled)
                completion(.success(self.device?.torchMode == .on))
            } catch { completion(.failure(error)) }
        }
    }

    private func applyLight(_ enabled: Bool) throws {
        guard let device, device.hasTorch else {
            if enabled { throw CameraCaptureError.notReady }
            return
        }
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        if enabled {
            guard device.isTorchAvailable, device.isTorchModeSupported(.on) else {
                throw CameraCaptureError.notReady
            }
            try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
        } else if device.isTorchModeSupported(.off) {
            device.torchMode = .off
        }
    }

    func capturePhoto(completion: @escaping (Result<Data, Error>) -> Void) {
        controlQueue.async {
            guard self.configured, self.session.isRunning, self.captureID == nil,
                  let connection = self.photoOutput.connection(with: .video), connection.isActive else {
                completion(.failure(CameraCaptureError.notReady)); return
            }
            if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
            let settings = AVCapturePhotoSettings()
            self.captureID = settings.uniqueID
            self.captureResult = nil
            self.completion = completion
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func configure() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraCaptureError.notReady
        }
        let input = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if session.canSetSessionPreset(.photo) { session.sessionPreset = .photo }
        guard session.canAddInput(input) else { throw CameraCaptureError.notReady }
        session.addInput(input)
        guard session.canAddOutput(photoOutput) else {
            session.removeInput(input)
            throw CameraCaptureError.notReady
        }
        session.addOutput(photoOutput)
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
        } catch { /* Default focus and exposure remain usable. */ }
        self.device = device
        configured = true
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let result: Result<Data, Error>
        if let error { result = .failure(error) }
        else if let data = photo.fileDataRepresentation() { result = .success(data) }
        else { result = .failure(CameraCaptureError.missingPhoto) }
        let id = photo.resolvedSettings.uniqueID
        controlQueue.async {
            guard self.captureID == id else { return }
            self.captureResult = result
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        let id = resolvedSettings.uniqueID
        controlQueue.async {
            guard self.captureID == id else { return }
            let result = error.map { Result<Data, Error>.failure($0) }
                ?? self.captureResult ?? .failure(CameraCaptureError.missingPhoto)
            self.finishCapture(result)
        }
    }

    private func finishCapture(_ result: Result<Data, Error>) {
        let callback = completion
        completion = nil
        captureResult = nil
        captureID = nil
        callback?(result)
    }
}
