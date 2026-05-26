import Foundation
import UIKit

enum ImageStoreError: LocalizedError {
    case directoryCreationFailed
    case writeFailed
    case imageNotFound

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed:
            return "画像フォルダの作成に失敗しました。"
        case .writeFailed:
            return "画像の保存に失敗しました。"
        case .imageNotFound:
            return "端末上の画像ファイルが見つかりません。"
        }
    }
}

final class ImageStore {
    private let fileManager = FileManager.default

    enum MediaDirectory {
        case originals
        case thumbnails
        case cache
    }

    private static let originalsRelativePrefix = "images/"
    private static let thumbnailsRelativePrefix = "thumbnails/"
    private static let cacheRelativePrefix = "cache/"

    private var nodeStorageDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Node", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var imagesDirectory: URL {
        let dir = nodeStorageDirectory.appendingPathComponent("images", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var thumbnailsDirectory: URL {
        let dir = nodeStorageDirectory.appendingPathComponent("thumbnails", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var cacheDirectory: URL {
        let dir = nodeStorageDirectory.appendingPathComponent("cache", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func storedRelativePath(for directory: MediaDirectory, observationId: UUID) -> String {
        let filename = "\(observationId.uuidString).jpg"
        switch directory {
        case .originals:
            return Self.originalsRelativePrefix + filename
        case .thumbnails:
            return Self.thumbnailsRelativePrefix + filename
        case .cache:
            return Self.cacheRelativePrefix + filename
        }
    }

    /// DB に保存されたパス（相対・旧絶対どちらも）から、現在のサンドボックス上の実ファイルパスを解決する。
    func resolveStoredPath(_ storedPath: String) -> String? {
        guard !storedPath.isEmpty else { return nil }

        if fileManager.fileExists(atPath: storedPath) {
            return storedPath
        }

        if !storedPath.hasPrefix("/") {
            let relativeURL = nodeStorageDirectory.appendingPathComponent(storedPath)
            if fileManager.fileExists(atPath: relativeURL.path) {
                return relativeURL.path
            }
        }

        let filename = URL(fileURLWithPath: storedPath).lastPathComponent
        guard !filename.isEmpty else { return nil }

        for directory in [imagesDirectory, thumbnailsDirectory, cacheDirectory] {
            let candidate = directory.appendingPathComponent(filename).path
            if fileManager.fileExists(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }

    /// 旧絶対パスを `images/<uuid>.jpg` 形式の相対パスへ変換する。ファイルが見つからない場合は nil。
    func normalizeStoredPath(_ storedPath: String) -> String? {
        guard !storedPath.isEmpty else { return nil }
        if !storedPath.hasPrefix("/") {
            return storedPath
        }
        guard let resolved = resolveStoredPath(storedPath) else { return nil }

        let filename = URL(fileURLWithPath: resolved).lastPathComponent
        if resolved.hasPrefix(imagesDirectory.path) {
            return Self.originalsRelativePrefix + filename
        }
        if resolved.hasPrefix(thumbnailsDirectory.path) {
            return Self.thumbnailsRelativePrefix + filename
        }
        if resolved.hasPrefix(cacheDirectory.path) {
            return Self.cacheRelativePrefix + filename
        }
        return nil
    }

    func saveOriginal(_ image: UIImage, observationId: UUID, quality: CGFloat = 0.92) throws -> String {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw ImageStoreError.writeFailed
        }
        let url = imagesDirectory.appendingPathComponent("\(observationId.uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return storedRelativePath(for: .originals, observationId: observationId)
    }

    func generateThumbnail(from image: UIImage, observationId: UUID, maxDimension: CGFloat = 400) throws -> String {
        let thumbnail = image.resized(maxDimension: maxDimension)
        guard let data = thumbnail.jpegData(compressionQuality: 0.75) else {
            throw ImageStoreError.writeFailed
        }
        let url = thumbnailsDirectory.appendingPathComponent("\(observationId.uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return storedRelativePath(for: .thumbnails, observationId: observationId)
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
        guard let resolvedPath = resolveStoredPath(path) else {
            throw ImageStoreError.imageNotFound
        }
        guard let data = fileManager.contents(atPath: resolvedPath) else {
            throw ImageStoreError.imageNotFound
        }
        return data
    }

    struct UploadPayload {
        let data: Data
        let contentType: String
    }

    func resolveUploadPath(localImagePath: String, thumbnailPath: String) -> String? {
        resolveStoredPath(localImagePath) ?? resolveStoredPath(thumbnailPath)
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
        guard let resolvedPath = resolveStoredPath(path) else { return nil }
        return UIImage(contentsOfFile: resolvedPath)
    }

    func fileExists(at path: String) -> Bool {
        resolveStoredPath(path) != nil
    }

    func cachePath(for observationId: UUID) -> String {
        storedRelativePath(for: .cache, observationId: observationId)
    }

    func saveCachedOriginal(_ data: Data, observationId: UUID) throws -> String {
        let url = cacheDirectory.appendingPathComponent("\(observationId.uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return storedRelativePath(for: .cache, observationId: observationId)
    }

    func deleteCachedOriginal(for observationId: UUID) {
        deleteImage(at: cachePath(for: observationId))
    }

    func deleteImage(at path: String) {
        guard !path.isEmpty else { return }
        guard let resolvedPath = resolveStoredPath(path) else { return }
        try? fileManager.removeItem(atPath: resolvedPath)
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
        if let resolvedPath = resolveStoredPath(path) {
            return URL(fileURLWithPath: resolvedPath)
        }
        return URL(fileURLWithPath: path)
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
