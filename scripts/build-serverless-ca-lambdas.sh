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

  pip_cache_dir=${PIP_CACHE_DIR:-"$output_dir/.pip-cache/$architecture"}
  mkdir -p "$pip_cache_dir"
  pip_cache_dir=$(cd "$pip_cache_dir" && pwd)

  docker run --rm \
    --platform "$docker_platform" \
    --entrypoint /bin/bash \
    --env "ARCHITECTURE=$architecture" \
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
    --volume "$pip_cache_dir:/pip-cache" \
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

    for function_name in create_issuing_ca create_root_ca expiry issuing_ca_crl notify root_ca_crl tls_cert; do
      package_root="/tmp/package/${function_name}"
      rm -rf "$package_root"
      mkdir -p "$package_root"
      python -m pip install \
        --disable-pip-version-check \
        --no-compile \
        --only-binary=:all: \
        --quiet \
        --require-hashes \
        --root-user-action=ignore \
        --cache-dir /pip-cache \
        --requirement "/src/lambda_code/${function_name}/requirements.lock" \
        --target "$package_root"
      cp -a "/src/lambda_code/${function_name}/." "$package_root/"
      cp -a /src/utils "$package_root/utils"
      python - "$package_root" "$function_name" "$ARCHITECTURE" <<"PY"
import sys
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

root = Path(sys.argv[1])
function_name = sys.argv[2]
architecture = sys.argv[3]
target = Path("/out") / f"{function_name}-{architecture}.zip"
with ZipFile(target, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
    for path in sorted(p for p in root.rglob("*") if p.is_file()):
        relative = path.relative_to(root).as_posix()
        info = ZipInfo(relative, date_time=(1980, 1, 1, 0, 0, 0))
        info.compress_type = ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        archive.writestr(info, path.read_bytes(), compress_type=ZIP_DEFLATED, compresslevel=9)
PY
      python - "$package_root" "$function_name" <<"PY"
import importlib
import sys

sys.path.insert(0, sys.argv[1])
importlib.import_module(sys.argv[2])
PY
    done
    '
done

expected_zip_names=()
for architecture in "${architectures[@]}"; do
  for function_name in "${functions[@]}"; do
    expected_zip_names+=("${function_name}-${architecture}.zip")
  done
done

(
  cd "$output_dir"
  actual_zip_names=$(find . -maxdepth 1 -type f -name '*.zip' -printf '%f\n' | LC_ALL=C sort)
  expected_zip_names_sorted=$(printf '%s\n' "${expected_zip_names[@]}" | LC_ALL=C sort)
  diff -u <(printf '%s\n' "$expected_zip_names_sorted") <(printf '%s\n' "$actual_zip_names")
  sha256sum -- "${expected_zip_names[@]}" | LC_ALL=C sort -k2 > SHA256SUMS
)
