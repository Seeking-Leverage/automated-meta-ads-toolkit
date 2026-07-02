# Clients

Each folder under `clients/` represents one ad account (or one business you manage). Credentials and campaign data stay inside that folder.

## Add a new client

```bash
# 1. Copy the example
cp -r clients/client-example clients/your-client-name

# 2. Create the real config (never commit this file)
cp clients/your-client-name/.env.example clients/your-client-name/.env

# 3. Fill in credentials — see .env.example for field descriptions
```

Required in `.env`:

- `META_ADS_ACCESS_TOKEN` — system user token with `ads_management` scope
- `META_ADS_ACCOUNT_ID` — ad account ID including `act_` prefix

Optional:

- `META_PAGE_ID` — default Facebook Page for creatives
- `META_PIXEL_ID` — default pixel for conversion campaigns
- `META_ADS_CLI_PROJECT` — path to your Meta Ads CLI uv project (default: `~/meta-ads-cli`)

## Run commands

```bash
meta your-client-name auth status
meta your-client-name -o json --no-input ads campaign list
meta your-client-name -o json --no-input ads --ad-account-id act_XXX campaign create \
  --name "My Campaign" --objective outcome_sales --daily-budget 5000
```

Add `bin/` to your PATH, or call `./bin/meta` from the repo root.

## Campaign folders

Each campaign lives at `clients/<client>/campaigns/<slug>/`:

```
campaigns/my-campaign-slug/
├── campaign.yaml      # spec (you write this)
├── state.json         # IDs (written by launch skill)
├── launch.log         # launch events (written by launch skill)
├── images/            # creative assets
├── videos/
└── insights/          # performance snapshots (written by pull-insights script)
```

Use the `scaffold-meta-campaign` skill to create this structure, or copy an existing campaign folder as a template.

## Goals template

`clients/client-example/goals.md` is a template for defining optimization vs success metrics. Copy it when onboarding a client:

```bash
cp clients/client-example/goals.md clients/your-client/goals.md
```

## Rules

- **Never commit `.env` files** — they are gitignored
- **One folder per client** — use clear, consistent names (`acme-co`, not `client1`)
- **Store repeated IDs in `.env`** — page ID, pixel ID, ad account ID
- **Override the CLI path per client** if needed via `META_ADS_CLI_PROJECT`