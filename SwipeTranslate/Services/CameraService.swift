import AVFoundation
import CoreImage
import Observation

struct CameraFrame {
    let image: CGImage
    let page: OCRPage
    var size: CGSize { CGSize(width: CGFloat(image.width), height: CGFloat(image.height)) }
}

enum CameraStatus: Equatable {
    case idle, requesting, running, denied, unavailable
    case interrupted(String), failed(String)
}

@MainActor @Observable
final class CameraService {
    var status: CameraStatus = .idle
    var latestFrame: CameraFrame?
    var ocrWarning: String?
    @ObservationIgnored private let worker = CameraWorker()
    @ObservationIgnored private var wantsCamera = false
    @ObservationIgnored private var generation = 0
    var session: AVCaptureSession { worker.session }

    init() {
        worker.onFrame = { [weak self] frame, generation in
            Task { @MainActor in
                guard let self, self.wantsCamera, self.generation == generation else { return }
                self.latestFrame = frame
                self.ocrWarning = nil
            }
        }
        worker.onStatus = { [weak self] status, generation in
            Task { @MainActor in
                guard let self, self.wantsCamera, self.generation == generation else { return }
                self.status = status
            }
        }
        worker.onOCRFailure = { [weak self] generation in
            Task { @MainActor in
                guard let self, self.wantsCamera, self.generation == generation else { return }
                self.ocrWarning = "Text couldn’t be read. Hold the page steady in brighter light."
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

    func stop() {
        wantsCamera = false
        generation += 1
        worker.stop()
        if status == .running || status == .requesting { status = .idle }
    }

    func retry() async { stop(); latestFrame = nil; await start() }
}

/// Session mutations run on controlQueue; Vision and CIContext run on frameQueue.
/// Callbacks cross to the main actor in CameraService. No camera work blocks SwiftUI.
private final class CameraWorker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    var onFrame: ((CameraFrame, Int) -> Void)?
    var onStatus: ((CameraStatus, Int) -> Void)?
    var onOCRFailure: ((Int) -> Void)?
    private let controlQueue = DispatchQueue(label: "SwipeTranslate.camera.control")
    private let frameQueue = DispatchQueue(label: "SwipeTranslate.camera.frames", qos: .userInitiated)
    private let imageContext = CIContext(options: [.cacheIntermediates: false])
    private var configured = false // controlQueue only
    private var activeGeneration = 0 // controlQueue only
    private var frameGeneration = 0 // frameQueue only
    private var acceptingFrames = false // frameQueue only
    private var lastScan = -Double.infinity // frameQueue only
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        observers.append(NotificationCenter.default.addObserver(forName: .AVCaptureSessionWasInterrupted, object: session, queue: nil) { [weak self] _ in
            self?.report(.interrupted("The camera is temporarily in use or unavailable. Tap Retry when you’re ready."))
        })
        observers.append(NotificationCenter.default.addObserver(forName: .AVCaptureSessionRuntimeError, object: session, queue: nil) { [weak self] _ in
            self?.report(.failed("The camera stopped unexpectedly. Tap Retry to restart it."))
        })
    }

    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }

    private func report(_ status: CameraStatus) {
        controlQueue.async { [weak self] in
            guard let self else { return }
            self.onStatus?(status, self.activeGeneration)
        }
    }

    func start(generation: Int) {
        controlQueue.async { [weak self] in
            guard let self else { return }
            self.activeGeneration = generation
            do {
                if !self.configured { try self.configure() }
                self.frameQueue.async {
                    self.frameGeneration = generation
                    self.lastScan = -Double.infinity
                    self.acceptingFrames = true
                }
                if !self.session.isRunning { self.session.startRunning() }
                self.onStatus?(self.session.isRunning ? .running : .failed("The camera couldn’t start. Tap Retry."), generation)
            } catch {
                self.onStatus?(.unavailable, generation)
            }
        }
    }

    func stop() {
        controlQueue.async { [weak self] in
            guard let self else { return }
            self.frameQueue.async { self.acceptingFrames = false }
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func configure() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraSetupError.noCamera
        }
        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: frameQueue)

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = session.canSetSessionPreset(.hd1920x1080) ? .hd1920x1080 : .high
        guard session.canAddInput(input) else { throw CameraSetupError.noCamera }
        session.addInput(input)
        guard session.canAddOutput(output) else { session.removeInput(input); throw CameraSetupError.noCamera }
        session.addOutput(output)
        guard let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) else {
            session.removeOutput(output); session.removeInput(input)
            throw CameraSetupError.noCamera
        }
        // The app is portrait-only. Physically rotate pixel buffers so Vision, frozen
        // CGImages, and the portrait preview all share the same upright coordinate space.
        connection.videoRotationAngle = 90
        if connection.isVideoMirroringSupported { connection.isVideoMirrored = false }
        if connection.isVideoStabilizationSupported { connection.preferredVideoStabilizationMode = .off }
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            device.unlockForConfiguration()
        } catch { /* Default focus/exposure still allow reading when configuration is busy. */ }
        configured = true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard acceptingFrames else { return }
        let timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        guard timestamp - lastScan >= 0.85 else { return }
        lastScan = timestamp
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        autoreleasepool {
            let ciImage = CIImage(cvPixelBuffer: buffer)
            guard let image = imageContext.createCGImage(ciImage, from: ciImage.extent) else { return }
            do {
                let page = try OCRService.recognize(image)
                onFrame?(CameraFrame(image: image, page: page), frameGeneration)
            } catch { onOCRFailure?(frameGeneration) }
        }
    }

    private enum CameraSetupError: Error { case noCamera }
}
