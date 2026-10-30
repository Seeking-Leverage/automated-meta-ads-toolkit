#!/usr/bin/env bash
# Spend-cap, client-name, and 1Password checks for bin/meta.
# A fake uv is placed first on PATH, so nothing reaches Meta.
#
# meta-ads 1.1.0 uses Click. Click also rejects --daily-bud before any API call.
# The wrapper refuses that abbreviation itself, and this script checks both.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
META="$REPO/bin/meta"
TEST="$REPO/clients/captest"
REAL_UV="$(command -v uv || true)"
FAKE="$(mktemp -d)"
fail=0

cleanup() {
  rm -rf "$TEST" "$FAKE"
}
trap cleanup EXIT

mkdir -p "$FAKE"
CLI_DIR="$FAKE/cli"
mkdir -p "$CLI_DIR/.venv/lib/python3.12/site-packages/meta_ads-1.1.0.dist-info"
printf 'Version: 1.1.0\nName: meta-ads\n' > "$CLI_DIR/.venv/lib/python3.12/site-packages/meta_ads-1.1.0.dist-info/METADATA"
cat > "$FAKE/uv" << 'EOF'
#!/bin/bash
echo "UV_CALLED: $*"
exit 0
EOF
chmod +x "$FAKE/uv"
export PATH="$FAKE:$PATH"

check() {
  local name="$1" expect="$2"
  shift 2
  set +e
  out="$("$@" 2>&1)"
  code=$?
  set -e
  local uv_note=" [uv not called]"
  if grep -q UV_CALLED <<< "$out"; then
    uv_note=" [uv called]"
  fi
  if [[ "$code" -eq "$expect" ]]; then
    echo "PASS $name (exit $code)$uv_note"
  else
    echo "FAIL $name (expected $expect, got $code)$uv_note"
    echo "$out" | sed 's/^/    /'
    fail=1
  fi
}

check "reject traversal" 2 "$META" "../../etc" auth status
check "reject slash" 2 "$META" "foo/bar" auth status
check "reject leading hyphen" 2 "$META" "-bad" auth status
check "missing client" 2 "$META" "no-such-client" auth status

mkdir -p "$TEST"
cp "$REPO/clients/client-example/.env.example" "$TEST/.env"
check "example comments do not require op" 2 "$META" captest auth status

if grep -E '^META_MAX_(DAILY|LIFETIME)_BUDGET_CENTS=.*#' "$REPO/clients/client-example/.env.example"; then
  echo "FAIL example budget lines still have inline comments"
  fail=1
else
  echo "PASS example budget comments are on their own lines"
fi

cat > "$TEST/.env" << EOF
# META_ADS_ACCESS_TOKEN=op://Agency/acme-co-meta/token
META_ADS_ACCESS_TOKEN=test-token
META_ADS_ACCOUNT_ID=act_123
META_ADS_CLI_PROJECT=$CLI_DIR
META_MAX_DAILY_BUDGET_CENTS=10000
META_MAX_LIFETIME_BUDGET_CENTS=300000
EOF
check "daily at cap" 0 "$META" captest ads campaign create --daily-budget 10000
check "daily over cap" 3 "$META" captest ads campaign create --daily-budget 10001
check "daily equals-form over cap" 3 "$META" captest ads campaign create --daily-budget=10001
check "daily equals-form at cap" 0 "$META" captest ads campaign create --daily-budget=10000
check "lifetime at cap" 0 "$META" captest ads campaign create --lifetime-budget 300000
check "lifetime over cap" 3 "$META" captest ads campaign create --lifetime-budget 300001
check "adset update over cap" 3 "$META" captest ads adset update 123 --daily-budget 10001
check "adset update at cap" 0 "$META" captest ads adset update 123 --daily-budget 10000
check "campaign update over lifetime" 3 "$META" captest ads campaign update 123 --lifetime-budget 300001
check "non-numeric blocked" 3 "$META" captest ads campaign create --daily-budget 50.00
check "list without budget" 0 "$META" captest -o json --no-input ads campaign list
check "abbreviated daily flag blocked" 3 "$META" captest ads campaign create --daily-bud 999999
check "abbreviated lifetime flag blocked" 3 "$META" captest ads campaign create --lifetime-bud 1
check "status paused allowed" 0 "$META" captest ads campaign update 1 --status PAUSED
check "status active blocked" 3 "$META" captest ads campaign update 1 --status ACTIVE
check "status active equals-form blocked" 3 "$META" captest ads campaign update 1 --status=ACTIVE
check "status archived blocked" 3 "$META" captest ads ad update 1 --status ARCHIVED

set +e
out="$("$META" captest ads campaign create --daily-budget 999999 2>&1)"
code=$?
set -e
if [[ "$code" -eq 3 ]] && ! grep -q UV_CALLED <<< "$out"; then
  echo "PASS over-cap does not invoke uv"
else
  echo "FAIL over-cap invoked uv or wrong exit ($code)"
  echo "$out"
  fail=1
fi

set +e
out="$("$META" captest ads campaign create --daily-budget 5000 2>&1)"
set -e
if grep -q "UV_CALLED: run meta ads campaign create --daily-budget 5000" <<< "$out"; then
  echo "PASS forwards args without client name"
else
  echo "FAIL unexpected forward: $out"
  fail=1
fi

# source strips an inline comment, so the cap still applies. op run may not.
cat > "$TEST/.env" << EOF
META_ADS_ACCESS_TOKEN=test-token
META_ADS_ACCOUNT_ID=act_123
META_ADS_CLI_PROJECT=$CLI_DIR
META_MAX_DAILY_BUDGET_CENTS=10000 # \$100/day
META_MAX_LIFETIME_BUDGET_CENTS=300000
EOF
check "sourced inline comment still caps" 3 "$META" captest ads campaign create --daily-budget 10001

cat > "$TEST/.env" << EOF
META_ADS_ACCESS_TOKEN=test-token
META_ADS_ACCOUNT_ID=act_123
META_ADS_CLI_PROJECT=$CLI_DIR
EOF
check "unset cap blocks budget write" 3 "$META" captest ads adset create 1 --daily-budget 100
check "unset cap allows read" 0 "$META" captest ads campaign list

cat > "$TEST/.env" << EOF
META_ADS_ACCESS_TOKEN=op://Agency/acme-co-meta/token
META_ADS_ACCOUNT_ID=act_123
META_ADS_CLI_PROJECT=$CLI_DIR
META_MAX_DAILY_BUDGET_CENTS=10000
META_MAX_LIFETIME_BUDGET_CENTS=300000
EOF
check "op reference without op cli" 127 "$META" captest auth status

cat > "$TEST/.env" << EOF
META_ADS_ACCESS_TOKEN=test-token
META_ADS_ACCOUNT_ID=act_123
META_ADS_CLI_PROJECT=$CLI_DIR
META_MAX_DAILY_BUDGET_CENTS=10000
META_MAX_LIFETIME_BUDGET_CENTS=300000
EOF

set +e
out=$(META_ALLOW_ACTIVATE=1 "$META" captest ads campaign update 1 --status ACTIVE 2>&1)
code=$?
set -e
if [[ "$code" -eq 0 ]] && grep -q "UV_CALLED: run meta ads campaign update 1 --status ACTIVE" <<< "$out"; then
  echo "PASS activate env allows ACTIVE"
else
  echo "FAIL activate env did not allow ACTIVE (exit $code)"
  echo "$out"
  fail=1
fi

set +e
out=$("$META" captest ads campaign update 1 --status ACTIVE 2>&1)
code=$?
set -e
if [[ "$code" -eq 3 ]] && ! grep -q UV_CALLED <<< "$out"; then
  echo "PASS active status does not invoke uv"
else
  echo "FAIL active status invoked uv or wrong exit ($code)"
  echo "$out"
  fail=1
fi

PWN="$FAKE/pwned"
rm -f "$PWN"
cat > "$TEST/.env" << EOF
META_ADS_ACCESS_TOKEN=\$(touch $PWN)
META_ADS_ACCOUNT_ID=act_123
META_ADS_CLI_PROJECT=$CLI_DIR
META_MAX_DAILY_BUDGET_CENTS=10000
META_MAX_LIFETIME_BUDGET_CENTS=300000
EOF
set +e
out=$("$META" captest ads campaign list 2>&1)
code=$?
set -e
if [[ "$code" -eq 0 ]] && [[ ! -e "$PWN" ]] && grep -q 'UV_CALLED:' <<< "$out"; then
  echo "PASS .env command substitution is not executed"
else
  echo "FAIL .env command substitution ran or command failed (exit $code)"
  echo "$out"
  fail=1
fi

cat > "$TEST/.env" << EOF
PATH=$FAKE/not-a-dir
META_ADS_ACCESS_TOKEN=test-token
META_ADS_ACCOUNT_ID=act_123
META_ADS_CLI_PROJECT=$CLI_DIR
META_MAX_DAILY_BUDGET_CENTS=10000
META_MAX_LIFETIME_BUDGET_CENTS=300000
EOF
set +e
out=$("$META" captest ads campaign list 2>&1)
code=$?
set -e
if [[ "$code" -eq 2 ]] && grep -q 'refusing PATH' <<< "$out" && ! grep -q UV_CALLED <<< "$out"; then
  echo "PASS non-META assignment is refused"
else
  echo "FAIL non-META assignment was accepted (exit $code)"
  echo "$out"
  fail=1
fi

BAD_CLI="$FAKE/bad-cli"
mkdir -p "$BAD_CLI/.venv/lib/python3.12/site-packages/meta_ads-9.9.9.dist-info"
printf 'Version: 9.9.9\n' > "$BAD_CLI/.venv/lib/python3.12/site-packages/meta_ads-9.9.9.dist-info/METADATA"
cat > "$TEST/.env" << EOF
META_ADS_ACCESS_TOKEN=test-token
META_ADS_ACCOUNT_ID=act_123
META_ADS_CLI_PROJECT=$BAD_CLI
META_MAX_DAILY_BUDGET_CENTS=10000
META_MAX_LIFETIME_BUDGET_CENTS=300000
EOF
set +e
out=$("$META" captest ads campaign list 2>&1)
code=$?
set -e
if [[ "$code" -eq 127 ]] && grep -q 'expects 1.1.0' <<< "$out" && ! grep -q UV_CALLED <<< "$out"; then
  echo "PASS wrong meta-ads version is refused"
else
  echo "FAIL wrong version was not refused (exit $code)"
  echo "$out"
  fail=1
fi

cat > "$TEST/.env" << EOF
META_ADS_ACCESS_TOKEN=test-token
META_ADS_ACCOUNT_ID=act_123
META_ADS_CLI_PROJECT=$CLI_DIR
META_MAX_DAILY_BUDGET_CENTS=010000
META_MAX_LIFETIME_BUDGET_CENTS=300000
EOF
check "leading-zero cap is decimal" 0 "$META" captest ads campaign create --daily-budget 10000
check "leading-zero cap still blocks" 3 "$META" captest ads campaign create --daily-budget 10001

if [[ -n "$REAL_UV" && -d "${HOME}/meta-ads-cli" ]]; then
  set +e
  out="$(cd "${HOME}/meta-ads-cli" && "$REAL_UV" run meta ads campaign create --name T --objective OUTCOME_TRAFFIC --daily-bud 999999 2>&1)"
  code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -q "No such option '--daily-bud'" <<< "$out"; then
    echo "PASS real cli rejects --daily-bud"
  else
    echo "FAIL real cli did not reject --daily-bud (exit $code)"
    echo "$out" | sed 's/^/    /'
    fail=1
  fi
else
  echo "SKIP real cli abbreviation check (no ~/meta-ads-cli)"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "ALL TESTS PASSED"
else
  echo "SOME TESTS FAILED"
  exit 1
fi
