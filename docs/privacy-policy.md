# Node. プライバシーポリシー

| 項目 | 内容 |
|------|------|
| サービス名 | Node.（ノード） |
| 対象 | iOS アプリ「Node.」（v1.0） |
| 最終更新日 | 2026年5月28日 |
| 施行日 | 2026年5月28日 |

---

## 1. はじめに

Node.（以下「本アプリ」）は、植物の観測・成長記録を蓄積するための iOS アプリケーションです。本プライバシーポリシー（以下「本ポリシー」）は、本アプリの利用にあたり、当方がどのような情報を取得し、どのように利用・保管・共有するかを説明するものです。

**v1.0 では、観測・記録データ（植物名・写真・メモ等）はお使いの iOS 端末内のみに保存され、当方または第三者パートナーのサーバーへ送信されません。** 一方で、アプリ改善のための匿名行動イベント（画面遷移・ボタンタップ回数・通知許可状態など）を PostHog に送信します（Settings からいつでも停止可能。詳細は第 3.3 条）。

本アプリを利用することにより、本ポリシーに同意したものとみなします。同意いただけない場合は、本アプリの利用を中止してください。

## 2. 運営者

| 項目 | 内容 |
|------|------|
| 運営者 | Node. Project |
| お問い合わせ | support@node-app.jp |

個人情報の取り扱いに関するお問い合わせは、上記連絡先までご連絡ください。

---

## 3. 取得する情報

本アプリでは、機能の提供に必要な範囲で、以下の情報を **端末内で** 取得・生成します。当方がサーバー経由で収集するデータはありません。

### 3.1 ユーザーが記録するコンテンツ

| 情報 | 内容 | 保存先 |
|------|------|--------|
| 植物情報 | 植物名、種・品種、取得日、水やり間隔 | 端末内（SwiftData） |
| 観測記録 | 撮影写真、メモ、観測日時 | 端末内 |
| 育成ログ | 水やり・施肥・植え替え等の種別、メモ、記録日時 | 端末内 |
| タイムラプス動画 | 観測写真から端末内（AVFoundation）で生成する MP4 | 端末内（Export 先はユーザー任意） |

観測写真には、植物そのもののほか、背景や撮影環境が写り込む場合があります。ユーザー自身の判断で記録内容を管理してください。

**注意:** アプリ削除・機種変更によりデータが失われる場合があります。Settings 画面にその旨を表示しています。

### 3.2 端末の権限・アクセス

本アプリは、以下の端末機能へのアクセスを求めます。いずれも端末内処理のために使用し、当方サーバーには送信されません。

| 権限 | 目的 |
|------|------|
| カメラ | 観測写真の撮影 |
| 写真ライブラリ（読み取り） | 観測写真の保存・共有 |
| 写真ライブラリ（追加） | タイムラプス動画の保存 |
| 通知 | 水やりリマインダー（Settings で ON にした場合のみ） |

### 3.3 匿名の使用状況データ（PostHog）

アプリの改善・品質維持のため、第三者サービス **PostHog**（PostHog, Inc.）を通じて、本アプリ内での操作に関する匿名のイベントデータを取得します。

| 取得する情報 | 例 |
|--------------|----|
| イベント | 画面遷移、ボタンタップ、通知許可結果、保存件数などの操作カウント |
| 端末メタ情報 | アプリバージョン、iOS バージョン、デバイスモデル識別子 |
| 匿名識別子 | 端末ローカルで生成される UUID（他社サービスや個人プロファイルに紐づけない） |

**送信しない情報**:

- 植物名・学名・メモ等のユーザー記録
- 観測写真・タイムラプス動画
- 位置情報・連絡先・電話番号・メールアドレス

PostHog は first-party 分析として利用します。iOS の App Tracking Transparency 許可は求めません。

#### オプトアウト

本アプリ Settings 画面の「アプリ改善」セクションの **「使用状況の送信」** トグルを OFF にすると、以降のイベント送信を停止できます。

---

## 4. 情報の利用目的

取得した情報は、以下の目的で **端末内** で利用します。

1. 本アプリの提供（観測記録、タイムライン、Compare、Timelapse、Quick Log 等）
2. お問い合わせへの対応
3. 法令遵守、利用規約違反への対応

---

## 5. 第三者への提供

v1.0 では、当方がユーザーの観測記録（植物名・写真・メモ等）を第三者のサーバーへ送信することはありません。前条の匿名使用状況データのみ PostHog（PostHog, Inc.）に送信されます。

当方は、以下の場合を除き、ユーザーの個人情報を第三者に販売または提供しません。

1. 法令に基づく開示請求への対応
2. 人の生命・身体・財産の保護に必要な場合
3. 合併・事業譲渡等により事業が承継される場合

---

## 6. 情報の保存場所と保管期間

| データ種別 | 保存場所 |
|------------|----------|
| 植物・観測・育成ログ・タイムラプス | お使いの iOS 端末のみ |

データは、アプリ削除または端末内データの消去まで端末に残ります。当方はクラウド上にバックアップを保持しません。

---

## 7. セキュリティ

当方は、端末内データの保護のため、iOS の標準的なセキュリティ機能（アプリサンドボックス、端末の暗号化等）に依存します。

ただし、端末の紛失・盗難・アプリ削除等によりデータが失われる可能性があること、および電子保存の性質上、完全な安全性を保証するものではないことをご理解ください。

---

## 8. ユーザーの権利と選択肢

### 8.1 端末内での利用

v1.0 では、サインイン機能を提供しません。観測・記録データは **端末内のみ** に保存されます。アプリを削除したり機種変更をすると、データを引き継げません。

### 8.2 端末内データの削除

端末内のデータを消去するには、本アプリ内の記録削除機能を利用するか、iOS の設定からアプリデータを削除、またはアプリをアンインストールしてください。

### 8.3 開示・訂正・削除等の請求

保有個人データの開示、訂正、利用停止、削除等を希望される場合は、第 2 条のお問い合わせ先までご連絡ください。本人確認のうえ、法令に従い対応します。

---

## 9. 未成年者

本アプリは、13 歳未満（またはお住まいの地域で定められた最低年齢未満）の方を対象としていません。当方が意図せず当該年齢未満の方の個人情報を取得したことが判明した場合、速やかに削除します。

---

## 10. 本ポリシーの変更

当方は、法令の改正、サービス内容の変更等に応じて、本ポリシーを改定することがあります。重要な変更がある場合は、本アプリ内で告知し、改定後の施行日を明示します。改定後に本アプリを継続利用した場合、改定後のポリシーに同意したものとみなします。

---

## 11. 附則

### 11.1 App Store プライバシー表示について

v1.0 では App Store Connect の App Privacy に **「使用状況データを収集」（リンクなし・トラッキングなし）** を申告してください。詳細は [App Store 申告ガイド](./app-privacy-labels.md) を参照してください。

### 11.2 関連ドキュメント

- [App Store 申告ガイド](./app-privacy-labels.md) — Privacy Nutrition Labels
- [公開 URL](https://node-app.jp/privacy/) — App Store Connect 申告用
- [同梱 HTML](../ios/Node/Resources/privacy.html) — v1.0 アプリ内表示
- [Web 公開版](../web/privacy.html) — リポジトリ内 HTML（Notion と同期用）

---

**以上**

---

# Node. Privacy Policy (English)

| Item | Detail |
|------|------|
| Service | Node. |
| Scope | iOS app "Node." (v1.0) |
| Last updated | 2026-05-28 |
| Effective | 2026-05-28 |

---

## 1. Introduction

Node. (the "App") is an iOS application for archiving plant observations and growth records. This Privacy Policy describes what information we collect, and how it is used, stored, and shared when you use the App.

**In v1.0, observation and record data (plant names, photos, notes, etc.) is stored only on your iOS device and is not transmitted to our servers or any third-party partners' servers.** We do, however, send anonymous behavioral events (screen transitions, button-tap counts, notification-permission state, etc.) to PostHog for app improvement (can be turned off in Settings at any time; see Section 3.3).

By using the App, you agree to this Policy. If you do not agree, please discontinue use of the App.

## 2. Operator

| Item | Detail |
|------|------|
| Operator | Node. Project |
| Contact | support@node-app.jp |

For inquiries regarding the handling of personal data, please contact us at the address above.

## 3. Information We Collect

We collect or generate the following information **only on your device**, to the extent necessary to provide the App's features. No data is collected via our servers.

### 3.1 User Content

| Information | Detail | Stored at |
|------|------|------|
| Plant info | Plant name, species/cultivar, acquisition date, watering interval | On device (SwiftData) |
| Observation records | Captured photos, notes, observation date | On device |
| Care logs | Watering, fertilizing, repotting, etc. | On device |
| Timelapse videos | MP4 generated on device from observation photos | On device |

Observation photos may include the plant itself as well as background and surrounding environment. Manage your records at your own discretion.

**Note:** Data may be lost if you delete the App or switch devices. This is also shown on the Settings screen of the App.

### 3.2 Device Permissions

| Permission | Purpose |
|------|------|
| Camera | Capturing observation photos |
| Photo Library (read) | Saving and sharing observation photos |
| Photo Library (add) | Saving timelapse videos |
| Notifications | Watering reminders (only if enabled in Settings) |

### 3.3 Anonymous Usage Data (PostHog)

To improve and maintain the quality of the App, we collect anonymous event data about in-app actions via the third-party service **PostHog** (PostHog, Inc.).

| Collected | Examples |
|------|------|
| Events | Screen transitions, button taps, notification permission results, action counts |
| Device metadata | App version, iOS version, device model identifier |
| Anonymous identifier | A UUID generated locally on device; not linked to any other service or personal profile |

**Not collected:** Plant names, species, notes, or any user record content; observation photos and timelapse videos; location, contacts, phone number, or email address.

PostHog is used as first-party analytics. We do not request iOS App Tracking Transparency permission.

**Opt-out:** Turn off the "Send usage data" toggle under the "App Improvement" section of the App's Settings screen to stop further event transmission.

## 4. Purpose of Use

1. Providing the App (observation records, Timeline, Compare, Timelapse, Quick Log, etc.)
2. Responding to inquiries
3. Compliance with laws, and response to violations of the Terms of Service

## 5. Disclosure to Third Parties

In v1.0, we do not send user observation records (plant names, photos, notes, etc.) to any third-party servers. Only the anonymous usage data described in Section 3.3 is sent to PostHog (PostHog, Inc.).

We will not sell or provide your personal data to third parties except in the following cases:

1. In response to legally mandated disclosure requests
2. When necessary to protect a person's life, body, or property
3. When the business is succeeded due to merger, business transfer, etc.

## 6. Storage Location and Retention

| Data Type | Stored at |
|------|------|
| Plants, observations, care logs, timelapses | Your iOS device only |

Data remains on the device until the App is deleted or the in-device data is erased. We do not maintain cloud backups.

## 7. Security

We rely on the standard security mechanisms of iOS (app sandbox, device encryption, etc.) to protect on-device data. Please understand that data may be lost due to device loss, theft, or App deletion, and that no electronic storage system can guarantee absolute security.

## 8. User Rights and Choices

### 8.1 On-device Use

In v1.0, no sign-in is provided. Observation and record data is stored **only on the device**. Data cannot be carried over if you delete the App or switch devices.

### 8.2 Deleting On-device Data

You can erase data via the in-app record deletion features, the iOS Settings app's "Delete App Data" function, or by uninstalling the App.

### 8.3 Disclosure, Correction, or Deletion Requests

Please contact us at the address in Section 2. We will respond in accordance with applicable law after verifying your identity.

## 9. Minors

The App is not intended for individuals under the age of 13 (or the minimum age set by the law of your jurisdiction).

## 10. Changes to This Policy

We may revise this Policy in response to legal changes or changes to the service. For material changes, we will announce them within the App and state the new effective date.

---

**End of Document**
