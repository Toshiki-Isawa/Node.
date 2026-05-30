import Foundation

/// v1.0 / v1.1 の機能公開を切り替えるリリース設定。
/// v1.1 でクラウド同期・課金を有効化する際は両方を `true` に変更する。
enum ReleaseConfig {
    /// クラウド同期（Sign in / SyncEngine / R2）を有効にする
    static let cloudSyncEnabled = false

    /// StoreKit 課金 UI を有効にする（`cloudSyncEnabled` と併用）
    static let subscriptionsEnabled = false

    /// タイムラプス機能を露出するか。無料で全ユーザーに開放。
    static let timelapseEnabled = true

    /// コレクション検索を露出するか。v1.0 では false（v1.0.1 の Pack で開放）
    static let searchEnabled = false

    /// 有料プランのみクラウド同期する（Seed は端末内のみ）
    static var requiresPaidPlanForCloudSync: Bool { cloudSyncEnabled }
}
