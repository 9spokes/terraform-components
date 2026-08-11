#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_root="$repo_root/components/serverless-ca/modules/ca/modules/terraform-aws-ca-lambda"
output_dir=${1:?usage: build-serverless-ca-lambdas.sh OUTPUT_DIR}
image="public.ecr.aws/lambda/python:3.14@sha256:4db2de7231d8bdc73c298aec36ddbb7b70366b6511913cbbf1a15a93a32b6cd9"

mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd)

functions=(
  create_issuing_ca
  create_root_ca
  expiry
  issuing_ca_crl
  notify
  root_ca_crl
  tls_cert
)

for function_name in "${functions[@]}"; do
  docker run --rm \
    --platform linux/amd64 \
    --entrypoint /bin/bash \
    --env "FUNCTION_NAME=$function_name" \
    --env AWS_DEFAULT_REGION=ap-southeast-2 \
    --env AWS_EC2_METADATA_DISABLED=true \
    --env SLACK_SECRET_ARN=arn:aws:secretsmanager:ap-southeast-2:111111111111:secret:smoke \
    --env SLACK_CHANNELS=smoke \
    --env SLACK_BAD_EMOJI=:x: \
    --env SLACK_GOOD_EMOJI=:white_check_mark: \
    --env SLACK_USERNAME=Serverless-CA-Smoke \
    --env SLACK_WARNING_EMOJI=:warning: \
    --volume "$source_root:/src:ro" \
    --volume "$output_dir:/out" \
    "$image" \
    -euo pipefail -c '
      python -m pip install \
        --disable-pip-version-check \
        --no-compile \
        --only-binary=:all: \
        --require-hashes \
        --requirement "/src/lambda_code/${FUNCTION_NAME}/requirements.lock" \
        --target /tmp/package
      cp -a "/src/lambda_code/${FUNCTION_NAME}/." /tmp/package/
      cp -a /src/utils /tmp/package/utils
      python - <<"PY"
import os
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

root = Path("/tmp/package")
function_name = os.environ["FUNCTION_NAME"]
target = Path("/out") / f"{function_name}.zip"
with ZipFile(target, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
    for path in sorted(p for p in root.rglob("*") if p.is_file()):
        relative = path.relative_to(root).as_posix()
        info = ZipInfo(relative, date_time=(1980, 1, 1, 0, 0, 0))
        info.compress_type = ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        archive.writestr(info, path.read_bytes(), compress_type=ZIP_DEFLATED, compresslevel=9)
PY
      python - <<"PY"
import importlib
import os
import sys
sys.path.insert(0, "/tmp/package")
importlib.import_module(os.environ["FUNCTION_NAME"])
PY
    '
done

(
  cd "$output_dir"
  sha256sum -- *.zip | sort -k2 > SHA256SUMS
)
