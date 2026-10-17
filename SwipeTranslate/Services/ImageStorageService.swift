import UIKit

struct ImageStorageService {
    private var directory: URL {
        URL.applicationSupportDirectory.appending(path: "Covers", directoryHint: .isDirectory)
    }

    func save(_ image: UIImage) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".jpg"
        guard let data = image.normalized(maxDimension: 1600).jpegData(compressionQuality: 0.85) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: directory.appending(path: name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return name
    }

    func load(_ name: String?) -> UIImage? {
        guard let name, name == URL(fileURLWithPath: name).lastPathComponent else { return nil }
        return UIImage(contentsOfFile: directory.appending(path: name).path)
    }

    func remove(_ name: String) throws {
        guard name == URL(fileURLWithPath: name).lastPathComponent else { return }
        try FileManager.default.removeItem(at: directory.appending(path: name))
    }
}

extension UIImage {
    /// Redrawing applies EXIF orientation before Vision sees the pixels.
    func normalized(maxDimension: CGFloat = 2400) -> UIImage {
        let factor = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * factor, height: size.height * factor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
