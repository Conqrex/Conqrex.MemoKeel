#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo"

node tests/test-model.mjs
bash tests/test-store-migration.sh
rg -q 'card\.Drag\.drop\(\)' package/contents/ui/KanbanCard.qml
qmllint package/contents/ui/*.qml package/contents/config/config.qml
echo "MemoKeel validation: PASS"
