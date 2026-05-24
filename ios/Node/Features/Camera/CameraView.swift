import SwiftUI

struct CameraView: View {
    @ObservedObject var viewModel: CameraViewModel
    @ObservedObject var cameraService: CameraService
    let imageStore: ImageStore
    var onClose: () -> Void

    @State private var showPhotoLibrary = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if CameraService.usesPhotoLibraryFallback {
                simulatorPlaceholder
            } else if cameraService.isAuthorized {
                AVCameraPreviewView(session: cameraService.session)
                    .ignoresSafeArea()
            }

            if cameraService.showOnionSkin,
               let path = viewModel.previousObservationImagePath,
               let image = imageStore.loadImage(path: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.28)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }

            framingOverlay

            if viewModel.showFlash {
                NodeColor.bone.opacity(0.06)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack {
                topChrome
                Spacer()
                bottomChrome
            }
        }
        .task {
            guard !CameraService.usesPhotoLibraryFallback else { return }
            if await cameraService.requestAuthorization() {
                try? cameraService.configure()
                await cameraService.start()
            }
        }
        .onDisappear { cameraService.stop() }
        .sheet(isPresented: $showPhotoLibrary) {
            PhotoLibraryPicker { image in
                Task { await viewModel.saveObservation(image: image) }
            }
        }
    }

    private var framingOverlay: some View {
        GeometryReader { geo in
            let insetX = geo.size.width * 0.10
            let insetTop = geo.size.height * 0.14
            let insetBottom = geo.size.height * 0.22
            let frame = CGRect(
                x: insetX,
                y: insetTop,
                width: geo.size.width - insetX * 2,
                height: geo.size.height - insetTop - insetBottom
            )

            ZStack {
                if cameraService.showGrid {
                    GridOverlay(frame: frame)
                }
                ReticleOverlay(frame: frame)
                LevelIndicator(roll: cameraService.rollDegrees)
                    .position(x: geo.size.width / 2, y: insetTop - 28)
            }
        }
        .allowsHitTesting(false)
    }

    private var topChrome: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(NodeColor.bone)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            Spacer()

            if let plant = viewModel.selectedPlant {
                HStack(spacing: 8) {
                    SyncDot(state: plant.aggregateSyncStatus, size: 5)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(plant.name)
                            .font(NodeFont.text(12, weight: .medium))
                            .foregroundStyle(NodeColor.bone)
                        MetaLabel(text: "\(plant.dayCount)日目", size: 9)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, NodeSpacing.sp4)
        .padding(.top, 62)
    }

    private var bottomChrome: some View {
        VStack(spacing: NodeSpacing.sp4) {
            if !viewModel.plants.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: NodeSpacing.sp2) {
                        ForEach(viewModel.plants, id: \.id) { plant in
                            Button {
                                viewModel.selectedPlant = plant
                            } label: {
                                Text(plant.name)
                                    .font(NodeFont.text(12, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(viewModel.selectedPlant?.id == plant.id ? NodeColor.graphite : NodeColor.bone)
                                    .background(
                                        Capsule().fill(viewModel.selectedPlant?.id == plant.id ? NodeColor.moss : NodeColor.charcoal.opacity(0.8))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, NodeSpacing.sp4)
                }
            }

            HStack(spacing: NodeSpacing.sp8) {
                toolButton("square.grid.3x3") { cameraService.showGrid.toggle() }
                shutterButton
                toolButton("arrow.triangle.2.circlepath.camera") {
                    try? cameraService.flipCamera()
                }
            }
            .padding(.bottom, 40)
        }
    }

    private func toolButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(NodeColor.bone)
                .frame(width: 44, height: 44)
        }
    }

    private var simulatorPlaceholder: some View {
        VStack(spacing: NodeSpacing.sp4) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(NodeColor.fog)
            MetaLabel(text: "シミュレータ · 写真ライブラリ", color: NodeColor.fog)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var shutterButton: some View {
        Button {
            if CameraService.usesPhotoLibraryFallback {
                showPhotoLibrary = true
            } else {
                Task { await capture() }
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(NodeColor.bone.opacity(0.85), lineWidth: 3)
                    .frame(width: 76, height: 76)
                Circle()
                    .fill(NodeColor.bone)
                    .frame(width: 62, height: 62)
                if CameraService.usesPhotoLibraryFallback {
                    Image(systemName: "photo")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(NodeColor.graphite)
                }
            }
        }
        .buttonStyle(NodePressStyle())
        .disabled(!CameraService.usesPhotoLibraryFallback && !cameraService.isCaptureReady)
        .opacity(!CameraService.usesPhotoLibraryFallback && !cameraService.isCaptureReady ? 0.5 : 1)
    }

    private func capture() async {
        guard cameraService.isCaptureReady else { return }
        guard let image = try? await cameraService.capturePhoto() else { return }
        await viewModel.saveObservation(image: image)
    }
}

private struct GridOverlay: View {
    let frame: CGRect

    var body: some View {
        ZStack {
            Path { path in
                let thirdW = frame.width / 3
                let thirdH = frame.height / 3
                path.move(to: CGPoint(x: frame.minX + thirdW, y: frame.minY))
                path.addLine(to: CGPoint(x: frame.minX + thirdW, y: frame.maxY))
                path.move(to: CGPoint(x: frame.minX + thirdW * 2, y: frame.minY))
                path.addLine(to: CGPoint(x: frame.minX + thirdW * 2, y: frame.maxY))
                path.move(to: CGPoint(x: frame.minX, y: frame.minY + thirdH))
                path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY + thirdH))
                path.move(to: CGPoint(x: frame.minX, y: frame.minY + thirdH * 2))
                path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY + thirdH * 2))
            }
            .stroke(Color.white.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct ReticleOverlay: View {
    let frame: CGRect
    private let bracketSize: CGFloat = 22

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                bracket(at: index)
            }
            Circle()
                .stroke(NodeColor.moss, lineWidth: 1)
                .frame(width: 5, height: 5)
                .position(x: frame.midX, y: frame.midY)
        }
    }

    @ViewBuilder
    private func bracket(at index: Int) -> some View {
        let isLeft = index % 2 == 0
        let isTop = index < 2
        Path { path in
            let x = isLeft ? frame.minX : frame.maxX
            let y = isTop ? frame.minY : frame.maxY
            if isLeft && isTop {
                path.move(to: CGPoint(x: x, y: y + bracketSize))
                path.addLine(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + bracketSize, y: y))
            } else if !isLeft && isTop {
                path.move(to: CGPoint(x: x - bracketSize, y: y))
                path.addLine(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x, y: y + bracketSize))
            } else if isLeft && !isTop {
                path.move(to: CGPoint(x: x, y: y - bracketSize))
                path.addLine(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + bracketSize, y: y))
            } else {
                path.move(to: CGPoint(x: x - bracketSize, y: y))
                path.addLine(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x, y: y - bracketSize))
            }
        }
        .stroke(NodeColor.bone.opacity(0.85), lineWidth: 1)
    }
}

private struct LevelIndicator: View {
    let roll: Double

    var body: some View {
        VStack(spacing: 6) {
            MetaLabel(text: String(format: "%.0f°", roll), color: NodeColor.moss, size: 9)
            HStack(spacing: 10) {
                Rectangle().fill(Color.white.opacity(0.35)).frame(width: 90, height: 1)
                Rectangle()
                    .fill(NodeColor.moss)
                    .frame(width: 30, height: 1)
                    .rotationEffect(.degrees(roll))
                    .shadow(color: NodeColor.moss.opacity(0.6), radius: 2)
                Rectangle().fill(Color.white.opacity(0.35)).frame(width: 90, height: 1)
            }
        }
    }
}
