import SwiftData
import SwiftUI

@main
struct NodeApp: App {
    let modelContainer: ModelContainer
    @StateObject private var environment: AppEnvironment

    init() {
        let container = try! ModelContainerFactory.makeContainer()
        modelContainer = container
        let context = container.mainContext
        _environment = StateObject(wrappedValue: AppEnvironment(modelContext: context))
    }

    var body: some Scene {
        WindowGroup {
            RootView(modelContext: modelContainer.mainContext, environment: environment)
                .environmentObject(environment)
                .preferredColorScheme(ColorScheme.dark)
        }
        .modelContainer(modelContainer)
    }
}
