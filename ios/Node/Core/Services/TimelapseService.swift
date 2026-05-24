import Foundation

@MainActor
final class TimelapseService: ObservableObject {
    @Published private(set) var currentJob: TimelapseJob?
    @Published private(set) var isGenerating = false
    @Published var errorMessage: String?

    private let supabaseService: SupabaseService

    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }

    func generate(plantId: UUID, observationIds: [UUID]) async {
        guard observationIds.count >= 2 else {
            errorMessage = "タイムラプスには2枚以上の観測が必要です。"
            return
        }

        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        do {
            let create = try await supabaseService.createTimelapseJob(
                plantId: plantId,
                observationIds: Array(observationIds.prefix(60))
            )
            var job = try await supabaseService.fetchTimelapseJob(jobId: create.jobId)
            currentJob = job

            var attempts = 0
            while job.status == .pending || job.status == .processing, attempts < 60 {
                try await Task.sleep(for: .seconds(2))
                job = try await supabaseService.fetchTimelapseJob(jobId: create.jobId)
                currentJob = job
                attempts += 1
            }

            if job.status == .failed {
                errorMessage = job.error ?? "タイムラプス生成に失敗しました。"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        currentJob = nil
        errorMessage = nil
    }
}
