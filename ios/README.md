# Node. iOS

SwiftUI + SwiftData による植物観測アーカイブアプリ。

## 要件

- Xcode 15 以上
- iOS 17 以上（SwiftData）
- Supabase プロジェクト（Auth + Postgres + Edge Functions）

## セットアップ

1. Xcode で `ios/Node.xcodeproj` を開く（必要に応じて `ios/` ディレクトリで `xcodegen generate` を実行して再生成）。
2. `Node/Config/Secrets.example.xcconfig` を `Node/Config/Secrets.xcconfig` にコピーし、以下を設定する：
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `GOOGLE_IOS_CLIENT_ID`（Google サインインを使う場合）
   - `GOOGLE_IOS_URL_SCHEME`（Google サインインを使う場合。REVERSED_CLIENT_ID）
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
   supabase functions deploy sync-premium
   ```
7. Premium 課金（StoreKit 2）のローカルテスト：
   - Xcode スキーム `Node` の Run オプションで `Node/Config/Products.storekit` が StoreKit Configuration として指定されていることを確認
   - プロダクト ID: `app.node.archive.monthly`（¥480/月）、`app.node.conservatory.monthly`（¥980/月）
8. ローカルで同期を試す場合は `supabase/functions/.env.example` を `supabase/functions/.env` にコピーし、R2 認証情報を設定して `supabase stop && supabase start` する。

## アーキテクチャ

- **Features/** — MVVM 画面（Collection、Camera、Compare など）
- **Core/DesignSystem/** — `design/colors_and_type.css` 由来のデザイントークン
- **Core/Models/** — SwiftData `@Model` 型
- **Core/Services/** — ImageStore、CameraService、SyncEngine、SupabaseService、PlanService、SubscriptionService

## タイムラプス

- `TimelapseVideoGenerator`（`AVFoundation`）が観測画像から端末内で MP4 を生成する。
- クラウドへ動画は保存しない。Export は共有シートまたは写真ライブラリ。
- 詳細は [specification.md](../specification.md) §10.7。

## 観測フロー

```
Collection → Camera → ローカル保存 → SyncEngine → Supabase + R2
```

オフラインでの撮影・保存は即時完了。クラウド同期はバックグラウンドで実行される。
