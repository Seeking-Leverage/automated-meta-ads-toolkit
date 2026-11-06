#!/usr/bin/env bash
# validate-campaign.sh — check campaign.yaml before any Meta write.
#
# Usage:
#   validate-campaign.sh <client> <slug>

set -euo pipefail

CLIENT="${1:-}"
SLUG="${2:-}"

if [[ -z "$CLIENT" || -z "$SLUG" || $# -ne 2 ]]; then
  echo "usage: $(basename "$0") <client> <slug>" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../bin/lib/client-env.sh
source "$HARNESS_DIR/bin/lib/client-env.sh"

validate_client_name "$CLIENT" || exit 2
validate_slug "$SLUG" || exit 2

ENV_FILE="$HARNESS_DIR/clients/$CLIENT/.env"
CAMPAIGN_DIR="$HARNESS_DIR/clients/$CLIENT/campaigns/$SLUG"
PY="$SCRIPT_DIR/validate-campaign.py"

[[ -f "$ENV_FILE" ]] || { echo "error: $ENV_FILE not found" >&2; exit 2; }
[[ -d "$CAMPAIGN_DIR" ]] || { echo "error: campaign folder not found: $CAMPAIGN_DIR" >&2; exit 1; }

if [[ -z "${META_OP_RESOLVED:-}" ]]; then
  clear_budget_caps
  reexec_if_op_env "$ENV_FILE" "$@"
  load_client_env "$ENV_FILE"
fi

if python3 -c 'import yaml' >/dev/null 2>&1; then
  exec python3 "$PY" "$CAMPAIGN_DIR"
fi

command -v uv >/dev/null 2>&1 || {
  echo "error: PyYAML is not installed and uv is not available" >&2
  exit 127
}
exec uv run --no-project --with pyyaml==6.0.2 python "$PY" "$CAMPAIGN_DIR"
