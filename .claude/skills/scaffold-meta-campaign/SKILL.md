---
name: scaffold-meta-campaign
description: Scaffold a new Meta Ads campaign folder with starter campaign.yaml under clients/<client>/campaigns/<slug>/
---

# Scaffold Meta Campaign Skill

Creates `clients/<client>/campaigns/<slug>/` with a starter `campaign.yaml` and subdirectories `images/`, `videos/`, and `insights/`. Local files only — no CLI writes.

## Inputs

- **Client** (required) — folder name under `clients/` (e.g. `acme-co`)
- **Slug** (required) — kebab-case campaign identifier (e.g. `summer-sale-jul26`)

If either is missing, ask the user.

Validate slug: `^[a-z0-9][a-z0-9-]*$`. Reject if `clients/<client>/campaigns/<slug>/` already exists.

## Steps

1. **Verify client exists:** `clients/<client>/.env` must exist (user should have copied from `.env.example`). If missing, tell them to follow [docs/getting-started.md](../../../docs/getting-started.md) Step 5.

2. **Read client defaults** from `clients/<client>/.env` (if set):
   - `META_ADS_ACCOUNT_ID`
   - `META_PAGE_ID`
   - `META_PIXEL_ID`

3. **Create folder structure:**

   ```
   clients/<client>/campaigns/<slug>/
   ├── images/
   ├── videos/
   ├── insights/.gitkeep
   └── campaign.yaml
   ```

4. **Write `campaign.yaml`** from the template below, substituting:
   - `<CLIENT>` → client name
   - `<SLUG>` → slug
   - `<SLUG_UPPER>` → slug uppercased, hyphens → underscores
   - Defaults from `.env` where available; otherwise placeholder comments

5. **Report to the user:**
   - Path to `campaign.yaml`
   - Path to drop creative: `clients/<client>/campaigns/<slug>/images/feed-v1.jpg`
   - Next steps: edit copy, add image, run `/launch-meta-campaign <client> <slug>`

## Template — `campaign.yaml`

```yaml
# Meta Ads campaign spec — see docs/04-campaign-spec-schema.md

ad_account_id: <FROM_CLIENT_ENV_OR_act_XXXXXXXXX>

campaign:
  name: "<YYYYMMDD>_<CLIENT>_<purpose>_<geo>_<month><year>"
  objective: outcome_traffic
  daily_budget_cents: 5000   # 5000 = $50/day — adjust for real launches

adset:
  name: "<YYYYMMDD>_<CLIENT>_Broad_US_V1"
  optimization_goal: LANDING_PAGE_VIEWS
  billing_event: IMPRESSIONS
  countries: [US]
  pixel_id: "<FROM_CLIENT_ENV_OR_YOUR_PIXEL_ID>"
  custom_event_type: purchase

creatives:
  - name: "Feed_V1"
    image: images/feed-v1.jpg
    page_id: "<FROM_CLIENT_ENV_OR_YOUR_PAGE_ID>"
    body: |
      <PRIMARY TEXT — hook + value prop + CTA, ~125 chars>
    title: "<HEADLINE — ~40 chars>"
    link_url: https://yourdomain.com/landing-page
    cta: learn_more

ads:
  - name: "Ad_V1"
    creative_ref: "Feed_V1"

# UTM tracking params are auto-appended by launch-meta-campaign — do not add them here.
```

## Naming convention

The template uses `YYYYMMDD_Client_Purpose_Geo_MonthYear` as an **example** convention. Teams can adopt their own — the launch skill does not enforce a prefix.

## After scaffolding

Tell the user, in order:

1. Drop a 1080×1080+ image at `clients/<client>/campaigns/<slug>/images/feed-v1.jpg`
2. Edit `campaign.yaml`: replace placeholders, adjust budget, verify IDs
3. Run `/launch-meta-campaign <client> <slug>`

Do **not** run the launch skill from here — scaffold and launch are separate steps.

## Don'ts

- No `meta ads` write commands — local files only
- No auto-generated marketing copy — that's a human judgment call
- Never clobber an existing campaign folder