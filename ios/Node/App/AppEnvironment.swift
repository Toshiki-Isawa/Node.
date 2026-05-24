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
    let supabaseService: SupabaseService
    let syncEngine: SyncEngine
    let cameraService: CameraService
    let timelapseService: TimelapseService

    let authViewModel: AuthViewModel

    init(modelContext: ModelContext) {
        let imageStore = ImageStore()
        let supabaseService = SupabaseService()
        let syncEngine = SyncEngine(
            modelContext: modelContext,
            imageStore: imageStore,
            supabaseService: supabaseService
        )
        let authViewModel = AuthViewModel(supabaseService: supabaseService, syncEngine: syncEngine)

        self.imageStore = imageStore
        self.supabaseService = supabaseService
        self.syncEngine = syncEngine
        self.cameraService = CameraService()
        self.timelapseService = TimelapseService(supabaseService: supabaseService)
        self.authViewModel = authViewModel

        authViewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        syncEngine.start()
    }

    private var cancellables = Set<AnyCancellable>()
}
