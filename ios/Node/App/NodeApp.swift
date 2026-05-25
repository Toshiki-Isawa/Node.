import GoogleSignIn
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

        if let clientID = SupabaseConfig.googleIOSClientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(modelContext: modelContainer.mainContext, environment: environment)
                .environmentObject(environment)
                .environment(\.locale, NodeDateFormat.locale)
                .preferredColorScheme(ColorScheme.dark)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(modelContainer)
    }
}
