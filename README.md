# automated-meta-ads-toolkit

[![bin/meta tests](https://github.com/Seeking-Leverage/automated-meta-ads-toolkit/actions/workflows/bin-meta.yml/badge.svg)](https://github.com/Seeking-Leverage/automated-meta-ads-toolkit/actions/workflows/bin-meta.yml)

A multi-client harness for running Meta Ads campaigns safely and repeatably. Clone it, add your clients, and manage ad accounts without mixing credentials.

## Who is this for?

Agencies and in-house teams who want:

- **Isolated credentials** per client or brand
- **Paused-by-default** campaign creation (no accidental spend)
- **Version-controlled** campaign specs (`campaign.yaml` in git)
- **Agent-driven launches** with validation, confirmation gates, and resumability

## ⚠️ Use a private copy — do not fork

Forks of public repos are public. Your campaign specs, goals, and insights are client data.

Create a private repo and pull updates from this one as `upstream`:

```bash
gh repo create <your-org>/meta-ads --private
git clone https://github.com/Seeking-Leverage/automated-meta-ads-toolkit.git meta-ads
cd meta-ads
git remote rename origin upstream
git remote add origin https://github.com/<your-org>/meta-ads.git
git push -u origin main
# later, to get toolkit updates:
git pull upstream main
```

## Quick start

**New here?** Follow the self-service guide: **[docs/self-service-setup.md](docs/self-service-setup.md)** — clone, install the CLI, customize the harness for your ad accounts, and launch your first PAUSED campaign. Includes Linux/WSL notes and a private-repo workflow for agencies.

Shorter path: [docs/getting-started.md](docs/getting-started.md)

```bash
git clone https://github.com/Seeking-Leverage/automated-meta-ads-toolkit.git
cd automated-meta-ads-toolkit
chmod +x bin/meta
export PATH="$PWD/bin:$PATH"

cp -r clients/client-example clients/your-client
cp clients/your-client/.env.example clients/your-client/.env
# Edit .env with your Meta credentials

meta your-client auth status
meta your-client -o json --no-input ads campaign list
```

## How campaigns work

There is no `meta campaign launch` CLI command. The workflow is:

1. **Scaffold** — `/scaffold-meta-campaign <client> <slug>` creates the folder + starter `campaign.yaml`
2. **Edit** — add creative assets and fill in copy, budget, targeting
3. **Launch** — `/launch-meta-campaign <client> <slug>` walks the CLI chain with per-step confirmation
4. **Review** — activate in Meta Ads Manager only after you are satisfied

See [docs/new-campaign-playbook.md](docs/new-campaign-playbook.md).

## Project structure

```
bin/meta                              # CLI wrapper
clients/<client>/
  .env                                # credentials (gitignored)
  goals.md                            # optimization vs success metrics
  campaigns/<slug>/
    campaign.yaml                     # intent
    state.json                        # captured IDs
    launch.log                        # launch timeline
    images/ videos/ insights/
docs/                                 # setup guide, schema, playbooks
scripts/                              # pause-campaign, pull-insights
.claude/skills/                       # scaffold + launch skills
```

## Requirements

- [uv](https://docs.astral.sh/uv/) + Python 3.12+
- Meta Ads CLI 1.1.0 (tested), installed in a local uv project (default: `~/meta-ads-cli`) — [setup instructions](docs/getting-started.md#step-3-install-the-meta-ads-cli-external-project)
- Meta Business Manager system user with ad account, Page, and Pixel assigned

The spend cap applies only when commands go through `bin/meta`. Running `uv run meta` directly bypasses it. meta-ads 1.1.0 has no budget params file; `--daily-budget` and `--lifetime-budget` are the only budget flags, and Click rejects shortened forms such as `--daily-bud` before any API call.

## Documentation

| Doc | What it covers |
| --- | --- |
| [self-service-setup.md](docs/self-service-setup.md) | **Start here** — clone, customize, and launch on your own |
| [getting-started.md](docs/getting-started.md) | Shorter setup path |
| [new-campaign-playbook.md](docs/new-campaign-playbook.md) | Launch workflow |
| [02-review-and-launch.md](docs/02-review-and-launch.md) | Pre-activation checklist |
| [03-performance-analysis.md](docs/03-performance-analysis.md) | Post-launch monitoring |
| [04-campaign-spec-schema.md](docs/04-campaign-spec-schema.md) | `campaign.yaml` reference |
| [HARNESS.md](docs/HARNESS.md) | Architecture and design decisions |
| [clients/README.md](clients/README.md) | Managing multiple clients |

**Example campaign:** `clients/client-example/campaigns/example-traffic-jul26/`

## Scripts

```bash
./scripts/pause-campaign.sh <client> <slug>          # pause all resources
./scripts/pull-insights.sh <client> <slug>             # snapshot performance data
```

See [scripts/README.md](scripts/README.md).

---

Created by [Seeking Leverage](https://www.seekingleverage.com). Open-sourced for agencies and in-house teams running Meta Ads at scale.

## License

MIT — see [LICENSE](LICENSE).