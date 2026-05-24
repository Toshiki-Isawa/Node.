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
3. Bundle ID `app.node.ios` で **Sign in with Apple** ケーパビリティを有効化する。
4. Supabase マイグレーションを適用する：
   ```bash
   supabase db push
   ```
5. Edge Functions をデプロイする：
   ```bash
   supabase functions deploy r2-presign-upload
   supabase functions deploy generate-timelapse
   ```
6. `r2-presign-upload` 用の R2 シークレットを設定する（`supabase/functions/r2-presign-upload/` を参照）。

## アーキテクチャ

- **Features/** — MVVM 画面（Collection、Camera、Compare など）
- **Core/DesignSystem/** — `design/colors_and_type.css` 由来のデザイントークン
- **Core/Models/** — SwiftData `@Model` 型
- **Core/Services/** — ImageStore、CameraService、SyncEngine、SupabaseService

## 観測フロー

```
Collection → Camera → ローカル保存 → SyncEngine → Supabase + R2
```

オフラインでの撮影・保存は即時完了。クラウド同期はバックグラウンドで実行される。
