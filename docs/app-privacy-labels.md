# App Store Privacy Nutrition Labels 申告ガイド

Node. iOS（`app.node.ios`）を App Store Connect に登録する際の **App Privacy** 申告のたたき台です。  
実際の申告は [Apple のデータ型定義](https://developer.apple.com/app-store/app-privacy-details/) および各 SDK の最新ドキュメントに合わせて最終確認してください。

---

## 1. データ収集の有無

| 質問 | 回答 |
|------|------|
| あなたまたは第三者パートナーはこのアプリからデータを収集しますか？ | **はい** |

サインインなし・PostHog 未設定・Seed 以外（広告なし）でも、**Sign in with Apple / Google 利用時** および **AdMob（Seed の Timelapse Export 時）** でデータが収集されます。

---

## 2. 収集データの分類（たたき台）

### 2.1 連絡先情報

| データ型 | 収集 | リンク | トラッキング | 用途 |
|----------|------|--------|--------------|------|
| メールアドレス | 場合あり | はい（アカウント） | いいえ | アプリ機能、認証 |

Sign in with Apple / Google 経由。Apple リレーアドレスの場合あり。

### 2.2 ユーザーコンテンツ

| データ型 | 収集 | リンク | トラッキング | 用途 |
|----------|------|--------|--------------|------|
| 写真または動画 | はい | はい | いいえ | アプリ機能 |
| その他ユーザーコンテンツ | はい | はい | いいえ | アプリ機能 |

植物観測写真、メモ、育成ログ。タイムラプス MP4 は端末内生成のみ（クラウド非保存）。

### 2.3 識別子

| データ型 | 収集 | リンク | トラッキング | 用途 |
|----------|------|--------|--------------|------|
| ユーザー ID | はい | はい | いいえ | アプリ機能、分析 |
| デバイス ID | 場合あり | いいえ | **場合あり** | 広告 |

ユーザー ID: Supabase Auth UUID。  
デバイス ID: AdMob / ATT 許可時の IDFA 等。**Seed プランの Export 時のみ**。

### 2.4 購入

| データ型 | 収集 | リンク | トラッキング | 用途 |
|----------|------|--------|--------------|------|
| 購入履歴 | はい | はい | いいえ | アプリ機能 |

StoreKit トランザクション ID。決済は Apple が処理。

### 2.5 使用状況データ

| データ型 | 収集 | リンク | トラッキング | 用途 |
|----------|------|--------|--------------|------|
| 製品の操作 | 場合あり | いいえ | いいえ | 分析 |

PostHog 有効時: 広告プリロード・表示・完了等のイベント（`plan`, `retry_count`, `error_code`）。

### 2.6 診断

| データ型 | 収集 | リンク | トラッキング | 用途 |
|----------|------|--------|--------------|------|
| クラッシュデータ | いいえ* | — | — | — |
| パフォーマンスデータ | いいえ* | — | — | — |
| その他診断データ | 場合あり | いいえ | いいえ | 分析 |

\* アプリ独自のクラッシュレポート SDK は未導入。Xcode Organizer / App Store Connect のクラッシュは Apple 経由。

PostHog 有効時: 広告読み込み失敗の `error_code` のみ。

---

## 3. 第三者 SDK 別チェックリスト

### Google Mobile Ads SDK（AdMob）

- **対象ユーザー**: Seed プランの Timelapse Export 時のみ
- **ATT**: 表示あり（`NSUserTrackingUsageDescription` 設定済み）
- **UMP**: GDPR / EEA 向け同意フォーム対応
- **参考**: [Google AdMob iOS プライバシー](https://developers.google.com/admob/ios/privacy)

申告候補: デバイス ID、使用状況データ、診断データ、位置情報（おおよその位置）— AdMob の最新ガイドで要確認。

### PostHog iOS SDK

- **送信イベント**: 広告関連 7 種のみ（`AnalyticsService.swift` 参照）
- **未設定時**: no-op（送信なし）
- **参考**: [PostHog Privacy](https://posthog.com/privacy)

申告候補: 製品の操作、診断データ（エラーコード）。トラッキング用途には該当しない想定。

### Supabase / Cloudflare R2

- アプリ機能のためのデータ保存。トラッキング目的ではない。
- ユーザーコンテンツ、識別子、連絡先情報として申告。

### Google Sign-In / Sign in with Apple

- 認証目的。Apple / Google の標準フロー。

---

## 4. トラッキングの申告

| 質問 | 回答 |
|------|------|
| あなたまたは第三者パートナーはトラッキングのためにデータを使用しますか？ | **はい**（AdMob 利用時） |

Seed プランで Timelapse Export 時に AdMob を使用。Archive / Conservatory では AdMob SDK を呼び出さない。

App Store Connect の **Privacy Nutrition Labels** と **App Tracking Transparency** の設定を一致させてください。

---

## 5. プライバシーポリシー URL

App Store Connect の「プライバシーポリシー URL」には、公開済みの以下いずれかを設定します。

| ファイル | 用途 |
|----------|------|
| [web/privacy.html](../web/privacy.html) | Web 公開用（App Store 申告 URL に推奨） |
| [docs/privacy-policy.md](./privacy-policy.md) | リポジトリ内 Markdown 正本 |

iOS アプリ内リンク: `PRIVACY_POLICY_URL`（`Secrets.xcconfig`）に公開 URL を設定。未設定時はアプリ同梱 HTML を表示。

---

## 6. 申告前チェックリスト

- [ ] `docs/privacy-policy.md` 第 2 条（運営者・連絡先）を記入
- [ ] `web/privacy.html` をホスティングし URL を取得
- [ ] App Store Connect にプライバシーポリシー URL を登録
- [ ] `Secrets.xcconfig` の `PRIVACY_POLICY_URL` を本番 URL に設定
- [ ] AdMob コンソールでアプリのプライバシー設定を完了
- [ ] PostHog プロジェクトのデータ保持期間を確認
- [ ] Privacy Nutrition Labels を Seed / 有料プラン両方の利用パスでレビュー

---

## 7. 関連ドキュメント

- [プライバシーポリシー](./privacy-policy.md)
- [iOS README](../ios/README.md)
- [要件定義書 §8.3.3](../specification.md) — プライバシー / コンプライアンス方針
