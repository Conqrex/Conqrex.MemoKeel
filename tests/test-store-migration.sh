#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root"

cat > "$test_root/store.json" <<'JSON'
{
  "schemaVersion": 1,
  "appVersion": "0.1.0",
  "rev": 3,
  "deviceId": "test",
  "generatedAt": "2026-08-20T00:00:00Z",
  "ui": {},
  "notes": [],
  "todos": [],
  "columns": [{"id":"legacy-col","type":"column","title":"To Do","order":1}],
  "cards": [{"id":"legacy-card","type":"card","columnId":"legacy-col","title":"Keep me","order":1}],
  "reminders": [],
  "tags": {},
  "links": [],
  "attachments": {},
  "trash": [],
  "meta": {"nextSeq":0}
}
JSON

loaded="$(QN_DATA_DIR="$test_root" bash "$repo/package/contents/code/store.sh" load)"
jq -e '
    .schemaVersion == 2
    and (.boards | length) == 1
    and .boards[0].id == "board-default"
    and .columns[0].boardId == "board-default"
    and .cards[0].columnId == "legacy-col"
' <<< "$loaded" >/dev/null

echo "store v1 to multi-board migration: PASS"
