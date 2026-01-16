#!/usr/bin/env python3
"""
Disable NSFW Check in FaceFusion
=================================
This script modifies FaceFusion to skip NSFW content analysis.
Run this after cloning FaceFusion repository.

Usage: python disable-nsfw-check.py [facefusion_dir]
"""

import sys
import re
from pathlib import Path


def patch_content_analyser(file_path: Path) -> None:
    """Modify content_analyser.py to always return False for NSFW checks."""
    content = file_path.read_text()

    # Add early return to pre_check to skip NSFW model download/validation
    content = re.sub(
        r'(def pre_check\(\) -> bool:)\n(\t)',
        r'\1\n\treturn True  # NSFW model check disabled\n\2',
        content
    )

    # Add early return to analyse_frame
    content = re.sub(
        r'(def analyse_frame\(vision_frame : VisionFrame\) -> bool:)\n(\t)',
        r'\1\n\treturn False  # NSFW check disabled\n\2',
        content
    )

    # Add early return to analyse_image
    content = re.sub(
        r'(def analyse_image\(image_path : str\) -> bool:)\n(\t)',
        r'\1\n\treturn False  # NSFW check disabled\n\2',
        content
    )

    # Add early return to analyse_video
    content = re.sub(
        r'(def analyse_video\(video_path : str, trim_frame_start : int, trim_frame_end : int\) -> bool:)\n(\t)',
        r'\1\n\treturn False  # NSFW check disabled\n\2',
        content
    )

    # Add early return to analyse_stream
    content = re.sub(
        r'(def analyse_stream\(vision_frame : VisionFrame, video_fps : Fps\) -> bool:)\n(\t)',
        r'\1\n\treturn False  # NSFW check disabled\n\2',
        content
    )

    file_path.write_text(content)
    print(f"  Patched: {file_path}")


def patch_core(file_path: Path) -> None:
    """Modify core.py to remove content_analyser hash check."""
    content = file_path.read_text()

    # Remove hash check - just keep the module pre_check
    content = content.replace(
        "return all(module.pre_check() for module in common_modules) and content_analyser_hash == 'b14e7b92'",
        "return all(module.pre_check() for module in common_modules)  # Hash check disabled"
    )

    file_path.write_text(content)
    print(f"  Patched: {file_path}")


def main():
    facefusion_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/facefusion")

    print("Disabling NSFW check in FaceFusion...")
    print(f"  Directory: {facefusion_dir}")

    content_analyser_path = facefusion_dir / "facefusion" / "content_analyser.py"
    core_path = facefusion_dir / "facefusion" / "core.py"

    if not content_analyser_path.exists():
        print(f"ERROR: {content_analyser_path} not found!")
        sys.exit(1)

    if not core_path.exists():
        print(f"ERROR: {core_path} not found!")
        sys.exit(1)

    patch_content_analyser(content_analyser_path)
    patch_core(core_path)

    print("NSFW check disabled successfully!")


if __name__ == "__main__":
    main()
