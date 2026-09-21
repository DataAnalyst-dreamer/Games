#!/usr/bin/env python3
"""쿼터뷰 단계 (b1) 1회용 단위 전환기 — 월드 px을 전부 2배로 올린다 (D-206).

타일이 16 월드단위에서 32 월드단위로 바뀌므로, "월드 거리"를 뜻하는 값은 전부 2배가
되어야 비율이 보존된다. 카메라 zoom 을 2에서 1로 낮추면 화면에 보이는 타일 수가 그대로라
**게임플레이도 화면도 바뀌지 않고 아트 해상도만 2배가 된다**(계획서 §1 실측).

핵심 규칙: 키 이름을 정규식으로 추측하지 않는다. 아래 allowlist 에 적힌 키만 건드리고,
나머지는 손대지 않는다. 무차원(비율·확률·배율)과 시간(_sec)과 화면 px(UI 여백)은
2배 대상이 아니다 — 잘못 곱하면 조용히 밸런스가 바뀐다.

사용: python3 tools/qv_scale2.py [--check]
  --check: 파일을 쓰지 않고 바뀔 내용만 출력한다.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
FACTOR = 2

# --- JSON: 월드 거리/속도를 뜻하는 키만 ---
SCALE_KEYS = {
    # combat.json
    "distance_px", "walk_speed_px", "normal_px", "heavy_px", "amplitude_px",
    # monsters.json
    "move_speed_px", "dash_speed_px", "aggro_range_px", "melee_range_px",
    "patrol_radius_px", "leash_range_px", "whistle_range_px", "aoe_radius_px",
    "attack_vfx_offset_px", "on_death_split_spawn_radius_px",
    # skills.json
    "range_px", "width_px", "knockback_px", "dash_px",
}
JSON_TARGETS = ["combat.json", "monsters.json", "skills.json"]

# 명시적 제외 — 이름이 비슷하지만 월드 거리가 아닌 것들을 사람이 읽을 수 있게 남겨 둔다.
NOT_SCALED_NOTE = """
  건드리지 않음(월드 거리가 아님):
    * 무차원      비율·확률·배율 (chip_damage_ratio, SCREEN_SHAKE_LEVELS, *_pct, *_multiplier)
    * 시간        *_sec, *_frames, frame_rate_reference
    * 화면 px     QUEST_ARROW_MARGIN_PX, MINIMAP_EDGE_MARGIN_PX, MINIMAP_SIZE, HUD 아이콘 크기
    * 비공간      hp/atk/exp/가격/드랍확률 테이블 전체
"""


NUMBER = r"-?\d+(?:\.\d+)?"


def _double(text):
    """숫자 문자열을 2배로.

    쓰여 있던 형태를 유지한다 - 정수는 정수로, 소수는 소수로. 80.0 을 160 으로 바꾸면
    값은 같아도 테이블의 타입 표기가 바뀌어 diff 가 지저분해지고, 소수 자리가 의미를
    갖는 항목(attack_vfx_offset_px 8.5 등)에서 의도가 흐려진다.
    """
    if "." in text:
        decimals = len(text.split(".")[1])
        return f"{float(text) * FACTOR:.{decimals}f}"
    return str(int(text) * FACTOR)


def convert_json(check):
    """JSON 을 파싱해 다시 덤프하지 않고 **텍스트로** 고친다.

    json.dumps 로 되쓰면 들여쓰기·줄바꿈이 전부 재배치돼 8개 값 바꾼 diff 가 68줄이
    된다 - 리뷰가 불가능해진다. 키 이름을 정확히 지정한 치환이라 오탐 위험도 없다.
    """
    total = 0
    for name in JSON_TARGETS:
        path = GAME / "data" / name
        text = path.read_text(encoding="utf-8")
        changes = []

        def replace(match):
            changes.append((match.group(1), match.group(2)))
            return f'"{match.group(1)}": {_double(match.group(2))}'

        pattern = r'"(' + "|".join(sorted(SCALE_KEYS)) + r')":\s*(' + NUMBER + r')'
        text = re.sub(pattern, replace, text)
        total += len(changes)
        print(f"  {name}: {len(changes)} 값")
        if not check:
            path.write_text(text, encoding="utf-8")
    return total


def convert_world_objects(check):
    """world_objects.json 의 position 배열만 2배. 여기도 텍스트 치환으로 서식을 보존한다."""
    path = GAME / "data" / "world_objects.json"
    text = path.read_text(encoding="utf-8")
    count = 0

    def replace(match):
        nonlocal count
        count += 1
        return (f'"position": [{match.group(1)}{_double(match.group(2))}'
                f'{match.group(3)}{_double(match.group(4))}{match.group(5)}]')

    pattern = (r'"position":\s*\[(\s*)(' + NUMBER + r')(\s*,\s*)('
               + NUMBER + r')(\s*)\]')
    text = re.sub(pattern, replace, text)
    print(f"  world_objects.json: {count} 좌표")
    if not check:
        path.write_text(text, encoding="utf-8")
    return count


# --- 씬 파일: 줄 앞머리 키를 정확히 지정한다 (부분 일치 금지) ---
SCENE_KEYS = ("position", "size", "radius", "scale", "polygon", "offset")


def scale_scene_line(line):
    """`키 = Vector2(a, b)` / `키 = 숫자` / `키 = PackedVector2Array(...)` 만 2배."""
    match = re.match(r"^(" + "|".join(SCENE_KEYS) + r") = (.+)$", line)
    if match is None:
        return line, False
    key, value = match.group(1), match.group(2)
    vector = re.fullmatch(r"Vector2\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)", value)
    if vector:
        x, y = float(vector.group(1)) * FACTOR, float(vector.group(2)) * FACTOR
        return f"{key} = Vector2({x:g}, {y:g})", True
    packed = re.fullmatch(r"PackedVector2Array\(([-\d.,\s]*)\)", value)
    if packed:
        numbers = [n.strip() for n in packed.group(1).split(",") if n.strip()]
        scaled = ", ".join(f"{float(n) * FACTOR:g}" for n in numbers)
        return f"{key} = PackedVector2Array({scaled})", True
    number = re.fullmatch(r"-?[\d.]+", value)
    if number:
        return f"{key} = {float(value) * FACTOR:g}", True
    return line, False


def convert_scene(relative, check):
    path = GAME / relative
    lines = path.read_text(encoding="utf-8").split("\n")
    out, count = [], 0
    for line in lines:
        new_line, changed = scale_scene_line(line)
        count += 1 if changed else 0
        out.append(new_line)
    print(f"  {relative}: {count} 줄")
    if not check:
        path.write_text("\n".join(out), encoding="utf-8")
    return count


SCENES = [
    "scenes/main/Main.tscn",
    "scenes/player/Player.tscn",
    "scenes/entities/monsters/Slime.tscn",
    "scenes/entities/monsters/HornRabbit.tscn",
    "scenes/entities/monsters/Mushroom.tscn",
    "scenes/entities/monsters/GoblinScout.tscn",
    "scenes/entities/monsters/EliteGoblinCaptain.tscn",
    "scenes/entities/monsters/EliteBunchiSpawn.tscn",
    # 월드 오브젝트·NPC·이펙트 — 이쪽을 빠뜨리면 지형과 액터만 2배가 되고 NPC 는
    # 그대로 남아 상대적으로 절반 크기가 된다(실제로 한 번 빠뜨렸고, 미니맵 랜드마크
    # 점이 작아진 것으로 캡처 비교에서 드러났다).
    "scenes/world/BlacksmithNpc.tscn",
    "scenes/world/BoardNpc.tscn",
    "scenes/world/MailboxNpc.tscn",
    "scenes/world/QuestNpc.tscn",
    "scenes/world/QuestObject.tscn",
    "scenes/world/QuestTrigger.tscn",
    "scenes/world/Waystone.tscn",
    "scenes/world/ItemDrop.tscn",
    "scenes/effects/Projectile.tscn",
]


def already_converted():
    """tuning.gd 의 TILE_SIZE_PROTOTYPE 로 전환 여부를 판정한다.

    이 도구는 **절대 두 번 돌리면 안 된다** - 두 번 돌면 ×4가 되고, 모든 값이 같은
    배수로 커지므로 비율 검사도 통과해 버린다(실제로 데이터만 두 번 돌려서 ×4가 됐고,
    비율 테스트가 아니라 "타일 단위 거리" 검사에서야 드러났다). 그래서 실행 전에
    스스로 막는다.
    """
    text = (GAME / "scripts" / "tuning.gd").read_text(encoding="utf-8")
    return "const TILE_SIZE_PROTOTYPE: int = 32" in text


def main():
    check = "--check" in sys.argv
    force = "--force" in sys.argv
    only = None
    for arg in sys.argv[1:]:
        if arg.startswith("--only="):
            only = arg.split("=", 1)[1]
    if already_converted() and not check and not force:
        print("이미 전환된 트리다(tuning.gd TILE_SIZE_PROTOTYPE = 32). 중단한다.")
        print("의도한 재실행이면 --force, 일부만 돌리려면 --only=data|scenes 와 함께 쓴다.")
        return
    print(f"쿼터뷰 단위 전환 ×{FACTOR}" + (" (검사만)" if check else ""))
    total = 0
    if only in (None, "data"):
        print("데이터 테이블:")
        total += convert_json(check) + convert_world_objects(check)
    if only in (None, "scenes"):
        print("씬:")
        for relative in SCENES:
            total += convert_scene(relative, check)
    print(f"합계 {total} 값 변환")
    print(NOT_SCALED_NOTE)
    print("  tuning.gd / 스크립트 상수는 손으로 바꾼다(주석이 값과 함께 갱신돼야 해서).")


if __name__ == "__main__":
    main()
