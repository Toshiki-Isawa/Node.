import StoreKit
import SwiftData
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview

    @State private var selectedTab: AppTab = .collection
    @State private var showCamera = false
    @State private var showObservationRequirement = false
    @State private var showAddPlant = false
    @State private var navigationPath: [AppNavigationRoute] = []
    @State private var quickLogTarget: PlantSheetTarget?
    @State private var showBulkQuickLog = false
    @State private var bulkQuickLogContext: BulkQuickLogContext = .general
    @State private var editPlantTarget: PlantSheetTarget?
    @State private var timelapseTarget: PlantSheetTarget?
    @State private var showSettings = false

    @StateObject private var collectionViewModel: CollectionViewModel
    @StateObject private var timelineViewModel: TimelineViewModel
    @StateObject private var compareViewModel: CompareViewModel
    @StateObject private var cameraViewModel: CameraViewModel
    @StateObject private var settingsViewModel: SettingsViewModel

    init(modelContext: ModelContext, environment: AppEnvironment) {
        _collectionViewModel = StateObject(wrappedValue: CollectionViewModel(
            modelContext: modelContext,
            recordDeletionService: environment.recordDeletionService,
            analyticsService: environment.analyticsService
        ))
        _timelineViewModel = StateObject(wrappedValue: TimelineViewModel(
            modelContext: modelContext,
            recordDeletionService: environment.recordDeletionService
        ))
        _compareViewModel = StateObject(wrappedValue: CompareViewModel(
            observationImageService: environment.observationImageService
        ))
        _cameraViewModel = StateObject(wrappedValue: CameraViewModel(
            modelContext: modelContext,
            imageStore: environment.imageStore,
            observationImageService: environment.observationImageService,
            syncEngine: environment.syncEngine,
            analyticsService: environment.analyticsService,
            reviewPromptService: environment.reviewPromptService
        ))
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel(
            modelContext: modelContext,
            imageStore: environment.imageStore,
            planService: environment.planService,
            subscriptionService: environment.subscriptionService,
            syncEngine: environment.syncEngine,
            authViewModel: environment.authViewModel,
            supabaseService: environment.supabaseService
        ))
    }

    var body: some View {
        Group {
            if !ReleaseConfig.cloudSyncEnabled || environment.authViewModel.hasEnteredApp {
                mainShell
            } else {
                SignInView(viewModel: environment.authViewModel)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: CareNotificationService.openCollectionNotification)) { _ in
            selectTab(.collection)
        }
        .onChange(of: environment.reviewPromptService.pendingPromptToken) { _, token in
            guard token != nil else { return }
            requestReview()
            environment.reviewPromptService.consumeToken()
        }
    }

    private var mainShell: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottom) {
                tabContent
                NodeTabBar(selectedTab: selectedTabBinding, onShoot: handleShootTap)
            }
            .navigationDestination(for: AppNavigationRoute.self) { route in
                switch route {
                case .plant(let plantId):
                    if let plant = fetchPlant(id: plantId) {
                        plantDetail(for: plant)
                    } else {
                        EmptyStateView(message: "Plant not found.")
                    }
                case .compare(let plantId):
                    if let plant = fetchPlant(id: plantId) {
                        compareView(for: plant)
                    } else {
                        EmptyStateView(message: "Plant not found.")
                    }
                case .observation(let observationId):
                    if let observation = fetchObservation(id: observationId),
                       let plant = observation.plant ?? fetchPlant(id: observation.plantId) {
                        observationDetail(for: observation, plant: plant)
                    } else {
                        EmptyStateView(message: "Observation not found.")
                    }
                }
            }
        }
        .sheet(isPresented: $showObservationRequirement) {
            ObservationRequirementSheet {
                showAddPlant = true
            }
            .presentationDetents([.fraction(0.52)])
            .presentationDragIndicator(.visible)
            .presentationBackground(NodeColor.charcoal)
        }
        .sheet(isPresented: $showAddPlant) {
            AddPlantView(viewModel: AddPlantViewModel(
                modelContext: modelContext,
                imageStore: environment.imageStore,
                syncEngine: environment.syncEngine,
                supabaseService: environment.supabaseService,
                analyticsService: environment.analyticsService
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
                    syncEngine: environment.syncEngine,
                    recordDeletionService: environment.recordDeletionService,
                    analyticsService: environment.analyticsService
                ),
                onDeleted: {
                    popNavigation(forPlantId: target.plant.id)
                    collectionViewModel.reload()
                    timelineViewModel.reload()
                    cameraViewModel.reloadPlants()
                }
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
                    syncEngine: environment.syncEngine,
                    analyticsService: environment.analyticsService
                )
            )
            .presentationDetents([.fraction(0.58), .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(NodeColor.charcoal)
        }
        .sheet(isPresented: $showBulkQuickLog) {
            BulkQuickLogSheet(
                viewModel: BulkQuickLogViewModel(
                    modelContext: modelContext,
                    syncEngine: environment.syncEngine,
                    analyticsService: environment.analyticsService,
                    context: bulkQuickLogContext
                ),
                onObserveAfterSave: {
                    cameraViewModel.reloadPlants()
                    showCamera = true
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(NodeColor.charcoal)
            .onDisappear {
                collectionViewModel.reload()
                timelineViewModel.reload()
            }
        }
        .sheet(item: $timelapseTarget) { target in
            TimelapseView(
                viewModel: PlantDetailViewModel(
                    plant: target.plant,
                    recordDeletionService: environment.recordDeletionService,
                    observationImageService: environment.observationImageService
                ),
                timelapseService: environment.timelapseService,
                planService: environment.planService,
                observationImageService: environment.observationImageService,
                imageStore: environment.imageStore
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                viewModel: settingsViewModel,
                planService: environment.planService,
                careNotificationService: environment.careNotificationService,
                analyticsService: environment.analyticsService
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(NodeColor.graphite)
            .onAppear {
                environment.analyticsService.capture(AnalyticsEvent.settingsOpened)
            }
        }
    }

    private func openCompare(for plant: Plant) {
        compareViewModel.configure(plant: plant)
        navigationPath.append(.compare(plant.id))
        environment.analyticsService.capture(
            AnalyticsEvent.compareOpened,
            properties: ["mode": compareViewModel.displayMode.analyticsValue]
        )
    }

    private func handleShootTap() {
        cameraViewModel.reloadPlants()
        if cameraViewModel.plants.isEmpty {
            showObservationRequirement = true
        } else {
            showCamera = true
        }
    }

    /// タブ切り替え時に NavigationStack の詳細画面を残さない
    private func selectTab(_ tab: AppTab) {
        navigationPath.removeAll()
        selectedTab = tab
        if tab == .timeline {
            environment.analyticsService.capture(AnalyticsEvent.timelineViewed)
        }
    }

    private var selectedTabBinding: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { selectTab($0) }
        )
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .collection, .shoot:
            CollectionView(
                viewModel: collectionViewModel,
                planService: environment.planService,
                imageStore: environment.imageStore,
                observationImageService: environment.observationImageService,
                onPlantTap: { plant in navigationPath.append(.plant(plant.id)) },
                onAddPlant: { showAddPlant = true },
                onBulkQuickLog: { context in
                    bulkQuickLogContext = context
                    showBulkQuickLog = true
                },
                onSettings: { showSettings = true }
            )
        case .timeline:
            TimelineView(
                viewModel: timelineViewModel,
                imageStore: environment.imageStore,
                observationImageService: environment.observationImageService,
                modelContext: modelContext,
                syncEngine: environment.syncEngine,
                onBack: { selectTab(.collection) },
                onPlantTap: { plant in navigationPath.append(.plant(plant.id)) },
                onObservationTap: { _, observation in
                    navigationPath.append(.observation(observation.id))
                }
            )
        }
    }

    @ViewBuilder
    private func compareView(for plant: Plant) -> some View {
        CompareView(
            viewModel: compareViewModel,
            imageStore: environment.imageStore,
            analyticsService: environment.analyticsService,
            onBack: { navigationPath.removeLast() },
            onTimelapse: {
                timelapseTarget = PlantSheetTarget(plant: plant)
            }
        )
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            compareViewModel.configure(plant: plant)
        }
    }

    @ViewBuilder
    private func plantDetail(for plant: Plant) -> some View {
        let detailVM = PlantDetailViewModel(
            plant: plant,
            recordDeletionService: environment.recordDeletionService,
            observationImageService: environment.observationImageService
        )
        PlantDetailView(
            plant: plant,
            viewModel: detailVM,
            imageStore: environment.imageStore,
            observationImageService: environment.observationImageService,
            modelContext: modelContext,
            syncEngine: environment.syncEngine,
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
                openCompare(for: plant)
            },
            onQuickLog: {
                quickLogTarget = PlantSheetTarget(plant: plant)
            },
            onObservationTap: { observation in
                navigationPath.append(.observation(observation.id))
            }
        )
    }

    private func fetchPlant(id: UUID) -> Plant? {
        var descriptor = FetchDescriptor<Plant>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchObservation(id: UUID) -> PlantObservation? {
        var descriptor = FetchDescriptor<PlantObservation>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    @ViewBuilder
    private func observationDetail(for observation: PlantObservation, plant: Plant) -> some View {
        ObservationDetailView(
            plant: plant,
            observation: observation,
            imageStore: environment.imageStore,
            observationImageService: environment.observationImageService,
            modelContext: modelContext,
            syncEngine: environment.syncEngine,
            recordDeletionService: environment.recordDeletionService,
            onBack: { navigationPath.removeLast() },
            onPlantTap: { navigationPath.append(.plant(plant.id)) },
            onDeleted: {
                navigationPath.removeLast()
                timelineViewModel.reload()
                collectionViewModel.reload()
            }
        )
    }

    private func popNavigation(forPlantId plantId: UUID) {
        navigationPath.removeAll { route in
            switch route {
            case .plant(let id), .compare(let id):
                return id == plantId
            case .observation(let observationId):
                return fetchObservation(id: observationId)?.plantId == plantId
            }
        }
        editPlantTarget = nil
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
