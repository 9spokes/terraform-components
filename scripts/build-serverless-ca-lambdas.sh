#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_root="$repo_root/components/serverless-ca/modules/ca/modules/terraform-aws-ca-lambda"
output_dir=${1:?usage: build-serverless-ca-lambdas.sh OUTPUT_DIR [x86_64|arm64 ...]}
shift

architectures=("$@")
if ((${#architectures[@]} == 0)); then
  architectures=(x86_64 arm64)
fi

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

for architecture in "${architectures[@]}"; do
  case "$architecture" in
    x86_64)
      docker_platform="linux/amd64"
      image="public.ecr.aws/lambda/python:3.14@sha256:387ef2f59bde4c88ec871293175f5a15705307662887a1398e10285c5f6c38a6"
      ;;
    arm64)
      docker_platform="linux/arm64"
      image="public.ecr.aws/lambda/python:3.14@sha256:c6922e6f45899b556a1acc0caa432457a5afd7bfde75d7ee7bad8ce692909d7e"
      ;;
    *)
      echo "unsupported architecture: $architecture" >&2
      exit 2
      ;;
  esac

  for function_name in "${functions[@]}"; do
    docker run --rm \
      --platform "$docker_platform" \
      --entrypoint /bin/bash \
      --env "ARCHITECTURE=$architecture" \
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
      machine=$(uname -m)
      case "${ARCHITECTURE}:${machine}" in
        x86_64:x86_64|arm64:aarch64) ;;
        *)
          echo "architecture mismatch: requested ${ARCHITECTURE}, container reported ${machine}" >&2
          exit 1
          ;;
      esac
      python -m pip install \
        --disable-pip-version-check \
        --no-compile \
        --only-binary=:all: \
        --quiet \
        --require-hashes \
        --root-user-action=ignore \
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
architecture = os.environ["ARCHITECTURE"]
target = Path("/out") / f"{function_name}-{architecture}.zip"
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
done

(
  cd "$output_dir"
  sha256sum -- *.zip | sort -k2 > SHA256SUMS
)
