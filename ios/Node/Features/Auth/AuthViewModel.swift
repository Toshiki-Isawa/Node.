import AuthenticationServices
import CryptoKit
import Foundation

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

    init(supabaseService: SupabaseService, syncEngine: SyncEngine) {
        self.supabaseService = supabaseService
        self.syncEngine = syncEngine
        Task { await refresh() }
    }

    func refresh() async {
        await supabaseService.refreshSession()
        guard !isOfflineMode else { return }
        if supabaseService.isAuthenticated {
            hasEnteredApp = true
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

    func signOut() async {
        do {
            try await supabaseService.signOut()
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
}
