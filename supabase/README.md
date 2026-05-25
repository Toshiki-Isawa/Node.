# Node. 用 Supabase バックエンド

## マイグレーション

DB をリセットしてから適用する場合:

```bash
supabase db reset
```

既存 DB に追記する場合:

```bash
supabase db push
```

### テーブル

| テーブル | 用途 |
|----------|------|
| `plants` | 植物（名前・種・カテゴリ・取得日・水やり間隔） |
| `observations` | 観測記録（画像 URL・メモ・同期ステータス） |
| `growth_logs` | 育成ログ（水やり・施肥・植え替え等） |
| `user_profiles` | ユーザープラン（`seed` / `archive` / `conservatory`） |
| `storage_objects` | R2 オブジェクトのメタデータ・容量管理 |
| `subscription_entitlements` | StoreKit 購入トランザクション記録 |

全テーブルに RLS を設定。プランは `seed` / `archive` / `conservatory` のみ。

### RPC

| 関数 | 用途 |
|------|------|
| `get_storage_usage_bytes()` | ユーザーの R2 使用量（バイト） |
| `get_user_plan()` | entitlements + profile からプラン解決 |
| `resolve_plan_from_product(product_id)` | StoreKit product_id → plan |

タイムラプスは iOS 端末内で生成し、クラウドには保存しません。

## Edge Functions

| 関数 | 用途 |
|------|------|
| `r2-presign-upload` | 観測画像用の R2 presigned PUT URL を返す。Seed 3 GB / Archive 50 GB / Conservatory 500 GB の上限をチェック |
| `r2-presign-download` | 観測画像の R2 presigned GET URL を返す（有効期限 1 時間）。Compare / Timelapse 用 |
| `sync-premium` | StoreKit 購入後に Archive / Conservatory プランをサーバーへ同期 |
| `delete-account` | ユーザーの R2 オブジェクト削除 → `auth.admin.deleteUser` |

### シークレット（本番・ローカル Edge Functions）

Supabase ダッシュボード、`supabase secrets set`、またはローカル用 `supabase/functions/.env` で設定します。

| 変数 | 用途 |
|------|------|
| `R2_ACCOUNT_ID` | Cloudflare アカウント ID |
| `R2_BUCKET` | バケット名（既定: `node-observations`） |
| `R2_ACCESS_KEY_ID` | R2 S3 API トークン（Access Key） |
| `R2_SECRET_ACCESS_KEY` | R2 S3 API トークン（Secret Key） |
| `R2_PUBLIC_BASE_URL` | 公開 CDN URL（任意。レスポンスの `publicURL` に使用） |

ローカル開発:

```bash
cp supabase/functions/.env.example supabase/functions/.env
# R2 認証情報を記入後
supabase stop && supabase start
```

本番デプロイ:

```bash
supabase secrets set --env-file supabase/functions/.env
supabase functions deploy r2-presign-upload
supabase functions deploy r2-presign-download
supabase functions deploy sync-premium
supabase functions deploy delete-account
```

### r2-presign-upload

AWS SigV4 互換の **presigned PUT URL** を発行します。リクエストに `byte_size`（アップロード予定サイズ）が必須です。プラン別容量上限を超える場合は `403 storage_limit_exceeded` を返します。iOS クライアントは `Content-Type` で PUT する必要があります（署名と一致必須）。

### r2-presign-download

JWT 認証後、指定した `observation_id` の R2 オブジェクトに対する presigned GET URL を返します。Compare / Timelapse で Original が端末にない場合に使用します。

### sync-premium

StoreKit 2 購入トランザクションを `subscription_entitlements` に記録し、`user_profiles.plan` を更新します。

### delete-account

ユーザーの R2 オブジェクトを一括削除した後、Supabase Auth ユーザーを削除します。Settings 画面のアカウント削除から呼び出されます。

## 認証

Supabase Auth で **Apple** と **Google** プロバイダを有効にします。

- リダイレクト URL: `app.node.ios://auth-callback`
- Google（iOS ネイティブ）: Web / iOS の Client ID をカンマ区切りで登録し、**Skip nonce check** を有効化
- Apple（iOS ネイティブ）: `config.toml` の `client_id = "app.node.ios"`。OAuth Secret は不要（`secret = ""`）
- ローカル開発: プロジェクトルートの `.env` に Google 用の環境変数を設定
  - `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID`
  - `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_SECRET`
- 設定変更後は `supabase stop && supabase start` で再起動
