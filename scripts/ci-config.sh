#!/usr/bin/env bash
# CI helper: writes the git-ignored backend.hcl and terraform.tfvars for one environment from GitHub environment variables.
set -euo pipefail
ENV="${1:?env: dev|test|prod}"
case "$ENV" in dev|test|prod) ;; *) echo "env must be dev, test or prod" >&2; exit 2 ;; esac
: "${TF_STATE_BUCKET:?TF_STATE_BUCKET is not set}" "${TF_STATE_REGION:?TF_STATE_REGION is not set}" "${TFVARS:?TFVARS is not set}"
DIR="$(cd "$(dirname "$0")/.." && pwd)/environments/$ENV"
cat > "$DIR/backend.hcl" <<HCL
bucket       = "$TF_STATE_BUCKET"
region       = "$TF_STATE_REGION"
use_lockfile = true
encrypt      = true
HCL
printf '%s\n' "$TFVARS" > "$DIR/terraform.tfvars"
echo "Wrote backend.hcl and terraform.tfvars for $ENV"
