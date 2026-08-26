#!/usr/bin/env python3
"""Write a compact provenance record for release assets before attestation."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("artifact_directory", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    release_tag = os.environ.get("RELEASE_TAG")
    release_commit = os.environ.get("RELEASE_COMMIT")
    missing = [name for name, value in (("RELEASE_TAG", release_tag), ("RELEASE_COMMIT", release_commit)) if not value]
    if missing:
        raise SystemExit(f"Missing required release metadata: {', '.join(missing)}")

    subjects = []
    for path in sorted(args.artifact_directory.iterdir()):
        if not path.is_file() or path == args.output or path.name == "SHA256SUMS":
            continue
        subjects.append(
            {
                "name": path.name,
                "digest": {"sha256": hashlib.sha256(path.read_bytes()).hexdigest()},
            }
        )

    statement = {
        "_type": "https://in-toto.io/Statement/v1",
        "subject": subjects,
        "predicateType": "https://slsa.dev/provenance/v1",
        "predicate": {
            "buildDefinition": {
                "buildType": "https://github.com/9spokes/terraform-components/.github/workflows/release.yml",
                "externalParameters": {"tag": release_tag},
                "resolvedDependencies": [
                    {
                        "uri": "git+https://github.com/9spokes/terraform-components",
                        "digest": {"gitCommit": release_commit},
                    }
                ],
            },
            "runDetails": {
                "builder": {"id": "https://github.com/actions/runner"},
                "metadata": {"invocationId": os.environ.get("GITHUB_RUN_ID", "")},
            },
        },
    }
    args.output.write_text(json.dumps(statement, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
