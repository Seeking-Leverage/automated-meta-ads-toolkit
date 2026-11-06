# Scripts

Helper scripts for checks, launch safety, and post-launch operations. Paths are resolved from the repo root.

Requires `bin/meta` on PATH or run from repo root (scripts resolve paths automatically).

## validate-campaign.sh

Checks `campaign.yaml` before any Meta write: required fields, budget against the client cap, creative files, and image dimensions. PNG, JPEG, and GIF are read in Python.

```bash
./scripts/validate-campaign.sh acme-co summer-sale-jul26
```

## activate-campaign.sh

Sets the campaign, ad set, and ads recorded in `state.json` to ACTIVE. `bin/meta` blocks `--status ACTIVE` on any other command.

```bash
./scripts/activate-campaign.sh --dry-run acme-co summer-sale-jul26
./scripts/activate-campaign.sh --confirm acme-co summer-sale-jul26
```

Review [docs/02-review-and-launch.md](../docs/02-review-and-launch.md) first. This spends money.

## graph.sh

Calls the Graph API with the client token kept off the command line. Budget and status fields are refused.

```bash
./scripts/graph.sh acme-co POST 120249 bid_strategy=LOWEST_COST_WITHOUT_CAP
./scripts/graph.sh acme-co GET 123456/assigned_pages fields=id,name
```

## pause-campaign.sh

Pauses all resources recorded in `state.json` (ads → ad set → campaign). A failed ad update does not skip the campaign. Never deletes. Appends `ops.log`.

```bash
./scripts/pause-campaign.sh acme-co summer-sale-jul26
./scripts/pause-campaign.sh --dry-run acme-co summer-sale-jul26
```

## pull-insights.sh

Saves a snapshot under `clients/<client>/campaigns/<slug>/insights/<YYYY-MM-DD>/`. The date is the folder name, not an API filter. Each snapshot includes lifetime, last 30 days, last 7 days, and month-to-date presets, plus `manifest.json`.

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