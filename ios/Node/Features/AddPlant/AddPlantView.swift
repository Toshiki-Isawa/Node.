import SwiftUI
import UIKit

struct AddPlantView: View {
    @ObservedObject var viewModel: AddPlantViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var initialImage: UIImage?
    @State private var initialImageFromLibrary = false
    @State private var showCamera = false

    var body: some View {
        ScrollView {
            VStack(spacing: NodeSpacing.sp4) {
                topBar
                firstObservationSlot

                if initialImage != nil, initialImageFromLibrary {
                    NodeRecordDateSection(
                        date: $viewModel.initialObservationAt,
                        range: viewModel.initialObservationAtRange,
                        label: "観測日時"
                    )
                    .padding(.horizontal, NodeSpacing.sp4)
                }

                formFields
            }
            .padding(.bottom, 140)
        }
        .background(NodeColor.graphite)
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureSheet { image, creationDate in
                initialImage = image
                if creationDate != nil {
                    initialImageFromLibrary = true
                    viewModel.applyLibraryPhotoDate(creationDate)
                } else {
                    initialImageFromLibrary = false
                    viewModel.initialObservationAt = .now
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(NodeColor.fog)
            }
            Spacer()
            Text("新規登録")
                .font(NodeFont.text(NodeFont.title3, weight: .medium))
                .foregroundStyle(NodeColor.bone)
            Spacer()
            Button("保存") { savePlant() }
                .font(NodeFont.text(NodeFont.body, weight: .medium))
                .foregroundStyle(viewModel.canSave ? NodeColor.moss : NodeColor.fossil)
                .disabled(!viewModel.canSave)
        }
        .padding(.horizontal, NodeSpacing.sp4)
        .padding(.top, 62)
    }

    private var firstObservationSlot: some View {
        Button { showCamera = true } label: {
            GeometryReader { geo in
                ZStack {
                    if let initialImage {
                        Image(uiImage: initialImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: NodeRadius.lg)
                            .fill(NodeColor.charcoal)
                            .overlay(
                                RoundedRectangle(cornerRadius: NodeRadius.lg)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                                    .foregroundStyle(NodeColor.stone)
                            )
                        VStack(spacing: NodeSpacing.sp3) {
                            Image(systemName: "camera")
                                .font(.system(size: 24, weight: .regular))
                                .foregroundStyle(NodeColor.bone)
                                .frame(width: 56, height: 56)
                                .background(Circle().fill(NodeColor.bark))
                                .overlay(Circle().stroke(NodeColor.hairline, lineWidth: 1))
                            VStack(spacing: 6) {
                                Text("最初の観測")
                                    .font(NodeFont.text(NodeFont.callout, weight: .medium))
                                    .foregroundStyle(NodeColor.bone)
                                MetaLabel(text: "タップして撮影 · 任意", color: NodeColor.fog, size: 9)
                            }
                        }
                    }
                }
            }
            .aspectRatio(4 / 5, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: NodeRadius.lg))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, NodeSpacing.sp4)
    }

    private var formFields: some View {
        VStack(spacing: NodeSpacing.sp4) {
            NodeTextField(label: "植物名", isRequired: true, text: $viewModel.name, placeholder: "例: アガベ チタノタ")

            NodeTextField(label: "学名 · クローン", hint: "任意", text: $viewModel.species, placeholder: "例: Agave titanota 'FO-076'")

            VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
                MetaLabel(text: "カテゴリ", size: 9)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: NodeSpacing.sp2) {
                        ForEach(PlantCategory.allCases) { cat in
                            NodeChip(title: cat.rawValue, isSelected: viewModel.category == cat.rawValue) {
                                viewModel.category = cat.rawValue
                            }
                        }
                    }
                }
            }

            WateringIntervalSection(
                intervalDays: $viewModel.wateringIntervalDays,
                footerHint: "コレクションで水やり優先順に並びます"
            )

            acquiredAtSection

            NodeTextField(label: "メモ", hint: "任意", text: $viewModel.note, placeholder: "—")

            bottomSaveButton
        }
        .padding(.horizontal, NodeSpacing.sp4)
    }

    private var acquiredAtSection: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
            HStack {
                MetaLabel(text: "育成開始日", size: 9)
                Spacer()
                MetaLabel(text: "任意", color: NodeColor.fog, size: 9)
            }
            HStack(spacing: NodeSpacing.sp3) {
                DatePicker(
                    "",
                    selection: $viewModel.acquiredAt,
                    in: viewModel.acquiredAtRange,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(NodeColor.moss)
                .colorScheme(.dark)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, NodeSpacing.sp3)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: NodeRadius.lg)
                    .fill(NodeColor.bark)
                    .overlay(RoundedRectangle(cornerRadius: NodeRadius.lg).stroke(NodeColor.hairline, lineWidth: 1))
            )
            MetaLabel(text: "日数カウントの起点 · 未変更時は今日", color: NodeColor.fog, size: 9)
        }
    }

    private var bottomSaveButton: some View {
        NodePrimaryButton("コレクションに追加") {
            savePlant()
        }
        .disabled(!viewModel.canSave)
        .opacity(viewModel.canSave ? 1 : 0.45)
        .padding(.top, NodeSpacing.sp3)
    }

    private func savePlant() {
        do {
            _ = try viewModel.save(
                initialImage: initialImage,
                useCustomObservationDate: initialImageFromLibrary
            )
            dismiss()
        } catch {
            // silent — local save should rarely fail
        }
    }
}

/// Minimal camera sheet for first observation during plant registration.
private struct CameraCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage, Date?) -> Void
    @StateObject private var camera = CameraService()
    @State private var showPhotoLibrary = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if CameraService.usesPhotoLibraryFallback {
                VStack(spacing: NodeSpacing.sp3) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(NodeColor.fog)
                    MetaLabel(text: "シミュレータでは写真を選択", color: NodeColor.fog)
                }
            } else if camera.isAuthorized {
                AVCameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            }
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(NodeColor.bone)
                            .padding()
                    }
                    Spacer()
                }
                Spacer()
                HStack(spacing: NodeSpacing.sp6) {
                    toolButton("photo.on.rectangle.angled") {
                        showPhotoLibrary = true
                    }
                    shutterButton
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.bottom, 40)
            }
        }
        .task {
            guard !CameraService.usesPhotoLibraryFallback else { return }
            if await camera.requestAuthorization() {
                try? camera.configure()
                await camera.start()
            }
        }
        .onDisappear { camera.stop() }
        .sheet(isPresented: $showPhotoLibrary) {
            PhotoLibraryPicker { picked in
                onCapture(picked.image, picked.creationDate)
                dismiss()
            }
        }
    }

    private var shutterButton: some View {
        Button {
            if CameraService.usesPhotoLibraryFallback {
                showPhotoLibrary = true
            } else {
                Task { await captureFromCamera() }
            }
        } label: {
            Circle()
                .stroke(NodeColor.bone, lineWidth: 3)
                .frame(width: 72, height: 72)
                .overlay(
                    Group {
                        if CameraService.usesPhotoLibraryFallback {
                            Image(systemName: "photo")
                                .foregroundStyle(NodeColor.graphite)
                        } else {
                            Circle().fill(NodeColor.bone).frame(width: 60, height: 60)
                        }
                    }
                )
        }
        .disabled(!CameraService.usesPhotoLibraryFallback && !camera.isCaptureReady)
        .opacity(!CameraService.usesPhotoLibraryFallback && !camera.isCaptureReady ? 0.5 : 1)
    }

    private func toolButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(NodeColor.bone)
                .frame(width: 44, height: 44)
        }
    }

    private func captureFromCamera() async {
        guard camera.isCaptureReady else { return }
        guard let image = try? await camera.capturePhoto() else { return }
        onCapture(image, nil)
        dismiss()
    }
}
