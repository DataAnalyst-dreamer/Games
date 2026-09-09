## 임시 상수 모음 (F8-4 규칙: 코드 하드코딩 금지, 임시 상수는 이 파일에만).
##
## 여기 있는 값은 전부 "테이블 이관 예정"이다. game-designer가 res://data/*.json 에
## 스키마를 확정하면 해당 항목을 삭제하고 Data.get_value(...) 호출로 바꾼다.
## 밸런스와 무관한 순수 기술 상수(청크 크기 등)도 GDD 12장 값을 그대로 옮겨두었다.
extends Node

# --- 입력 (테이블 이관 예정 → settings/input.json) ---
## 아날로그 스틱 데드존. project.godot 의 move_* deadzone(0.2)과 맞춘다.
const STICK_DEADZONE: float = 0.2

# --- 애니메이션 (테이블 이관 예정 → animation.json 또는 캐릭터 데이터) ---
## 걷기 애니메이션 FPS. GDD 9장 "이동 6프레임" 기준 원작 아트 전환 시 재조정.
const ANIM_WALK_FPS: float = 8.0
const ANIM_IDLE_FPS: float = 4.0

# --- 카메라 (테이블 이관 예정 → camera.json / 접근성 설정) ---
## 프로토타입 16px 아트를 640×360 뷰포트에서 읽기 좋게 하기 위한 정수 줌.
const CAMERA_ZOOM: float = 2.0
## 화면 흔들림 강도 4단계(GDD 11장 접근성). 0 = 완전 off.
const SCREEN_SHAKE_LEVELS: Array[float] = [0.0, 0.5, 1.0, 1.5]
## 히트스톱 배율 (접근성). 0 = off. combat.json hitstop.min/max 에 곱한다.
const HITSTOP_SCALE_DEFAULT: float = 1.0

# --- 월드 (GDD 12장 확정 기술 사양, 데이터화 불필요할 수 있음) ---
## 청크 한 변의 타일 수 (64×64).
const CHUNK_TILES: int = 64
## 플레이어 주변 활성 청크 반경 (1 → 3×3).
const ACTIVE_CHUNK_RADIUS: int = 1
## 프로토타입 타일 크기(px). 원작 아트는 32px (GDD 9장).
const TILE_SIZE_PROTOTYPE: int = 16

# --- 전투: characters.json 이관 예정 (M1-1, docs/specs/combat-tuning-m1.md §0) ---
## 레벨1·무기 미장착 기준 임시 공격력. characters.json 확정 전까지 여기에만 존재해야 한다.
const PLAYER_BASE_ATTACK: float = 10.0
## 레벨1 임시 최대 HP. characters.json/stats.json 확정 전 임시값(F2-2 HP바 표시용).
const PLAYER_MAX_HP: int = 100

# --- 전투: 애니메이션/타이밍 (combat.json 미확정 — game-designer 질문 목록 참고) ---
## 공격 애니메이션 프레임 재생 속도. S2-1a "캐릭터별 공격 애니메이션 4~6프레임" 기준,
## 실제 스프라이트가 없어(무기 스프라이트 회전으로 대체) 임시로 4프레임/12fps ≈ 0.333초/타로 잡는다.
const ATTACK_ANIM_FPS: float = 12.0
const ATTACK_ANIM_FRAMES: int = 4
## 1·2타 활성(스윙) 지속시간(초) = ATTACK_ANIM_FRAMES / ATTACK_ANIM_FPS. combo.input_buffer_sec의
## 기준점(콤보 타이밍 모델, scripts/systems/combo_state.gd 참고). game-designer 실측 필요.
const ATTACK_HIT_DURATION_SEC: float = float(ATTACK_ANIM_FRAMES) / ATTACK_ANIM_FPS
## 타별 짧은 전진 이동 거리(px, S2-1a "각 타는 짧은 전진 이동 포함"). 제안값.
const ATTACK_LUNGE_PX: float = 6.0

## 피격 넉백을 "고정 거리(px)를 고정 시간 동안 이동"으로 처리하는 지속시간(초).
## combat.json의 knockback.normal_px/heavy_px는 거리만 정의하므로 속도 환산에 필요.
const KNOCKBACK_DURATION_SEC: float = 0.12

## Hurt 상태 경직 시간과 무적 프레임(초). GDD/스펙에 수치 미확정 — 제안값.
const HURT_STUN_SEC: float = 0.25
const HURT_IFRAMES_SEC: float = 0.5

## 사망 판정 직후 텔레포트(부활)까지의 순수 UX 지연(초, F8-2). 밸런스와 무관한 연출
## 값이라 combat.json이 아닌 여기 둔다 — docs/specs/combat-tuning-m1-addendum.md §7-3
## 제안값(DEATH_RESPAWN_DELAY_SEC=1.0)과 동일한 이름/값으로 맞췄다.
const DEATH_RESPAWN_DELAY_SEC: float = 1.0

# --- 카메라 셰이크 강도 (테이블 이관 예정 → camera.json / 접근성 설정) ---
## 강공격·크리티컬(피니셔) 타격 시 노이즈 진폭(px)·지속시간(초). F2-2: 일반 타격은 셰이크 없음.
## GDD/스펙에 구체 수치가 없어 제안값 — game-designer 확인 필요.
const SHAKE_AMPLITUDE_HEAVY: float = 6.0
const SHAKE_DURATION_HEAVY: float = 0.18

# --- 몬스터 AI (테이블 이관 예정 → monsters.json 확장 필드 또는 attack_patterns.json) ---
## monsters.json에는 hp/atk/속도/예고 시간만 있고(F6-1, D-49) 인지 범위·근접 사거리·
## 공격 후딜·순찰 반경·귀환(leash) 거리는 아직 정의되지 않아 M1-1 프로토타입 공통값으로 둔다.
## game-designer 확인 필요(질문 목록 참고).
const MONSTER_DETECTION_RADIUS_PX: float = 64.0
const MONSTER_MELEE_RANGE_PX: float = 14.0
const MONSTER_ATTACK_ACTIVE_SEC: float = 0.2
const MONSTER_ATTACK_RECOVERY_SEC: float = 0.4
const MONSTER_PATROL_RADIUS_PX: float = 32.0
const MONSTER_PATROL_PAUSE_SEC: float = 1.2
const MONSTER_LEASH_RANGE_PX: float = 140.0
const MONSTER_HURT_STUN_SEC: float = 0.2
