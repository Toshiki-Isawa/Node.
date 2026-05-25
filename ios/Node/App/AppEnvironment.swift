import Combine
import Foundation
import SwiftData
import SwiftUI

enum ModelContainerFactory {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([Plant.self, PlantObservation.self, GrowthLog.self])

        if inMemory {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [config])
        }

        let supportURL = try applicationSupportDirectory()
        let storeURL = supportURL.appendingPathComponent("Node.store", isDirectory: false)
        let config = ModelConfiguration(url: storeURL)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private static func applicationSupportDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("Node", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

@MainActor
final class AppEnvironment: ObservableObject {
    let imageStore: ImageStore
    let observationImageService: ObservationImageService
    let supabaseService: SupabaseService
    let subscriptionService: SubscriptionService
    let planService: PlanService
    let syncEngine: SyncEngine
    let recordDeletionService: RecordDeletionService
    let cameraService: CameraService
    let timelapseService: TimelapseService

    let authViewModel: AuthViewModel

    init(modelContext: ModelContext) {
        let imageStore = ImageStore()
        let supabaseService = SupabaseService()
        let observationImageService = ObservationImageService(
            imageStore: imageStore,
            supabaseService: supabaseService
        )
        let subscriptionService = SubscriptionService()
        let planService = PlanService(
            supabaseService: supabaseService,
            subscriptionService: subscriptionService
        )
        let syncEngine = SyncEngine(
            modelContext: modelContext,
            imageStore: imageStore,
            observationImageService: observationImageService,
            supabaseService: supabaseService,
            planService: planService
        )
        planService.syncEngine = syncEngine
        let recordDeletionService = RecordDeletionService(
            modelContext: modelContext,
            imageStore: imageStore,
            observationImageService: observationImageService,
            supabaseService: supabaseService
        )
        let authViewModel = AuthViewModel(supabaseService: supabaseService, syncEngine: syncEngine)

        self.imageStore = imageStore
        self.observationImageService = observationImageService
        self.supabaseService = supabaseService
        self.subscriptionService = subscriptionService
        self.planService = planService
        self.syncEngine = syncEngine
        self.recordDeletionService = recordDeletionService
        self.cameraService = CameraService()
        self.timelapseService = TimelapseService(
            imageStore: imageStore,
            observationImageService: observationImageService
        )
        self.authViewModel = authViewModel

        authViewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        subscriptionService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        planService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        syncEngine.start()
    }

    private var cancellables = Set<AnyCancellable>()
}
