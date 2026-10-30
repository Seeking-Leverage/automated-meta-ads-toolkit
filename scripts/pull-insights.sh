#!/usr/bin/env bash
# pull-insights.sh — snapshot campaign insights into the campaign insights/ folder.
#
# The optional third argument is a snapshot folder name (YYYY-MM-DD). It does
# not filter the API. The files are lifetime, last 30 days, last 7 days,
# month-to-date, and a last-7-days platform breakdown, plus per-ad last 7 days.
#
# Usage:
#   pull-insights.sh <client> <slug> [YYYY-MM-DD]

set -euo pipefail

CLIENT="${1:-}"
SLUG="${2:-}"
LABEL="${3:-$(date -u +%Y-%m-%d)}"

if [[ -z "$CLIENT" || -z "$SLUG" ]]; then
  echo "usage: $(basename "$0") <client> <slug> [YYYY-MM-DD]" >&2
  echo "example: $(basename "$0") acme-co summer-sale-jul26" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../bin/lib/client-env.sh
source "$HARNESS_DIR/bin/lib/client-env.sh"

validate_client_name "$CLIENT" || exit 2
validate_slug "$SLUG" || exit 2

if ! [[ "$LABEL" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "error: snapshot label must be YYYY-MM-DD. It names the folder and does not filter the API." >&2
  exit 2
fi

META="$HARNESS_DIR/bin/meta"
STATE_FILE="$HARNESS_DIR/clients/$CLIENT/campaigns/$SLUG/state.json"
OUT_DIR="$HARNESS_DIR/clients/$CLIENT/campaigns/$SLUG/insights/$LABEL"
ENV_FILE="$HARNESS_DIR/clients/$CLIENT/.env"

[[ -f "$STATE_FILE" ]] || { echo "error: state.json not found at $STATE_FILE" >&2; exit 1; }
[[ -f "$ENV_FILE" ]] || { echo "error: $ENV_FILE not found" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "error: jq required" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "error: python3 required" >&2; exit 1; }

CAMPAIGN_ID="$(jq -r '.campaign.id // empty' "$STATE_FILE")"
[[ -n "$CAMPAIGN_ID" && "$CAMPAIGN_ID" != "null" ]] || { echo "error: no campaign.id in state.json" >&2; exit 1; }

AD_ACCOUNT_ID="$(jq -r '.ad_account_id // empty' "$STATE_FILE")"
FIELDS="spend,impressions,reach,frequency,clicks,ctr,cpc,cpm,actions,cost_per_action_type"

mkdir -p "$OUT_DIR"
ERR_FILE=$(mktemp)
trap 'rm -f "$ERR_FILE"' EXIT

extract_json() {
  python3 -c '
import json
import sys
text = sys.stdin.read()
decoder = json.JSONDecoder()
for i, ch in enumerate(text):
    if ch not in "[{":
        continue
    try:
        obj, _end = decoder.raw_decode(text, i)
    except json.JSONDecodeError:
        continue
    json.dump(obj, sys.stdout)
    sys.stdout.write("\n")
    raise SystemExit(0)
raise SystemExit(1)
'
}

FAILURES=0
MANIFEST_ROWS=()

pull() {
  local out="$1"
  shift
  local attempt raw code tmp
  local cmd=("$META" "$CLIENT" -o json --no-input ads)
  if [[ -n "$AD_ACCOUNT_ID" && "$AD_ACCOUNT_ID" != "null" ]]; then
    cmd+=(--ad-account-id "$AD_ACCOUNT_ID")
  fi
  cmd+=("$@")
  tmp="${out}.tmp"
  for attempt in 1 2 3 4 5; do
    set +e
    raw=$("${cmd[@]}" 2>"$ERR_FILE")
    code=$?
    set -e
    if [[ $code -eq 2 || $code -eq 3 ]]; then
      echo "FAIL $out (meta exit $code)" >&2
      [[ -s "$ERR_FILE" ]] && cat "$ERR_FILE" >&2
      FAILURES=$((FAILURES + 1))
      MANIFEST_ROWS+=("${out#"$OUT_DIR"/}"$'\t'"fail")
      rm -f "$tmp"
      return 1
    fi
    if printf '%s' "$raw" | extract_json > "$tmp"; then
      mv "$tmp" "$out"
      echo "OK   $out"
      MANIFEST_ROWS+=("${out#"$OUT_DIR"/}"$'\t'"ok")
      return 0
    fi
    rm -f "$tmp"
    if [[ $attempt -lt 5 ]]; then
      sleep 1
    fi
  done
  echo "FAIL $out (after 5 attempts)" >&2
  [[ -s "$ERR_FILE" ]] && cat "$ERR_FILE" >&2
  FAILURES=$((FAILURES + 1))
  MANIFEST_ROWS+=("${out#"$OUT_DIR"/}"$'\t'"fail")
  return 1
}

echo "Client: $CLIENT | Slug: $SLUG | Campaign: $CAMPAIGN_ID | Snapshot: $LABEL"
echo "The folder name is when this snapshot was saved. It does not change the date presets."
echo "Output: $OUT_DIR"
echo ""

pull "$OUT_DIR/lifetime-summary.json" insights get --campaign-id "$CAMPAIGN_ID" --date-preset maximum --fields "$FIELDS" || true
pull "$OUT_DIR/last-30d-summary.json" insights get --campaign-id "$CAMPAIGN_ID" --date-preset last_30d --fields "$FIELDS" || true
pull "$OUT_DIR/last-7d-summary.json" insights get --campaign-id "$CAMPAIGN_ID" --date-preset last_7d --fields "$FIELDS" || true
pull "$OUT_DIR/mtd-summary.json" insights get --campaign-id "$CAMPAIGN_ID" --date-preset this_month --fields "$FIELDS" || true
pull "$OUT_DIR/last-7d-by-platform.json" insights get --campaign-id "$CAMPAIGN_ID" --date-preset last_7d --fields "$FIELDS" --breakdown publisher_platform || true

ADS_LEN="$(jq '(.ads // []) | length' "$STATE_FILE")"
if [[ "$ADS_LEN" -gt 0 ]]; then
  mkdir -p "$OUT_DIR/per-ad"
  while read -r ad; do
    ad_id="$(echo "$ad" | jq -r '.id')"
    ad_name="$(echo "$ad" | jq -r '.name')"
    safe_name="$(echo "$ad_name" | tr ' ' '_' | tr -cd '[:alnum:]_-')"
    pull "$OUT_DIR/per-ad/${safe_name}-last-7d.json" \
      insights get --ad-id "$ad_id" --date-preset last_7d --fields "$FIELDS" || true
  done < <(jq -c '.ads[]' "$STATE_FILE")
fi

PULLED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
export SNAPSHOT_LABEL="$LABEL" PULLED_AT CAMPAIGN_ID OUT_DIR
python3 - "$OUT_DIR/manifest.json" "${MANIFEST_ROWS[@]}" << 'PY'
import json
import os
import sys
rows = []
for item in sys.argv[2:]:
    name, result = item.split("\t", 1)
    rows.append({"file": name, "result": result})
doc = {
    "snapshot_label": os.environ["SNAPSHOT_LABEL"],
    "note": "snapshot_label is the folder name. Presets are lifetime, last_30d, last_7d, and this_month.",
    "pulled_at": os.environ["PULLED_AT"],
    "campaign_id": os.environ["CAMPAIGN_ID"],
    "files": rows,
}
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(doc, handle, indent=2)
    handle.write("\n")
PY

echo ""
if [[ $FAILURES -eq 0 ]]; then
  echo "done. insights saved to $OUT_DIR"
else
  echo "done with $FAILURES failure(s). See $OUT_DIR/manifest.json" >&2
  exit 1
fi
