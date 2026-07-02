# Harness architecture

How this toolkit fits together, and why it is designed this way.

For setup instructions, see [getting-started.md](getting-started.md). For day-to-day workflows, see the numbered docs in [README.md](README.md).

---

## System map

```
~/meta-ads-cli/                          ← external CLI (uv-managed Python project)
├── .venv/
└── pyproject.toml                       ← depends on meta-ads package

automated-meta-ads-toolkit/              ← this repo
├── bin/meta                             ← bash wrapper (loads client .env, execs CLI)
├── clients/
│   └── <client>/
│       ├── .env                         ← credentials (gitignored)
│       ├── goals.md                     ← optimization vs success metrics
│       └── campaigns/<slug>/
│           ├── campaign.yaml            ← intent
│           ├── state.json               ← outcomes (IDs)
│           ├── launch.log               ← launch timeline (JSONL)
│           ├── ops.log                  ← post-launch timeline (JSONL)
│           ├── images/ videos/ insights/
├── docs/                                ← guides and schemas
├── scripts/                             ← pause, pull-insights
└── .claude/
    ├── skills/                          ← scaffold + launch skills
    └── rules/meta-ads.md                ← agent invocation rules
```

| Component | Owns | Changes when |
| --- | --- | --- |
| External CLI (`~/meta-ads-cli/`) | The `meta-ads` binary | CLI package is upgraded |
| Harness (this repo) | Wrapper, docs, skills, scripts | Workflow or documentation changes |
| Client data (`clients/<client>/`) | Credentials + per-campaign files | Per-client work |
| Agent surface (`.claude/`) | Skills + rules | Orchestration logic changes |

---

## Multi-client model

Each client folder is self-contained:

- `clients/acme-co/.env` — that client's token, ad account, page, pixel
- `clients/acme-co/campaigns/<slug>/` — that client's campaign specs and assets

The wrapper loads the right `.env` based on the first argument:

```bash
meta acme-co ads campaign list    # uses clients/acme-co/.env
meta beta-inc ads campaign list   # uses clients/beta-inc/.env
```

---

## Key design decisions

### YAML specs in version control

Campaign intent lives in `campaign.yaml` under git. This makes specs diffable, reviewable, and reproducible.

### Everything creates PAUSED

The launch skill never passes `--status active`. Activation is a separate human action in Ads Manager. This is an air gap between "created" and "spending."

### CLI lives outside the repo

The `meta-ads` Python package is a separate uv project. Different toolchain, independent upgrades, no false signal on `git status`. Override path per client via `META_ADS_CLI_PROJECT`.

### Two env var naming conventions

| Namespaced (canonical) | Generic (CLI expects) |
| --- | --- |
| `META_ADS_ACCESS_TOKEN` | `ACCESS_TOKEN` |
| `META_ADS_ACCOUNT_ID` | `AD_ACCOUNT_ID` |

The wrapper reads namespaced vars from the client `.env` and exports both.

### Skills, not API routes

Launch logic is an agent skill (markdown procedure), not a web API. The work is inherently agent-driven: read YAML, validate, confirm, run CLI, parse JSON, capture state.

### Tracking params auto-appended

The launch skill appends standard UTM params to every `link_url`. They are not in YAML to prevent per-campaign drift. See [04-campaign-spec-schema.md](04-campaign-spec-schema.md).

### Four-file provenance model

| File | Role |
| --- | --- |
| `campaign.yaml` | What we want |
| `state.json` | What we got (IDs, resumable) |
| `launch.log` | What happened during launch |
| `ops.log` | What happened after launch |

---

## Known CLI quirks

1. **`-o json` is top-level** — `meta -o json --no-input ads ...` (not after `ads`)
2. **`--ad-account-id` is on the `ads` group** — `meta ads --ad-account-id act_XXX campaign list`
3. **JSON responses are arrays** — parse `.[0].id`, not `.id`
4. **Human-readable lines precede JSON** — strip before piping to `jq`
5. **`objective` / `cta` / `custom_event_type` are lowercase** — `outcome_sales`, `learn_more`, `purchase`
6. **`optimization_goal` is UPPERCASE** — `OFFSITE_CONVERSIONS`, `LINK_CLICKS`
7. **No `--bid-strategy` flag** — use Graph API directly, log as `out_of_band_patch`
8. **No `--breakdown ad`** — loop per-ad with `--ad-id` instead
9. **New ads show `effective_status: IN_PROCESS`** — review queue; `status` is still `PAUSED`
10. **`platform_position` + actions blocked** — use Graph API without `actions` field

### CLI gaps requiring Graph API

| Capability | CLI | Workaround |
| --- | --- | --- |
| Create campaign/adset/creative/ad | Yes | — |
| Pause/activate | Yes | — |
| Campaign `bid_strategy` | No | `curl` POST to `/{campaign-id}` |
| Adset placement edits | No | `curl` POST to `/{adset-id}` |
| Page listing | No | `/{sys_user_id}/assigned_pages` GET |

Log all Graph API calls as `out_of_band_patch` events.

---

## Bootstrap checklist

See [getting-started.md](getting-started.md) for the full walkthrough. Summary:

1. Install `uv`, `jq`
2. Clone this repo, add `bin/` to PATH
3. Install Meta Ads CLI at `~/meta-ads-cli`
4. Create system user + assign ad account, Page, Pixel
5. Copy `clients/client-example` → `clients/your-client`
6. Fill in `.env`
7. Verify: `meta your-client auth status`
8. Scaffold + launch first campaign via skills