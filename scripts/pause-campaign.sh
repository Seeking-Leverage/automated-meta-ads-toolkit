#!/usr/bin/env bash
# pause-campaign.sh — pause all resources for a launched campaign.
#
# Reads clients/<client>/campaigns/<slug>/state.json and pauses:
#   ads -> adset -> campaign
#
# Usage:
#   pause-campaign.sh [--dry-run] <client> <slug>
#
# NEVER deletes anything. Pause only.

set -euo pipefail

DRY_RUN=0
CLIENT=""
SLUG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1; shift ;;
    -h|--help)
      echo "usage: $(basename "$0") [--dry-run] <client> <slug>"
      echo "example: $(basename "$0") acme-co summer-sale-jul26"
      exit 0
      ;;
    -*)
      echo "error: unknown flag: $1" >&2; exit 1 ;;
    *)
      if [[ -z "$CLIENT" ]]; then CLIENT="$1"
      elif [[ -z "$SLUG" ]]; then SLUG="$1"
      else echo "error: unexpected argument: $1" >&2; exit 1
      fi
      shift ;;
  esac
done

if [[ -z "$CLIENT" || -z "$SLUG" ]]; then
  echo "usage: $(basename "$0") [--dry-run] <client> <slug>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
META="$HARNESS_DIR/bin/meta"
ENV_FILE="$HARNESS_DIR/clients/$CLIENT/.env"
CAMPAIGN_DIR="$HARNESS_DIR/clients/$CLIENT/campaigns/$SLUG"
STATE_FILE="$CAMPAIGN_DIR/state.json"

[[ -d "$CAMPAIGN_DIR" ]] || { echo "error: campaign folder not found: $CAMPAIGN_DIR" >&2; exit 1; }
[[ -f "$STATE_FILE" ]] || { echo "error: state.json not found — campaign may not be launched yet" >&2; exit 1; }
[[ -f "$ENV_FILE" ]] || { echo "error: $ENV_FILE not found" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "error: jq required" >&2; exit 1; }

AD_ACCOUNT_ID="$(jq -r '.ad_account_id // empty' "$STATE_FILE")"
[[ -n "$AD_ACCOUNT_ID" ]] || AD_ACCOUNT_ID="$(grep META_ADS_ACCOUNT_ID "$ENV_FILE" | cut -d= -f2-)"

pause_resource() {
  local kind="$1" id="$2" name="$3"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] $kind: $name ($id)"
    echo "          would run: $META $CLIENT -o json --no-input ads --ad-account-id $AD_ACCOUNT_ID $kind update $id --status PAUSED"
    return 0
  fi
  echo "[pause] $kind: $name ($id)"
  "$META" "$CLIENT" -o json --no-input ads --ad-account-id "$AD_ACCOUNT_ID" \
    "$kind" update "$id" --status PAUSED
}

CAMPAIGN_NAME="$(jq -r '.campaign.name // "<unknown>"' "$STATE_FILE")"
MODE="pause"; [[ $DRY_RUN -eq 1 ]] && MODE="DRY RUN"
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
if [[ -n "$ADSET_ID" ]]; then pause_resource adset "$ADSET_ID" "$ADSET_NAME"
else echo "[skip] no adset in state.json"; fi

CAMPAIGN_ID="$(jq -r '.campaign.id // empty' "$STATE_FILE")"
if [[ -n "$CAMPAIGN_ID" ]]; then pause_resource campaign "$CAMPAIGN_ID" "$CAMPAIGN_NAME"
else echo "[skip] no campaign in state.json"; fi

echo ""
[[ $DRY_RUN -eq 1 ]] && echo "dry-run complete." || echo "done. all recorded resources are PAUSED."