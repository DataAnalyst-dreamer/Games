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

## 타별 선딜/후딜 프레임(addendum §5-2, 결정 요청 6 — 미승인, 실제 적용 보류). 실제 캐릭터
## 공격 프레임(4~6f)이 나오기 전까지는 검증 불가능한 추정치라 combat.json으로 승격하지
## 않고 여기 이름만 정식으로 남겨둔다(D-66 예정). attack.gd는 아직 이 값들을 사용하지
## 않는다 — 승인 시 선딜만큼 히트박스 활성을 늦추고, 1·2타 후딜만큼 자세 복귀를 늦추는
## 방향으로 attack.gd에 배선한다.
const ATTACK_STARTUP_FRAMES: int = 4
const ATTACK_STARTUP_SEC: float = float(ATTACK_STARTUP_FRAMES) / 60.0
const ATTACK_RECOVER_TO_IDLE_FRAMES: int = 6
const ATTACK_RECOVER_TO_IDLE_SEC: float = float(ATTACK_RECOVER_TO_IDLE_FRAMES) / 60.0

## 사망 판정 직후 텔레포트(부활)까지의 순수 UX 지연(초, F8-2). 밸런스와 무관한 연출
## 값이라 combat.json이 아닌 여기 둔다 — docs/specs/combat-tuning-m1-addendum.md §7-3
## 제안값(DEATH_RESPAWN_DELAY_SEC=1.0)과 동일한 이름/값으로 맞췄다.
const DEATH_RESPAWN_DELAY_SEC: float = 1.0

# --- 카메라 셰이크: 4단계 진폭·지속은 combat.json.camera_shake로 이관됨
# (addendum §3-2, D-63 예정, _balance_todo — M1 게이트 실측 후 확정). 접근성 배율표만
# settings.json 소유자 미배정(addendum §3-3 결정 요청 4)으로 잠정 여기 유지.
## 화면 흔들림 강도 4단계(GDD 11장 접근성). 0 = 완전 off. combat.json.camera_shake.*.
## amplitude_px에 곱한다(지속시간에는 곱하지 않는다 — 멀미 방지, §3-3).
const SCREEN_SHAKE_LEVELS: Array[float] = [0.0, 0.5, 1.0, 1.5]

# --- 몬스터 AI: 종별 5필드(aggro/melee/attack_recovery/patrol/leash)는 monsters.json으로
# 승격됨(addendum §4, D-65 예정). 아래는 승격 대상에서 명시적으로 제외된 공통값
# (addendum §4-1 "이번 승격 범위 밖")만 남는다 — game-designer 확인 필요(질문 목록 참고).
const MONSTER_ATTACK_ACTIVE_SEC: float = 0.2
const MONSTER_PATROL_PAUSE_SEC: float = 1.2
const MONSTER_HURT_STUN_SEC: float = 0.2

## 뿔토끼 돌진(charge) 중 벽(정적 콜라이더) 충돌 시 기절 시간(초). addendum이 "즉시 정지 +
## 경직 유지" 정책만 확정하고 구체 수치는 정의하지 않아 제안값 — game-designer 확인 필요
## (완료 보고 질문 목록 참고). _balance_todo 취급.
const DASH_WALL_STUN_SEC: float = 0.5

## 버섯돌이 포자 장판(spore_patch) 지속시간(초). combat-tuning-m1(-addendum) 어디에도
## 정의되지 않은 완전 신규 제안값 — game-designer 확인 필요(완료 보고 질문 목록 참고).
## 장판 내부 초당 피해는 monsters.json.atk_tick_per_sec(4.0/초)를 그대로 쓰되, 실제 틱은
## 1초 간격으로 round(atk_tick_per_sec) 데미지를 주는 방식으로 단순화했다(§구현 노트 —
## "초당 4틱"이 아니라 "1틱/초, 4데미지"로 해석. 하위 초 단위 틱 간격이 필요하면 이 상수
## 옆에 SPORE_PATCH_TICK_INTERVAL_SEC을 추가하고 monster_base.gd만 고치면 된다).
const SPORE_PATCH_DURATION_SEC: float = 2.0
