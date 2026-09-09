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
