#!/usr/bin/env bash
# Pause, activate, graph, validate, and insights checks.
# A fake uv and curl sit first on PATH, so nothing reaches Meta.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT="harnessfix"
ROOT="$REPO/clients/$CLIENT"
FAKE="$(mktemp -d)"
LOG="$FAKE/calls.log"
CURL_LOG="$FAKE/curl.log"
fail=0

cleanup() {
  rm -rf "$ROOT" "$FAKE"
}
trap cleanup EXIT

mkdir -p "$FAKE"
CLI_DIR="$FAKE/cli"
mkdir -p "$CLI_DIR/.venv/lib/python3.12/site-packages/meta_ads-1.1.0.dist-info"
printf 'Version: 1.1.0\nName: meta-ads\n' > "$CLI_DIR/.venv/lib/python3.12/site-packages/meta_ads-1.1.0.dist-info/METADATA"

cat > "$FAKE/uv" << EOF
#!/bin/bash
echo "\$*" >> "$LOG"
if [[ "\$*" == *insights* ]]; then
  echo "warning: preamble"
  echo '[{"spend":"1"}]'
  exit 0
fi
if [[ "\$*" == *a-fail* && "\$*" == *PAUSED* ]]; then
  echo "boom" >&2
  exit 1
fi
echo "UV_CALLED: \$*"
exit 0
EOF
cat > "$FAKE/curl" << EOF
#!/bin/bash
{
  echo "ARGV:\$*"
  prev=""
  for a in "\$@"; do
    if [[ "\$prev" == "--config" && -f "\$a" ]]; then
      echo "CONFIG:"
      cat "\$a"
    fi
    prev="\$a"
  done
} >> "$CURL_LOG"
exit 0
EOF
chmod +x "$FAKE/uv" "$FAKE/curl"
export PATH="$FAKE:$PATH"

mkdir -p "$ROOT/campaigns/sample/images" "$ROOT/campaigns/bad-event" "$ROOT/campaigns/tiny/images"
cat > "$ROOT/.env" << EOF
META_ADS_ACCESS_TOKEN=test-token
META_ADS_ACCOUNT_ID=act_123
META_ADS_CLI_PROJECT=$CLI_DIR
META_MAX_DAILY_BUDGET_CENTS=10000
META_MAX_LIFETIME_BUDGET_CENTS=300000
EOF

cat > "$ROOT/campaigns/sample/state.json" << 'EOF'
{
  "ad_account_id": "act_123",
  "campaign": {"id": "c1", "name": "Camp"},
  "adset": {"id": "s1", "name": "Set"},
  "ads": [
    {"id": "a1", "name": "Ad One"},
    {"id": "a-fail", "name": "Ad Fail"},
    {"id": "a3", "name": "Ad Three"}
  ]
}
EOF

python3 - << PY
import struct, zlib
from pathlib import Path
def png(w, h, path):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + b"\x00\x00\x00" * w for _ in range(h))
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    Path(path).write_bytes(data)
png(1080, 1080, "$ROOT/campaigns/sample/images/feed.png")
png(10, 10, "$ROOT/campaigns/tiny/images/feed.png")
PY

cat > "$ROOT/campaigns/sample/campaign.yaml" << 'EOF'
ad_account_id: act_123
campaign:
  name: Test
  objective: outcome_traffic
  daily_budget_cents: 5000
adset:
  name: Set
  optimization_goal: LANDING_PAGE_VIEWS
  billing_event: IMPRESSIONS
  countries: [US]
creatives:
  - name: Feed_V1
    image: images/feed.png
    page_id: "123"
    body: Hello
    title: Headline
    link_url: https://example.com/landing
    cta: learn_more
ads:
  - name: Ad_V1
    creative_ref: Feed_V1
EOF

cp "$ROOT/campaigns/sample/campaign.yaml" "$ROOT/campaigns/tiny/campaign.yaml"
mkdir -p "$ROOT/campaigns/bad-event/images"
cp "$ROOT/campaigns/sample/images/feed.png" "$ROOT/campaigns/bad-event/images/feed.png"
python3 - << PY
from pathlib import Path
p = Path("$ROOT/campaigns/bad-event/campaign.yaml")
text = Path("$ROOT/campaigns/sample/campaign.yaml").read_text()
text = text.replace("countries: [US]\n", "countries: [US]\n  custom_event_type: purchase\n")
p.write_text(text)
PY

check() {
  local name="$1" expect="$2"
  shift 2
  set +e
  out="$("$@" 2>&1)"
  code=$?
  set -e
  if [[ "$code" -eq "$expect" ]]; then
    echo "PASS $name (exit $code)"
  else
    echo "FAIL $name (expected $expect, got $code)"
    echo "$out" | sed 's/^/    /'
    fail=1
  fi
}

check "pause rejects traversal" 2 "$REPO/scripts/pause-campaign.sh" "../etc" "sample"
check "activate requires confirm" 2 "$REPO/scripts/activate-campaign.sh" harnessfix sample

set +e
"$REPO/scripts/pause-campaign.sh" harnessfix sample >"$FAKE/pause.out" 2>"$FAKE/pause.err"
code=$?
set -e
if [[ "$code" -eq 1 ]] && grep -q "campaign update c1" "$LOG" && grep -q "ad update a3" "$LOG" && grep -q "ad update a-fail" "$LOG"; then
  echo "PASS pause continues after an ad failure"
else
  echo "FAIL pause did not finish the campaign (exit $code)"
  echo "--- log ---"; cat "$LOG"
  echo "--- err ---"; cat "$FAKE/pause.err"
  fail=1
fi
if grep -q '"result":"fail"' "$ROOT/campaigns/sample/ops.log" && grep -q '"target":"campaign"' "$ROOT/campaigns/sample/ops.log"; then
  echo "PASS pause writes ops.log"
else
  echo "FAIL ops.log missing pause results"
  cat "$ROOT/campaigns/sample/ops.log" 2>/dev/null || true
  fail=1
fi

: > "$LOG"
check "activate dry-run" 0 "$REPO/scripts/activate-campaign.sh" --dry-run harnessfix sample
if [[ ! -s "$LOG" ]]; then
  echo "PASS activate dry-run does not call uv"
else
  echo "FAIL activate dry-run called uv"
  cat "$LOG"
  fail=1
fi

check "activate confirm" 0 "$REPO/scripts/activate-campaign.sh" --confirm harnessfix sample
if grep -q "campaign update c1 --status ACTIVE" "$LOG"; then
  echo "PASS activate sends ACTIVE through the wrapper"
else
  echo "FAIL activate did not send ACTIVE"
  cat "$LOG"
  fail=1
fi

: > "$CURL_LOG"
check "graph refuses budget" 3 "$REPO/scripts/graph.sh" harnessfix POST 120249 daily_budget=5000
if [[ ! -s "$CURL_LOG" ]]; then
  echo "PASS graph budget refusal does not call curl"
else
  echo "FAIL graph called curl for a budget field"
  cat "$CURL_LOG"
  fail=1
fi

check "graph post keeps token off argv" 0 "$REPO/scripts/graph.sh" harnessfix POST 120249 bid_strategy=LOWEST_COST_WITHOUT_CAP
if grep -q 'ARGV:' "$CURL_LOG" && ! grep -q 'test-token' <(grep '^ARGV:' "$CURL_LOG") && grep -q 'Authorization: Bearer test-token' "$CURL_LOG"; then
  echo "PASS graph token is in the curl config, not argv"
else
  echo "FAIL graph token handling"
  cat "$CURL_LOG"
  fail=1
fi

check "validate sample" 0 "$REPO/scripts/validate-campaign.sh" harnessfix sample
check "validate rejects purchase on traffic" 1 "$REPO/scripts/validate-campaign.sh" harnessfix bad-event
check "validate rejects tiny image" 1 "$REPO/scripts/validate-campaign.sh" harnessfix tiny
check "validate rejects traversal" 2 "$REPO/scripts/validate-campaign.sh" "../x" sample

check "insights rejects path label" 2 "$REPO/scripts/pull-insights.sh" harnessfix sample "../evil"
: > "$LOG"
check "insights snapshot" 0 "$REPO/scripts/pull-insights.sh" harnessfix sample 2026-07-02
SNAP="$ROOT/campaigns/sample/insights/2026-07-02"
if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$SNAP/lifetime-summary.json" \
  && grep -q '"spend": "1"' "$SNAP/lifetime-summary.json" \
  && [[ -f "$SNAP/manifest.json" ]] \
  && [[ -f "$SNAP/per-ad/Ad_One-last-7d.json" ]]; then
  echo "PASS insights JSON ignores the warning preamble"
else
  echo "FAIL insights output"
  find "$SNAP" -type f -print 2>/dev/null || true
  fail=1
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "ALL HARNESS TESTS PASSED"
else
  echo "SOME HARNESS TESTS FAILED"
  exit 1
fi
