---
name: launch-meta-campaign
description: Launch a Meta Ads campaign from campaign.yaml — walks the CLI chain with per-write user confirmation, all objects PAUSED
---

# Launch Meta Campaign Skill

Reads `clients/<client>/campaigns/<slug>/campaign.yaml` and walks the CLI chain: campaign → adset → creatives → ads. Captures IDs in `state.json`. Every write requires explicit user confirmation. Everything is created **PAUSED**.

## Inputs

- **Client** (required) — folder under `clients/` (e.g. `acme-co`)
- **Slug** (required) — kebab-case folder under `campaigns/` (e.g. `summer-sale-jul26`)

If `campaign.yaml` is missing, tell the user to run `/scaffold-meta-campaign <client> <slug>` first.

## Reference docs

- Schema: `docs/04-campaign-spec-schema.md`
- Log schema: `docs/05-launch-log-schema.md`
- Invocation rules: `.claude/rules/meta-ads.md`
- Manual workflow: `docs/01-campaign-setup-guide.md`

## Paths

```bash
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CLIENT="<client>"
SLUG="<slug>"
CAMPAIGN_DIR="$REPO_ROOT/clients/$CLIENT/campaigns/$SLUG"
META="$REPO_ROOT/bin/meta"
LOG="$CAMPAIGN_DIR/launch.log"
STATE="$CAMPAIGN_DIR/state.json"
```

## Execution policy

- **Reads run freely** — validation, dimension checks, auth, dataset lookups
- **Writes require per-step confirmation** — show exact command, wait for "go" or "yes"
- **All creates PAUSED** — never pass `--status active`
- **Never `--force`**, never delete
- **Save state after each success** — partial failures must be resumable
- **Log every action** to `launch.log` per `docs/05-launch-log-schema.md`
- **Redact tokens** in logged commands

## Steps

### 1. Load and validate

1. Read `clients/<client>/campaigns/<slug>/campaign.yaml`
2. Validate per `docs/04-campaign-spec-schema.md`:
   - Required fields present
   - `daily_budget_cents` XOR `lifetime_budget_cents`
   - If `OFFSITE_CONVERSIONS`: `pixel_id` + `custom_event_type` required
   - Each creative: exactly one of `image:` or `video:`
   - Image exists + ≥1080×1080 (`sips -g pixelWidth -g pixelHeight`)
   - Video exists; if `ffprobe` available, check ≥1080×1080
   - Every `page_id` set; every `creative_ref` matches a `creatives[].name`
   - Valid `cta` (lowercase); countries are 2-letter uppercase ISO codes
3. **Stop on any failure** — list all errors, zero writes
4. Read existing `state.json` if present — skip completed steps

### 2. Sanity checks (read-only, no confirmation)

```bash
$META $CLIENT auth status
$META $CLIENT -o json --no-input ads dataset get <pixel_id>
$META $CLIENT -o json --no-input ads --ad-account-id <ad_account_id> campaign list | head -c 200
```

Stop if any read fails.

- Budget cap: read META_MAX_DAILY_BUDGET_CENTS / META_MAX_LIFETIME_BUDGET_CENTS from clients/<client>/.env. If campaign.yaml's budget exceeds the cap, STOP and tell the user. Never raise the cap yourself.

### 3. Show launch plan

Present a summary table (campaign, adset, creatives, ads, account, pixel, page). Ask: "Ready to launch? I'll confirm each write individually."

On user confirmation, append `launch_start` to `launch.log`.

### 4. Walk the CLI chain

For each step: build command → show user → wait for "go" → log `step_attempt` → run → log `step_success` or `step_fail` → update `state.json`.

**Parse responses:** strip non-JSON lines, pipe to `jq`, use `.[0].id`.

#### 4a — Campaign

```bash
$META $CLIENT -o json --no-input ads --ad-account-id <ad_account_id> campaign create \
  --name "<campaign.name>" \
  --objective <campaign.objective> \
  --daily-budget <campaign.daily_budget_cents>
```

Save `state.campaign.id`.

#### 4b — Ad set

```bash
$META $CLIENT -o json --no-input ads --ad-account-id <ad_account_id> adset create <CAMPAIGN_ID> \
  --name "<adset.name>" \
  --optimization-goal <adset.optimization_goal> \
  --billing-event <adset.billing_event> \
  --targeting-countries <comma-separated countries> \
  --pixel-id <adset.pixel_id> \
  --custom-event-type <adset.custom_event_type>
```

`custom_event_type` must be lowercase (`purchase`, `lead`, `start_trial`, etc.).

If bid strategy fails with "Bid amount required", patch via Graph API:

```bash
curl -X POST "https://graph.facebook.com/v19.0/<CAMPAIGN_ID>" \
  -d "bid_strategy=LOWEST_COST_WITHOUT_CAP" \
  -d "access_token=$META_ADS_ACCESS_TOKEN"
```

Log as `out_of_band_patch`. Save `state.adset.id`.

#### 4c — Creatives (loop)

Append tracking params to each `link_url`:

```
utm_source=facebook&utm_medium=paid&utm_campaign={{campaign.name}}&utm_term={{adset.name}}&utm_content={{ad.name}}
```

Use `?` or `&` as separator. Do NOT URL-encode `{{...}}` macros.

```bash
$META $CLIENT -o json --no-input ads --ad-account-id <ad_account_id> creative create \
  --name "<creative.name>" \
  --page-id <creative.page_id> \
  --image "<ABSOLUTE_PATH_TO_CAMPAIGN_DIR>/<creative.image>" \
  --body "<creative.body>" \
  --title "<creative.title>" \
  --link-url "<enriched link_url>" \
  --call-to-action <creative.cta>
```

Use `--video` instead of `--image` for video creatives. Add `--description` only if set in spec.

Build name→id map for ads step.

#### 4d — Ads (loop)

```bash
$META $CLIENT -o json --no-input ads --ad-account-id <ad_account_id> ad create <ADSET_ID> \
  --name "<ad.name>" \
  --creative-id <CREATIVE_ID>
```

New ads may show `effective_status: IN_PROCESS` — normal; `status` is `PAUSED`.

### 5. Final report

Set `state.completed_at`. Append `launch_complete` to `launch.log`. Show:

- All object IDs
- Ads Manager link: `https://business.facebook.com/adsmanager/manage/campaigns?act=<id without act_>&selected_campaign_ids=<campaign_id>`
- Reminder: **everything is PAUSED** — activate in Ads Manager after review

## Resume behaviour

If `state.json` has partial data, reuse existing IDs and skip completed steps. To force fresh run, user deletes `state.json`.

## Don'ts

- No `--status active`
- No silent retries
- No writes after validation failure
- No auto-activation