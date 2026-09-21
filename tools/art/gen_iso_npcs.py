#!/usr/bin/env python3
"""등각 NPC 대역 placeholder 시트 생성기 (D-228~D-234 확장, 단계 iso-3 NPC 이관).

gen_iso_actors.py(핀·몬스터)와 셀 규격·발 기준점·행/열 계약이 완전히 같다 - 파일을
나눈 이유는 CLAUDE.md 500줄 상한 하나뿐이다. 실제 도형 헬퍼(ball/cyl/foot_shadow/
eye_pair/right_of)·시트 조립(build_sheet)·팔레트 파서(actor_colors)는 전부
gen_iso_actors.py 것을 그대로 재사용한다(사본 금지).

NPC 는 4방향(s/w/n/e)만 쓴다 - 좌우대칭 인물이라 8방향 정밀도가 필요 없다(D-230과
같은 논리). 열 배치는 핀·몬스터와 동일한 18열 계약(idle 4 / walk 8 / attack 6)을
유지해 정식 시트 교체 규칙이 그대로 통하게 하지만, 퀘스트 NPC는 전투하지 않으므로
attack 6열은 실제 동작 없이 idle 프레임을 반복해 채운다.

사용: python3 tools/art/gen_iso_npcs.py [--out game/assets/iso/actors]
"""
import argparse
import json

from gen_iso_actors import (
    ROOT, IDLE_BOB, PIVOT_X, PIVOT_Y, WALK_BOB, WALK_STEP,
    actor_colors, ball, build_sheet, cyl, eye_pair, foot_shadow, load_palette, right_of,
)

NPC_BODY_PX = (64, 96)
NPC_SHADOW_SCALE = 1.8


def draw_villager(d, c, vec, clip, t, n, *, robe, robe_sh, hair, skin, hold=None):
    """단순 인물 대역: 로브 원기둥 하나 + 머리 구 + (선택) 손에 든 소품 한 개.

    몬스터 대역(draw_creature)과 달리 이족보행 인간형이지만, NPC는 서서 대화만
    하므로 다리를 따로 그리지 않는다 - 원기둥 하나로 몸통 전체를 표현하고 걷기는
    좌우로 살짝 흔드는 정도면 충분하다(지시사항 "과한 디테일 불필요").
    """
    fx, _fy = vec
    # attack 열은 실제 공격 동작이 없다 - idle 프레임을 그대로 반복해 채운다.
    pose_clip, pose_t = ("idle", t % 4) if clip == "attack" else (clip, t)
    bob = IDLE_BOB[pose_t] if pose_clip == "idle" else WALK_BOB[pose_t]
    sway = WALK_STEP[pose_t] if pose_clip == "walk" else 0.0
    bx = PIVOT_X + int(sway * 3)
    by = PIVOT_Y + bob
    foot_shadow(d, PIVOT_X, PIVOT_Y, 16)

    top = cyl(d, bx, by, 15, 46, robe, c["ink"], hi=robe, sh=robe_sh)

    if hold == "staff":
        hx = bx + int(right_of(vec)[0] * 13)
        d.line([(hx, top + 8), (hx, top - 38)], fill=c["wood"], width=3)
        d.ellipse([hx - 4, top - 44, hx + 4, top - 36], fill=c["violet"], outline=c["ink"])
    elif hold == "hammer":
        hx = bx + int(right_of(vec)[0] * 13)
        d.line([(hx, top + 4), (hx, top - 22)], fill=c["wood"], width=3)
        d.rectangle([hx - 6, top - 29, hx + 6, top - 19], fill=c["silver"], outline=c["ink"])

    head_cy = top - 15
    ball(d, bx, head_cy, 10, 9, skin, c["ink"], sh=c["fur"])
    d.pieslice([bx - 11, head_cy - 10, bx + 11, head_cy + 4], 180, 360, fill=hair, outline=c["ink"])
    eye_pair(d, bx + int(fx * 3), head_cy + 3, vec, c["ink"], c["white"])


def npc_table(c):
    """npc_id -> 그리기 함수. 팔레트만 다른 인물은 draw_villager 하나를 공유한다."""
    def villager(**kw):
        return lambda d, cc, vec, clip, t, n: draw_villager(d, cc, vec, clip, t, n, **kw)

    return {
        # 유물 조사단 안내역 - 회색 머리 + 이끼색 로브 + 지팡이.
        "npc_teo": villager(
            robe=c["sage"], robe_sh=c["sage_sh"], hair=c["silver_sh"], skin=c["skin"], hold="staff"),
        # 대장장이 - 가죽 앞치마(황토색 가죽 톤) + 망치.
        "npc_blacksmith": villager(
            robe=c["ochre_sh"], robe_sh=c["wood_sh"], hair=c["fur"], skin=c["skin"], hold="hammer"),
        # 그 외 마을 NPC 4인 - 역할 구분용 2~3색만.
        "npc_meru": villager(  # 노파 - 회색 머리 + 차분한 이끼색 옷.
            robe=c["sage_sh"], robe_sh=c["wood_sh"], hair=c["silver_sh"], skin=c["skin"]),
        "npc_pinto": villager(  # 소년 - 밝은 흙길색 옷.
            robe=c["ochre"], robe_sh=c["ochre_sh"], hair=c["wood_sh"], skin=c["skin"]),
        "npc_rozel": villager(  # 마을 주민 - 짙은 초록 옷.
            robe=c["green_dk"], robe_sh=c["wood_sh"], hair=c["fur"], skin=c["skin"]),
        "npc_dami": villager(  # 어린이 - 연분홍 옷 + 밝은 머리색.
            robe=c["pink"], robe_sh=c["wood_sh"], hair=c["ochre_hi"], skin=c["skin"]),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="game/assets/iso/actors")
    parser.add_argument("--atlas", default="game/assets/iso/iso_actor_atlas.json")
    args = parser.parse_args()
    out_root = ROOT / args.out
    out_root.mkdir(parents=True, exist_ok=True)
    c = actor_colors(load_palette())
    table = npc_table(c)

    # 기존 계약(핀·몬스터 8종)을 덮어쓰지 않고 actors 맵에 NPC 항목만 병합한다.
    atlas_path = ROOT / args.atlas
    atlas = json.loads(atlas_path.read_text(encoding="utf-8"))
    actors: dict = atlas.setdefault("actors", {})

    for npc_id, draw_fn in table.items():
        sheet = build_sheet(c, 4, draw_fn)
        sheet.save(out_root / f"{npc_id}.png")
        actors[npc_id] = {
            "path": f"{args.out}/{npc_id}.png",
            "directions": 4,
            "body_px": list(NPC_BODY_PX),
            "shadow_scale": NPC_SHADOW_SCALE,
        }
        print(f"  {npc_id}.png  {sheet.width}×{sheet.height}  (4방향)")

    atlas_path.write_text(json.dumps(atlas, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"계약 갱신: {args.atlas}  (NPC {len(table)}개 추가, 총 {len(actors)}개 액터)")


if __name__ == "__main__":
    main()
