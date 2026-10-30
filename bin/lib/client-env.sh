#!/usr/bin/env bash
# Shared client checks and .env parsing.
# Sourced by bin/meta and the scripts. Does not execute .env as shell.

EXPECTED_META_ADS_VERSION="1.1.0"

validate_client_name() {
  local name="$1"
  if [[ -z "$name" || ! "$name" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
    echo "error: invalid client name '${name:-}' (letters, numbers, - and _ only)" >&2
    return 2
  fi
}

validate_slug() {
  local name="$1"
  if [[ -z "$name" || ! "$name" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
    echo "error: invalid campaign slug '${name:-}' (letters, numbers, - and _ only)" >&2
    return 2
  fi
}

# Drop budget caps inherited from the parent shell so only this client's file applies.
clear_budget_caps() {
  unset META_MAX_DAILY_BUDGET_CENTS META_MAX_LIFETIME_BUDGET_CENTS
}

# Re-exec under `op run` when the env file contains an un-commented op:// reference.
# Remaining arguments are the original argv (without $0).
reexec_if_op_env() {
  local env_file="$1"
  shift
  if [[ -n "${META_OP_RESOLVED:-}" ]]; then
    return 0
  fi
  if grep -vE '^[[:space:]]*#' "$env_file" | grep -q 'op://'; then
    command -v op >/dev/null 2>&1 || {
      echo "error: $env_file uses op:// references but the 1Password CLI 'op' is not installed" >&2
      exit 127
    }
    exec env META_OP_RESOLVED=1 op run --env-file="$env_file" -- "$0" "$@"
  fi
}

# Parse one assignment value into REPLY. Does not expand $() or ${}.
parse_env_value() {
  local raw="$1"
  local i c n rest
  REPLY=""
  if [[ "$raw" == \"* ]]; then
    raw="${raw:1}"
    i=0
    while [[ $i -lt ${#raw} ]]; do
      c="${raw:i:1}"
      if [[ "$c" == "\\" ]]; then
        n="${raw:i+1:1}"
        REPLY+="$n"
        i=$((i + 2))
        continue
      fi
      if [[ "$c" == '"' ]]; then
        rest="${raw:i+1}"
        rest="${rest#"${rest%%[![:space:]]*}"}"
        if [[ -n "$rest" && "$rest" != \#* ]]; then
          echo "error: trailing junk after a quoted .env value" >&2
          return 2
        fi
        return 0
      fi
      REPLY+="$c"
      i=$((i + 1))
    done
    echo "error: unterminated double quote in .env" >&2
    return 2
  fi
  if [[ "$raw" == \'* ]]; then
    raw="${raw:1}"
    if [[ "$raw" != *"'"* ]]; then
      echo "error: unterminated single quote in .env" >&2
      return 2
    fi
    REPLY="${raw%%\'*}"
    rest="${raw#*\'}"
    rest="${rest#"${rest%%[![:space:]]*}"}"
    if [[ -n "$rest" && "$rest" != \#* ]]; then
      echo "error: trailing junk after a quoted .env value" >&2
      return 2
    fi
    return 0
  fi
  if [[ "$raw" == *" #"* ]]; then
    raw="${raw%% #*}"
  fi
  raw="${raw#"${raw%%[![:space:]]*}"}"
  raw="${raw%"${raw##*[![:space:]]}"}"
  REPLY="$raw"
}

# Export META_* keys from FILE. Refuses every other assignment.
load_client_env() {
  local file="$1"
  local line key val
  [[ -f "$file" ]] || {
    echo "error: missing $file" >&2
    return 2
  }
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    line="${line#"${line%%[![:space:]]*}"}"
    if [[ "$line" == export[[:space:]]* ]]; then
      line="${line#export}"
      line="${line#"${line%%[![:space:]]*}"}"
    fi
    if [[ ! "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      echo "error: invalid line in $file (expected KEY=value)" >&2
      return 2
    fi
    key="${BASH_REMATCH[1]}"
    val="${BASH_REMATCH[2]}"
    if [[ "$key" != META_* ]]; then
      echo "error: $file may only set META_* variables (refusing $key)" >&2
      return 2
    fi
    parse_env_value "$val" || return 2
    printf -v "$key" '%s' "$REPLY"
    export "${key?}"
  done < "$file"
}

installed_meta_ads_version() {
  local project="$1"
  local meta got
  # head -n 1 is portable. -quit is GNU-only and breaks the macOS find.
  meta=$(find "$project/.venv" -path '*meta_ads-*.dist-info/METADATA' 2>/dev/null | head -n 1 || true)
  if [[ -n "$meta" && -f "$meta" ]]; then
    awk '/^Version: / { print substr($0, 10); exit }' "$meta"
    return 0
  fi
  if [[ -f "$project/uv.lock" ]]; then
    got=$(awk '
      $0 ~ /^name = "meta-ads"$/ { found=1; next }
      found && $0 ~ /^version = / {
        gsub(/"/, "", $3)
        print $3
        exit
      }
      found && $0 ~ /^name = / { exit }
    ' "$project/uv.lock")
    if [[ -n "$got" ]]; then
      printf '%s' "$got"
      return 0
    fi
  fi
  return 1
}

require_pinned_cli() {
  local project="$1"
  local got
  if ! got=$(installed_meta_ads_version "$project"); then
    echo "error: cannot find meta-ads version in $project" >&2
    echo "expected meta-ads==${EXPECTED_META_ADS_VERSION}. Install it in that uv project." >&2
    exit 127
  fi
  if [[ "$got" != "$EXPECTED_META_ADS_VERSION" ]]; then
    echo "error: $project has meta-ads ${got}; this harness expects ${EXPECTED_META_ADS_VERSION}" >&2
    exit 127
  fi
}

append_ops_log() {
  local file="$1" kind="$2" target="$3" id="$4" name="$5" result="$6" error="${7:-}"
  command -v jq >/dev/null 2>&1 || {
    echo "error: jq required to write $file" >&2
    return 1
  }
  mkdir -p "$(dirname "$file")"
  jq -nc \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg kind "$kind" \
    --arg target "$target" \
    --arg id "$id" \
    --arg name "$name" \
    --arg result "$result" \
    --arg error "$error" \
    '{ts:$ts, kind:$kind, target:$target, id:$id, name:$name, result:$result} + (if $error == "" then {} else {error:$error} end)' \
    >> "$file"
}
