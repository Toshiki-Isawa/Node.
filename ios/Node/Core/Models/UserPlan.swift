import CoreGraphics
import Foundation

enum UserPlan: String, Codable, Sendable, CaseIterable {
    case seed
    case archive
    case conservatory

    static func fromServerValue(_ raw: String) -> UserPlan {
        UserPlan(rawValue: raw) ?? .seed
    }

    var displayName: String {
        switch self {
        case .seed: return "Seed"
        case .archive: return "Archive"
        case .conservatory: return "Conservatory"
        }
    }

    var tagline: String {
        switch self {
        case .seed: return "観測を始める"
        case .archive: return "植物の時間を残す"
        case .conservatory: return "コレクションを保存する"
        }
    }

    var storageLimitBytes: Int64 {
        switch self {
        case .seed: return 3 * 1024 * 1024 * 1024
        case .archive: return 50 * 1024 * 1024 * 1024
        case .conservatory: return 500 * 1024 * 1024 * 1024
        }
    }

    var allowsOriginalSync: Bool {
        self != .seed
    }

    var isPaid: Bool {
        self != .seed
    }

    /// App Store 商品未取得時の表示用（日本円・税込想定）
    var marketingMonthlyPrice: String? {
        switch self {
        case .seed: return nil
        case .archive: return "¥480"
        case .conservatory: return "¥980"
        }
    }

    /// タイムラプス Export の長辺上限（px）
    var timelapseMaxLongEdge: CGFloat {
        switch self {
        case .seed: 1280
        case .archive, .conservatory: 3840
        }
    }

    var timelapseQualityLabel: String {
        switch self {
        case .seed: "720p"
        case .archive, .conservatory: "4K"
        }
    }

    var tierRank: Int {
        switch self {
        case .seed: return 0
        case .archive: return 1
        case .conservatory: return 2
        }
    }

    static func highest(_ plans: [UserPlan]) -> UserPlan {
        plans.max(by: { $0.tierRank < $1.tierRank }) ?? .seed
    }
}

enum SubscriptionProducts {
    static let archiveMonthly = "app.node.archive.monthly"
    static let conservatoryMonthly = "app.node.conservatory.monthly"

    static let all: Set<String> = [
        archiveMonthly,
        conservatoryMonthly,
    ]

    static func plan(for productId: String) -> UserPlan? {
        switch productId {
        case archiveMonthly:
            return .archive
        case conservatoryMonthly:
            return .conservatory
        default:
            return nil
        }
    }
}
