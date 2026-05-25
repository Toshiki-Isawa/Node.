# Node.

**植物の時間を残す** — 植物観測アーカイブアプリ

Node. は植物の成長・観測履歴を蓄積し、定点観測・成長比較・タイムライン・タイムラプスを通じて「植物を観測する体験そのもの」を価値化する iOS アプリです。

水やり通知や AI 診断ではなく、**観測履歴** を中心に据えた個人向けアーカイブ。Botanical Archive / Quiet Luxury をコンセプトに、写真主役・ダーク UI の静かな体験を目指しています。

---

## 主な機能

| 機能 | 説明 |
|------|------|
| Collection | 登録した植物のコレクション表示 |
| Camera | 高速撮影・即保存・オフライン対応 |
| Timeline | 時系列の観測記録 |
| Compare | 任意の時点間での成長比較 |
| Timelapse | 観測写真から端末内でタイムラプス生成・Export（クラウド非保存） |
| Quick Log | 観測以外の育成ログ記録 |

---

## リポジトリ構成

```
.
├── ios/              # SwiftUI + SwiftData クライアント
├── supabase/         # Postgres スキーマ・Edge Functions
├── design/           # デザインシステム・UI キット
└── specification.md  # 要件定義書
```

---

## 技術スタック

| レイヤー | 技術 |
|----------|------|
| クライアント | SwiftUI / SwiftData |
| バックエンド | Supabase（Auth + Postgres） |
| ストレージ | Cloudflare R2 |
| 認証 | Sign in with Apple |

**アーキテクチャ方針:** Local-first。Seed（無料・3 GB）/ Archive（50 GB）/ Conservatory（500 GB）の 3 プラン構成。

```
Collection → Camera → ローカル保存 → SyncEngine → Supabase + R2
```

---

## はじめに

### 前提条件

- Xcode 15 以上
- iOS 17 以上
- Supabase プロジェクト
- Cloudflare R2 バケット（画像ストレージ）

### セットアップ

1. **iOS アプリ** — [ios/README.md](ios/README.md) を参照
   - `Secrets.example.xcconfig` をコピーして Supabase 認証情報を設定
   - Sign in with Apple の有効化

2. **Supabase バックエンド** — [supabase/README.md](supabase/README.md) を参照
   - マイグレーションの適用
   - Edge Functions のデプロイ（`r2-presign-upload` / `sync-premium`）
   - R2 シークレットの設定

3. **デザインシステム** — [design/README.md](design/README.md) を参照

---

## ドキュメント

| ファイル | 内容 |
|----------|------|
| [specification.md](specification.md) | 要件定義書（プロダクト思想・機能・非機能要件） |
| [ios/README.md](ios/README.md) | iOS アプリのセットアップ・アーキテクチャ |
| [supabase/README.md](supabase/README.md) | バックエンド・Edge Functions |
| [design/README.md](design/README.md) | カラー・タイポグラフィ・UI キット |

---

## ライセンス

未定
