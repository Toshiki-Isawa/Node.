import GoogleSignIn
import SwiftData
import SwiftUI

@main
struct NodeApp: App {
    let modelContainer: ModelContainer
    @StateObject private var environment: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase

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
                .preferredColorScheme(ColorScheme.dark)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        environment.analyticsService.capture(AnalyticsEvent.appForeground)
                        Task {
                            await environment.careNotificationService.refreshAuthorizationStatus()
                            await environment.careNotificationService.rescheduleIfNeeded()
                            await environment.careNotificationService.updateBadge()
                        }
                    case .background:
                        // アプリ内で水やり/編集した結果を離脱時に反映:
                        // 通知本文と content.badge を貼り直し、アイコンバッジを即時更新する。
                        Task {
                            await environment.careNotificationService.rescheduleIfNeeded()
                            await environment.careNotificationService.updateBadge()
                        }
                    default:
                        break
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
