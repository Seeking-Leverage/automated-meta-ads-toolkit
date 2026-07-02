# Performance analysis

Ongoing monitoring after a campaign is activated. Use this repeatedly — not just once.

## When to use this

After activation and delivery confirmation ([02-review-and-launch.md](02-review-and-launch.md)). Pull insights when the user asks, or on a schedule you define.

## Key files

| File | Purpose |
| --- | --- |
| `clients/<client>/campaigns/<slug>/state.json` | Campaign and ad IDs |
| `clients/<client>/campaigns/<slug>/insights/<date>/` | Saved snapshots from `pull-insights.sh` |
| `clients/<client>/goals.md` | Optimization metric vs success metric targets |

Fill in `goals.md` before your first analysis round — see `clients/client-example/goals.md`.

---

## Pull insights (recommended)

Use the script to save timestamped JSON snapshots:

```bash
./scripts/pull-insights.sh your-client your-slug
./scripts/pull-insights.sh your-client your-slug 2026-07-02
```

This writes lifetime, last-7d, last-30d, MTD, platform breakdown, and per-ad files to `insights/<date>/`.

## Manual CLI commands

Replace `CAMPAIGN_ID` with the value from `state.json` (`campaign.id`).

```bash
# Today
meta your-client -o json --no-input ads --ad-account-id act_XXX insights get \
  --campaign-id CAMPAIGN_ID --date-preset today \
  --fields spend,impressions,clicks,ctr,cpc,cpm,actions,cost_per_action_type

# Last 7 days
meta your-client -o json --no-input ads --ad-account-id act_XXX insights get \
  --campaign-id CAMPAIGN_ID --date-preset last_7d \
  --fields spend,impressions,reach,frequency,clicks,ctr,cpc,cpm,actions,cost_per_action_type

# By platform
meta your-client -o json --no-input ads --ad-account-id act_XXX insights get \
  --campaign-id CAMPAIGN_ID --date-preset last_7d \
  --fields spend,impressions,clicks,actions \
  --breakdown publisher_platform
```

### Per-ad comparison

There is no `--breakdown ad`. Loop per ad using IDs from `state.json`:

```bash
meta your-client -o json --no-input ads --ad-account-id act_XXX insights get \
  --ad-id AD_ID --date-preset last_7d \
  --fields spend,impressions,clicks,actions,cost_per_action_type
```

---

## Reading `actions[]` — don't conflate metrics

Insights return `actions` and `cost_per_action_type` as arrays. Multiple entries often refer to the same event.

| What you care about | Typical `action_type` | Notes |
| --- | --- | --- |
| Purchases | `purchase` | Ignore `omni_purchase` aliases unless you need them |
| Leads | `lead` | |
| Link clicks | `link_click` | |
| Landing page views | `landing_page_view` | |
| Custom pixel events | `offsite_conversion.fb_pixel_custom` | Maps to your `--custom-event-type` at ad set creation |

**Use `goals.md`** to separate:

- **Optimization metric** — what Meta learns on (higher volume, directional)
- **Success metric** — what your business measures (has a dollar target)

Never compare the optimization metric to the success-metric target.

---

## Monitoring cadence

### Daily (2 minutes)

```bash
meta your-client -o json --no-input ads insights get \
  --campaign-id CAMPAIGN_ID --date-preset today \
  --fields spend,impressions,clicks,actions
```

Look for: spend roughly tracking daily budget, non-zero impressions. If spend is $0 for a full day, investigate.

### Days 1–3: learning phase

**Do not make changes.** Let the algorithm collect data.

Watch: spend ramping, CTR (below 0.5% on feed is a concern), CPM/CPC volatility (normal early on).

### Day 7: baseline review

Pull last 7d and record:

| Metric | Value | Notes |
| --- | --- | --- |
| Total spend | | |
| CPM | | |
| CTR | | |
| CPC | | |
| Success-metric conversions | | From `goals.md` |
| Cost per success metric | | vs target in `goals.md` |
| Frequency | | Above 3.0 → consider new creative |

```bash
./scripts/pull-insights.sh your-client your-slug
```

### Day 14+: iteration decisions

| Observation | Action |
| --- | --- |
| CTR declining week over week | Creative fatigue — add a variation |
| Frequency above 3.0 | New creative or broader targeting |
| Cost per success metric rising | Algorithm may be exhausting audience |
| Performance stable or improving | Stay the course |

To add a new creative, create it + a new ad under the same ad set. Do not pause the original unless clearly underperforming.

### End of campaign

1. `./scripts/pull-insights.sh your-client your-slug`
2. Compare lifetime and last-7d against `goals.md` targets
3. `./scripts/pause-campaign.sh your-client your-slug`

---

## CLI quirks for insights

1. **Flag names use hyphens:** `--campaign-id`, `--ad-id` (not underscores)
2. **`insights get` returns JSON by default** — `-o json` at top level still works via wrapper
3. **`--breakdown platform_position` + actions** often fails — use `publisher_platform` via CLI, or Graph API without `actions` for position-level spend
4. **Reporting lag** — insights can trail by 1–3 hours
5. **See also:** `06-insights-breakdown-cheatsheet.md` (coming soon)

---

## Troubleshooting

| Problem | Fix |
| --- | --- |
| Spend $0 for a full day | Check ad status, creative review, billing |
| Learning Limited | Broaden targeting or simplify conversion event |
| Auth exit code 3 | Regenerate token, update client `.env` |
| Metrics look wrong | Wait 2–3 hours for reporting lag |
| Frequency above 5.0 | Audience exhaustion — refresh creative |

---

## Related docs

- [02-review-and-launch.md](02-review-and-launch.md) — pre-activation checklist
- [new-campaign-playbook.md](new-campaign-playbook.md) — full launch workflow
- [scripts/README.md](../scripts/README.md) — pull-insights and pause scripts