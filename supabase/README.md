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

`plants`、`observations`、`growth_logs`、`user_profiles`、`storage_objects`、`subscription_entitlements` と RLS を作成します。プランは `seed` / `archive` / `conservatory` のみです。

タイムラプスは iOS 端末内で生成し、クラウドには保存しません。

## Edge Functions

| 関数 | 用途 |
|------|------|
| `r2-presign-upload` | 観測画像用の R2 presigned PUT URL を返す。Seed 3 GB / Archive 50 GB / Conservatory 500 GB の上限をチェック |
| `sync-premium` | StoreKit 購入後に Archive / Conservatory プランをサーバーへ同期 |

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
```

`r2-presign-upload` は AWS SigV4 互換の **presigned PUT URL** を発行します。リクエストに `byte_size`（アップロード予定サイズ）が必須です。プラン別容量上限を超える場合は `403 storage_limit_exceeded` を返します。iOS クライアントは `Content-Type` で PUT する必要があります（署名と一致必須）。

### デプロイ

```bash
supabase functions deploy r2-presign-upload
supabase functions deploy sync-premium
```

## 認証

Supabase Auth で **Apple** と **Google** プロバイダを有効にします。

- リダイレクト URL: `app.node.ios://auth-callback`
- Google（iOS ネイティブ）: Web / iOS の Client ID をカンマ区切りで登録し、**Skip nonce check** を有効化
- Apple（iOS ネイティブ）: `config.toml` の `client_id = "app.node.ios"`。OAuth Secret は不要（`secret = ""`）
- ローカル開発: プロジェクトルートの `.env` に Google 用の環境変数を設定
- 設定変更後は `supabase stop && supabase start` で再起動
