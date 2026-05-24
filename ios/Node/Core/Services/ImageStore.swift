import Foundation
import UIKit

enum ImageStoreError: Error {
    case directoryCreationFailed
    case writeFailed
    case imageNotFound
}

final class ImageStore {
    private let fileManager = FileManager.default

    private var imagesDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Node/images", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var thumbnailsDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Node/thumbnails", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func saveOriginal(_ image: UIImage, observationId: UUID, quality: CGFloat = 0.92) throws -> String {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw ImageStoreError.writeFailed
        }
        let url = imagesDirectory.appendingPathComponent("\(observationId.uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url.path
    }

    func generateThumbnail(from image: UIImage, observationId: UUID, maxDimension: CGFloat = 400) throws -> String {
        let thumbnail = image.resized(maxDimension: maxDimension)
        guard let data = thumbnail.jpegData(compressionQuality: 0.75) else {
            throw ImageStoreError.writeFailed
        }
        let url = thumbnailsDirectory.appendingPathComponent("\(observationId.uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url.path
    }

    func compressedData(for path: String, quality: CGFloat = 0.72) throws -> Data {
        guard let image = loadImage(path: path) else {
            throw ImageStoreError.imageNotFound
        }
        let resized = image.resized(maxDimension: 2048)
        guard let data = resized.jpegData(compressionQuality: quality) else {
            throw ImageStoreError.writeFailed
        }
        return data
    }

    func loadImage(path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }

    func url(for path: String) -> URL {
        URL(fileURLWithPath: path)
    }
}

private extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
