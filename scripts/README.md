# Scripts

Helper scripts for post-launch operations. All take `<client>` and `<slug>` as the first two arguments.

Requires `bin/meta` on PATH or run from repo root (scripts resolve paths automatically).

## pause-campaign.sh

Pauses all resources recorded in `state.json` (ads → adset → campaign). Never deletes.

```bash
./scripts/pause-campaign.sh acme-co summer-sale-jul26
./scripts/pause-campaign.sh --dry-run acme-co summer-sale-jul26
```

## pull-insights.sh

Pulls campaign-level insights snapshots into `clients/<client>/campaigns/<slug>/insights/<date>/`.

```bash
./scripts/pull-insights.sh acme-co summer-sale-jul26
./scripts/pull-insights.sh acme-co summer-sale-jul26 2026-07-02
```

Outputs:

- `lifetime-summary.json`
- `last-30d-summary.json`
- `last-7d-summary.json`
- `mtd-summary.json`
- `last-7d-by-platform.json`
- `per-ad/<ad-name>-last-7d.json` (one per ad in state.json)