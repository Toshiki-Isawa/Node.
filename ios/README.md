# Node. iOS

SwiftUI + SwiftData による植物観測アーカイブアプリ。

## リリース設定（v1.0 / v1.1）

`Node/Core/Config/ReleaseConfig.swift` で機能公開を切り替えます。

| フラグ | v1.0（現行） | v1.1（クラウド同期・課金） |
|--------|-------------|---------------------------|
| `cloudSyncEnabled` | `false` | `true` |
| `subscriptionsEnabled` | `false` | `true` |

**v1.0（ローカル無料）**

- 起動後すぐメイン画面（サインイン・同期 UI 非表示）
- 観測記録は端末内のみ。Supabase / R2 の本番デプロイは不要
- Settings に「端末内保存」の注意書きを表示

**v1.1（有料クラウド同期）**

- 両フラグを `true` に変更し、Supabase + R2 + Edge Functions を本番デプロイ
- **Seed（無料）は引き続きローカルのみ**。Archive / Conservatory のみ R2 同期
- 既存ユーザーのローカルデータは購入・サインイン後に `SyncEngine` がバックフィル

## 要件

- Xcode 15 以上
- iOS 17 以上（SwiftData）
- Supabase プロジェクト（**v1.1 以降**。v1.0 ローカルリリースでは不要）

## セットアップ

1. Xcode で `ios/Node.xcodeproj` を開く（必要に応じて `ios/` ディレクトリで `xcodegen generate` を実行して再生成）。
2. `Node/Config/Secrets.example.xcconfig` を `Node/Config/Secrets.xcconfig` にコピーし、以下を設定する：
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `GOOGLE_IOS_CLIENT_ID`（Google サインインを使う場合）
   - `GOOGLE_IOS_URL_SCHEME`（Google サインインを使う場合。REVERSED_CLIENT_ID）
   - `POSTHOG_API_KEY` / `POSTHOG_HOST`（PostHog。未設定時は計測 no-op）
   - `PRIVACY_POLICY_URL` — **v1.0 では未設定**（同梱 HTML を表示。Web 公開時のみ設定）
3. Bundle ID `app.node.ios` で **Sign in with Apple** ケーパビリティを有効化する。
4. Google サインインを使う場合：
   - [Google Cloud Console](https://console.cloud.google.com/auth/clients) で Web / iOS の OAuth クライアント ID を作成する
   - Supabase Dashboard の Google プロバイダに **Web クライアント ID を先頭** に、iOS クライアント ID をカンマ区切りで登録する
   - **Skip nonce check** を有効にする
5. Supabase マイグレーションを適用する：
   ```bash
   supabase db push
   ```
6. Edge Functions をデプロイする：
   ```bash
   supabase secrets set --env-file supabase/functions/.env
   supabase functions deploy r2-presign-upload
   supabase functions deploy r2-presign-download
   supabase functions deploy sync-premium
   supabase functions deploy delete-account
   ```
7. Premium 課金（StoreKit 2）のローカルテスト：
   - Xcode スキーム `Node` の Run オプションで `Node/Config/Products.storekit` が StoreKit Configuration として指定されていることを確認
   - プロダクト ID: `app.node.archive.monthly`（¥480/月）、`app.node.conservatory.monthly`（¥980/月）
8. ローカルで同期を試す場合は `supabase/functions/.env.example` を `supabase/functions/.env` にコピーし、R2 認証情報を設定して `supabase stop && supabase start` する。
9. **PostHog**:
   - [PostHog](https://posthog.com/) でプロジェクトを作成し API Key を取得（未設定時は計測 no-op）

## アーキテクチャ

```
Node/
├── App/              # エントリポイント、RootView
├── Features/         # MVVM 画面
├── Core/
│   ├── DesignSystem/ # design/colors_and_type.css 由来のデザイントークン
│   ├── Models/       # SwiftData @Model 型
│   └── Services/     # ビジネスロジック
└── Config/           # Secrets.xcconfig, Products.storekit
```

### Features（画面）

| 機能 | 説明 |
|------|------|
| Auth | Apple / Google サインイン、オフライン続行 |
| Collection | 植物グリッド、カテゴリフィルタ、検索、水やり優先ソート |
| AddPlant / EditPlant | 植物登録・編集（水やり間隔含む） |
| Camera | 高速撮影、前回写真オーバーレイ、即ローカル保存 |
| Timeline | 観測 + 育成ログの時系列表示 |
| PlantDetail | 詳細、Compare / Timelapse / Quick Log への導線 |
| CareCalendar | ケア履歴の月間カレンダー |
| Compare | 2 時点スライダー比較 |
| Timelapse | 端末内 MP4 生成、プラン別解像度 Export |
| QuickLog / BulkQuickLog | 単体・複数植物のケア記録 |
| Settings | プラン・容量・同期状態・購入復元・アカウント削除 |

### Services

| Service | 役割 |
|---------|------|
| `SupabaseService` | Auth、CRUD upsert、Edge Function 呼び出し |
| `SyncEngine` | オンライン検知、plants / observations / growth_logs のプッシュ同期 |
| `ImageStore` | Original / サムネイル / キャッシュ管理 |
| `ObservationImageService` | 表示用サムネ、同期後 Original 退避、R2 から再取得 |
| `PlanService` | サーバー + StoreKit のプラン統合 |
| `SubscriptionService` | StoreKit 2 商品取得・購入・復元 |
| `CameraService` | AVFoundation カメラ |
| `TimelapseService` / `TimelapseVideoGenerator` | 端末内 MP4 生成 |
| `AnalyticsService` | PostHog イベント送信 |
| `RecordDeletionService` | 観測 / ログ削除 |
| `StorageStatsService` | ローカル / 同期状態集計 |

## 同期フロー

```
Collection → Camera → ローカル保存 → SyncEngine → Supabase + R2
```

- オフラインでの撮影・保存は即時完了。クラウド同期はバックグラウンドで実行される（`ReleaseConfig.cloudSyncEnabled == true` かつ有料プランのみ）
- Archive / Conservatory は Original を R2 へ同期。Seed（無料）は端末内のみ
- 容量上限到達時は `sync_paused_storage_limit` となり同期のみ停止（撮影は継続）
- 同期完了後、Original は端末から退避。Compare / Timelapse 利用時に R2 から presigned URL で取得

## タイムラプス

- `TimelapseVideoGenerator`（`AVFoundation`）が観測画像から端末内で MP4 を生成する
- 最小 5 枚、最大 60 フレーム。Seed は 720p、Archive 以上は 4K
- クラウドへ動画は保存しない。Export は共有シートまたは写真ライブラリ
- v1.0 では全プランで即 Export
- 詳細は [specification.md](../specification.md) §10.7

## 認証

- **Sign in with Apple** — ネイティブ SDK + Supabase `signInWithIdToken`
- **Google Sign-In** — `GOOGLE_IOS_CLIENT_ID` 設定時のみ UI 表示
- **オフライン続行** — サインインなしでも端末内機能は利用可能（同期・課金・クラウド復元は不可）

## v1.0 リリース前チェック

| 項目 | 状態 |
|------|------|
| `ReleaseConfig` — 両フラグ `false` | 設定済み |
| `MARKETING_VERSION` — `1.0.0` | 設定済み |
| 同梱 `Node/Resources/privacy.html` — v1.0 専用 | 設定済み（アプリ内表示の正本） |
| `PRIVACY_POLICY_URL` — 未設定（同梱 HTML を使用） | 設定済み |
| 運営者名・問い合わせ先 | 設定済み |
| `project.yml` — `DEVELOPMENT_TEAM` | **要設定**（Apple Developer Program） |
| App Store Connect — プライバシーポリシー URL | [公開済み](https://node-app.jp/privacy/)（ASC 登録は申請時） |
| App Privacy — **データを収集しない** | 申告時 |
| Release Archive + 実機 QA | 要実施 |

**v1.0 の方針:** アプリ内（Settings → プライバシーポリシー）は **`ios/Node/Resources/privacy.html` の同梱 HTML** を使用する。`Secrets.xcconfig` に `PRIVACY_POLICY_URL` を書かないこと。

App Store Connect の「プライバシーポリシー URL」には https://node-app.jp/privacy/ を登録する。アプリ内は引き続き同梱 HTML。公開ページ本文は `docs/privacy-policy.md`（v1.0 専用）と一致させること。
