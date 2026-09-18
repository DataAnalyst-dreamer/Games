#!/usr/bin/env bash
# 《이슬란드 연대기》 웹(HTML5) 데모 빌드 스크립트.
# 사용: GODOT=/path/to/Godot_v4.4.1 tools/build/export_web.sh
# 전제: ~/.local/share/godot/export_templates/4.4.1.stable/ 에 web_nothreads_release.zip 설치.
# 결과: build/web/ (index.html·js·wasm·pck·.nojekyll). GitHub Pages(gh-pages 브랜치)에 그대로 올린다.
# thread_support=false 라 COOP/COEP 헤더 없이(GitHub Pages) 동작한다.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
cp "$ROOT/tools/build/export_presets.web.cfg" "$ROOT/game/export_presets.cfg"   # export_presets.cfg는 gitignore
mkdir -p "$ROOT/build/web"
"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT/game" --export-release "Web" "$ROOT/build/web/index.html"
touch "$ROOT/build/web/.nojekyll"
ls -la "$ROOT/build/web"
