# Review and launch

Pre-activation checklist for a campaign created via the CLI or `launch-meta-campaign` skill. **Do not skip steps.** Once you activate, real money starts flowing.

## When to use this

After a launch completes. You should have IDs in `clients/<client>/campaigns/<slug>/state.json`:

- Campaign ID
- Ad set ID
- Creative ID(s)
- Ad ID(s)

All objects should be **PAUSED**.

## Prerequisites

| Tool | Purpose |
| --- | --- |
| Meta Ads CLI (`meta <client> …`) | Verify status, make fixes |
| [Meta Ads Manager](https://adsmanager.facebook.com) | Visual review |
| [Meta Events Manager](https://business.facebook.com/events_manager) | Pixel verification |
| Your analytics tool | UTM verification |

---

## Step 1: Review in Ads Manager

Open Ads Manager and confirm:

- [ ] Campaign name, objective, and daily budget are correct
- [ ] Ad set countries match your plan (CLI only sets geo — check age/gender/placements if edited manually)
- [ ] Pixel ID and conversion event type are correct (for conversion campaigns)
- [ ] Optimization goal and billing event are correct
- [ ] Creative preview shows correct image, copy, headline, and CTA
- [ ] Destination URL is correct

**If something is wrong**, fix via CLI before activating:

```bash
meta your-client -o json --no-input ads --ad-account-id act_XXX campaign update CAMPAIGN_ID \
  --name "Corrected Name" --daily-budget 5000

meta your-client -o json --no-input ads --ad-account-id act_XXX adset update ADSET_ID \
  --bid-amount 200

# New creative + swap on ad
meta your-client -o json --no-input ads --ad-account-id act_XXX creative create \
  --name "Feed_V2" --page-id PAGE_ID --image /absolute/path/to/image.jpg \
  --body "New copy" --title "New headline" \
  --link-url "https://yourdomain.com/page" --call-to-action learn_more

meta your-client -o json --no-input ads --ad-account-id act_XXX ad update AD_ID \
  --creative-id NEW_CREATIVE_ID
```

---

## Step 2: Verify pixel on destination URL

1. Open **Events Manager** → select your pixel → **Test Events**
2. Visit your landing page in another tab
3. Confirm **PageView** appears within seconds
4. If optimizing for conversions, trigger the event (e.g. purchase, lead) and confirm it fires

**Do not activate** if the pixel is not firing. Meta cannot optimize without conversion data.

---

## Step 3: Verify tracking parameters

The launch skill appends UTM params to every `link_url`:

```
utm_source=facebook
utm_medium=paid
utm_campaign={{campaign.name}}
utm_term={{adset.name}}
utm_content={{ad.name}}
```

1. Copy the destination URL from the ad preview in Ads Manager
2. Click through and check your analytics real-time view
3. Confirm UTM values resolve correctly at serve time (not literal `{{...}}` macros in live traffic)

---

## Step 4: Confirm budget and schedule

```bash
meta your-client -o json --no-input ads --ad-account-id act_XXX campaign list
```

Verify:

- [ ] Daily budget matches your intent (amount is in **cents** in the CLI)
- [ ] Start/end dates are correct if set
- [ ] Payment method is valid on the ad account in Business Manager

---

## Step 5: Activate (explicit decision required)

Activation is a **human decision** — not automated by the launch skill.

Show the user the exact commands and wait for explicit approval:

```bash
meta your-client -o json --no-input ads --ad-account-id act_XXX campaign update CAMPAIGN_ID --status ACTIVE
meta your-client -o json --no-input ads --ad-account-id act_XXX adset update ADSET_ID --status ACTIVE
meta your-client -o json --no-input ads --ad-account-id act_XXX ad update AD_ID --status ACTIVE
```

**Common activation failures:**

| Error | Fix |
| --- | --- |
| API error — billing | Add valid payment method in Business Manager |
| Creative in review | Wait for Meta approval (can take hours) |
| Policy violation | Fix creative, create new one, update ad |

---

## Step 6: Confirm delivery (1–2 hours after activation)

```bash
meta your-client -o json --no-input ads --ad-account-id act_XXX insights get \
  --campaign-id CAMPAIGN_ID --date-preset today \
  --fields impressions,spend,reach
```

Expect non-zero impressions and spend within a few hours.

| Symptom | Likely cause |
| --- | --- |
| Learning Limited | Budget too low for optimization goal — consider `LINK_CLICKS` temporarily |
| In Review | Creative pending — wait up to 24h |
| Zero impressions | Targeting too narrow, bid too low, or billing issue |
| Not Delivering | Check Ads Manager notifications |

---

## Decision gate

| Condition | Action |
| --- | --- |
| Steps 1–4 all pass | Proceed to activation with explicit user approval |
| Pixel not firing | **Do not activate** — fix tracking first |
| Wrong creative or URL | **Do not activate** — fix first |
| UTMs broken | Fix destination URL / creative |
| Anything uncertain | **Do not activate** — verify first |

---

## Emergency pause

```bash
./scripts/pause-campaign.sh your-client your-slug
```

Or pause the campaign directly (stops all delivery under it):

```bash
meta your-client -o json --no-input ads --ad-account-id act_XXX campaign update CAMPAIGN_ID --status PAUSED
```

---

## Checklist

- [ ] Structure reviewed in Ads Manager
- [ ] Creative preview correct
- [ ] Destination URL loads
- [ ] Pixel fires PageView (and conversion event if applicable)
- [ ] UTMs tracked in analytics
- [ ] Budget confirmed
- [ ] User explicitly approved activation
- [ ] Delivery confirmed after 1–2 hours

**Next:** [03-performance-analysis.md](03-performance-analysis.md)