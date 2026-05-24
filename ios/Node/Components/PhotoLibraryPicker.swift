import PhotosUI
import SwiftUI
import UIKit

/// シミュレータなど AVFoundation カメラが使えない環境向けのフォールバック。
struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
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
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                parent.dismiss()
                return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                Task { @MainActor in
                    if let image = object as? UIImage {
                        self.parent.onImage(image)
                    }
                    self.parent.dismiss()
                }
            }
        }
    }
}
