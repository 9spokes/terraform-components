#!/usr/bin/env python3
"""Create a deterministic, self-contained Serverless CA component ZIP."""

from __future__ import annotations

import argparse
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    component = repo_root / "components" / "serverless-ca"
    excluded_parts = {".terraform", "__pycache__", ".pytest_cache"}
    excluded_names = {".terraform.lock.hcl", ".DS_Store"}

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(args.output, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(p for p in component.rglob("*") if p.is_file()):
            relative = path.relative_to(component)
            if excluded_parts.intersection(relative.parts) or path.name in excluded_names:
                continue
            info = ZipInfo(
                f"serverless-ca/{relative.as_posix()}",
                date_time=(1980, 1, 1, 0, 0, 0),
            )
            info.compress_type = ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(
                info,
                path.read_bytes(),
                compress_type=ZIP_DEFLATED,
                compresslevel=9,
            )


if __name__ == "__main__":
    main()
