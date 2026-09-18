# 웹 데모 (GitHub Pages) 운영 메모

## 주소
- `https://dataanalyst-dreamer.github.io/Games/` — 저장소 **Settings → Pages → Build and deployment → Source: "Deploy from a branch" → Branch: `gh-pages` / `/(root)` → Save** 로 1회 활성화해야 열린다(관리자 작업). 활성화 후 첫 배포까지 1~3분.

## 빌드·배포 (디렉터/엔지니어)
```bash
GODOT=/path/to/Godot_v4.4.1-stable_linux.x86_64 tools/build/export_web.sh   # → build/web/
# gh-pages 브랜치(고아 브랜치)에 build/web 내용을 통째로 커밋·강제 푸시
```
- 프리셋 원본: `tools/build/export_presets.web.cfg` (스크립트가 gitignore된 `game/export_presets.cfg`로 복사).
  `thread_support=false` 라 COOP/COEP 헤더 없이 GitHub Pages에서 동작한다.
- `exclude_filter`에 참조되지 않는 서드파티 애셋 523항목을 명시해 `index.pck`를 96MB → 16MB로 줄였다.
  새 애셋을 참조하기 시작하면 이 목록에서 해당 항목을 빼야 한다(빠뜨리면 웹에서만 로드 실패).
  목록 재계산 스크립트는 `tools/build/compute_exclude.py`.
- 템플릿: `~/.local/share/godot/export_templates/4.4.1.stable/web_nothreads_release.zip`
  (공식 `Godot_v4.4.1-stable_export_templates.tpz`에서 해당 파일만 추출).

## 검증
- 헤드리스 Chromium(Playwright, `--use-gl=swiftshader`)으로 `index.html`을 열어 25초 대기 후
  콘솔에 `Godot Engine v4.4.1` / `[Metrics] 세션 시작` 로그와 스크립트 오류 0을 확인, 스크린샷 육안 확인.

## 알려진 제약
- 세이브는 브라우저 IndexedDB(`user://`)에 저장 — 브라우저·기기별로 따로다.
- 첫 로딩 약 58MB(엔진 wasm 44MB + pck 16MB). 이후는 브라우저 캐시.
- 소리는 첫 클릭/키 입력 뒤부터 난다(브라우저 자동재생 정책).
- 게임패드는 브라우저가 지원하는 범위에서만 동작.
