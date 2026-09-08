## 등급 6종 조회 헬퍼(docs/ui/wireframes.md §0.2, docs/art/art-bible.md §6).
## 색상 값 자체는 규칙대로 game/ui/theme.tres 한 곳에서만 정의하고, 이 스크립트는
## "등급 키 → 테마 색상" 조회와 색약 대체 아이콘(색이 아니므로 테마 규칙과 무관) 매핑만
## 담당한다. game-designer의 등급 테이블이 나오면 KEYS 순서를 그대로 맞춘다.
class_name Rarity
extends RefCounted

enum Grade { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, RELIC }

const THEME_TYPE := &"Rarity"

const KEYS := {
	Grade.COMMON: &"common",
	Grade.UNCOMMON: &"uncommon",
	Grade.RARE: &"rare",
	Grade.EPIC: &"epic",
	Grade.LEGENDARY: &"legendary",
	Grade.RELIC: &"relic",
}

## 색약 모드 대체 아이콘. 색과 항상 병기한다(색만으로 구분 금지, GDD 11장 접근성 원칙).
const ICONS := {
	Grade.COMMON: "●",
	Grade.UNCOMMON: "▲",
	Grade.RARE: "◆",
	Grade.EPIC: "★",
	Grade.LEGENDARY: "✦",
	Grade.RELIC: "❖",
}


static func color_of(grade: Grade, theme: Theme) -> Color:
	return theme.get_color(KEYS[grade], THEME_TYPE)


static func icon_of(grade: Grade) -> String:
	return ICONS[grade]
