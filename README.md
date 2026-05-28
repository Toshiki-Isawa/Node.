# Node.

**植物の時間を残す** — 植物観測アーカイブアプリ

Node. は植物の成長・観測履歴を蓄積し、定点観測・成長比較・タイムライン・タイムラプスを通じて「植物を観測する体験そのもの」を価値化する iOS アプリです。

水やり通知や AI 診断ではなく、**観測履歴** を中心に据えた個人向けアーカイブ。Botanical Archive / Quiet Luxury をコンセプトに、写真主役・ダーク UI の静かな体験を目指しています。

---

## 主な機能

| 機能 | 説明 |
|------|------|
| Collection | 登録した植物のコレクション表示（カテゴリ・検索・水やり優先ソート） |
| Camera | 高速撮影・即保存・オフライン対応 |
| Timeline | 時系列の観測記録・育成ログ |
| Compare | 任意の時点間での成長比較（スライダー） |
| Timelapse | 観測写真から端末内でタイムラプス生成・Export（クラウド非保存） |
| Quick Log | 撮影なしでの育成ログ記録（水やり・施肥・植え替え等） |
| Care Calendar | 植物ごとのケア履歴を月間カレンダーで表示 |
| Settings | v1.0: 端末内保存・ローカル容量。v1.1: プラン・同期・購入 |

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
| バックエンド | Supabase（Auth + Postgres + Edge Functions） |
| ストレージ | Cloudflare R2 |
| 認証 | Sign in with Apple / Google Sign-In |
| 課金 | StoreKit 2 |
| タイムラプス | AVFoundation（端末内生成。クラウド非保存） |

**アーキテクチャ方針:** Local-first。**v1.0** は端末内無料。**v1.1** 以降、Archive / Conservatory で有料クラウド同期。

```
v1.0: Collection → Camera → ローカル保存（端末内完結）
v1.1: Collection → Camera → ローカル保存 → SyncEngine → Supabase + R2（有料のみ）
```

- v1.0: サインインなし。撮影・保存・Compare / Timelapse / Quick Log は端末内で完結
- v1.1: 有料プラン購入・サインイン後にクラウドバックアップ。Seed は引き続き端末内のみ
- 有料同期後、Original は R2 を正本として端末から退避。Compare / Timelapse は必要時 R2 から取得

---

## リリース段階

| 段階 | 内容 | インフラ |
|------|------|----------|
| **v1.0** | ローカル無料。`ReleaseConfig` で同期・課金 OFF | $0/月 |
| **v1.1** | Archive / Conservatory のクラウド同期 + StoreKit | 有料ユーザー分のみ |

詳細: [ios/README.md](ios/README.md) の「リリース設定」、`ios/Node/Core/Config/ReleaseConfig.swift`

---

## プラン構成（v1.1 以降の有料同期）

| プラン | 月額 | クラウド容量 | 同期 | Timelapse Export |
|--------|------|-------------|------|------------------|
| Seed | 無料 | —（端末内のみ） | × | 720p |
| Archive | ¥480 | 50 GB | Original | 4K |
| Conservatory | ¥980 | 500 GB | Original | 4K |

StoreKit プロダクト ID: `app.node.archive.monthly` / `app.node.conservatory.monthly`

---

## はじめに

### 前提条件

- Xcode 15 以上
- iOS 17 以上
- **v1.1 以降:** Supabase プロジェクト、Cloudflare R2 バケット

### セットアップ

1. **iOS アプリ** — [ios/README.md](ios/README.md) を参照
   - v1.0 ローカルリリース: Supabase 設定は不要（`ReleaseConfig` 参照）
   - v1.1 以降: `Secrets.example.xcconfig` をコピーして認証情報を設定

2. **Supabase バックエンド（v1.1 以降）** — [supabase/README.md](supabase/README.md) を参照
   - マイグレーションの適用
   - Edge Functions のデプロイ（4 関数）
   - R2 シークレットの設定

3. **デザインシステム** — [design/README.md](design/README.md) を参照

---

## ドキュメント

| ファイル | 内容 |
|----------|------|
| [specification.md](specification.md) | 要件定義書（プロダクト思想・機能・非機能要件） |
| [docs/privacy-policy.md](docs/privacy-policy.md) | プライバシーポリシー |
| [docs/app-privacy-labels.md](docs/app-privacy-labels.md) | App Store Privacy Nutrition Labels 申告ガイド |
| [docs/v1.0-app-store-screenshots.md](docs/v1.0-app-store-screenshots.md) | v1.0 App Store スクリーンショット計画（Before/After 中心の 6 枚） |
| [ios/README.md](ios/README.md) | iOS アプリのセットアップ・アーキテクチャ |
| [supabase/README.md](supabase/README.md) | バックエンド・Edge Functions |
| [design/README.md](design/README.md) | カラー・タイポグラフィ・UI キット |

---

## ライセンス

未定
