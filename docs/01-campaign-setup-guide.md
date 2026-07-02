# Campaign Setup Guide (Manual CLI)

Manual step-by-step for creating a campaign via the CLI. For the automated path, use the `launch-meta-campaign` skill and [new-campaign-playbook.md](new-campaign-playbook.md).

This produces a fully built campaign (campaign → ad set → creative → ad) in **PAUSED** status.

## Prerequisites

- Meta Ads CLI installed and working
- System user access token with `ads_management` scope
- Ad account ID (`act_XXXXXXXX`)
- Facebook Page ID (assigned to system user)
- Meta Pixel ID (for conversion campaigns)
- Ad image ≥1080×1080 pixels

## Step 1: Verify access

```bash
meta your-client auth status
meta your-client -o json --no-input ads campaign list
```

Exit code 3 on auth status means the token expired — generate a new one in Business Manager.

## Step 2: Create the campaign

```bash
meta your-client -o json --no-input ads --ad-account-id act_XXXXXXXX campaign create \
  --name "Your Campaign Name" \
  --objective outcome_sales \
  --daily-budget 5000
```

Budget is in cents (5000 = $50/day). Save the campaign ID from the JSON response (`.[0].id`).

Valid objectives (lowercase): `outcome_sales`, `outcome_traffic`, `outcome_awareness`, `outcome_engagement`, `outcome_leads`, `outcome_app_promotion`

## Step 3: Create the ad set

```bash
meta your-client -o json --no-input ads --ad-account-id act_XXXXXXXX \
  adset create CAMPAIGN_ID \
  --name "Your Ad Set Name" \
  --optimization-goal OFFSITE_CONVERSIONS \
  --billing-event IMPRESSIONS \
  --targeting-countries US \
  --pixel-id YOUR_PIXEL_ID \
  --custom-event-type purchase
```

`optimization_goal` is UPPERCASE. `custom_event_type` is lowercase (`purchase`, `lead`, `start_trial`, etc.).

## Step 4: Create the creative

```bash
meta your-client -o json --no-input ads --ad-account-id act_XXXXXXXX \
  creative create \
  --name "Your Creative Name" \
  --page-id YOUR_PAGE_ID \
  --image ./clients/your-client/campaigns/my-slug/images/your-image.jpg \
  --body "Your primary ad text here" \
  --title "Your headline here" \
  --link-url "https://yourwebsite.com/landing-page" \
  --call-to-action learn_more
```

CTAs are lowercase: `learn_more`, `sign_up`, `shop_now`, `buy_now`, `contact_us`, `download`, etc.

## Step 5: Create the ad

```bash
meta your-client -o json --no-input ads --ad-account-id act_XXXXXXXX \
  ad create ADSET_ID \
  --name "Your Ad Name" \
  --creative-id CREATIVE_ID
```

## Step 6: Verify

```bash
meta your-client -o json --no-input ads campaign list
meta your-client -o json --no-input ads adset list --campaign-id CAMPAIGN_ID
meta your-client -o json --no-input ads ad list --adset-id ADSET_ID
```

All objects should show `PAUSED` status. Activate manually in Ads Manager.

## Troubleshooting

| Issue | Fix |
| --- | --- |
| Auth exit code 3 | Regenerate token, update client `.env` |
| Creative create fails | Image too small or wrong format — use JPG/PNG ≥1080×1080 |
| Ad set create fails | Pixel may lack conversion data — try `LINK_CLICKS` for first 1–2 weeks |
| `API error (10)` | Page not assigned to system user in Business Manager |
| Wrong ad account | Pass `--ad-account-id act_XXX` on the `ads` group |
| `No such option: -o` | Move `-o json` before the subcommand |