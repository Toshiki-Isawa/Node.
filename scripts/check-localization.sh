#!/usr/bin/env bash
# ローカライズ漏れチェック
# - Swift 内の日本語リテラルでローカライズ API を経由していないものを検出
# - Localizable.xcstrings / InfoPlist.xcstrings に en 翻訳が無いキーを検出
#
# Usage:
#   ./scripts/check-localization.sh         # チェックのみ
#   ./scripts/check-localization.sh --build # 上記 + ビルド + en.lproj 検証
#
# CLAUDE.md のローカライズ規約に従って実装。

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT/ios"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

EXIT_CODE=0

bold "==> 1. Swift 内の日本語リテラル: ローカライズ API 経由でないものをスキャン (warning)"
# ローカライズ API 経由 (Text/Button/String(localized:) 等) や、コメント・ログ・systemImage 等を除外
# 注: LocalizedStringKey 型のプロパティ/関数引数を完全に判定できないため、
#     ここでヒットしても誤検出の可能性が高い。真の合格基準は §2 の xcstrings カバレッジ。
NAKED=$(grep -rnE '"[ぁ-んァ-ン一-龯][^"]*"' Node --include="*.swift" \
  | grep -vE 'String\(localized:|Text\(|Button\(|MetaLabel\(|NodeChip\(|NodePrimaryButton\(|NodeSecondaryButton\(|NodeTextField\(|EmptyStateView\(|NodeRecordDateSection\(|placeholder:|hint:|"comment"|/\*|^\s*///|^\s*//|\.navigationTitle\(|\.alert\(|\.accessibilityLabel\(|SettingsCard\(title:|accountActionRow\(|appRow\(|filterChip\(|statItem\(|statusItem\(|timelapseStatusItem\(|summaryItem\(|TimelineRowActionsMenu\(|cardHeader\(|TextField\(|label:|title:|subtitle:|message:|hint:|badge:|editLabel:|return ' \
  || true)

if [ -n "$NAKED" ]; then
  yellow "  以下の日本語リテラルが見つかりました (LocalizedStringKey 受け渡しの場合は誤検出):"
  echo "$NAKED" | sed 's/^/    /'
  yellow "  ※ 警告のみ。§2 の xcstrings カバレッジが OK ならビルド時に正しく英訳されます。"
else
  green "  OK (スキャン対象なし)"
fi

bold "==> 2. Localizable.xcstrings の英訳カバレッジ"
python3 - <<'PY'
import json, sys
with open('Node/Localizable.xcstrings') as f:
    data = json.load(f)
strings = data.get('strings', {})
missing_en = []
new_state = []
for k, v in strings.items():
    if v.get('shouldTranslate') == False:
        continue
    locs = v.get('localizations', {})
    if 'en' not in locs:
        missing_en.append(k)
        continue
    en = locs['en']
    if 'stringUnit' in en and en['stringUnit'].get('state') == 'new':
        new_state.append(k)
total = len(strings)
print(f"  全 {total} エントリ / 英訳欠落: {len(missing_en)} / state=new: {len(new_state)}")
if missing_en or new_state:
    for k in missing_en[:15]:
        print(f"    [no en] {k!r}")
    for k in new_state[:15]:
        print(f"    [state=new] {k!r}")
    sys.exit(2)
PY
EN_RC=$?
if [ $EN_RC -ne 0 ]; then
  EXIT_CODE=1
else
  green "  OK"
fi

bold "==> 3. InfoPlist.xcstrings の英訳カバレッジ"
python3 - <<'PY'
import json, sys
with open('Node/InfoPlist.xcstrings') as f:
    data = json.load(f)
strings = data.get('strings', {})
missing = []
for k, v in strings.items():
    locs = v.get('localizations', {})
    if 'en' not in locs:
        missing.append(k)
        continue
    en = locs['en']
    if 'stringUnit' in en and en['stringUnit'].get('state') == 'new':
        missing.append(k)
if missing:
    print(f"  英訳欠落 {len(missing)}:")
    for k in missing:
        print(f"    {k}")
    sys.exit(2)
else:
    print(f"  全 {len(strings)} エントリ OK")
PY
INFO_RC=$?
[ $INFO_RC -ne 0 ] && EXIT_CODE=1

bold "==> 4. NodeDateFormat の Locale ハードコード"
HARDCODE=$(grep -rnE 'Locale\(identifier:|cal\.locale\s*=\s*Locale\(' Node --include="*.swift" || true)
if [ -n "$HARDCODE" ]; then
  red "  Locale ハードコードが残っています:"
  echo "$HARDCODE" | sed 's/^/    /'
  yellow "  → Locale.current を使ってください"
  EXIT_CODE=1
else
  green "  OK"
fi

if [ "${1:-}" = "--build" ]; then
  bold "==> 5. ビルド検証 + en.lproj 内容確認"
  xcodebuild -project Node.xcodeproj -scheme Node \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Debug build > /tmp/node-build.log 2>&1
  if [ $? -eq 0 ]; then
    green "  BUILD SUCCEEDED"
    EN_STRINGS=$(find ~/Library/Developer/Xcode/DerivedData/Node-*/Build/Products/Debug-iphonesimulator/Node.app/en.lproj -name "Localizable.strings" 2>/dev/null | head -1)
    if [ -n "$EN_STRINGS" ]; then
      COUNT=$(plutil -p "$EN_STRINGS" | wc -l | tr -d ' ')
      green "  en.lproj/Localizable.strings: $COUNT 行"
    else
      yellow "  en.lproj が見つかりません (DerivedData 確認)"
    fi
  else
    red "  ビルド失敗 → /tmp/node-build.log を確認"
    tail -20 /tmp/node-build.log | sed 's/^/    /'
    EXIT_CODE=1
  fi
fi

echo
if [ $EXIT_CODE -eq 0 ]; then
  bold "$(green 'ALL LOCALIZATION CHECKS PASSED')"
else
  bold "$(red 'LOCALIZATION CHECK FAILED')"
  yellow "詳細は CLAUDE.md の「ローカライズ規約」を参照"
fi
exit $EXIT_CODE
