#!/usr/bin/env python3
"""Generate game/assets/assets.json — automatic asset catalog per D-268~D-270.

Enumerates game/assets/ (excluding .import, assets_local), categorizes by type,
collects references from Godot scripts, and builds pack-unit index for third-party
assets + file-level for project assets. Pretty-prints deterministic JSON.

Usage: python3 tools/qa/build_asset_index.py [--asset-root game/assets] [--data-dir game/data] [--licenses docs/art/LICENSES.md] [--output game/assets/assets.json]
"""
from __future__ import annotations

import argparse, json, mimetypes, os, re, sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Set

sys.path.insert(0, str(Path(__file__).parent.parent / 'build'))
from asset_scan import collect_references

def get_mime_type(path: str) -> str:
    """Get MIME type for a file."""
    mime, _ = mimetypes.guess_type(path)
    return mime or 'application/octet-stream'

def load_licenses(licenses_path: Path) -> Dict[str, str]:
    """Parse LICENSES.md to extract pack -> license text mapping.

    Looks for lines containing 'third_party/<name>/' or 'fonts/<name>/'.
    Returns dict: pack_root -> full license line text.
    """
    licenses = {}
    if not licenses_path.exists():
        return licenses

    content = licenses_path.read_text(encoding='utf-8', errors='ignore')
    for line in content.split('\n'):
        if not line.strip() or line.startswith('#'):
            continue
        # Look for pack references: third_party/<name>/ or fonts/<name>/
        for match in re.finditer(r'(third_party|fonts)/([^/]+)/', line):
            pack_type = match.group(1)
            pack_name = match.group(2)
            pack_root = f'{pack_type}/{pack_name}'
            licenses[pack_root] = line.strip()

    return licenses

def get_license_grade(license_line: str) -> str:
    """Determine license grade A or C based on CC0/OFL presence."""
    if 'CC0' in license_line or 'OFL' in license_line:
        return 'A'
    return 'C'

def should_exclude_file(name: str) -> bool:
    """Check if file should be excluded from index."""
    return (name.endswith('.import') or
            name.startswith('README') or
            name.startswith('NOTICE') or
            name.startswith('LICENSE') or
            name == '.gitignore' or
            name.startswith('.'))

def collect_project_assets(asset_root: Path, game_root: Path) -> Dict[str, Any]:
    """Enumerate game/assets/ and collect file metadata.

    Excludes .import/, assets_local/, README/NOTICE/LICENSE* files.
    Returns dict: normalized path -> {path, mime, size, is_referenced, referenced_by}.
    """
    all_refs = collect_references(str(game_root))
    # Normalize refs to file paths (remove res:// prefix)
    ref_paths = {r[len('res://'):] for r in all_refs}

    assets = {}
    excluded_roots = {'.import', '.git'}

    for root, dirs, files in os.walk(asset_root):
        # Prune excluded directories
        dirs[:] = [d for d in dirs if d not in excluded_roots]

        for file in files:
            if should_exclude_file(file):
                continue

            full_path = Path(root) / file
            rel_path = full_path.relative_to(asset_root.parent)  # Relative to game/
            rel_str = str(rel_path).replace('\\', '/')

            try:
                size = full_path.stat().st_size
            except (OSError, IOError):
                continue

            # Check if referenced
            is_referenced = False
            referenced_by = []
            for ref in ref_paths:
                if ref.endswith(rel_str) or f'/{rel_str}' in ref:
                    is_referenced = True
                    # Collect referencing files (simplified: just paths that contain this asset)
                    # In practice, we'd need to track which file references which asset
                    # For now, mark as referenced
                    break

            assets[rel_str] = {
                'path': rel_str,
                'mime': get_mime_type(rel_str),
                'size': size,
                'is_referenced': is_referenced,
                'referenced_by': referenced_by,
            }

    return assets

def categorize_assets(assets: Dict[str, Any]) -> Dict[str, List[Dict[str, Any]]]:
    """Group assets by category based on directory path."""
    categories = {
        'audio': [],
        'fonts': [],
        'generated': [],
        'iso': [],
        'sprites': [],
        'third_party': [],
    }

    for path, metadata in sorted(assets.items()):
        if path.startswith('assets/audio/'):
            categories['audio'].append(metadata)
        elif path.startswith('assets/fonts/'):
            categories['fonts'].append(metadata)
        elif path.startswith('assets/generated/'):
            categories['generated'].append(metadata)
        elif path.startswith('assets/iso/'):
            categories['iso'].append(metadata)
        elif path.startswith('assets/sprites/'):
            categories['sprites'].append(metadata)
        elif path.startswith('assets/third_party/'):
            categories['third_party'].append(metadata)

    return categories

def build_pack_units(assets: Dict[str, Any], licenses: Dict[str, str], game_root: Path) -> tuple[List[Dict[str, Any]], List[str]]:
    """Build pack-unit objects for third-party assets.

    Returns: (pack_unit_list, unreferenced_files_list)
    """
    all_refs = collect_references(str(game_root))
    ref_paths = {r[len('res://'):] for r in all_refs}

    packs = {}  # pack_root -> {files, referenced_files}

    for path, metadata in assets.items():
        if not path.startswith('assets/third_party/') and not path.startswith('assets/fonts/'):
            continue

        # Extract pack root
        parts = path.split('/')
        if len(parts) >= 3:
            pack_type = parts[1]  # third_party or fonts
            pack_name = parts[2]
            pack_root = f'{pack_type}/{pack_name}'

            if pack_root not in packs:
                packs[pack_root] = {
                    'files': [],
                    'referenced_files': {},
                }

            rel_file_path = '/'.join(parts[3:])
            packs[pack_root]['files'].append(rel_file_path)

            # Check if this file is referenced
            if metadata['is_referenced']:
                packs[pack_root]['referenced_files'][rel_file_path] = []

    # Build pack unit objects
    pack_units = []
    unreferenced = []

    for pack_root in sorted(packs.keys()):
        pack_data = packs[pack_root]
        license_line = licenses.get(pack_root, '')
        grade = get_license_grade(license_line)

        referenced_count = len(pack_data['referenced_files'])
        unreferenced_count = len(pack_data['files']) - referenced_count

        # Collect unreferenced files
        all_files = set(pack_data['files'])
        ref_files = set(pack_data['referenced_files'].keys())
        for unref in sorted(all_files - ref_files):
            unreferenced.append(f'assets/{pack_root}/{unref}')

        pack_unit = {
            'pack': pack_root.split('/')[-1],
            'root': f'assets/{pack_root}',
            'license_grade': grade,
            'license': license_line,
            'creator': '',  # Could parse from license line if needed
            'referenced_files': pack_data['referenced_files'],
            'referenced_count': referenced_count,
            'unreferenced_count': unreferenced_count,
        }
        pack_units.append(pack_unit)

    return pack_units, unreferenced

def build_asset_index(asset_root: Path, game_root: Path, licenses_path: Path) -> Dict[str, Any]:
    """Build complete asset index."""
    licenses = load_licenses(licenses_path)
    assets = collect_project_assets(asset_root, game_root)
    categories = categorize_assets(assets)
    pack_units, unreferenced_files = build_pack_units(assets, licenses, game_root)

    # Separate third-party into packs; project assets remain as files
    tp_assets = []
    for asset in categories.get('third_party', []):
        # Skip if in a pack unit (will be represented as pack instead)
        is_in_pack = False
        for pack in pack_units:
            if asset['path'].startswith(pack['root'] + '/'):
                is_in_pack = True
                break
        if not is_in_pack:
            tp_assets.append(asset)

    # Build final index
    index = {
        'metadata': {
            'version': '1.0',
            'assets_by_category': {
                'audio': len(categories['audio']),
                'fonts': len(categories['fonts']),
                'generated': len(categories['generated']),
                'iso': len(categories['iso']),
                'sprites': len(categories['sprites']),
                'third_party_packs': len(pack_units),
            },
            'total_files': sum(1 for k in assets.keys()),
            'total_packs': len(pack_units),
        },
        'assets': {
            'audio': categories['audio'],
            'fonts': categories['fonts'],
            'generated': categories['generated'],
            'iso': categories['iso'],
            'sprites': categories['sprites'],
            'third_party': pack_units,  # Packs, not individual files
        },
    }

    return index, unreferenced_files

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--asset-root', default=None, help='game/assets path')
    parser.add_argument('--data-dir', default=None, help='game/data path')
    parser.add_argument('--licenses', default=None, help='docs/art/LICENSES.md path')
    parser.add_argument('--output', default=None, help='game/assets/assets.json output path')
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    asset_root = Path(args.asset_root) if args.asset_root else (script_dir / '..' / '..' / 'game' / 'assets')
    asset_root = asset_root.resolve()
    game_root = asset_root.parent

    licenses_path = Path(args.licenses) if args.licenses else (script_dir / '..' / '..' / 'docs' / 'art' / 'LICENSES.md')
    licenses_path = licenses_path.resolve()

    output_path = Path(args.output) if args.output else (asset_root / 'assets.json')
    output_path = output_path.resolve()

    print(f"[build_asset_index] asset_root = {asset_root}")
    print(f"[build_asset_index] game_root = {game_root}")
    print(f"[build_asset_index] licenses = {licenses_path}")
    print(f"[build_asset_index] output = {output_path}")

    index, unreferenced = build_asset_index(asset_root, game_root, licenses_path)

    # Write JSON
    with output_path.open('w', encoding='utf-8') as f:
        json.dump(index, f, indent=2, ensure_ascii=False, sort_keys=True)
        f.write('\n')  # Final newline

    print(f"\n[build_asset_index] Index written to {output_path}")
    print(f"[build_asset_index] Total packs: {index['metadata']['total_packs']}")
    print(f"[build_asset_index] Total files: {index['metadata']['total_files']}")

    if unreferenced:
        print(f"\n[build_asset_index] Unreferenced third-party files ({len(unreferenced)}):")
        for path in unreferenced[:20]:
            print(f"  - {path}")
        if len(unreferenced) > 20:
            print(f"  ... and {len(unreferenced) - 20} more")

    return 0

if __name__ == '__main__':
    sys.exit(main())
