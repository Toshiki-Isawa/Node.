import SwiftData
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab: AppTab = .collection
    @State private var showCamera = false
    @State private var showAddPlant = false
    @State private var navigationPath: [UUID] = []
    @State private var quickLogTarget: PlantSheetTarget?
    @State private var editPlantTarget: PlantSheetTarget?
    @State private var timelapseTarget: PlantSheetTarget?
    @State private var showPlantPicker = false

    @StateObject private var collectionViewModel: CollectionViewModel
    @StateObject private var timelineViewModel: TimelineViewModel
    @StateObject private var compareViewModel = CompareViewModel()
    @StateObject private var cameraViewModel: CameraViewModel

    init(modelContext: ModelContext, environment: AppEnvironment) {
        _collectionViewModel = StateObject(wrappedValue: CollectionViewModel(modelContext: modelContext))
        _timelineViewModel = StateObject(wrappedValue: TimelineViewModel(modelContext: modelContext))
        _cameraViewModel = StateObject(wrappedValue: CameraViewModel(
            modelContext: modelContext,
            imageStore: environment.imageStore,
            syncEngine: environment.syncEngine
        ))
    }

    var body: some View {
        Group {
            if environment.authViewModel.hasEnteredApp {
                mainShell
            } else {
                SignInView(viewModel: environment.authViewModel)
            }
        }
    }

    private var mainShell: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottom) {
                tabContent
                NodeTabBar(selectedTab: $selectedTab) {
                    cameraViewModel.reloadPlants()
                    showCamera = true
                }
            }
            .navigationDestination(for: UUID.self) { plantId in
                if let plant = fetchPlant(id: plantId) {
                    plantDetail(for: plant)
                } else {
                    EmptyStateView(message: "Plant not found.")
                }
            }
        }
        .sheet(isPresented: $showAddPlant) {
            AddPlantView(viewModel: AddPlantViewModel(
                modelContext: modelContext,
                imageStore: environment.imageStore,
                syncEngine: environment.syncEngine,
                supabaseService: environment.supabaseService
            ))
            .onDisappear {
                collectionViewModel.reload()
                timelineViewModel.reload()
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(
                viewModel: cameraViewModel,
                cameraService: environment.cameraService,
                imageStore: environment.imageStore
            ) {
                showCamera = false
                collectionViewModel.reload()
                timelineViewModel.reload()
            }
        }
        .sheet(item: $editPlantTarget) { target in
            EditPlantView(
                viewModel: EditPlantViewModel(
                    plant: target.plant,
                    modelContext: modelContext,
                    syncEngine: environment.syncEngine
                )
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(NodeColor.graphite)
            .onDisappear {
                collectionViewModel.reload()
            }
        }
        .sheet(item: $quickLogTarget) { target in
            QuickLogSheet(
                viewModel: QuickLogViewModel(
                    plant: target.plant,
                    modelContext: modelContext,
                    syncEngine: environment.syncEngine
                )
            )
            .presentationDetents([.fraction(0.58), .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(NodeColor.charcoal)
        }
        .sheet(item: $timelapseTarget) { target in
            TimelapseView(
                viewModel: PlantDetailViewModel(plant: target.plant),
                timelapseService: environment.timelapseService,
                imageStore: environment.imageStore
            )
        }
        .confirmationDialog("比較する植物", isPresented: $showPlantPicker, titleVisibility: .visible) {
            ForEach(collectionViewModel.plants, id: \.id) { plant in
                Button(plant.name) {
                    compareViewModel.configure(plant: plant)
                    selectedTab = .compare
                }
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .collection:
            CollectionView(
                viewModel: collectionViewModel,
                imageStore: environment.imageStore,
                onPlantTap: { plant in navigationPath.append(plant.id) },
                onAddPlant: { showAddPlant = true }
            )
        case .timeline:
            TimelineView(
                viewModel: timelineViewModel,
                imageStore: environment.imageStore,
                onPlantTap: { plant in navigationPath.append(plant.id) }
            )
        case .shoot:
            CollectionView(
                viewModel: collectionViewModel,
                imageStore: environment.imageStore,
                onPlantTap: { plant in navigationPath.append(plant.id) },
                onAddPlant: { showAddPlant = true }
            )
        case .compare:
            CompareView(
                viewModel: compareViewModel,
                imageStore: environment.imageStore,
                onBack: { selectedTab = .collection },
                onSelectPlant: { showPlantPicker = true }
            )
            .onAppear {
                if compareViewModel.plant == nil {
                    compareViewModel.configure(plant: collectionViewModel.plants.first)
                }
            }
        }
    }

    @ViewBuilder
    private func plantDetail(for plant: Plant) -> some View {
        let detailVM = PlantDetailViewModel(plant: plant)
        PlantDetailView(
            plant: plant,
            viewModel: detailVM,
            imageStore: environment.imageStore,
            onBack: { navigationPath.removeLast() },
            onEdit: {
                editPlantTarget = PlantSheetTarget(plant: plant)
            },
            onObserve: {
                cameraViewModel.reloadPlants()
                cameraViewModel.selectPlant(plant)
                showCamera = true
            },
            onCompare: {
                compareViewModel.configure(plant: plant)
                selectedTab = .compare
            },
            onQuickLog: {
                quickLogTarget = PlantSheetTarget(plant: plant)
            },
            onTimelapse: {
                timelapseTarget = PlantSheetTarget(plant: plant)
            }
        )
    }

    private func fetchPlant(id: UUID) -> Plant? {
        var descriptor = FetchDescriptor<Plant>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}

/// `.sheet(item:)` 用。`isPresented` + 別 `State` だと初回表示が空になる SwiftUI の既知問題を避ける。
private struct PlantSheetTarget: Identifiable {
    let id: UUID
    let plant: Plant

    init(plant: Plant) {
        self.id = plant.id
        self.plant = plant
    }
}
