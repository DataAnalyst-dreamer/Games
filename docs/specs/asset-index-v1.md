# 애셋 인덱스 스펙 v1

**목표**: 게임 빌드에 포함된 모든 애셋을 자동으로 카탈로그화하고 미사용·미등록 애셋을 검출한다. 게임 런타임과 빌드 최적화(웹 export exclude)에서 애셋 참조를 신뢰할 수 있는 진실 공급원을 제공한다.

**작성**: 2026-09-21, 등각 placeholder 생성 이후
**대상**: M6 iso 통합 단계 이후, 출시 전 asset audit
**현황**: v1 draft — 참조 수집 규칙, 라이선스 검증 로직 재설계 필요

---

## 1. 인덱스 파일 형식

### 경로: `game/assets/assets.json`

핵심은 모든 애셋을 명시적으로 나열하고, 각각에 메타데이터(규격·출처·라이선스·참조 여부)를 붙인다. 웹 빌드 최적화와 라이선스 크레딧 생성에 사용된다.

```
{
  "metadata": {
    "generated_at": "2026-09-21T14:30:00Z",
    "generated_by": "tools/qa/build_asset_index.py",
    "game_version": "m2",
    "total_files": 2150,
    "total_size_bytes": 45234567
  },
  "assets": {
    "audio": [
      {
        "path": "audio/sfx/just_guard_parry_ting.wav",
        "type": "audio/wav",
        "size_bytes": 12345,
        "source": "project",
        "source_pack": null,
        "license_grade": "project",
        "creator": null,
        "referenced_by": ["game/scripts/audio/sfx.gd", "game/data/audio_sfx.json"],
        "is_referenced": true,
        "checksum": "sha256:abc123..."
      },
      {
        "path": "audio/sfx/drop_common.wav",
        "type": "audio/wav",
        "size_bytes": 8765,
        "source": "project",
        "source_pack": null,
        "license_grade": "project",
        "creator": null,
        "referenced_by": ["game/data/audio_sfx.json"],
        "is_referenced": true,
        "checksum": "sha256:def456..."
      }
    ],
    "fonts": [
      {
        "path": "fonts/galmuri/Galmuri11.ttf",
        "type": "font/ttf",
        "size_bytes": 89012,
        "source": "third_party",
        "source_pack": "galmuri",
        "license_grade": "A",
        "creator": "quiple (Lee Minseo)",
        "referenced_by": ["game/scenes/hud/HUD.tscn"],
        "is_referenced": true,
        "checksum": "sha256:ghi789..."
      }
    ],
    "iso": [
      {
        "path": "iso/actors/fin.png",
        "type": "image/png",
        "size_bytes": 34567,
        "format_spec": "96×128 px, 8방향×프레임(idle/walk/attack)",
        "source": "project",
        "source_pack": null,
        "license_grade": "project",
        "creator": null,
        "atlas_schema": "iso_actor_atlas.json",
        "referenced_by": ["game/scenes/player/Player.tscn"],
        "is_referenced": true,
        "checksum": "sha256:jkl012..."
      },
      {
        "path": "iso/ground/grass.png",
        "type": "image/png",
        "size_bytes": 5432,
        "format_spec": "2:1 isometric diamond",
        "source": "project",
        "source_pack": null,
        "license_grade": "project",
        "generated_from": "tools/art/gen_iso_tiles.py",
        "referenced_by": ["game/scenes/world/TileMap.tscn"],
        "is_referenced": true
      }
    ],
    "sprites": [
      {
        "path": "sprites/characters/fin/fin-walk-v1.png",
        "type": "image/png",
        "size_bytes": 12345,
        "format_spec": "64×96 px, 4프레임 walk cycle",
        "source": "project",
        "source_pack": null,
        "license_grade": "project",
        "generated_from": "docs/art/preview/fin-cq-walk-prompt.txt",
        "referenced_by": ["game/scripts/systems/actor_sheet.gd"],
        "is_referenced": true
      }
    ],
    "third_party": [
      {
        "path": "third_party/ninja_adventure/Items/Weapons/Sword/Sprite.png",
        "type": "image/png",
        "size_bytes": 2048,
        "source": "third_party",
        "source_pack": "ninja_adventure",
        "license_grade": "A",
        "creator": "Pixel-boy, AAA",
        "referenced_by": ["game/data/item_icons.json"],
        "is_referenced": true
      },
      {
        "path": "third_party/ninja_adventure/Audio/Musics/31 - Sunny.ogg",
        "type": "audio/ogg",
        "size_bytes": 456789,
        "source": "third_party",
        "source_pack": "ninja_adventure",
        "license_grade": "A",
        "creator": "Pixel-boy, AAA",
        "referenced_by": ["game/data/audio_bgm.json"],
        "is_referenced": true
      },
      {
        "path": "third_party/kenney/tiny_dungeon/Tiles/tile_42.png",
        "type": "image/png",
        "size_bytes": 1024,
        "source": "third_party",
        "source_pack": "kenney",
        "license_grade": "A",
        "creator": "Kenney",
        "referenced_by": [],
        "is_referenced": false,
        "flag": "unused_but_committed"
      }
    ]
  },
  "atlases": {
    "iso_actor_atlas": {
      "path": "iso/iso_actor_atlas.json",
      "covers": ["iso/actors/*.png"],
      "format": "isometric actor sheet 96×128, cell-based sprite regions"
    },
    "iso_world_atlas": {
      "path": "iso/iso_atlas.json",
      "covers": ["iso/ground/*.png", "iso/walls/*.png", "iso/buildings/*.png", "iso/props/*.png"],
      "format": "isometric world tiles 2:1 diamond"
    }
  },
  "statistics": {
    "by_type": {
      "audio/wav": 17,
      "audio/ogg": 120,
      "image/png": 2839,
      "font/ttf": 7,
      "application/json": 4
    },
    "by_source": {
      "project": 120,
      "third_party": 6494,
      "assets_local": 0
    },
    "by_license_grade": {
      "A": 6494,
      "project": 120
    },
    "unreferenced_count": 142,
    "referenced_count": 2008
  }
}
```

**주요 필드**:
- `path`: 프로젝트 루트 기준 상대 경로 (`game/assets/` 생략)
- `type`: MIME type
- `source`: `"project"` | `"third_party"` | `"assets_local"`
- `source_pack`: 팩 이름 (예: `"ninja_adventure"`, `"galmuri"`) 또는 null
- `license_grade`: `"A"` | `"B"` | `"C"` | `"project"` — 문제: asset-sources.md 규칙(A|B|C|✕)과 enum 다름. **결정 필요**
- `referenced_by`: 참조하는 파일 목록 (경로 또는 테이블 항목 ID)
- `is_referenced`: boolean
- `format_spec`: 스프라이트 규격 (선택, 문서용)
- `checksum`: 무결성 확인용 (선택)

---

## 2. 생성 스크립트 설계

### 경로: `tools/qa/build_asset_index.py`

패턴: `validate_tables.py`처럼 Godot 없이 오프라인으로 실행 가능.

```python
#!/usr/bin/env python3
"""game/assets/와 game/data의 참조를 수집해
game/assets/assets.json을 생성한다.

사용: python3 tools/qa/build_asset_index.py \
  --asset-root game/assets \
  --data-dir game/data \
  --output game/assets/assets.json

종료 코드: 0 = OK, 1 = 미등록 애셋 또는 미참조 CC0 팩 발견"""
```

**스크립트 역할**:
1. 디렉토리 tree walk (game/assets/):
   - 모든 파일 열거 (`.import` 파일 제외)
   - 확장자로 타입 추론 (MIME)
   - 크기, 체크섬 수집
   - 서브디렉토리 + 팩 이름 파싱 (third_party/ninja_adventure → "ninja_adventure")

2. 참조 수집 (재설계 필요 — 이슈: 동적 로드, `.tres` 미포함):
   - **정적 참조**: `game/data/*.json` → `path`, `files` 필드의 `res://assets` 경로
   - **정적 참조**: `game/**/*.gd`, `game/**/*.tscn` → 정규식 `res://assets` 패턴
   - **JSON 내부 참조**: `game/data/audio/*.json`의 `file` 필드 (단수, 스펙 규칙과 다름)
   - **JSON 내부 참조**: `game/data/quests/` 하위 quest.json들 (현재 `game/data/*.json` 범위 밖)
   - **JSON 스키마 참조**: `game/assets/iso/iso_actor_atlas.json` 등의 `"path": "game/assets/iso/actors/fin.png"` (res:// 접두 없음, game/ 상대)
   - **테마 참조**: `game/ui/theme.tres` (`.tres` 파일 동적 참조 수집 필요, 현재 미스캔 — 폰트·parchment_gui 미탐지)
   - **runtime 동적 로드**: `actor_sheet.gd:76 load(_res_path(...))`, `world.gd:96/242` 패턴 — 정규식으로 근사 추출
   - 각 파일마다 역참조 리스트 기록
   
   **대안**: 기존 `tools/build/compute_exclude.py` 참조 수집 로직(`.tres`·`project.godot` 포함)을 재사용하거나, 신규 스크립트에서 동등한 범위로 확장 권장.

3. 라이선스 할당 (재설계 필요):
   - `third_party/*` → `docs/art/LICENSES.md` + 팩별 NOTICE.md 조회 → 등급 결정 (A/B/C 확인 필요)
     - **주의**: parchment_gui는 LICENSES.md에서 'CC0/OGA-BY 등록 — 페이지에서 표기 재확인 필요'라고 기록 → A 확정 아님
   - `fonts/*` → 팩별 README.md (galmuri의 경우 "quiple (Lee Minseo)") 조회 + 등급 결정
   - `audio/sfx/`, `iso/`, `sprites/` (프로젝트 자체) → 등급 "project"
   - `iso/` (생성 스크립트) → 등급 "project" + `generated_from`

4. 통계 계산:
   - 총 파일, 크기, 타입별 분포
   - 미참조 애셋 목록 (주로 third_party 팩의 미사용 파일)
   - 미등록 애셋 경고 (game/assets/ 안의 파일인데 LICENSES.md에 없음)

5. 출력:
   - 구조화된 JSON (위 스키마)
   - 미참조/미등록 애셋 → 테이블 형식 로그

**예상 줄 수**: 300~350줄 (validate_tables.py보다 단순)

---

## 3. 참조되지 않는 애셋 검출

### 규칙

**미참조 애셋**:
- 존재: `game/assets/` 안의 파일
- 조건: `game/data/*.json`, `game/**/*.{gd,tscn}` 어디에도 `res://assets/...` 참조 없음
- 플래그: `"is_referenced": false`

**예시**:
- `third_party/kenney/tiny_dungeon/Tiles/tile_42.png` - 던전 placeholder 시절 남은 미사용 파일
- `third_party/ninja_adventure/Ui/Skill Icon/` 일부 - 아이템 아이콘 매핑에서 제외된 variant

**정책** (M6 현재):
- M3~M5: 미참조 third_party 팩 제외하지 않음 (프로토타입 자산 보관)
- M6 iso 통합 이후: `compute_exclude.py` 결과와 assets.json 대조 → 웹 빌드 exclude 갱신
- 원작 교체 완료 시: 미참조 third_party 파일 삭제 권고 (크레딧만 LICENSES.md에 보관)

---

## 4. 미등록 애셋 검출

### 규칙 (재설계 필요 — 이슈: LICENSES.md 구조 복잡)

**미등록 애셋**:
- 존재: `game/assets/third_party/*/` 또는 `game/assets/fonts/*/` 파일
- 조건: `docs/art/LICENSES.md` + 팩별 `NOTICE.md` 에 출처·라이선스 기록 없음
- 심각도: 상용 게임 출시 전 Fatal Error

**현황**:
- `LICENSES.md`: 산문 4절 + 표 4개 혼합, 팩별 위치 접두 불규칙 (`game/assets/third_party/ninja_adventure/` vs `third_party/kenney/tiny_dungeon/`)
- `game/assets/third_party/ninja_adventure/NOTICE.md` 등 팩 폴더별 NOTICE.md 기존 존재
- `game/assets/fonts/galmuri/README.md` 폰트별 정보 기존 존재
- Kenney tiny_dungeon/tiny_town/tiny_creatures: 기록엔 있으나 디스크엔 없음 (커밋 1411053에서 삭제됨)

**검출 방법** (결정 필요):
- Option A: `LICENSES.md` 마크다운 테이블 파싱만 (현재 스펙)
  - 문제: 팩별 NOTICE.md는 미반영, parchment_gui 재확인 필요 (스펙에선 A 확정이라고 했으나 문서는 CC0/OGA-BY 등록 — 재확인 필요)
- Option B: 팩별 NOTICE.md + `LICENSES.md` 함께 파싱
  - 장점: 기존 구조 존중, 팩별 세부 정보 보존
  - 단점: 스크립트 복잡도 증가
- Option C: `LICENSES.md` 구조 단순화 + 팩별 NOTICE.md 삭제 (스펙 관리 단순화)
  - 장점: 스크립트·문서 일관성
  - 단점: 팩별 상세 정보 손실

**예시 워크플로우** (현 스펙 기준):
```
$ python3 tools/qa/build_asset_index.py
game/assets/third_party/ninja_adventure/Items/Weapons/Sword/Sprite.png
  ✓ registered in LICENSES.md (ninja_adventure pack)

game/assets/third_party/unknown_pack/sprite.png
  ✗ NOT FOUND in LICENSES.md or NOTICE.md
  → Add to LICENSES.md + NOTICE.md, or remove from assets/
```

---

## 5. validate_tables 통합

### 문제

기존 `validate_tables.py` (612줄):
- D-157 위반: 새 로직을 추가하되 파일 500줄 초과 상태
- 스키마 미일치: 코드는 `asset_index["assets_by_path"]` 참조하지만 §1 스키마 assets는 카테고리별 리스트 (`assets.audio[]` 등), `assets_by_path` 키 없음
- 중복 검증: 기존 `tools/qa/validate_audio_assets.py` (135줄)가 이미 audio_sfx/audio_bgm의 파일 존재·참조 수집 처리 (중복 위험)

### 개선안 (결정 필요)

**Option A**: 독립 검증 파일로 분리 (D-157 준수)
- `tools/qa/validate_asset_index.py` (신규, ~50줄)
  - `build_asset_index.py`의 결과 `game/assets/assets.json` 검증
  - item_icons.json 등 데이터 테이블 참조 ↔ assets.json 존재 여부 검사
  - 스키마 정정: `asset_index` 순회 시 카테고리별 리스트 처리 (`for asset in asset_index["assets"][category]`)
- `tools/qa/validate_audio_assets.py` 유지 (기존 음성 파일 검증 담당)
- 실행 순서: `build_asset_index.py` → `validate_asset_index.py` → `validate_tables.py`

**Option B**: validate_audio_assets.py 통합 (파일 수 축소)
- `build_asset_index.py`에서 음성 파일 검증 포함
- `validate_audio_assets.py` 삭제 (중복 제거)
- 단점: build_asset_index.py 복잡도 증가

**권장**: Option A (문서 일관성 + D-157 준수)

---

## 6. 웹 빌드 exclude_filter 관계

### 문제

기존 `tools/build/compute_exclude.py` (스펙 미탐지):
- `game/` 스캔 → `res://assets/third_party|fonts` 참조 수집
- 참조되지 않는 **디렉토리** → `dir/*` 축약으로 exclude 목록 생성 (~30 항목)
- `assets/third_party`와 `assets/fonts` 둘 다 처리
- 마지막에 `tests/*` 부가
- 결과를 `tools/build/export_presets.web.cfg` 에서 읽어, `tools/build/export_web.sh`가 `game/export_presets.cfg` (gitignore)로 복사

신규 스펙 `sync_exclude_filter.py`:
- 현재 코드: 파일 단위로 나열 (assets.json의 모든 third_party 미참조 파일)
- **문제**: exclude_filter 크기 33KB → 파일 단위면 훨씬 더 커짐, 기존 compute_exclude.py와 일관성 차이
- 프리셋 파일 경로 오류: `export_presets.web.cfg` (스펙)이 아니라 `tools/build/export_presets.web.cfg` (실제)

### 개선안 (재설계 필요 — 결정 필요)

**Option A**: 기존 `compute_exclude.py` 재사용 + assets.json 검증만
- compute_exclude.py의 디렉토리 축약 로직 유지 (크기 제어)
- assets.json 생성 후, 미참조 파일이 compute_exclude.py 결과와 일치하는지 검증
- 장점: 기존 빌드 프로세스와 호환성, 파일 크기 제어
- 단점: 두 도구 동기화 필요

**Option B**: sync_exclude_filter.py 구현 (스펙 현재)
- assets.json의 unreferenced 목록 → exclude_filter 자동 생성
- 파일 단위 나열의 크기 증가 수용
- 프리셋 경로 수정: `tools/build/export_presets.web.cfg` 명시
- 장점: assets.json이 진실 공급원, 자동화
- 단점: compute_exclude.py와 분리, 유지보수 부담

**권장**: Option A (기존 도구 재활용) — 단, assets.json에서 compute_exclude.py와 부분적 일관성 검증

---

## 7. 예상 줄 수 (재계산 필요 — 현재 모순)

**문제**:
- 예시 통계: total_files 2150, by_source 합 6614, by_type 합 ≈2987, referenced+unreferenced=2150 (불일치)
- 실제 `game/assets` 파일 수: 6,638개 (`.import` 3,303개 제외 시 실 애셋 3,335개)
- §1 예시 JSON: 애셋당 ~12줄 pretty format
- §7 추정: 6,000+ × 0.4줄 = 2,000~3,000줄 (예시와 모순)
- 정정: 3,335개 실 애셋 × 12줄 ≈ 40,000줄, `.import` 포함 시 약 80,000줄

**결정 필요**:
- `.import` 파일 포함 여부? (현재 명시 없음, compute_exclude.py는 제외)
- Minified JSON vs Pretty-print format? (현재 스키마는 pretty-print 예시)

**권장 추정** (`.import` 제외, minified):
- **assets.json**: 40,000~50,000 줄 (3,335 애셋 × 12~15줄, minified 적용 시 10,000~15,000줄)
- **build_asset_index.py**: 300~400 줄 (compute_exclude.py 참조 수집 로직 포함)
- **validate_asset_index.py**: 50~80 줄 (독립 검증)

---

## 8. 결정 필요 항목

**D-N 번호는 docs/brd/04-decisions.md에서 할당받음**

1. **참조 수집 범위**: 현재 스펙(`game/data/*.json` + `game/**/*.gd,*.tscn` 정규식)로는 iso 동적 로드·`.tres` 폰트·parchment_gui가 놓침. 범위 확대 필요?
   - Option A: 기존 `compute_exclude.py`의 참조 로직 재사용 (`.tres`·`project.godot` 포함)
   - Option B: 신규 스크립트에서 compute_exclude.py와 동등한 범위로 확장
   - Option C: JSON 스키마(iso_actor_atlas.json) + 동적 로드 정규식 근사만 지원 (현재, 불완전)

2. **라이선스 등급 enum**: asset-sources.md 규칙(A|B|C|✕)과 스펙(A|B|project)의 불일치
   - asset-sources.md에 맞춰 enum 수정? (C, ✕ 추가)
   - parchment_gui 등급 확인? (현재 'CC0/OGA-BY 등록 — 페이지에서 표기 재확인 필요'라고 기록)

3. **미등록 검출 구조**: LICENSES.md + 팩별 NOTICE.md + 폰트별 README.md 중 어디를 파싱할 것인가?
   - Option A: 마크다운 테이블만 (현재 스펙)
   - Option B: 팩별 NOTICE.md + README.md 함께 파싱 (기존 구조 존중)
   - Option C: LICENSES.md 단순화 + 팩별 NOTICE.md 통합 (스펙 관리 단순화, 기존 파일 삭제)

4. **validate_tables 통합**: D-157(500줄 상한) 준수하면서 asset 참조 검증을 어디에 둘 것인가?
   - Option A: 독립 파일 `validate_asset_index.py` 신규 (권장, D-157 준수)
   - Option B: validate_tables.py에 추가 (현재 스펙, 500줄 위반)
   - Option C: build_asset_index.py에 통합 (복잡도 증가)

5. **웹 빌드 exclude_filter**: compute_exclude.py와의 관계?
   - Option A: compute_exclude.py 재사용 + assets.json 검증 (권장, 기존 호환성)
   - Option B: sync_exclude_filter.py 구현 (스펙 현재, compute_exclude.py와 분리)

6. **.import 파일 포함 여부**: assets.json과 exclude_filter에 `.import` 파일을 포함할 것인가?
   - 포함 안 함(권장): 실 애셋만 추적, 생성 파일 제외
   - 포함: 빌드 후 생성 파일도 검증 (세밀하지만 복잡)

7. **JSON 형식**: assets.json을 pretty-print vs minified로 저장할 것인가?
   - Pretty-print (현재 예시): 가독성, 파일 크기 ~40,000줄
   - Minified: 저장소 크기 절감, 파일 크기 ~10,000줄
   - 결정에 따라 줄 수 추정 갱신 필요

8. **assets_local/ 처리**: B등급 팩(Cainos, Anokolisa)은 `.gitignore` 대상. assets.json에 포함할 것인가?
   - 안 함(권장): JSON은 커밋되는 진실 공급원. 로컬 전용 애셋은 제외
   - 함: CI/CD에서 assets_local 존재 검증 복잡화

9. **checksum 필드**: SHA256 포함 필요성?
   - 필요 (권장): 애셋 변조 탐지, 스트리밍 다운로드 검증
   - 미포함: 생성 시간 증가, 저장소 크기 증가

10. **참조 추적 세밀도**: `referenced_by` 필드를 확장할 것인가?
    - 현재: 파일 경로만 기록 (예: "game/data/item_icons.json")
    - 확장: 라인 번호/키까지 (예: "item_icons.json:weapon_common_1.path")
    - 의견: M6 현재에서는 파일 수준이면 충분, M7 이상에 세분화

11. **미참조 정책**: M6 iso 통합 이후 미참조 애셋에 대한 CI 정책?
    - 경고만(권장): `build_asset_index.py --strict` 플래그로 선택
    - 에러: CI에서 빌드 중단 (자유도 감소)

12. **자동 실행**: assets.json을 언제 갱신할 것인가?
    - 수동: 개발자가 필요시 실행 (느슨한 제어)
    - 커밋 hook: git post-commit → assets.json 갱신 (자동화, 충돌 위험)
    - CI/CD: PR 체크만 (안전, 로컬 개발 편의 감소)

---

## 9. 구현 순서 (재설계 필요 — 블로커 해결 후)

**블로커**:
- 결정 필요 항목 1, 2, 3, 5, 7번 미결정 (참조 수집 범위, 등급 enum, LICENSES.md 구조, exclude_filter 전략, JSON 형식)

**권장 순서** (Option A·C 가정):
1. 결정 필요 항목 사용자 승인 (비동기) — 특히 1, 2, 3, 5, 7번
2. `build_asset_index.py` 작성 (2~3시간, compute_exclude.py 참조 수집 로직 포함)
3. 초기 `assets.json` 생성 및 검증 (30분)
4. `validate_asset_index.py` 신규 작성 (1시간, D-157 준수)
5. 기존 `compute_exclude.py`와 일관성 검증 (30분, exclude_filter 생략 가능)
6. 문서 예시·예상 줄 수 갱신 (30분)
7. CI/CD 통합 (1시간, 의존성: 6 결정 필요 항목)

---

## 참고

- 관련 문서: `docs/art/asset-sources.md`, `docs/art/LICENSES.md`, 팩별 NOTICE.md, 폰트별 README.md
- 데이터 참조: `game/data/item_icons.json`, `game/data/audio_*.json`, `game/data/quests/`
- 생성기: `tools/art/gen_iso_tiles.py`, `tools/art/gen_iso_actors.py`, `tools/art/gen_iso_npcs.py`
- 검증: `tools/qa/validate_tables.py`, `tools/qa/validate_audio_assets.py` (기존, 재사용 권고), `tools/qa/validate_layout.py`
- 웹 최적화: `tools/build/compute_exclude.py` (기존, 참조 수집 로직 재사용 권고)
- 테마: `game/ui/theme.tres` (폰트·UI 애셋 동적 참조, 현 스펙 미포함)

---

## 검증 이력

| 날짜 | 반박 이슈 | 심각도 | 처리 |
|------|---------|-------|-----|
| 2026-09-21 | blocker: §2-2 참조 규칙이 iso 동적 로드·`.tres`·JSON 스키마 참조 미포함 | blocker → major | §2-2 재설계: compute_exclude.py 참조 로직 재사용 옵션 제시, 해결 경로 명기 |
| 2026-09-21 | major: §6 exclude_filter 퇴행, 프리셋 경로 오류 | major | §6 재설계: Option A (compute_exclude.py 재사용) · Option B (sync_exclude_filter.py) 비교 제시, 권장안 명기 |
| 2026-09-21 | major: §4 LICENSES.md 구조 불일치, 팩별 NOTICE.md 미반영 | major | §4 재설계: 3가지 Option 제시 (테이블만 vs 팩별 NOTICE.md vs 구조 단순화) |
| 2026-09-21 | major: §2-3 등급 enum A\|B\|project vs asset-sources.md A\|B\|C\|✕ | major | 등급 enum 명시: A\|B\|C\|project, 결정 필요 항목 2번 추가 |
| 2026-09-21 | major: §5 validate_tables 500줄 초과 + 스키마 미일치 | major | D-157 준수: 독립 파일 validate_asset_index.py 권고, Option A/B/C 제시 |
| 2026-09-21 | major: validate_audio_assets.py 재사용 미언급 | major | 참고 섹션에 명기, §5에서 재사용 권고 |
| 2026-09-21 | major: 문서 시점 M2~M3 vs 현재 M6 | major | 대상 갱신: 'M2~M3 플레이테스트' → 'M6 iso 통합 단계', 정책 갱신 |
| 2026-09-21 | major: §7 통계·줄 수 추정 모순, .import 정책 미정 | major | 통계 재계산: 실 애셋 3,335개 기준, minified 가정 시 10K~15K줄, 결정 필요 항목 6·7번 추가 |
| 2026-09-21 | 종합 | — | 결정 필요 항목 12개로 확대 (기존 6개 → 12개), 각 항목별 Option 제시, §9 구현 순서 재정의 |
