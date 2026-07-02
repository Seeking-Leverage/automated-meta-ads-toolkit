# New Campaign Playbook

Step-by-step guide to launching a Meta Ads campaign with this toolkit.

## Before you start

Have ready:

- An ad image (minimum 1080×1080 pixels) or video
- Ad copy (primary text, headline, destination URL, CTA)
- Budget, targeting countries, and campaign objective decided
- Client `.env` filled in with token, ad account, page ID, and pixel ID

## Step 1: Scaffold the campaign folder

Use the **`scaffold-meta-campaign`** agent skill:

```
/scaffold-meta-campaign <client> <slug>
```

Or create manually:

```bash
mkdir -p clients/your-client/campaigns/my-campaign-slug/{images,videos,insights}
touch clients/your-client/campaigns/my-campaign-slug/insights/.gitkeep
```

## Step 2: Write campaign.yaml

Create `clients/your-client/campaigns/my-campaign-slug/campaign.yaml` following [04-campaign-spec-schema.md](04-campaign-spec-schema.md).

Use placeholder IDs from your client's `.env` for `ad_account_id`, `page_id`, and `pixel_id`.

## Step 3: Add creative assets

Place your image in `images/` (or video in `videos/`). The filename must match the path in `campaign.yaml`.

## Step 4: Launch

There is **no** `meta campaign launch` CLI command. Launch via the **`launch-meta-campaign`** agent skill:

```
/launch-meta-campaign <client> <slug>
```

The skill will:

1. Validate the spec (stop on any error — zero writes)
2. Show each CLI command and wait for your explicit "go"
3. Create campaign → ad set → creatives → ads, all **PAUSED**
4. Write IDs to `state.json` and events to `launch.log`
5. Auto-append UTM tracking params to every `link_url`

## Step 5: Review before activating

Follow the full pre-activation checklist: **[02-review-and-launch.md](02-review-and-launch.md)**

Do not activate until pixel, UTMs, budget, and creative preview all pass.

## Step 6: Monitor performance

After 24–48 hours of runtime:

```bash
./scripts/pull-insights.sh your-client my-campaign-slug
```

See **[03-performance-analysis.md](03-performance-analysis.md)** for monitoring cadence and how to read results against `clients/<client>/goals.md`.

## Step 7: Pause if needed

```bash
./scripts/pause-campaign.sh your-client my-campaign-slug
# or dry-run first:
./scripts/pause-campaign.sh --dry-run your-client my-campaign-slug
```

## Tips

- Campaigns stay PAUSED until you activate them in Ads Manager
- Store repeated IDs in the client's `.env` to avoid retyping
- `creative_ref` must exactly match a `creatives[].name`
- Use lowercase enums for `objective`, `custom_event_type`, and `cta`

## Common mistakes

| Mistake | Consequence |
| --- | --- |
| Wrong enum casing (`OUTCOME_SALES` instead of `outcome_sales`) | CLI rejects the command |
| Image smaller than 1080×1080 | Validation fails before launch |
| `creative_ref` typo | Ad creation fails mid-chain |
| Activating before review | Unreviewed ads start spending |
| Putting UTM params in YAML | Duplicated or inconsistent tracking |