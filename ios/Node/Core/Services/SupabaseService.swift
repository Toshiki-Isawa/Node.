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

    func signOut() async throws {
        try await client.auth.signOut()
        session = nil
    }

    // MARK: - Database

    func upsertPlant(_ plant: Plant) async throws {
        guard let userId else { return }
        struct Payload: Encodable {
            let id: UUID
            let user_id: UUID
            let name: String
            let species: String?
            let category: String?
            let acquired_at: Date
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

    // MARK: - R2 Presigned Upload

    func requestPresignedUpload(
        observationId: UUID,
        contentType: String = "image/jpeg"
    ) async throws -> PresignedUploadResponse {
        struct Body: Encodable {
            let observation_id: String
            let content_type: String
        }
        let response: PresignedUploadResponse = try await client.functions.invoke(
            "r2-presign-upload",
            options: .init(body: Body(
                observation_id: observationId.uuidString,
                content_type: contentType
            ))
        )
        return response
    }

    func uploadToPresignedURL(_ data: Data, uploadURL: String, contentType: String = "image/jpeg") async throws {
        guard let url = URL(string: uploadURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Timelapse

    func createTimelapseJob(plantId: UUID, observationIds: [UUID]) async throws -> TimelapseCreateResponse {
        struct Body: Encodable {
            let plant_id: String
            let observation_ids: [String]
        }
        return try await client.functions.invoke(
            "generate-timelapse",
            options: .init(body: Body(
                plant_id: plantId.uuidString,
                observation_ids: observationIds.map(\.uuidString)
            ))
        )
    }

    func fetchTimelapseJob(jobId: String) async throws -> TimelapseJob {
        try await client.functions.invoke(
            "generate-timelapse",
            options: .init(body: ["job_id": jobId])
        )
    }
}
