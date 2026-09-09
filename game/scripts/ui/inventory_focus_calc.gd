## 인벤토리 메뉴(F7-2, M2-2)의 포커스 이동 순수 계산. Godot 노드에 의존하지 않는
## RefCounted라 GUT에서 직접 테스트한다 — inventory_menu.gd는 이 계산 결과로 실제
## 포커스 인덱스/슬롯명만 바꾼다(그리기·입력 폴링은 이 클래스의 책임이 아니다).
##
## 좌측 장비 패널(8슬롯)은 격자가 아니라 사람 모양 배치(와이어프레임 화면4 ASCII)라
## Vector2i 좌표로 표현하고, 우측 가방은 8열 균일 격자라 index/cols 산수로 처리한다.
class_name InventoryFocusCalc
extends RefCounted

## 장비 슬롯 이름 -> 화면상 좌표(열, 행). Equipment.SLOT_NAMES와 반드시 같은 8개를 커버한다.
##   행0:      head
##   행1: weapon armor sub
##   행2:      boots
##   행3: ring1 ring2 amulet
const EQUIP_POSITIONS := {
	"head": Vector2i(1, 0),
	"weapon": Vector2i(0, 1),
	"armor": Vector2i(1, 1),
	"sub": Vector2i(2, 1),
	"boots": Vector2i(1, 2),
	"ring1": Vector2i(0, 3),
	"ring2": Vector2i(1, 3),
	"amulet": Vector2i(2, 3),
}

const EQUIP_MAX_COL := 2 ## armor/sub/amulet 열 — 이 열의 슬롯에서 오른쪽으로 가면 가방 격자로 넘어간다.
const EQUIP_MIN_COL := 0 ## weapon/ring1 열 — 가방 격자 왼쪽 경계에서 여기로 들어온다.


## dir(단위벡터, 예: Vector2i(1,0)=오른쪽) 방향으로 가장 가까운 다음 슬롯을 찾는다.
## 후보가 없으면(그 방향에 아무 슬롯도 없으면) 현재 슬롯을 그대로 반환한다.
static func equip_neighbor(current: String, dir: Vector2i) -> String:
	if not EQUIP_POSITIONS.has(current) or dir == Vector2i.ZERO:
		return current
	var origin: Vector2i = EQUIP_POSITIONS[current]
	var best: String = current
	var best_score: float = INF
	for slot_name: String in EQUIP_POSITIONS:
		if slot_name == current:
			continue
		var pos: Vector2i = EQUIP_POSITIONS[slot_name]
		var delta: Vector2i = pos - origin
		var primary: int = delta.x * dir.x + delta.y * dir.y # dir 축 성분(양수라야 그 방향의 후보)
		if primary <= 0:
			continue
		var lateral: int = absi(delta.x * dir.y - delta.y * dir.x) # 직교축 편차(작을수록 "정면")
		var score: float = float(primary) + float(lateral) * 10.0
		if score < best_score:
			best_score = score
			best = slot_name
	return best


static func is_equip_rightmost(slot_name: String) -> bool:
	return int((EQUIP_POSITIONS.get(slot_name, Vector2i(-1, -1)) as Vector2i).x) == EQUIP_MAX_COL


static func is_equip_leftmost(slot_name: String) -> bool:
	return int((EQUIP_POSITIONS.get(slot_name, Vector2i(-1, -1)) as Vector2i).x) == EQUIP_MIN_COL


## 장비 패널에서 가방 격자로 넘어갈 때 진입할 그리드 인덱스.
static func grid_enter_index_from_equip() -> int:
	return 0


## 가방 격자에서 장비 패널로 넘어갈 때 진입할 슬롯.
static func equip_enter_slot_from_grid() -> String:
	return "weapon"


## 8열 균일 격자에서 위/아래/좌/우 이동. count는 실제 채워진 슬롯 수가 아니라 화면에
## 그려지는 총 칸 수(=Inventory.capacity(), 빈 칸도 포커스 가능해야 정렬 후 빈자리가
## 눈에 보인다). 경계를 넘어가지 않고 clamp한다(래핑 없음).
static func grid_neighbor(index: int, cols: int, count: int, dir: Vector2i) -> int:
	if count <= 0 or cols <= 0:
		return 0
	var clamped_index: int = clampi(index, 0, count - 1)
	if dir == Vector2i.ZERO:
		return clamped_index
	var row: int = clamped_index / cols
	var col: int = clamped_index % cols
	var rows: int = int(ceil(float(count) / float(cols)))
	var new_row: int = clampi(row + dir.y, 0, rows - 1)
	var new_col: int = clampi(col + dir.x, 0, cols - 1)
	return clampi(new_row * cols + new_col, 0, count - 1)


static func grid_is_leftmost_col(index: int, cols: int) -> bool:
	return cols > 0 and (index % cols) == 0
