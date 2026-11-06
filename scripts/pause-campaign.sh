#!/usr/bin/env bash
# pause-campaign.sh — pause every object recorded in state.json.
#
# Order: ads, then ad set, then campaign. A failed ad update does not skip
# the campaign pause. Nothing is deleted.
#
# Usage:
#   pause-campaign.sh [--dry-run] <client> <slug>

set -euo pipefail

DRY_RUN=0
CLIENT=""
SLUG=""
ORIG_ARGS=("$@")

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1; shift ;;
    -h|--help)
      echo "usage: $(basename "$0") [--dry-run] <client> <slug>"
      echo "example: $(basename "$0") acme-co summer-sale-jul26"
      exit 0
      ;;
    -*)
      echo "error: unknown flag: $1" >&2
      exit 2
      ;;
    *)
      if [[ -z "$CLIENT" ]]; then CLIENT="$1"
      elif [[ -z "$SLUG" ]]; then SLUG="$1"
      else
        echo "error: unexpected argument: $1" >&2
        exit 2
      fi
      shift
      ;;
  esac
done

if [[ -z "$CLIENT" || -z "$SLUG" ]]; then
  echo "usage: $(basename "$0") [--dry-run] <client> <slug>" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../bin/lib/client-env.sh
source "$HARNESS_DIR/bin/lib/client-env.sh"

validate_client_name "$CLIENT" || exit 2
validate_slug "$SLUG" || exit 2

META="$HARNESS_DIR/bin/meta"
ENV_FILE="$HARNESS_DIR/clients/$CLIENT/.env"
CAMPAIGN_DIR="$HARNESS_DIR/clients/$CLIENT/campaigns/$SLUG"
STATE_FILE="$CAMPAIGN_DIR/state.json"
OPS_LOG="$CAMPAIGN_DIR/ops.log"

[[ -d "$CAMPAIGN_DIR" ]] || { echo "error: campaign folder not found: $CAMPAIGN_DIR" >&2; exit 1; }
[[ -f "$STATE_FILE" ]] || { echo "error: state.json not found — campaign may not be launched yet" >&2; exit 1; }
[[ -f "$ENV_FILE" ]] || { echo "error: $ENV_FILE not found" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "error: jq required" >&2; exit 1; }

if [[ -z "${META_OP_RESOLVED:-}" ]]; then
  clear_budget_caps
  reexec_if_op_env "$ENV_FILE" "${ORIG_ARGS[@]}"
  load_client_env "$ENV_FILE"
fi

AD_ACCOUNT_ID="$(jq -r '.ad_account_id // empty' "$STATE_FILE")"
if [[ -z "$AD_ACCOUNT_ID" || "$AD_ACCOUNT_ID" == "null" ]]; then
  AD_ACCOUNT_ID="${META_ADS_ACCOUNT_ID:-}"
fi
[[ -n "$AD_ACCOUNT_ID" ]] || { echo "error: no ad account id in state.json or $ENV_FILE" >&2; exit 1; }

FAILURES=0

pause_resource() {
  local kind="$1" id="$2" name="$3"
  local err code
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] $kind: $name ($id)"
    echo "          would run: $META $CLIENT -o json --no-input ads --ad-account-id $AD_ACCOUNT_ID $kind update $id --status PAUSED"
    return 0
  fi
  echo "[pause] $kind: $name ($id)"
  set +e
  err=$("$META" "$CLIENT" -o json --no-input ads --ad-account-id "$AD_ACCOUNT_ID" \
    "$kind" update "$id" --status PAUSED 2>&1)
  code=$?
  set -e
  if [[ $code -eq 0 ]]; then
    append_ops_log "$OPS_LOG" pause "$kind" "$id" "$name" ok
    return 0
  fi
  echo "[fail] $kind $id" >&2
  printf '%s\n' "$err" >&2
  append_ops_log "$OPS_LOG" pause "$kind" "$id" "$name" fail "$err"
  FAILURES=$((FAILURES + 1))
}

CAMPAIGN_NAME="$(jq -r '.campaign.name // "<unknown>"' "$STATE_FILE")"
MODE="pause"
[[ $DRY_RUN -eq 1 ]] && MODE="DRY RUN"
echo "Mode: $MODE | Client: $CLIENT | Slug: $SLUG | Campaign: $CAMPAIGN_NAME"
echo "Order: ads -> adset -> campaign"
echo ""

ADS_COUNT=0
while IFS=$'\t' read -r id name; do
  [[ -z "$id" || "$id" == "null" ]] && continue
  pause_resource ad "$id" "$name"
  ADS_COUNT=$((ADS_COUNT + 1))
done < <(jq -r '.ads[]? | [.id, .name] | @tsv' "$STATE_FILE")
[[ $ADS_COUNT -eq 0 ]] && echo "[skip] no ads in state.json"

ADSET_ID="$(jq -r '.adset.id // empty' "$STATE_FILE")"
ADSET_NAME="$(jq -r '.adset.name // "<unknown>"' "$STATE_FILE")"
if [[ -n "$ADSET_ID" && "$ADSET_ID" != "null" ]]; then
  pause_resource adset "$ADSET_ID" "$ADSET_NAME"
else
  echo "[skip] no adset in state.json"
fi

CAMPAIGN_ID="$(jq -r '.campaign.id // empty' "$STATE_FILE")"
if [[ -n "$CAMPAIGN_ID" && "$CAMPAIGN_ID" != "null" ]]; then
  pause_resource campaign "$CAMPAIGN_ID" "$CAMPAIGN_NAME"
else
  echo "[skip] no campaign in state.json"
fi

echo ""
if [[ $DRY_RUN -eq 1 ]]; then
  echo "dry-run complete."
elif [[ $FAILURES -eq 0 ]]; then
  echo "done. all recorded resources are PAUSED."
else
  echo "done with $FAILURES failure(s). Campaign pause was still attempted. See $OPS_LOG" >&2
  exit 1
fi
