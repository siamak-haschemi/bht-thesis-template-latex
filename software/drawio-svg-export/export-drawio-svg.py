#!/usr/bin/env python3
"""
Export a .drawio file to SVGs (one per tab, named after tab titles).
Incremental: only exports tabs whose content changed since the last run.

Usage:
    python export-drawio-svg.py <path-to-drawio-file>

Requires the `drawio` CLI (drawio-desktop) on PATH. Outputs land in
../../figures relative to this script. Staging/committing the result is
left to the user.
"""
from __future__ import annotations

import re
import sys
import json
import hashlib
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Dict, List, Tuple

# =============================================================================
# Configuration
# =============================================================================
SCRIPT_DIR = Path(__file__).parent.absolute()
MANIFEST_DIR = SCRIPT_DIR  # Manifest lives next to this script
DEFAULT_OUTPUT_DIR = SCRIPT_DIR.parent.parent / "figures"  # ../../figures


# =============================================================================
# Helper Functions
# =============================================================================
def sanitize(name: str) -> str:
    """Sanitize a filename by removing invalid characters."""
    name = re.sub(r'[\\/:"*?<>|]+', '_', name)
    name = re.sub(r'\s+', ' ', name).strip()
    return name or "Untitled"


def get_page_elements(path: Path) -> List[ET.Element]:
    """Extract diagram pages from a .drawio file."""
    try:
        tree = ET.parse(path)
        return list(tree.getroot().findall(".//diagram"))
    except ET.ParseError:
        return []


def page_hash(element: ET.Element) -> str:
    """Compute a stable content hash for a diagram page."""
    canonical = ET.tostring(element, encoding="utf-8")
    return hashlib.sha1(canonical).hexdigest()


# =============================================================================
# Manifest Management
# =============================================================================
def manifest_path(input_file: Path) -> Path:
    """Get path to the manifest file for a given .drawio file."""
    return MANIFEST_DIR / f".drawio-export.{input_file.stem}.json"


def load_manifest(path: Path) -> Dict:
    """Load manifest from disk; return empty dict on any error."""
    if not path.is_file():
        return {}
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return {}


def save_manifest(path: Path, data: Dict) -> None:
    """Save manifest to disk atomically."""
    tmp = path.with_suffix(path.suffix + ".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, sort_keys=True)
    tmp.replace(path)


# =============================================================================
# Export Planning
# =============================================================================
def plan_pages(input_file: Path) -> Tuple[List[Tuple[int, str]], Dict[int, str]]:
    """
    Determine output filenames and content hashes for each page.

    Returns:
        - file_specs: list of (page_index, filename)
        - page_hashes: dict of page_index -> content_hash
    """
    diagrams = get_page_elements(input_file)
    titles = [(d.attrib.get("name") or f"Page {i+1}") for i, d in enumerate(diagrams)] or ["Page 1"]

    # Deduplicate filenames so two tabs with the same name don't collide.
    seen: Dict[str, int] = {}
    file_specs: List[Tuple[int, str]] = []

    for idx, title in enumerate(titles):
        base = sanitize(title)
        name = base
        count = seen.get(base, 0)

        while name in seen:
            count += 1
            name = f"{base} ({count})"

        seen[base] = count
        seen[name] = 0
        file_specs.append((idx, name + ".svg"))

    # Compute content hashes (fall back to hashing the whole file if there
    # are no diagram elements, so we can still detect changes).
    if diagrams:
        hashes = {i: page_hash(el) for i, el in enumerate(diagrams)}
    else:
        hashes = {0: hashlib.sha1(input_file.read_bytes()).hexdigest()}

    return file_specs, hashes


def determine_exports(input_file: Path, output_dir: Path) -> Tuple[List[Tuple[int, str]], Dict]:
    """
    Determine which pages need to be exported based on the manifest.

    Returns:
        - to_export: list of (page_index, filename) that need export
        - new_manifest: updated manifest data to persist after a successful run
    """
    file_specs, hashes = plan_pages(input_file)
    prev_pages: Dict[str, Dict] = load_manifest(manifest_path(input_file)).get("pages", {})

    to_export: List[Tuple[int, str]] = []
    for idx, filename in file_specs:
        prev_entry = prev_pages.get(str(idx))
        out_path = output_dir / filename

        # Re-export if: new page, content changed, filename changed, or output missing.
        if (not prev_entry
                or prev_entry.get("hash") != hashes[idx]
                or prev_entry.get("filename") != filename
                or not out_path.is_file()):
            to_export.append((idx, filename))

    new_manifest = {
        "version": 1,
        "pages": {
            str(idx): {"filename": fname, "hash": hashes[idx]}
            for idx, fname in file_specs
        },
    }
    return to_export, new_manifest


# =============================================================================
# Export Execution
# =============================================================================
def export_svg(input_file: Path, page_index: int, output_file: Path) -> None:
    """Export a single page from a .drawio file to SVG via the drawio CLI."""
    # draw.io uses 1-based page indexing
    cmd = [
        "drawio", "-x", "-f", "svg",
        "-p", str(page_index + 1),
        "-o", str(output_file),
        str(input_file),
    ]
    subprocess.run(cmd, check=True)


def do_export(input_file: Path, output_dir: Path) -> List[Path]:
    """Export changed pages. Returns the list of files written."""
    output_dir.mkdir(parents=True, exist_ok=True)
    to_export, new_manifest = determine_exports(input_file, output_dir)

    if not to_export:
        print("✓ No changes detected; nothing to export.")
        save_manifest(manifest_path(input_file), new_manifest)
        return []

    print(f"Exporting {len(to_export)} page(s) to {output_dir}")
    exported: List[Path] = []
    for page_idx, filename in to_export:
        output_file = output_dir / filename
        try:
            export_svg(input_file, page_idx, output_file)
        except FileNotFoundError:
            print("Error: 'drawio' CLI not found in PATH.")
            print("Install from: https://github.com/jgraph/drawio-desktop/releases")
            sys.exit(2)
        except subprocess.CalledProcessError as e:
            print(f"Error exporting page {page_idx + 1}: {e}")
            sys.exit(3)
        print(f"  ✓ Page {page_idx + 1}: {filename}")
        exported.append(output_file)

    save_manifest(manifest_path(input_file), new_manifest)
    return exported


# =============================================================================
# Main
# =============================================================================
def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    input_file = Path(sys.argv[1]).absolute()
    if not input_file.is_file():
        print(f"Error: File not found: {input_file}")
        sys.exit(1)

    do_export(input_file, DEFAULT_OUTPUT_DIR)


if __name__ == "__main__":
    main()
