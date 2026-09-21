#!/usr/bin/env python3
"""웹 내보내기 exclude_filter 재계산: game/ 안의 .gd/.tscn/.tres/.json/project.godot가 참조하지
않는 assets/third_party·assets/fonts 파일/폴더 목록을 만든다. 결과를 export_presets.web.cfg의
exclude_filter에 붙여 넣는다(tests/* 포함). 사용: python3 tools/build/compute_exclude.py"""
import os
from asset_scan import collect_references

root = os.path.join(os.path.dirname(__file__), '..', '..', 'game')
all_refs = collect_references(root)
refs = {r[len('res://'):] for r in all_refs if '/third_party/' in r or '/fonts/' in r}
def used(p): return any(p == r or p.startswith(r.rstrip('/') + '/') for r in refs)
excl = []
def walk(d):
    files = [os.path.relpath(os.path.join(dp, f), root) for dp, _, fs in os.walk(os.path.join(root, d)) for f in fs if not f.endswith('.import')]
    if not any(used(f) for f in files):
        excl.append(d + '/*'); return
    for sub in sorted(os.listdir(os.path.join(root, d))):
        sp = os.path.join(d, sub)
        if os.path.isdir(os.path.join(root, sp)): walk(sp)
        elif not sub.endswith('.import') and not used(sp): excl.append(sp)
for top in ('assets/third_party', 'assets/fonts'): walk(top)
excl.append('tests/*')
print(','.join(excl))
