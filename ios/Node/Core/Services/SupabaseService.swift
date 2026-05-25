import Foundation
import Supabase

enum SupabaseConfig {
    static var url: URL {
        guard let raw = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              let url = URL(string: raw) else {
            return URL(string: "https://placeholder.supabase.co")!
        }
        return url
    }

    static var anonKey: String {
        Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? "placeholder"
    }

    static var googleIOSClientID: String? {
        guard let raw = Bundle.main.infoDictionary?["GOOGLE_IOS_CLIENT_ID"] as? String,
              !raw.isEmpty,
              !raw.contains("your-google-ios-client-id") else {
            return nil
        }
        return raw
    }
}

@MainActor
final class SupabaseService: ObservableObject {
    let client: SupabaseClient

    @Published private(set) var session: Session?
    @Published private(set) var isConfigured: Bool

    init() {
        let url = SupabaseConfig.url
        let key = SupabaseConfig.anonKey
        isConfigured = !url.absoluteString.contains("placeholder") && key != "placeholder"
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
        Task { await refreshSession() }
    }

    func refreshSession() async {
        session = client.auth.currentSession
    }

    var userId: UUID? {
        session?.user.id
    }

    var isAuthenticated: Bool {
        session != nil
    }

    // MARK: - Auth

    func signInWithApple(idToken: String, nonce: String) async throws {
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        self.session = session
    }

    func signInWithGoogle(idToken: String, accessToken: String) async throws {
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken
            )
        )
        self.session = session
    }

    func signOut() async throws {
        try await client.auth.signOut()
        session = nil
    }

    func deleteAccount() async throws {
        struct Response: Decodable {
            let deleted: Bool
        }

        let _: Response = try await client.functions.invoke("delete-account")
        session = nil
    }

    // MARK: - Database

    func upsertPlant(_ plant: Plant) async throws {
        guard let userId else {
            throw SyncError.notAuthenticated
        }
        struct Payload: Encodable {
            let id: UUID
            let user_id: UUID
            let name: String
            let species: String?
            let category: String?
            let acquired_at: Date
            let watering_interval_days: Int?
            let created_at: Date
            let updated_at: Date
        }
        let payload = Payload(
            id: plant.id,
            user_id: userId,
            name: plant.name,
            species: plant.species.isEmpty ? nil : plant.species,
            category: plant.category,
            acquired_at: plant.acquiredAt,
            watering_interval_days: plant.wateringIntervalDays,
            created_at: plant.createdAt,
            updated_at: plant.updatedAt
        )
        try await client.from("plants").upsert(payload).execute()
    }

    func upsertObservation(_ observation: PlantObservation) async throws {
        struct Payload: Encodable {
            let id: UUID
            let plant_id: UUID
            let image_url: String?
            let note: String?
            let created_at: Date
            let sync_status: String
            let updated_at: Date
        }
        let payload = Payload(
            id: observation.id,
            plant_id: observation.plantId,
            image_url: observation.remoteImageURL,
            note: observation.note.isEmpty ? nil : observation.note,
            created_at: observation.createdAt,
            sync_status: observation.syncStatusRaw,
            updated_at: observation.updatedAt
        )
        try await client.from("observations").upsert(payload).execute()
    }

    func deleteObservation(id: UUID) async throws {
        try await client.from("observations")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func upsertGrowthLog(_ log: GrowthLog) async throws {
        struct Payload: Encodable {
            let id: UUID
            let plant_id: UUID
            let type: String
            let memo: String?
            let created_at: Date
            let updated_at: Date
        }
        let payload = Payload(
            id: log.id,
            plant_id: log.plantId,
            type: log.typeRaw,
            memo: log.memo.isEmpty ? nil : log.memo,
            created_at: log.createdAt,
            updated_at: log.updatedAt
        )
        try await client.from("growth_logs").upsert(payload).execute()
    }

    func deleteGrowthLog(id: UUID) async throws {
        try await client.from("growth_logs")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - R2 Presigned Upload

    func requestPresignedUpload(
        observationId: UUID,
        contentType: String = "image/jpeg",
        byteSize: Int
    ) async throws -> PresignedUploadResponse {
        struct Body: Encodable {
            let observation_id: String
            let content_type: String
            let byte_size: Int
        }
        do {
            let response: PresignedUploadResponse = try await client.functions.invoke(
                "r2-presign-upload",
                options: .init(body: Body(
                    observation_id: observationId.uuidString,
                    content_type: contentType,
                    byte_size: byteSize
                ))
            )
            return response
        } catch {
            if Self.isStorageLimitError(error) {
                throw SyncError.storageLimitExceeded
            }
            throw error
        }
    }

    private static func isStorageLimitError(_ error: Error) -> Bool {
        String(describing: error).contains("storage_limit_exceeded")
    }

    func fetchUserPlan() async throws -> UserPlan {
        guard isAuthenticated else {
            throw SyncError.notAuthenticated
        }
        let value: String = try await client.rpc("get_user_plan").execute().value
        return UserPlan.fromServerValue(value)
    }

    func syncPremiumSubscription(
        productId: String,
        transactionId: String,
        originalTransactionId: String,
        expiresAt: Date?,
        environment: String
    ) async throws {
        struct Body: Encodable {
            let product_id: String
            let transaction_id: String
            let original_transaction_id: String
            let expires_at: String?
            let environment: String
        }

        struct Response: Decodable {
            let plan: String
            let active: Bool
        }

        let _: Response = try await client.functions.invoke(
            "sync-premium",
            options: .init(body: Body(
                product_id: productId,
                transaction_id: transactionId,
                original_transaction_id: originalTransactionId,
                expires_at: expiresAt.map { ISO8601DateFormatter().string(from: $0) },
                environment: environment
            ))
        )
    }

    func fetchStorageUsageBytes() async throws -> Int64 {
        guard isAuthenticated else {
            throw SyncError.notAuthenticated
        }
        let value: Int64 = try await client.rpc("get_storage_usage_bytes").execute().value
        return value
    }

    func fetchStorageObjectKey(observationId: UUID) async throws -> String? {
        struct Row: Decodable {
            let object_key: String
        }
        let rows: [Row] = try await client.from("storage_objects")
            .select("object_key")
            .eq("observation_id", value: observationId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first?.object_key
    }

    func registerStorageObject(
        observationId: UUID,
        objectKey: String,
        byteSize: Int,
        contentType: String
    ) async throws {
        guard let userId else {
            throw SyncError.notAuthenticated
        }
        struct Payload: Encodable {
            let user_id: UUID
            let observation_id: UUID
            let object_key: String
            let byte_size: Int
            let content_type: String
        }
        try await client.from("storage_objects")
            .upsert(
                Payload(
                    user_id: userId,
                    observation_id: observationId,
                    object_key: objectKey,
                    byte_size: byteSize,
                    content_type: contentType
                ),
                onConflict: "object_key"
            )
            .execute()
    }

    func uploadToPresignedURL(_ data: Data, uploadURL: String, contentType: String = "image/jpeg") async throws {
        guard let url = URL(string: uploadURL), url.host != nil else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func requestPresignedDownload(observationId: UUID) async throws -> PresignedDownloadResponse {
        struct Body: Encodable {
            let observation_id: String
        }

        return try await client.functions.invoke(
            "r2-presign-download",
            options: .init(body: Body(observation_id: observationId.uuidString))
        )
    }

    func downloadFromPresignedURL(_ downloadURL: String) async throws -> Data {
        guard let url = URL(string: downloadURL), url.host != nil else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ObservationImageError.downloadFailed
        }
        return data
    }

}
