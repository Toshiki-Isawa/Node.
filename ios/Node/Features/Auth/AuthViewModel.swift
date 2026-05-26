import AuthenticationServices
import CryptoKit
import Foundation
import GoogleSignIn
import UIKit

@MainActor
final class AuthViewModel: ObservableObject {
    /// メイン画面へ進めるか（オフライン続行 or サインイン済み）
    @Published private(set) var hasEnteredApp = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentNonce: String?

    private var isOfflineMode = false
    private let supabaseService: SupabaseService
    private let syncEngine: SyncEngine

    var isGoogleSignInAvailable: Bool {
        SupabaseConfig.googleIOSClientID != nil
    }

    init(supabaseService: SupabaseService, syncEngine: SyncEngine) {
        self.supabaseService = supabaseService
        self.syncEngine = syncEngine
        if ReleaseConfig.cloudSyncEnabled {
            Task { await refresh() }
        } else {
            isOfflineMode = true
            hasEnteredApp = true
        }
    }

    func refresh() async {
        guard ReleaseConfig.cloudSyncEnabled else { return }
        await supabaseService.refreshSession()
        guard !isOfflineMode else { return }
        if supabaseService.isAuthenticated {
            hasEnteredApp = true
            await syncEngine.processQueue()
        }
    }

    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Apple サインインに失敗しました。"
                return
            }
            do {
                try await supabaseService.signInWithApple(idToken: idToken, nonce: nonce)
                isOfflineMode = false
                hasEnteredApp = true
                await syncEngine.processQueue()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func signInWithGoogle() async {
        guard let clientID = SupabaseConfig.googleIOSClientID else {
            errorMessage = "Google サインインが設定されていません。"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenter = Self.topViewController() else {
            errorMessage = "Google サインイン画面を表示できませんでした。"
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google サインインに失敗しました。"
                return
            }
            let accessToken = result.user.accessToken.tokenString
            try await supabaseService.signInWithGoogle(idToken: idToken, accessToken: accessToken)
            isOfflineMode = false
            hasEnteredApp = true
            await syncEngine.processQueue()
        } catch {
            let nsError = error as NSError
            if nsError.domain == GIDSignInError.errorDomain,
               nsError.code == GIDSignInError.Code.canceled.rawValue {
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await supabaseService.signOut()
            GIDSignIn.sharedInstance.signOut()
            isOfflineMode = false
            hasEnteredApp = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAccount() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await supabaseService.deleteAccount()
            GIDSignIn.sharedInstance.signOut()
            isOfflineMode = false
            hasEnteredApp = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func continueOffline() {
        isOfflineMode = true
        hasEnteredApp = true
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in UInt8.random(in: 0...255) }
            randoms.forEach { random in
                if remaining == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let base = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController

        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}
