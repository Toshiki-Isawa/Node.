# Node. 用 Supabase バックエンド

## マイグレーション

```bash
supabase db push
```

`plants`、`observations`、`growth_logs`、`timelapse_jobs` テーブルと RLS を作成します。

## Edge Functions

| 関数 | 用途 |
|------|------|
| `r2-presign-upload` | 観測画像用の R2 presigned PUT URL を返す |
| `generate-timelapse` | タイムラプスジョブを作成する。`job_id` でポーリング |

### シークレット（本番）

Supabase ダッシュボードまたは CLI で設定します。

- `R2_ACCOUNT_ID`、`R2_BUCKET`、`R2_ACCESS_KEY_ID`、`R2_SECRET_ACCESS_KEY`、`R2_PUBLIC_BASE_URL`
- `TIMELAPSE_STUB_URL` — FFmpeg ワーカーなしの Closed Beta 向け、任意のスタブ MP4 URL

### デプロイ

```bash
supabase functions deploy r2-presign-upload
supabase functions deploy generate-timelapse
```

## 認証

Supabase Auth の設定で Apple プロバイダを有効にします。リダイレクト URL: `app.node.ios://auth-callback`
