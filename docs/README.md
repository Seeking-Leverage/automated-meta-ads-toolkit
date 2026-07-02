# Documentation

## Start here

| Doc | Audience | Purpose |
| --- | --- | --- |
| **[getting-started.md](getting-started.md)** | Everyone cloning the repo | Complete setup: prerequisites → Business Manager → first client → first command |
| [clients/README.md](../clients/README.md) | Agencies with multiple clients | Adding clients, folder structure, rules |

## Workflows

| Doc | Purpose |
| --- | --- |
| [new-campaign-playbook.md](new-campaign-playbook.md) | End-to-end launch workflow (scaffold → launch → review) |
| [01-campaign-setup-guide.md](01-campaign-setup-guide.md) | Manual CLI walkthrough (alternative to launch skill) |
| [02-review-and-launch.md](02-review-and-launch.md) | Pre-activation checklist — review before spending |
| [03-performance-analysis.md](03-performance-analysis.md) | Post-launch monitoring and reading insights |

## Reference

| Doc | Purpose |
| --- | --- |
| [HARNESS.md](HARNESS.md) | Architecture, design decisions, CLI quirks |
| [04-campaign-spec-schema.md](04-campaign-spec-schema.md) | `campaign.yaml` schema, enums, validation rules |
| [05-launch-log-schema.md](05-launch-log-schema.md) | `launch.log` / `ops.log` event schema |
| [scripts/README.md](../scripts/README.md) | `pause-campaign.sh`, `pull-insights.sh` |

## Agent skills

Located in `.claude/skills/`:

| Skill | Invocation |
| --- | --- |
| `scaffold-meta-campaign` | `/scaffold-meta-campaign <client> <slug>` |
| `launch-meta-campaign` | `/launch-meta-campaign <client> <slug>` |

Invocation rules: `.claude/rules/meta-ads.md`

## Example campaign

See `clients/client-example/campaigns/example-traffic-jul26/` for a ready-to-customize folder with `campaign.yaml`, images, and insights structure.

## Coming soon

- `06-insights-breakdown-cheatsheet.md` — breakdown reference
- `scripts/generate-report.py` — HTML email reports from insights snapshots