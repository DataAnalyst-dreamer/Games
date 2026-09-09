## 아이템별 아이콘 조회 헬퍼(M2-3 소규모 추가 — asset-wrangler `game/data/item_icons.json`
## + `docs/art/item-icon-map.md` 연결). item_icons.json은 `Data` 오토로드가 `res://data/
## *.json`을 전부 읽어 들이는 기존 규칙으로 자동 등록되므로(코드 변경 불필요), 이 헬퍼는
## 그 테이블을 스키마(path/region/source_pack/license)대로 해석해 실제 Texture2D로
## 바꿔주기만 한다.
##
## entry.region이 있으면 AtlasTexture(atlas=path 원본, region=Rect2(x,y,w,h))를 만들고,
## null이면(원본 파일 전체가 곧 아이콘) 원본 텍스처를 그대로 돌려준다. item_id가
## item_icons.json에 없거나 경로를 못 찾으면 null — 호출부(ItemDrop/Hud)가 기존
## 카테고리 placeholder로 폴백한다.
class_name ItemIcon
extends RefCounted


static func resolve(item_id: String) -> Texture2D:
	if item_id.is_empty():
		return null
	var entry: Dictionary = Data.get_value("item_icons", item_id, {})
	if entry.is_empty():
		return null
	var path: String = String(entry.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var base_tex: Texture2D = load(path)
	if base_tex == null:
		return null
	var region_data: Variant = entry.get("region")
	if not (region_data is Dictionary):
		return base_tex
	var region: Dictionary = region_data
	var atlas := AtlasTexture.new()
	atlas.atlas = base_tex
	atlas.region = Rect2(
		float(region.get("x", 0)), float(region.get("y", 0)),
		float(region.get("w", base_tex.get_width())), float(region.get("h", base_tex.get_height())))
	return atlas
