# Meta Ads CLI Rules

Per-invocation rules for agents working with this toolkit. Read this every time you touch Meta Ads.

## Setup (one-time, human-run)

See [docs/getting-started.md](../../docs/getting-started.md) for the full walkthrough. Summary:

1. Install `uv` and the Meta Ads CLI at `~/meta-ads-cli` (or custom path via `META_ADS_CLI_PROJECT`)
2. Clone this repo, add `bin/` to PATH
3. Create a system user in Business Manager with `ads_management` + `ads_read` scopes
4. Assign ad account, Facebook Page, and Pixel to the system user
5. Copy `clients/client-example` → `clients/<client>`, fill in `.env`
6. Verify: `meta <client> auth status`

Credentials live in `clients/<client>/.env` — never in the repo root, never in shell history.

## How to invoke the CLI

Use the repo wrapper from the repo root:

```bash
meta <client> -o json --no-input ads --ad-account-id act_XXX campaign list
```

The wrapper loads `clients/<client>/.env`, exports `ACCESS_TOKEN` and `AD_ACCOUNT_ID`, and execs `uv run meta` from the CLI project directory.

### Flag positions

- `-o json` and `--no-input` are **top-level** — before the subcommand
- `--ad-account-id` is on the **`ads` group**

```bash
# Correct
meta acme-co -o json --no-input ads --ad-account-id act_XXX campaign create --name "..." ...

# Wrong
meta acme-co ads campaign create -o json ...
meta acme-co --ad-account-id act_XXX ads campaign list
```

## Agent invocation rules

- **Reads** (list, get, insights, validate): run freely
- **Writes** (create, update): show the exact command, wait for explicit user "go" or "yes", then run. Every write. No batching.
- **All creates stay PAUSED** — never pass `--status active`
- **Never use `--force`**
- **Never delete** — pause instead
- **After every write**, show the returned JSON to the user
- **Parse JSON as array** — use `.[0].id`; strip human-readable lines before `jq`
- **Redact tokens** in logs — `access_token=***REDACTED***`

## Campaign paths

```
clients/<client>/campaigns/<slug>/campaign.yaml   ← spec
clients/<client>/campaigns/<slug>/state.json      ← IDs (resumable)
clients/<client>/campaigns/<slug>/launch.log      ← launch events (JSONL)
```

Creative asset paths in CLI commands must be **absolute** (the CLI runs from `~/meta-ads-cli`, not the repo root):

```bash
--image "/full/path/to/repo/clients/<client>/campaigns/<slug>/images/feed-v1.jpg"
```

## Asset ID discovery

System user tokens typically lack `business_management` scope:

- `me/accounts` returns empty for system users
- `ads page list` requires `business_management`

What works:

- Assigned pages: `curl "https://graph.facebook.com/v21.0/<sys_user_id>/assigned_pages?access_token=$TOKEN&fields=id,name"`
- Pixel by ID: `meta <client> -o json --no-input ads dataset get <pixel_id>`
- Ad accounts: `meta <client> -o json --no-input ads adaccount list`

## Graph API fallbacks

When the CLI lacks a flag, use `curl` against Graph API and log as `out_of_band_patch` in `launch.log`. See [docs/HARNESS.md](../../docs/HARNESS.md) for the gap table.

## What NOT to do

- Don't invent CLI commands (`campaign launch`, `insights pull` do not exist)
- Don't use wrong enum casing (`OUTCOME_SALES` → use `outcome_sales`)
- Don't auto-activate campaigns
- Don't share access tokens between team members