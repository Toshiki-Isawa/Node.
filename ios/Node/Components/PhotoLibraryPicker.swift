import Photos
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PickedPhoto {
    let image: UIImage
    let creationDate: Date?
}

/// 写真ライブラリから画像を1枚選択する。
struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onPick: (PickedPhoto) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker

        init(parent: PhotoLibraryPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                parent.dismiss()
                return
            }

            let creationDate = Self.creationDate(for: result)

            loadImage(from: result.itemProvider) { image in
                Task { @MainActor in
                    if let image {
                        self.parent.onPick(PickedPhoto(image: image, creationDate: creationDate))
                    }
                    self.parent.dismiss()
                }
            }
        }

        private static func creationDate(for result: PHPickerResult) -> Date? {
            guard let assetId = result.assetIdentifier else { return nil }
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            return assets.firstObject?.creationDate
        }

        private func loadImage(from provider: NSItemProvider, completion: @escaping (UIImage?) -> Void) {
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    completion(object as? UIImage)
                }
                return
            }

            let typeIdentifiers = [
                UTType.image.identifier,
                UTType.heic.identifier,
                UTType.jpeg.identifier,
                UTType.png.identifier,
            ]

            for typeIdentifier in typeIdentifiers where provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
                provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
                    guard let data else {
                        completion(nil)
                        return
                    }
                    completion(UIImage(data: data))
                }
                return
            }

            completion(nil)
        }
    }
}
