#!/bin/sh
# N5 초안 전체를 앱 형식으로 내보내기 (Tools/build/n5) — 검사는 swift test
cd "$(dirname "$0")/.." && python3 -I Tools/export_catalog.py Tools/build/kanji_base.json Tools/build/words_base.json Tools/drafts/n5_*.json Tools/build/n5
