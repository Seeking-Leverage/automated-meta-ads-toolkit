
#### 4. `bin/meta` (Most Important)

Create a file at `bin/meta` and paste the full script below:

```bash
#!/usr/bin/env bash
# Meta Ads CLI Wrapper
# Part of automated-meta-ads-toolkit
#
# Usage:
#   meta <client> [command...]
#   meta --client <client> [command...]
#
# Example:
#   meta client-example campaigns list

set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENTS_DIR="$HARNESS_DIR/clients"

# Parse client
CLIENT=""
if [[ "${1:-}" == "--client" ]]; then
  CLIENT="${2:-}"
  shift 2
elif [[ -n "${1:-}" && "${1}" != --* ]]; then
  CLIENT="$1"
  shift
fi

if [[ -z "$CLIENT" ]]; then
  cat >&2 <<EOF
error: No client specified.

Usage:
  meta <client> [command...]
  meta --client <client> [command...]

Available clients:
$(ls "$CLIENTS_DIR" 2>/dev/null | cat || echo "  (no clients yet)")

Example: meta client-example campaigns list
EOF
  exit 2
fi

ENV_FILE="$CLIENTS_DIR/$CLIENT/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "error: No config found for client '$CLIENT'" >&2
  echo "Expected: $ENV_FILE" >&2
  exit 2
fi

set -a
source "$ENV_FILE"
set +a

if [[ -z "${META_ADS_ACCESS_TOKEN:-}" || -z "${META_ADS_ACCOUNT_ID:-}" ]]; then
  echo "error: META_ADS_ACCESS_TOKEN and META_ADS_ACCOUNT_ID must be set in $ENV_FILE" >&2
  exit 2
fi

export ACCESS_TOKEN="$META_ADS_ACCESS_TOKEN"
export AD_ACCOUNT_ID="$META_ADS_ACCOUNT_ID"

PROJECT_DIR="${META_ADS_CLI_PROJECT:-$HOME/meta-ads-cli}"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "error: Meta Ads CLI project not found at $PROJECT_DIR" >&2
  echo "Set META_ADS_CLI_PROJECT in the client's .env file if needed." >&2
  exit 127
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "error: 'uv' not found. Install from https://docs.astral.sh/uv/" >&2
  exit 127
fi

cd "$PROJECT_DIR"
exec uv run meta "$@"
