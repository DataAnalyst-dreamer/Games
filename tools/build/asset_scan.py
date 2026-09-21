#!/usr/bin/env python3
"""Shared asset reference scanner — extract res://assets/... references from Godot project files.

Used by compute_exclude.py (web export filter) and build_asset_index.py (catalog generator).
Regex-based only (no dynamic load analysis).
"""
import re, os, glob

def collect_references(root: str) -> set:
    """Scan .gd, .tscn, .tres, .json, project.godot for res://assets/... refs.

    Args:
        root: Game directory root (game/).

    Returns:
        Set of normalized res://assets/... paths (no trailing slashes).
    """
    refs = set()
    for pat in ('**/*.gd', '**/*.tscn', '**/*.tres', '**/*.json', 'project.godot'):
        for f in glob.glob(os.path.join(root, pat), recursive=True):
            try:
                t = open(f, encoding='utf-8', errors='ignore').read()
            except (OSError, IOError):
                continue
            for m in re.findall(r'res://assets/[^"\')\n]+', t):
                refs.add(m.rstrip())
    return refs
