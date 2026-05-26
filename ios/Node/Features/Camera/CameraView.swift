import SwiftUI

struct CameraView: View {
    @ObservedObject var viewModel: CameraViewModel
    @ObservedObject var cameraService: CameraService
    let imageStore: ImageStore
    var onClose: () -> Void

    @State private var showPhotoLibrary = false
    @State private var captureTask: Task<Void, Never>?
    @State private var didFinishAuthorizationRequest = false

    var body: some View {
        ZStack {
            Color.black
            cameraPreviewLayer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .overlay {
            cameraFramedOverlay
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            topChrome
        }
        .overlay(alignment: .bottom) {
            bottomChrome
        }
        .overlay {
            if viewModel.showFlash {
                NodeColor.bone.opacity(0.06)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if viewModel.isBusy {
                captureBusyOverlay
            }
        }
        .overlay {
            if showsCameraPermissionPrompt {
                cameraPermissionPrompt
            }
        }
        .task {
            guard !CameraService.usesPhotoLibraryFallback else { return }
            defer { didFinishAuthorizationRequest = true }
            if await cameraService.requestAuthorization() {
                try? cameraService.configure()
                await cameraService.start()
            }
        }
        .onAppear {
            didFinishAuthorizationRequest = CameraService.usesPhotoLibraryFallback
            viewModel.reloadPlants()
            viewModel.prepareForSession()
        }
        .onDisappear {
            cancelActiveCapture()
            cameraService.stop()
        }
        .sheet(isPresented: $showPhotoLibrary) {
            PhotoLibraryPicker { picked in
                viewModel.stageLibraryImport(image: picked.image, creationDate: picked.creationDate)
            }
        }
        .sheet(isPresented: libraryImportSheetPresented) {
            LibraryObservationImportSheet(
                viewModel: viewModel,
                onSaved: { saved in
                    if saved {
                        handleSavedCapture(true)
                    }
                }
            )
            .presentationDetents([.fraction(0.62), .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(NodeColor.charcoal)
        }
    }

    private var libraryImportSheetPresented: Binding<Bool> {
        Binding(
            get: { viewModel.pendingLibraryImage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.cancelLibraryImport()
                }
            }
        )
    }

    private var captureBusyOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: NodeSpacing.sp4) {
                ProgressView()
                    .tint(NodeColor.moss)
                    .scaleEffect(1.1)

                MetaLabel(text: viewModel.capturePhase.statusText, color: NodeColor.fog, size: 9)

                Button(action: cancelActiveCapture) {
                    Text("キャンセル")
                        .font(NodeFont.text(NodeFont.callout, weight: .medium))
                        .foregroundStyle(NodeColor.bone)
                        .padding(.horizontal, NodeSpacing.sp5)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .stroke(NodeColor.hairlineStrong, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(NodeSpacing.sp6)
            .background(
                RoundedRectangle(cornerRadius: NodeRadius.xl)
                    .fill(NodeColor.charcoal.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: NodeRadius.xl)
                            .stroke(NodeColor.hairline, lineWidth: 1)
                    )
            )
        }
    }

    private func startCaptureFlow() {
        captureTask?.cancel()
        cameraService.cancelCapture()

        captureTask = Task {
            viewModel.setCapturePhase(.capturing)

            guard !Task.isCancelled, let image = try? await cameraService.capturePhoto() else {
                viewModel.resetCaptureState()
                return
            }

            viewModel.setCapturePhase(.saving)
            let saved = await viewModel.saveObservation(image: image, preprocessForStorage: true)

            guard !Task.isCancelled else {
                viewModel.resetCaptureState()
                return
            }

            viewModel.resetCaptureState()
            handleSavedCapture(saved)
        }
    }

    private func cancelActiveCapture() {
        captureTask?.cancel()
        cameraService.cancelCapture()
        viewModel.resetCaptureState()
        captureTask = nil
    }

    private func closeCamera() {
        cancelActiveCapture()
        onClose()
    }

    private func handleSavedCapture(_ saved: Bool) {
        guard saved else { return }
        if viewModel.captureMode == .single {
            onClose()
        }
    }

    /// 撮影補助オーバーレイ用。上下 chrome と端末角を避け、プレビューは全面のまま。
    private func cameraFrame(in size: CGSize) -> CGRect {
        CameraFrameLayout.frame(in: size)
    }

    private var overlayLayoutSize: CGSize {
        let previewSize = cameraService.previewBounds
        if previewSize.width > 0, previewSize.height > 0 {
            return previewSize
        }
        return UIScreen.main.bounds.size
    }

    @ViewBuilder
    private var cameraPreviewLayer: some View {
        if CameraService.usesPhotoLibraryFallback {
            simulatorPlaceholder
        } else if cameraService.isAuthorized {
            AVCameraPreviewView(session: cameraService.session, cameraService: cameraService)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var topChrome: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
            HStack(spacing: NodeSpacing.sp2) {
                Button(action: closeCamera) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(NodeColor.bone)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Spacer()

                if !CameraService.usesPhotoLibraryFallback {
                    gridToggleButton
                }

                if let plant = viewModel.selectedPlant {
                    HStack(spacing: 8) {
                        if ReleaseConfig.cloudSyncEnabled {
                            SyncDot(state: plant.aggregateSyncStatus, size: 5)
                        }
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

            if !CameraService.usesPhotoLibraryFallback {
                LevelIndicator(roll: cameraService.rollDegrees)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            previousObservationPreview
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, NodeSpacing.sp4)
        .nodeScreenTopPadding()
    }

    @ViewBuilder
    private var previousObservationPreview: some View {
        if let path = viewModel.previousObservationImagePath {
            Button {
                cameraService.showReferenceOverlay.toggle()
            } label: {
                ObservationThumbnail(
                    imagePath: path,
                    imageStore: imageStore,
                    size: 80
                )
                .overlay(
                    RoundedRectangle(cornerRadius: NodeRadius.sm)
                        .stroke(
                            cameraService.showReferenceOverlay ? NodeColor.moss : NodeColor.hairlineStrong,
                            lineWidth: 1
                        )
                )
                .nodePhotoShadow()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                cameraService.showReferenceOverlay
                    ? "前回の観測オーバーレイをオフ"
                    : "前回の観測オーバーレイをオン"
            )
        }
    }

    private var cameraFramedOverlay: some View {
        GeometryReader { geo in
            let layoutSize = overlayLayoutSize
            let frame = cameraFrame(in: layoutSize)
            let offsetX = (geo.size.width - layoutSize.width) / 2
            let offsetY = (geo.size.height - layoutSize.height) / 2
            let alignedFrame = frame.offsetBy(dx: offsetX, dy: offsetY)

            ZStack {
                if cameraService.showReferenceOverlay,
                   let path = viewModel.previousObservationImagePath,
                   let image = imageStore.loadImage(path: path) {
                    referenceOverlay(image: image, layoutSize: layoutSize, frame: frame)
                }

                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geo.size))
                    path.addRect(alignedFrame)
                }
                .fill(Color.black.opacity(0.32), style: FillStyle(eoFill: true))

                if cameraService.showGrid {
                    GridOverlay(frame: alignedFrame)
                    SubjectZoneOverlay(frame: alignedFrame)
                }
                ReticleOverlay(frame: alignedFrame)
            }
        }
        .ignoresSafeArea()
    }

    /// 観測オーバーレイをライブプレビューと同じスケールで描画し、観測枠内だけ可視化する。
    /// プレビュー全面に `.scaledToFill` で配置することで `.resizeAspectFill` と同じ拡大率になる。
    @ViewBuilder
    private func referenceOverlay(image: UIImage, layoutSize: CGSize, frame: CGRect) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: layoutSize.width, height: layoutSize.height)
            .clipped()
            .mask {
                Rectangle()
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }
            .opacity(0.34)
            .allowsHitTesting(false)
    }

    private var showsCameraPermissionPrompt: Bool {
        !CameraService.usesPhotoLibraryFallback
            && didFinishAuthorizationRequest
            && !cameraService.isAuthorized
    }

    private var cameraPermissionPrompt: some View {
        VStack(spacing: NodeSpacing.sp4) {
            Image(systemName: "camera.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(NodeColor.fog)
            Text("カメラへのアクセスが必要です")
                .font(NodeFont.text(NodeFont.callout, weight: .medium))
                .foregroundStyle(NodeColor.bone)
            MetaLabel(
                text: "設定アプリで Node. のカメラを許可してください。",
                color: NodeColor.fog
            )
            .multilineTextAlignment(.center)
            NodeSecondaryButton("閉じる", systemImage: "xmark") {
                closeCamera()
            }
        }
        .padding(NodeSpacing.sp6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.72))
    }

    private var gridToggleButton: some View {
        Button {
            cameraService.showGrid.toggle()
        } label: {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(cameraService.showGrid ? NodeColor.moss : NodeColor.bone)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isBusy)
        .opacity(viewModel.isBusy ? 0.5 : 1)
        .accessibilityLabel(cameraService.showGrid ? "グリッドをオフ" : "グリッドをオン")
    }

    private var bottomChrome: some View {
        VStack(spacing: NodeSpacing.sp4) {
            captureModePicker

            if !viewModel.plants.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: NodeSpacing.sp2) {
                        ForEach(viewModel.plants, id: \.id) { plant in
                            Button {
                                viewModel.selectPlant(plant)
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

            HStack(spacing: NodeSpacing.sp6) {
                toolButton("photo.on.rectangle.angled") {
                    showPhotoLibrary = true
                }
                .disabled(viewModel.isBusy)
                .opacity(viewModel.isBusy ? 0.5 : 1)
                shutterButton
                if !CameraService.usesPhotoLibraryFallback {
                    toolButton("arrow.triangle.2.circlepath.camera") {
                        try? cameraService.flipCamera()
                    }
                    .disabled(viewModel.isBusy)
                    .opacity(viewModel.isBusy ? 0.5 : 1)
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }
            }
            .safeAreaPadding(.bottom, NodeSpacing.sp2)
            .padding(.bottom, NodeSpacing.sp4)
        }
    }

    private var captureModePicker: some View {
        VStack(spacing: NodeSpacing.sp2) {
            HStack(spacing: NodeSpacing.sp2) {
                ForEach(CameraCaptureMode.allCases) { mode in
                    Button {
                        viewModel.captureMode = mode
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode.systemImage)
                                .font(.system(size: 12, weight: .medium))
                            Text(mode.label)
                                .font(NodeFont.text(12, weight: .medium))
                        }
                        .padding(.horizontal, NodeSpacing.sp3)
                        .padding(.vertical, 8)
                        .foregroundStyle(viewModel.captureMode == mode ? NodeColor.graphite : NodeColor.bone)
                        .background(
                            Capsule().fill(viewModel.captureMode == mode ? NodeColor.moss : NodeColor.charcoal.opacity(0.8))
                        )
                        .overlay(
                            Capsule().stroke(
                                viewModel.captureMode == mode ? NodeColor.moss.opacity(0.5) : NodeColor.hairline,
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            MetaLabel(text: viewModel.captureModeHint, color: NodeColor.fog, size: 9)
        }
        .padding(.horizontal, NodeSpacing.sp4)
        .disabled(viewModel.isBusy)
        .opacity(viewModel.isBusy ? 0.6 : 1)
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
                startCaptureFlow()
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
        .disabled(viewModel.isBusy || (!CameraService.usesPhotoLibraryFallback && !cameraService.isCaptureReady))
        .opacity(viewModel.isBusy || (!CameraService.usesPhotoLibraryFallback && !cameraService.isCaptureReady) ? 0.5 : 1)
    }
}

private struct LibraryObservationImportSheet: View {
    @ObservedObject var viewModel: CameraViewModel
    var onSaved: (Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: NodeSpacing.sp4) {
            Capsule()
                .fill(NodeColor.stone)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
                MetaLabel(text: viewModel.selectedPlant?.name.uppercased() ?? "PLANT", size: 9)
                Text("ライブラリから観測")
                    .font(NodeFont.display(NodeFont.title3, weight: .light))
                    .foregroundStyle(NodeColor.bone)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let image = viewModel.pendingLibraryImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: NodeRadius.lg))
            }

            NodeRecordDateSection(
                date: $viewModel.observedAt,
                range: viewModel.observedAtRange,
                label: "観測日時"
            )

            if let error = viewModel.errorMessage {
                MetaLabel(text: error, color: NodeColor.syncFail)
            }

            Spacer(minLength: 0)

            VStack(spacing: NodeSpacing.sp2) {
                NodePrimaryButton(saveButtonTitle, systemImage: "square.and.arrow.down") {
                    Task {
                        isSaving = true
                        let saved = await viewModel.savePendingLibraryImport()
                        isSaving = false
                        if saved {
                            dismiss()
                            onSaved(true)
                        }
                    }
                }
                .disabled(isSaving || viewModel.selectedPlant == nil)
                .opacity(isSaving || viewModel.selectedPlant == nil ? 0.45 : 1)

                NodeSecondaryButton("キャンセル") {
                    viewModel.cancelLibraryImport()
                    dismiss()
                }
                .disabled(isSaving)
            }
        }
        .padding(.horizontal, NodeSpacing.sp5)
        .padding(.top, 10)
        .padding(.bottom, NodeSpacing.sp4)
    }

    private var saveButtonTitle: String {
        let time = viewModel.observedAt.nodeTime()
        if viewModel.isObservingInPast {
            return "記録する · \(viewModel.observedAt.nodeMonthDay()) \(time)"
        }
        return "記録する · \(time)"
    }
}

