#!/usr/bin/env bash
# graph.sh — call the Graph API with the client token kept off argv.
#
# Budget and status fields are refused. Those go through bin/meta, which
# enforces the spend cap and the PAUSED status gate.
#
# Usage:
#   graph.sh <client> GET <path> [key=value...]
#   graph.sh <client> POST <path> [key=value...]
#
# path is the id or path after the version, for example:
#   graph.sh acme-co POST 120249 bid_strategy=LOWEST_COST_WITHOUT_CAP
#   graph.sh acme-co GET 123456/assigned_pages fields=id,name

set -euo pipefail

GRAPH_VERSION="v21.0"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 3 ]]; then
  echo "usage: $(basename "$0") <client> GET|POST <path> [key=value...]" >&2
  exit 2
fi

CLIENT="$1"
METHOD=$(printf '%s' "$2" | tr '[:lower:]' '[:upper:]')
PATH_PART="$3"
shift 3

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../bin/lib/client-env.sh
source "$HARNESS_DIR/bin/lib/client-env.sh"

validate_client_name "$CLIENT" || exit 2

if [[ "$METHOD" != "GET" && "$METHOD" != "POST" ]]; then
  echo "error: method must be GET or POST" >&2
  exit 2
fi
if [[ -z "$PATH_PART" || "$PATH_PART" == *"?"* || "$PATH_PART" == http* || "$PATH_PART" == *" "* ]]; then
  echo "error: path must be a Graph node id or relative path, with query fields as key=value arguments" >&2
  exit 2
fi

ENV_FILE="$HARNESS_DIR/clients/$CLIENT/.env"
[[ -f "$ENV_FILE" ]] || { echo "error: $ENV_FILE not found" >&2; exit 2; }

if [[ -z "${META_OP_RESOLVED:-}" ]]; then
  clear_budget_caps
  reexec_if_op_env "$ENV_FILE" "$CLIENT" "$METHOD" "$PATH_PART" "$@"
  load_client_env "$ENV_FILE"
fi

if [[ -z "${META_ADS_ACCESS_TOKEN:-}" ]]; then
  echo "error: META_ADS_ACCESS_TOKEN is missing in $ENV_FILE" >&2
  exit 2
fi
if [[ "$META_ADS_ACCESS_TOKEN" == *"'"* || "$META_ADS_ACCESS_TOKEN" == *$'\n'* || "$META_ADS_ACCESS_TOKEN" == *'"'* ]]; then
  echo "error: token contains a character this script will not put in a curl config" >&2
  exit 2
fi

fields=()
for kv in "$@"; do
  if [[ "$kv" != *=* ]]; then
    echo "error: expected key=value, got: $kv" >&2
    exit 2
  fi
  key="${kv%%=*}"
  val="${kv#*=}"
  key_upper=$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')
  case "$key_upper" in
    DAILY_BUDGET|LIFETIME_BUDGET|SPEND_CAP)
      echo "error: $key is a budget field. Pass --daily-budget or --lifetime-budget through bin/meta so the cap applies." >&2
      exit 3
      ;;
    STATUS)
      echo "error: status changes go through scripts/pause-campaign.sh or scripts/activate-campaign.sh --confirm" >&2
      exit 3
      ;;
    ACCESS_TOKEN)
      echo "error: do not pass access_token. The script sends it as a header." >&2
      exit 2
      ;;
  esac
  if [[ "$val" == *$'\n'* || "$val" == *'"'* ]]; then
    echo "error: refusing field value with a newline or double quote" >&2
    exit 2
  fi
  fields+=("$key=$val")
done

command -v curl >/dev/null 2>&1 || { echo "error: curl required" >&2; exit 127; }

query=""
if [[ ${#fields[@]} -gt 0 && "$METHOD" == "GET" ]]; then
  query=$(python3 - "${fields[@]}" << 'PY'
import sys
import urllib.parse
pairs = []
for item in sys.argv[1:]:
    key, value = item.split("=", 1)
    pairs.append((key, value))
print(urllib.parse.urlencode(pairs))
PY
)
fi

url="https://graph.facebook.com/${GRAPH_VERSION}/${PATH_PART}"
if [[ -n "$query" ]]; then
  url="${url}?${query}"
fi

cfg=$(mktemp)
chmod 600 "$cfg"
trap 'rm -f "$cfg"' EXIT

{
  printf 'silent\n'
  printf 'show-error\n'
  printf 'fail\n'
  printf 'header = "Authorization: Bearer %s"\n' "$META_ADS_ACCESS_TOKEN"
  printf 'url = "%s"\n' "$url"
  if [[ "$METHOD" == "POST" ]]; then
    printf 'request = "POST"\n'
    for kv in "${fields[@]}"; do
      printf 'data-urlencode = "%s"\n' "$kv"
    done
  fi
} > "$cfg"

curl --config "$cfg"
echo
