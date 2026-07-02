# Example campaign: example-traffic-jul26

This folder shows what a real campaign looks like after scaffolding. It is **not launched** — there is no `state.json` yet.

## What's here

| File / folder | Purpose |
| --- | --- |
| `campaign.yaml` | Campaign spec — edit before launch |
| `images/` | Drop your 1080×1080+ creative here (`feed-v1.jpg`) |
| `insights/` | Performance snapshots land here after `./scripts/pull-insights.sh` |

## Quick start

```bash
# 1. Copy this client folder for real use
cp -r clients/client-example clients/your-client
cp clients/your-client/.env.example clients/your-client/.env
# Fill in .env

# 2. Edit campaign.yaml with your IDs, copy, and budget

# 3. Add creative
cp /path/to/your-image.jpg clients/your-client/campaigns/example-traffic-jul26/images/feed-v1.jpg

# 4. Launch (via Claude Code skill)
/launch-meta-campaign your-client example-traffic-jul26

# 5. Review before activating — see docs/02-review-and-launch.md
```

Or scaffold a fresh campaign with your own slug:

```
/scaffold-meta-campaign your-client my-new-campaign
```