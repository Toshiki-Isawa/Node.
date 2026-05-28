# Claude 向け開発ガイド

このリポジトリで作業する Claude (および将来の自分) 向けの規約。
Node. は **日本語 + 英語 (US/UK/AU/CA)** で配信する iOS アプリ。**新規 UI / 新規ユーザー向け文字列を追加するときは、必ずローカライズもセットで行うこと。**

---

## ローカライズ規約 (必須)

### 大原則

> **ユーザーに見える日本語文字列をコードに書いたら、それは未完成のコミットである。**
> 同じ PR / 同じ作業セッション内で英訳まで投入してビルドが通る状態にする。

### 文字列の置き場所

| 種類 | 置き場所 | キー形式 |
|------|---------|---------|
| アプリ UI 全般 | [ios/Node/Localizable.xcstrings](ios/Node/Localizable.xcstrings) | 日本語原文 (development region = ja) |
| Info.plist (権限文・Bundle 名等) | [ios/Node/InfoPlist.xcstrings](ios/Node/InfoPlist.xcstrings) | Info.plist のキー名 (例: `NSCameraUsageDescription`) |
| プライバシーポリシー | [web/privacy.html](web/privacy.html) + [ios/Node/Resources/privacy.html](ios/Node/Resources/privacy.html) (1 ページに日英並記) と [docs/privacy-policy.md](docs/privacy-policy.md) | — |

### コードに新規日本語を書くときの判断フロー

#### SwiftUI の `Text` / `Button` / `.navigationTitle` / `.alert` 等 (LocalizedStringKey 自動)

```swift
Text("水やり完了")          // ✅ そのまま OK (Localizable.xcstrings にキー追加)
Button("削除") { ... }      // ✅
.navigationTitle("設定")    // ✅
```

#### 自前のコンポーネント・関数引数

**新規パラメータは原則 `LocalizedStringKey` で受ける。** `String` で受けると verbatim (翻訳されない) 出力になる。

```swift
// ✅ Good
struct MetaLabel: View {
    let text: LocalizedStringKey
    ...
}
MetaLabel(text: "観測範囲")        // リテラル → 自動抽出される
MetaLabel(text: "\(plantName)")    // 動的 String は補間でラップ (key = "%@")

// ❌ Bad (現存している `String` 引数を使い続ける)
let label: String = "観測範囲"
MetaLabel(text: label)             // verbatim、英訳されない
```

既存コンポーネントの代表は [ios/Node/Components/NodeComponents.swift](ios/Node/Components/NodeComponents.swift):
`MetaLabel` / `NodeChip` / `NodePrimaryButton` / `NodeSecondaryButton` / `NodeTextField` / `EmptyStateView` / `NodeRecordDateSection` — すべて `LocalizedStringKey`。

#### SwiftUI 外 (Service / ViewModel / Model のラベル・エラーメッセージ・Notification body)

`String(localized:)` で囲む。これで `String` 型のまま、xcstrings 経由で翻訳される。

```swift
// ✅ Good
enum SyncStatus {
    var label: String {
        switch self {
        case .syncing: return String(localized: "同期中")
        ...
        }
    }
}

// CareNotificationService
content.title = String(localized: "今日の水やり")
content.body  = String(localized: "\(count) 株が水やり時期です: \(names)")

// Error
errorMessage = String(localized: "保存に失敗しました。")
```

#### 動的 String を `Text` / コンポーネントに渡すとき

```swift
// ✅ Good (interpolation で LocalizedStringKey 化)
MetaLabel(text: "\(viewModel.captureModeHint)")

// ❌ Bad (Text の verbatim init になる)
MetaLabel(text: viewModel.captureModeHint)
```

**ただし** 渡している `String` 変数自体がローカライズ済み (上記 `String(localized:)` パターンで生成された) 場合のみ意味がある。元が生の日本語リテラルなら、生成元を `String(localized:)` 化するのが先。

### 文字列補間と xcstrings キーの対応

Swift の `\(...)` は **コンパイル時に format specifier に変換** されて xcstrings のキーになる:

| Swift コード | xcstrings のキー |
|-------------|-----------------|
| `Int` (`\(count)`) | `%lld` |
| `String` (`\(name)`) | `%@` |
| `Double` (`\(value)`) | `%lf` |

```swift
String(localized: "\(plantCount) 株")
// → xcstrings キー = "%lld 株"
// → en 翻訳例 (plural):
//   one:   "%lld plant"
//   other: "%lld plants"
```

### 複数形 (plural)

英語では単数・複数で語尾が変わる箇所は **必ず** xcstrings の `variations.plural` で記述する。
代表ケース: 「N 株」「N 日」「N 日前」「N 日遅れ」「N 回」「N 件」など。

例: [ios/Node/Localizable.xcstrings](ios/Node/Localizable.xcstrings) の `"%lld 株が水やり時期です: %@"`, `"%lld日前"` などを参照。

### 日時・数値フォーマット

- 日付フォーマットは [NodeDateFormat.swift](ios/Node/Core/DesignSystem/NodeDateFormat.swift) を使う。Locale ハードコードは禁止 (`Locale.current` で動作する状態を維持)。
- `Calendar` を新規生成するときも `cal.locale = .current`。

### Info.plist の新規キー

権限を増やしたり Bundle 名を変えるときは:
1. `project.yml` の `INFOPLIST_KEY_*` に**日本語の値**を入れる (development region のデフォルト)
2. [ios/Node/InfoPlist.xcstrings](ios/Node/InfoPlist.xcstrings) に同じキー名で日英両エントリを追加

### プライバシーポリシーの改定

文言を変更した場合は **3 ファイルすべて** を同期させる:
- [web/privacy.html](web/privacy.html) (Notion 公開用と同期)
- [ios/Node/Resources/privacy.html](ios/Node/Resources/privacy.html) (アプリ内表示)
- [docs/privacy-policy.md](docs/privacy-policy.md) (Markdown 原本)

それぞれの「最終更新日 / Last updated」と施行日も更新する。

---

## 作業前後のセルフチェック

新規 UI / 新規ユーザー向け文字列を含む PR を出す前に実行:

```bash
# 1. ローカライズ漏れスキャン (xcstrings に未登録の日本語リテラルを探す)
cd ios
grep -rnE '"[ぁ-んァ-ン一-龯]' Node --include="*.swift" \
  | grep -vE 'String\(localized:|Text\(|Button\(|MetaLabel\(|NodeChip\(|NodePrimaryButton\(|NodeSecondaryButton\(|NodeTextField\(|EmptyStateView\(|NodeRecordDateSection\(|placeholder:|hint:|/\*|^\s*///|^\s*//'
# → 何も出ない or 既知の verbatim (ログ・コメント) だけならOK

# 2. xcstrings 未翻訳チェック
python3 -c "
import json
data = json.load(open('Node/Localizable.xcstrings'))
miss = [k for k,v in data['strings'].items()
        if v.get('shouldTranslate') != False
        and 'en' not in v.get('localizations', {})]
print('Missing en:', len(miss))
for k in miss[:20]: print(repr(k))
"

# 3. ビルドして en.lproj に翻訳が compile されることを確認
xcodebuild -project Node.xcodeproj -scheme Node \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build 2>&1 | tail -3
# → BUILD SUCCEEDED
plutil -p ~/Library/Developer/Xcode/DerivedData/Node-*/Build/Products/Debug-iphonesimulator/Node.app/en.lproj/Localizable.strings | wc -l
```

---

## その他の規約

### Xcode プロジェクトの再生成

`project.yml` を変更したら必ず `cd ios && xcodegen` を実行 → `Node.xcodeproj/project.pbxproj` の差分もコミットする。

### コミットメッセージ

直近の履歴に従い **日本語の conventional commit** (`feat:` `fix:` `docs:` `chore:` `refactor:` `test:`)。
- タイトル: 1 行・体言止めまたは「〜する/〜を XX に変更」
- 本文: 「何を / なぜ」を箇条書き

### v1.0 / v1.1 切替

機能の出し分けは [ios/Node/Core/Config/ReleaseConfig.swift](ios/Node/Core/Config/ReleaseConfig.swift) のフラグで管理。
詳細は [ios/README.md](ios/README.md) の「リリース設定」セクションを参照。

### 関連ドキュメント

- 全体構成: [README.md](README.md)
- 要件定義: [specification.md](specification.md)
- iOS セットアップ: [ios/README.md](ios/README.md)
- App Privacy: [docs/app-privacy-labels.md](docs/app-privacy-labels.md)
- v1.0 スクリーンショット計画: [docs/v1.0-app-store-screenshots.md](docs/v1.0-app-store-screenshots.md)
