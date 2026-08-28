import importlib.util
from pathlib import Path
from unittest.mock import MagicMock

import pytest


def _load_operational_s3_module():
    module_path = Path(__file__).resolve().parents[3] / "utils" / "modules" / "aws" / "s3.py"
    spec = importlib.util.spec_from_file_location("operational_s3_utils", module_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_get_s3_bucket_reports_missing_purpose():
    s3_utils = _load_operational_s3_module()
    session = MagicMock()
    session.client.return_value.list_buckets.return_value = {
        "Buckets": [{"Name": "example-external-certificates"}]
    }

    with pytest.raises(
        LookupError,
        match=r"No S3 bucket name contains '-internal-' \(searched 1 bucket\(s\)\)",
    ):
        s3_utils.get_s3_bucket("internal", session=session)


def test_list_s3_object_keys_returns_empty_list_without_contents():
    s3_utils = _load_operational_s3_module()
    session = MagicMock()
    session.client.return_value.list_objects_v2.return_value = {
        "KeyCount": 0,
        "IsTruncated": False,
    }

    assert s3_utils.list_s3_object_keys("empty-bucket", session=session) == []
