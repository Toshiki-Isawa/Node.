import Foundation
import UIKit

enum ImageStoreError: Error {
    case directoryCreationFailed
    case writeFailed
    case imageNotFound
}

final class ImageStore {
    private let fileManager = FileManager.default

    enum MediaDirectory {
        case originals
        case thumbnails
        case cache
    }

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

    private var cacheDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Node/cache", isDirectory: true)
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

    func originalData(for path: String) throws -> Data {
        guard fileManager.fileExists(atPath: path) else {
            throw ImageStoreError.imageNotFound
        }
        guard let data = fileManager.contents(atPath: path) else {
            throw ImageStoreError.imageNotFound
        }
        return data
    }

    struct UploadPayload {
        let data: Data
        let contentType: String
    }

    func uploadPayload(for path: String, premium: Bool) throws -> UploadPayload {
        if premium {
            let data = try originalData(for: path)
            return UploadPayload(data: data, contentType: contentType(for: path))
        }
        let data = try compressedData(for: path)
        return UploadPayload(data: data, contentType: "image/jpeg")
    }

    private func contentType(for path: String) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "png": return "image/png"
        case "heic", "heif": return "image/heic"
        default: return "image/jpeg"
        }
    }

    func loadImage(path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }

    func fileExists(at path: String) -> Bool {
        !path.isEmpty && fileManager.fileExists(atPath: path)
    }

    func cachePath(for observationId: UUID) -> String {
        cacheDirectory.appendingPathComponent("\(observationId.uuidString).jpg").path
    }

    func saveCachedOriginal(_ data: Data, observationId: UUID) throws -> String {
        let url = cacheDirectory.appendingPathComponent("\(observationId.uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url.path
    }

    func deleteCachedOriginal(for observationId: UUID) {
        deleteImage(at: cachePath(for: observationId))
    }

    func deleteImage(at path: String) {
        guard !path.isEmpty else { return }
        try? fileManager.removeItem(atPath: path)
    }

    func deleteOriginal(at path: String) {
        deleteImage(at: path)
    }

    func deleteObservationFiles(_ observation: PlantObservation) {
        deleteImage(at: observation.localImagePath)
        deleteImage(at: observation.thumbnailPath)
        deleteCachedOriginal(for: observation.id)
    }

    func url(for path: String) -> URL {
        URL(fileURLWithPath: path)
    }

    func directoryByteSize(for directory: MediaDirectory) -> Int64 {
        let url: URL
        switch directory {
        case .originals: url = imagesDirectory
        case .thumbnails: url = thumbnailsDirectory
        case .cache: url = cacheDirectory
        }
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        return contents.reduce(Int64(0)) { total, fileURL in
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            return total + size
        }
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
