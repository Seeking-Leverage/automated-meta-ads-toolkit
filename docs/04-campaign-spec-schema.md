# Campaign spec schema

Each campaign is declared in `clients/<client>/campaigns/<slug>/campaign.yaml`. The `launch-meta-campaign` skill reads this file and walks the CLI chain (campaign → adset → creatives → ads), capturing IDs into `state.json`.

## Folder layout

```
clients/<client>/campaigns/<slug>/
├── campaign.yaml      # the spec (this schema)
├── state.json         # IDs captured during launch
├── launch.log         # launch event timeline (JSONL)
├── ops.log            # post-launch operations (JSONL)
├── images/            # ad creative images (tracked in git)
├── videos/            # ad creative videos (consider gitignoring large files)
└── insights/          # performance snapshots (written by pull-insights script)
```

Use a kebab-case slug as the folder name (e.g. `summer-sale-jul26`).

---

## Schema

```yaml
# Required: which ad account to bill against
ad_account_id: act_XXXXXXXXXXXXXXXXX

# Required: campaign-level settings
campaign:
  name: "20260702_Meta_Web_Prospecting_US_Purchase_Broad_Test"
  objective: outcome_sales   # lowercase snake_case — see enum below
  daily_budget_cents: 5000   # 5000 = $50.00. Mutually exclusive with lifetime_budget_cents.
                             # Must be at or under META_MAX_DAILY_BUDGET_CENTS in the client .env.
                             # lifetime_budget_cents must be at or under META_MAX_LIFETIME_BUDGET_CENTS.
  # lifetime_budget_cents: 50000

# Required: ad set settings
adset:
  name: "20260702_Meta_Web_Prospecting_US_Purchase_Broad_Test_V1"
  optimization_goal: OFFSITE_CONVERSIONS   # UPPERCASE — see enum below
  billing_event: IMPRESSIONS
  countries: [US]                          # ISO 2-letter codes
  pixel_id: "123456789012345"              # required for OFFSITE_CONVERSIONS
  custom_event_type: purchase              # lowercase snake_case — see enum below

# Required: one or more creatives. Exactly one of image: or video: per creative.
creatives:
  - name: "Feed_V1"
    image: images/feed-v1.jpg              # path relative to campaign folder, ≥1080×1080
    page_id: "123456789012345"             # Facebook Page ID (required by Meta)
    body: |
      Your primary ad text goes here.
    title: "Your headline"
    description: "Optional link description"  # omit to hide
    link_url: "https://yourdomain.com/landing-page"
    cta: learn_more                        # lowercase snake_case — see enum below

# Required: one or more ads — each references a creative by name
ads:
  - name: "Ad_V1"
    creative_ref: "Feed_V1"                # must match a creatives[].name exactly
```

---

## Enum reference

### `campaign.objective` — lowercase snake_case

`outcome_app_promotion` | `outcome_awareness` | `outcome_engagement` | `outcome_leads` | `outcome_sales` | `outcome_traffic`

### `adset.optimization_goal` — UPPERCASE

`OFFSITE_CONVERSIONS` | `LANDING_PAGE_VIEWS` | `LINK_CLICKS` | `REACH` | `IMPRESSIONS` | `THRUPLAY` | and others per Meta API

### `adset.custom_event_type` — lowercase snake_case

`add_payment_info` | `add_to_cart` | `add_to_wishlist` | `complete_registration` | `contact` | `content_view` | `customize_product` | `donate` | `find_location` | `initiated_checkout` | `lead` | `other` | `purchase` | `schedule` | `search` | `start_trial` | `submit_application` | `subscribe`

### `creatives[].cta` — lowercase snake_case

`apply_now` | `book_travel` | `buy_now` | `contact_us` | `download` | `get_offer` | `get_quote` | `learn_more` | `no_button` | `open_link` | `shop_now` | `sign_up` | `subscribe` | `watch_more`

> **Casing matters.** `objective`, `custom_event_type`, and `cta` are lowercase. `optimization_goal` is uppercase. Getting this wrong causes silent CLI failures.

---

## Tracking params (auto-appended)

The launch skill appends standard UTM params to every `link_url`. Do not put them in YAML — the skill adds them uniformly.

```
utm_source=facebook
utm_medium=paid
utm_campaign={{campaign.name}}
utm_term={{adset.name}}
utm_content={{ad.name}}
```

The `{{...}}` tokens are [Meta URL parameter macros](https://www.facebook.com/business/help/2360940870872492) — Meta substitutes them at ad-serve time.

Optional vendor params (enable per client if needed):

```
fbadid={{ad.id}}          # Meta ad ID for attribution
```

---

## Validation rules

The launch skill verifies all of these **before any write**. On failure: stop, list all errors, run zero writes.

1. **Required fields** — `ad_account_id`, `campaign.name`, `campaign.objective`, budget (`daily_budget_cents` XOR `lifetime_budget_cents`), `adset.name`, `adset.optimization_goal`, `adset.countries`, `creatives[]`, `ads[]`
2. **Conversion coupling** — if `optimization_goal: OFFSITE_CONVERSIONS`, both `pixel_id` and `custom_event_type` required
3. **Creative asset** — exactly one of `image:` or `video:` per creative; file must exist on disk
4. **Image dimensions** — ≥1080×1080 (checked via `sips` on macOS)
5. **Video dimensions** — ≥1080×1080 if `ffprobe` available (optional check)
6. **Page ID** — every `creatives[].page_id` must be set
7. **Creative refs** — every `ads[].creative_ref` must match a `creatives[].name`
8. **CTA enum** — must be a valid lowercase value
9. **Country codes** — ISO 2-letter, uppercase

---

## State file format

`state.json` captures final IDs. For the full event timeline, see `launch.log` (schema: [05-launch-log-schema.md](05-launch-log-schema.md)).

```json
{
  "spec_path": "clients/acme-co/campaigns/summer-sale-jul26/campaign.yaml",
  "ad_account_id": "act_XXXXXXXXXXXXXXXXX",
  "started_at": "2026-07-02T10:00:00Z",
  "completed_at": "2026-07-02T10:02:14Z",
  "campaign": { "name": "...", "id": "120249xxxxxx", "command": "...", "created_at": "..." },
  "adset": { "name": "...", "id": "120249xxxxxx", "command": "...", "created_at": "..." },
  "creatives": [{ "name": "Feed_V1", "id": "...", "command": "...", "created_at": "..." }],
  "ads": [{ "name": "Ad_V1", "creative_id": "...", "id": "...", "command": "...", "created_at": "..." }]
}
```

**Resumability:** if a step already has an `id` in `state.json`, the launch skill skips it.

---

## CLI mapping

| Spec field | CLI flag |
| --- | --- |
| `ad_account_id` | `meta ads --ad-account-id act_XXX` |
| `campaign.name` | `meta ads campaign create --name` |
| `campaign.objective` | `--objective` (lowercase) |
| `campaign.daily_budget_cents` | `--daily-budget` (blocked by `bin/meta` when above the client cap) |
| `adset.optimization_goal` | `--optimization-goal` (UPPERCASE) |
| `adset.custom_event_type` | `--custom-event-type` (lowercase) |
| `creatives[].cta` | `--call-to-action` (lowercase) |
| `creatives[].image` | `--image` |

Correct invocation order:

```bash
meta -o json --no-input ads --ad-account-id act_XXX campaign create \
  --name "..." --objective outcome_sales --daily-budget 5000
```

---

## Known CLI quirks

1. **`-o json` is a top-level flag** — before the subcommand, not after
2. **`--ad-account-id` is on the `ads` group** — not top-level
3. **JSON responses are arrays** — parse `.[0].id`, not `.id`
4. **Human-readable lines precede JSON** — strip non-JSON lines before piping to `jq`
5. **New ads show `effective_status: IN_PROCESS`** — review queue; `status` is still `PAUSED`
6. **No `--bid-strategy` flag** — use Graph API directly if needed (logged as `out_of_band_patch`)
7. **No `--breakdown ad`** — loop per-ad with `--ad-id` instead