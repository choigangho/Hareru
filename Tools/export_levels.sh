#!/bin/sh
# N5 초안 + N4~N1 뜻 초안(Tools/drafts/n?_meanings.json)을 한 묶음으로 내보내고 번들에 합치기 — 검사는 swift test
# 한 묶음인 이유: 한자 초안은 급수 사이에 공유됨 (N4 단어의 한자가 N5 초안에 있을 수 있음)
cd "$(dirname "$0")/.." || exit 1
python3 -I Tools/export_catalog.py Tools/build/kanji_base.json Tools/build/words_base.json \
  Tools/drafts/n5_*.json Tools/drafts/n?_meanings.json Tools/build/all \
  && python3 -I Tools/bundle_catalog.py Tools/build/all
