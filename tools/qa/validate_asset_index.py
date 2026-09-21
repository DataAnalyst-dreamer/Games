#!/usr/bin/env python3
"""Validate game/assets/assets.json — stale detection and registration check.

Regenerates index in-memory per identical build_asset_index logic and compares
byte-for-byte against committed version. Checks third-party packs are registered
in LICENSES.md and all referenced files exist.

Exit codes: 0 = valid, 1 = stale or registration error.
Usage: python3 tools/qa/validate_asset_index.py [--asset-root game/assets] [--licenses docs/art/LICENSES.md]
"""
from __future__ import annotations

import argparse, json, sys
from pathlib import Path
from typing import Any, Dict

# Import the build logic directly to regenerate (same directory)
import build_asset_index as bai

def load_index(path: Path) -> Dict[str, Any]:
    """Load and parse assets.json."""
    if not path.exists():
        return {}
    with path.open('r', encoding='utf-8') as f:
        return json.load(f)

def validate_asset_index(asset_root: Path, game_root: Path, licenses_path: Path, index_path: Path) -> tuple[bool, list[str]]:
    """Validate index.

    Returns: (is_valid, error_messages)
    """
    errors = []

    # Load committed index
    committed = load_index(index_path)
    if not committed:
        errors.append(f"Index file not found or empty: {index_path}")
        return False, errors

    # Regenerate index in-memory
    try:
        regenerated, _ = bai.build_asset_index(asset_root, game_root, licenses_path)
    except Exception as e:
        errors.append(f"Failed to regenerate index: {e}")
        return False, errors

    # Serialize both with identical settings for byte-for-byte comparison
    committed_json = json.dumps(committed, indent=2, ensure_ascii=False, sort_keys=True)
    regenerated_json = json.dumps(regenerated, indent=2, ensure_ascii=False, sort_keys=True)

    if committed_json != regenerated_json:
        errors.append("Index is stale — regenerate with build_asset_index.py")
        return False, errors

    # Check third-party pack registration
    licenses_content = licenses_path.read_text(encoding='utf-8', errors='ignore') if licenses_path.exists() else ''

    for pack in committed.get('assets', {}).get('third_party', []):
        pack_root = pack.get('root', 'assets/unknown')  # e.g., 'assets/third_party/ninja_adventure'
        pack_path = pack_root.replace('assets/', '')  # e.g., 'third_party/ninja_adventure'

        if pack_path not in licenses_content:
            errors.append(f"Pack '{pack_path}' not registered in LICENSES.md")

    # Check file existence for referenced files
    for cat in ['audio', 'fonts', 'generated', 'iso', 'sprites']:
        for asset in committed.get('assets', {}).get(cat, []):
            path_str = asset.get('path', '')
            full_path = game_root / path_str
            if asset.get('is_referenced') and not full_path.exists():
                errors.append(f"Referenced file not found: {path_str}")

    return len(errors) == 0, errors

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--asset-root', default=None, help='game/assets path')
    parser.add_argument('--licenses', default=None, help='docs/art/LICENSES.md path')
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    asset_root = Path(args.asset_root) if args.asset_root else (script_dir / '..' / '..' / 'game' / 'assets')
    asset_root = asset_root.resolve()
    game_root = asset_root.parent

    licenses_path = Path(args.licenses) if args.licenses else (script_dir / '..' / '..' / 'docs' / 'art' / 'LICENSES.md')
    licenses_path = licenses_path.resolve()

    index_path = asset_root / 'assets.json'

    print(f"[validate_asset_index] asset_root = {asset_root}")
    print(f"[validate_asset_index] index = {index_path}")
    print(f"[validate_asset_index] licenses = {licenses_path}")

    is_valid, errors = validate_asset_index(asset_root, game_root, licenses_path, index_path)

    if errors:
        print(f"\n[validate_asset_index] Validation errors ({len(errors)}):")
        for error in errors:
            print(f"  - {error}")
        print("\nFAIL")
        return 1

    print("\n[validate_asset_index] PASS - Index is valid and up-to-date")
    return 0

if __name__ == '__main__':
    sys.exit(main())
