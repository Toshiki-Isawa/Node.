import SwiftData
import SwiftUI

struct ObservationDetailView: View {
    @Bindable var plant: Plant
    @Bindable var observation: PlantObservation
    let imageStore: ImageStore
    let observationImageService: ObservationImageService
    let modelContext: ModelContext
    let syncEngine: SyncEngine
    let recordDeletionService: RecordDeletionService
    var onBack: () -> Void
    var onPlantTap: () -> Void
    var onDeleted: () -> Void

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    bodySection
                }
                .padding(.bottom, NodeTabBarMetrics.scrollBottomInset + NodeSpacing.sp4)
            }
            .background(NodeColor.graphite)
            .ignoresSafeArea(edges: .top)

            topBar
        }
        .background(NodeColor.graphite)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            "観測を削除",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                try? recordDeletionService.deleteObservation(observation, from: plant)
                onDeleted()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この観測記録を削除します。写真も端末から削除され、元に戻せません。")
        }
        .sheet(isPresented: $showEditSheet) {
            EditObservationSheet(
                viewModel: EditObservationViewModel(
                    plant: plant,
                    observation: observation,
                    modelContext: modelContext,
                    syncEngine: syncEngine
                ),
                imageStore: imageStore,
                observationImageService: observationImageService
            )
            .presentationDetents([.fraction(0.58), .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(NodeColor.charcoal)
        }
        .sheet(isPresented: $showShareSheet) {
            shareSheet
        }
    }

    private var shareSheet: some View {
        ShareExportSheet(
            fileName: "Node-observation",
            analyticsKind: "observation",
            analyticsService: nil
        ) {
            ObservationShareCard(
                plantName: plant.name,
                species: plant.species,
                image: observationImage(),
                dateText: observation.createdAt.nodeYearMonthDay(),
                dayNumber: observationDayNumber,
                note: observation.note
            )
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(NodeColor.graphite)
    }

    private func observationImage() -> UIImage? {
        imageStore.loadImage(path: observation.localImagePath)
            ?? imageStore.loadImage(path: observationImageService.displayThumbnailPath(for: observation))
    }

    private var observationDayNumber: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .current
        let days = calendar.dateComponents([.day], from: plant.acquiredAt, to: observation.createdAt).day ?? 0
        return days + 1
    }

    private var topBar: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(NodeColor.bone)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            Spacer()
            HStack(spacing: NodeSpacing.sp2) {
                Button { showShareSheet = true } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(NodeColor.bone)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .accessibilityLabel("画像をシェア")

                Menu {
                    Button("日時を変更") { showEditSheet = true }
                    Button("削除", role: .destructive) { showDeleteConfirmation = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(NodeColor.bone)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, NodeSpacing.sp4)
        .nodeScreenTopPadding()
        .padding(.bottom, NodeSpacing.sp2)
    }

    private var heroSection: some View {
        PhotoCard(
            imagePath: observationImageService.displayThumbnailPath(for: observation),
            imageStore: imageStore,
            aspectRatio: 4 / 5,
            cornerRadius: 0,
            overlay: AnyView(
                LinearGradient(
                    colors: [NodeColor.void.opacity(0.4), .clear, NodeColor.void.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        )
    }

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp4) {
            HStack {
                MetaLabel(text: "観測", size: 9)
                MetaLabel(
                    text: "\(observation.createdAt.nodeYearMonthDayTime())",
                    color: NodeColor.fog,
                    size: 9
                )
                Spacer()
                if ReleaseConfig.cloudSyncEnabled {
                    SyncDot(state: observation.syncStatus, size: 6)
                }
            }

            Button(action: onPlantTap) {
                HStack(spacing: NodeSpacing.sp2) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plant.name)
                            .font(NodeFont.display(NodeFont.title3, weight: .light))
                            .foregroundStyle(NodeColor.bone)
                        if !plant.species.isEmpty {
                            Text(plant.species)
                                .font(NodeFont.display(13, weight: .light))
                                .italic()
                                .foregroundStyle(NodeColor.fog)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(NodeColor.fog)
                }
                .padding(NodeSpacing.sp3)
                .background(
                    RoundedRectangle(cornerRadius: NodeRadius.lg)
                        .fill(NodeColor.charcoal)
                        .overlay(
                            RoundedRectangle(cornerRadius: NodeRadius.lg)
                                .stroke(NodeColor.hairline, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            if !observation.note.isEmpty {
                VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
                    MetaLabel(text: "ノート", color: NodeColor.fog, size: 9)
                    Text(observation.note)
                        .font(NodeFont.text(NodeFont.body))
                        .foregroundStyle(NodeColor.paper)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, NodeSpacing.sp4)
        .padding(.top, NodeSpacing.sp4)
    }
}
