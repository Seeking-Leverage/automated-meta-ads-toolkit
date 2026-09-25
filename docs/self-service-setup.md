# Self-Service Setup Guide

**Audience:** Anyone cloning [automated-meta-ads-toolkit](https://github.com/Seeking-Leverage/automated-meta-ads-toolkit) who wants to run Meta Ads through a safe, repeatable harness — without depending on Seeking Leverage.

**Time:** ~45–60 minutes the first time (mostly Meta Business Manager setup).

**Outcome:** Your own multi-client harness, connected to your ad accounts, ready to scaffold and launch PAUSED campaigns.

---

## What you are cloning

This repo is a **harness** around the open-source [meta-ads](https://pypi.org/project/meta-ads/) Python CLI. It does **not** contain the CLI itself.

```
Your machine
├── automated-meta-ads-toolkit/     ← this repo (wrapper, docs, skills, your client data)
└── ~/meta-ads-cli/                 ← separate uv project you install once
```

| Layer | What it does | You customize? |
| --- | --- | --- |
| **Meta Ads CLI** (`~/meta-ads-cli`) | Talks to Meta's Graph API | Path per client via `.env` if needed |
| **`bin/meta` wrapper** | Loads `clients/<client>/.env`, runs the CLI | Rarely — works out of the box |
| **`clients/<client>/`** | Credentials, campaign specs, assets | **Yes — this is your workspace** |
| **`.claude/skills/`** | Agent procedures for scaffold + launch | Optional — copy to your AI tool |
| **`scripts/`** | Pause campaigns, pull insights | Optional — edit if your workflow differs |

Everything you create for your business lives under `clients/`. That folder is designed to stay local (credentials are gitignored) or be committed to a **private fork** if your team wants version-controlled specs without sharing tokens.

---

## Part 1: Install tools and clone the repo

### 1a. Prerequisites

| Tool | Purpose | Install |
| --- | --- | --- |
| **git** | Clone the repo | Preinstalled on most systems |
| **uv** | Runs the Meta Ads CLI | https://docs.astral.sh/uv/ |
| **jq** | Parses JSON in scripts | macOS: `brew install jq` — Linux: `sudo apt install jq` |
| **sips** or **ImageMagick** | Image dimension checks at launch | macOS: `sips` (preinstalled) — Linux: `identify` via ImageMagick — see [Linux and WSL notes](#linux-and-wsl-notes) |
| **ffprobe** | Video dimension checks (optional) | macOS: `brew install ffmpeg` — Linux: `sudo apt install ffmpeg` |

Running on Linux or WSL? Read [Linux and WSL notes](#linux-and-wsl-notes) before your first launch.

### 1b. Clone and add the wrapper to PATH

```bash
git clone https://github.com/Seeking-Leverage/automated-meta-ads-toolkit.git
cd automated-meta-ads-toolkit

# Make the wrapper executable (required on fresh clones)
chmod +x bin/meta

# Add to PATH for this session
export PATH="$PWD/bin:$PATH"

# Make permanent — add the export line to ~/.zshrc or ~/.bashrc
```

Verify:

```bash
which meta
# → .../automated-meta-ads-toolkit/bin/meta
```

### 1c. Install the Meta Ads CLI (one-time, outside the repo)

```bash
mkdir -p ~/meta-ads-cli && cd ~/meta-ads-cli
uv init --python 3.12 --no-readme --no-pin-python --bare
uv add "meta-ads==1.1.0"
uv run meta --version
# → meta, version 1.x.x
```

You can install the CLI anywhere. Point a client at a custom path with `META_ADS_CLI_PROJECT` in that client's `.env` (default: `~/meta-ads-cli`).

---

## Part 2: Meta Business Manager setup

You need a **system user** token — not a personal Facebook login token.

### 2a. Create or select a system user

1. Open [Meta Business Manager](https://business.facebook.com)
2. **Business Settings → Users → System Users**
3. Create a system user (Admin role is typical for campaign management)

### 2b. Assign assets to the system user

This step is required. Without these assignments, API calls fail with opaque permission errors.

| Asset | Required for | Permissions to grant |
| --- | --- | --- |
| **Ad account** | All ad operations | Manage campaigns |
| **Facebook Page** | Creative creation | Create content + Advertise |
| **Pixel / Dataset** | Conversion campaigns | View + Manage |
| **Instagram account** | IG placements only | Create content + Advertise |

**How to assign:** Business Settings → Accounts → [Ad Accounts / Pages / Pixels] → Add people → select your system user → grant permissions.

### 2c. Generate a token

1. **System Users → [your user] → Generate New Token**
2. Select your app (create one in [Meta for Developers](https://developers.facebook.com) if needed)
3. Scopes: **`ads_management`**, **`ads_read`**
4. Copy the token immediately — you cannot view it again

### 2d. Collect IDs for your `.env`

| Variable | Where to find it |
| --- | --- |
| `META_ADS_ACCOUNT_ID` | Ads Manager URL: `act_XXXXXXXXX` — **include the `act_` prefix** |
| `META_PAGE_ID` | Page Settings → About → Page ID |
| `META_PIXEL_ID` | Events Manager → your pixel → Settings |

---

## Part 3: Customize the harness for your organization

This is the core customization step. Each business, brand, or ad account you manage gets its own folder under `clients/`.

### 3a. Create your first client folder

Pick a **kebab-case** name that your team will recognize (`acme-co`, `brand-retail`, `internal-saas`). This name is the first argument to every `meta` command.

```bash
cd automated-meta-ads-toolkit

# Copy the example template
cp -r clients/client-example clients/your-client-name

# Create the real config (gitignored — never commit)
cp clients/your-client-name/.env.example clients/your-client-name/.env
```

### 3b. Fill in `clients/your-client-name/.env`

```bash
# System user token (ads_management + ads_read)
META_ADS_ACCESS_TOKEN=your_token_here

# Ad account — must include act_ prefix
META_ADS_ACCOUNT_ID=act_1234567890

# Defaults used when scaffolding campaigns (optional but recommended)
META_PAGE_ID=123456789012345
META_PIXEL_ID=123456789012345

# Only if CLI is not at ~/meta-ads-cli:
# META_ADS_CLI_PROJECT=/custom/path/to/meta-ads-cli
```

**Rules:**

- One `.env` per client folder — never put credentials in the repo root
- Never commit `.env` — it is gitignored by default
- Rotate tokens in Business Manager; update `.env` and note dates in the comments at the top of `.env.example`

### 3c. Define business goals (optional but recommended)

Copy and edit `goals.md` so performance reviews have clear targets:

```bash
# Already copied with client-example; edit in place:
$EDITOR clients/your-client-name/goals.md
```

This file separates **optimization metrics** (what Meta learns on) from **success metrics** (what your business cares about). See [03-performance-analysis.md](03-performance-analysis.md).

### 3d. Choose your campaign naming convention

The example uses `YYYYMMDD_Client_Purpose_Geo_MonthYear`. You can adopt it or define your own — the harness does not enforce a prefix. What matters is consistency within your team.

Example names in `campaign.yaml`:

```yaml
campaign:
  name: "20260708_Acme_Traffic_US_LPV_Test"
adset:
  name: "20260708_Acme_Broad_US_V1"
```

Campaign **folder slugs** (the directory name) should be kebab-case: `summer-sale-jul26`, `prospecting-us-v1`.

### 3e. Scaffold or copy a campaign folder

**Option A — Use the included example (fastest)**

The repo ships an unlaunched example:

```
clients/client-example/campaigns/example-traffic-jul26/
├── campaign.yaml
├── images/          ← add feed-v1.jpg (1080×1080+)
└── README.md
```

Copy it into your client folder:

```bash
cp -r clients/client-example/campaigns/example-traffic-jul26 \
      clients/your-client-name/campaigns/my-first-campaign
```

**Option B — Scaffold with an AI agent (Claude Code)**

If you use Claude Code with this repo open:

```
/scaffold-meta-campaign your-client-name my-first-campaign
```

**Option C — Create manually**

```bash
mkdir -p clients/your-client-name/campaigns/my-first-campaign/{images,videos,insights}
touch clients/your-client-name/campaigns/my-first-campaign/insights/.gitkeep
```

Then write `campaign.yaml` following [04-campaign-spec-schema.md](04-campaign-spec-schema.md).

### 3f. Edit `campaign.yaml` for your launch

Replace every placeholder before launching:

| Field | Source |
| --- | --- |
| `ad_account_id` | `META_ADS_ACCOUNT_ID` from `.env` |
| `page_id` | `META_PAGE_ID` from `.env` |
| `pixel_id` | `META_PIXEL_ID` from `.env` (required for conversion campaigns) |
| `body`, `title`, `link_url` | Your ad copy and landing page |
| `daily_budget_cents` | Your test budget (5000 = $50/day) |

Add creative:

```bash
cp /path/to/your-image.jpg \
   clients/your-client-name/campaigns/my-first-campaign/images/feed-v1.jpg
```

Image must be **≥ 1080×1080** pixels and match the path in `campaign.yaml`.

### 3g. Add more clients (agencies)

Repeat Part 3a–3b for each ad account:

```bash
cp -r clients/client-example clients/another-client
cp clients/another-client/.env.example clients/another-client/.env
# Fill in that client's token and IDs
meta another-client auth status
```

See [clients/README.md](../clients/README.md) for multi-client rules.

### 3h. Customize harness components (advanced)

Most teams only touch `clients/`. If you need deeper customization:

| File | When to edit |
| --- | --- |
| `bin/meta` | Different default CLI path, extra env var exports |
| `.claude/skills/scaffold-meta-campaign/SKILL.md` | Change default `campaign.yaml` template |
| `.claude/skills/launch-meta-campaign/SKILL.md` | Change launch procedure or UTM format |
| `.claude/rules/meta-ads.md` | Tighten or relax agent safety rules |
| `scripts/pause-campaign.sh` | Custom pause order or logging |
| `scripts/pull-insights.sh` | Different insight windows or breakdowns |

If you use an AI tool other than Claude Code, copy the skill markdown files into your tool's equivalent (Cursor rules, custom GPT instructions, etc.). The skills are plain procedural docs — no proprietary runtime.

---

## Part 4: Verify your setup

Run from the repo root with `bin/` on your PATH:

```bash
# 1. Token is valid
meta your-client-name auth status

# 2. Can reach the ad account
meta your-client-name -o json --no-input ads campaign list
```

**Success:** auth status exits 0; campaign list returns a JSON array (possibly empty).

### Common errors

| Error | Fix |
| --- | --- |
| `permission denied: meta` | `chmod +x bin/meta` |
| `No configuration found for client` | Folder name must match: `clients/your-client-name/.env` exists |
| `META_ADS_ACCESS_TOKEN ... missing` | Fill in `.env` |
| `Meta Ads CLI project not found` | Install CLI at `~/meta-ads-cli` or set `META_ADS_CLI_PROJECT` |
| Auth exit code 3 | Token expired — regenerate in Business Manager |
| `uv: command not found` | Install uv |
| `Error: No such option: -o` | Flags go **before** subcommand: `meta -o json --no-input ads ...` |
| `Application does not have permission` | Assign Page to system user (Part 2b) |

---

## Part 5: Launch your first campaign

There is **no** `meta campaign launch` command. Campaigns are created step by step: campaign → ad set → creative(s) → ad(s). Everything is created **PAUSED**.

### Option A — AI agent (recommended)

With Claude Code (or an agent that can read `.claude/skills/`):

```
/launch-meta-campaign your-client-name my-first-campaign
```

The skill will:

1. Validate `campaign.yaml` (stops on any error — zero writes)
2. Show each CLI command and wait for your explicit **"go"**
3. Create all objects PAUSED
4. Write IDs to `state.json` and events to `launch.log`
5. Auto-append UTM params to every `link_url`

### Option B — Manual CLI

Follow [01-campaign-setup-guide.md](01-campaign-setup-guide.md) for copy-paste commands.

### Option C — Playbook walkthrough

See [new-campaign-playbook.md](new-campaign-playbook.md) for the full end-to-end flow.

### After launch: review before spending

**Do not activate in Ads Manager until you complete the checklist:**

[02-review-and-launch.md](02-review-and-launch.md)

---

## Part 6: Operate campaigns day to day

| Task | Command or doc |
| --- | --- |
| Pause everything | `./scripts/pause-campaign.sh your-client-name my-first-campaign` |
| Pull performance data | `./scripts/pull-insights.sh your-client-name my-first-campaign` |
| Analyze vs goals | [03-performance-analysis.md](03-performance-analysis.md) |
| Resume a partial launch | Re-run `/launch-meta-campaign` — reads existing `state.json` |
| Start fresh launch | Delete `state.json` in the campaign folder |

---

## What to commit vs keep local

| Path | Commit to git? | Notes |
| --- | --- | --- |
| `clients/<client>/.env` | **Never** | Credentials — gitignored |
| `clients/<client>/goals.md` | Yes (if no secrets) | Business targets |
| `clients/<client>/campaigns/<slug>/campaign.yaml` | Yes | Campaign intent — diffable |
| `clients/<client>/campaigns/<slug>/images/` | Yes (small files) | Creative assets |
| `clients/<client>/campaigns/<slug>/state.json` | Your choice | IDs — useful for team resumability |
| `clients/<client>/campaigns/<slug>/launch.log` | Your choice | Audit trail |
| `clients/<client>/campaigns/<slug>/insights/` | Optional | Snapshots — can be large |

**Recommended for agencies:** Commit specs and assets to a **private** repo — see [Fork and private-repo workflow](#fork-and-private-repo-workflow) below.

---

## Linux and WSL notes

The harness was developed on macOS. Everything works on Linux and WSL with a few tool substitutions.

### Install prerequisites on Linux

**Debian / Ubuntu / WSL:**

```bash
sudo apt update
sudo apt install -y git jq imagemagick ffmpeg
# uv — follow https://docs.astral.sh/uv/getting-started/installation/
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Fedora / RHEL:**

```bash
sudo dnf install -y git jq ImageMagick ffmpeg
```

### Image dimension checks

The launch skill validates creatives are **≥ 1080×1080** before any write. On macOS it uses `sips`. On Linux, use ImageMagick's `identify`:

```bash
# macOS
sips -g pixelWidth -g pixelHeight clients/your-client/campaigns/my-campaign/images/feed-v1.jpg

# Linux / WSL
identify -format "%wx%h" clients/your-client/campaigns/my-campaign/images/feed-v1.jpg
# → 1080x1080 (both dimensions must be ≥ 1080)
```

If you launch via an AI agent, tell it you are on Linux — it should use `identify` instead of `sips`. If launching manually, run the `identify` command yourself before proceeding.

### Video dimension checks (optional)

If your campaign uses video creatives and `ffprobe` is installed:

```bash
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height \
  -of csv=p=0:s=x clients/your-client/campaigns/my-campaign/videos/feed-v1.mp4
```

### Wrapper and PATH

Same as macOS — Linux clones also need:

```bash
chmod +x bin/meta
export PATH="$PWD/bin:$PATH"
# Add to ~/.bashrc for persistence
```

### Absolute paths for creatives

The Meta Ads CLI runs from `~/meta-ads-cli`, not your repo root. Creative paths in CLI commands must be **absolute**:

```bash
# Good
--image "/home/you/automated-meta-ads-toolkit/clients/acme-co/campaigns/summer-sale/images/feed-v1.jpg"

# Bad — relative paths break
--image "clients/acme-co/campaigns/summer-sale/images/feed-v1.jpg"
```

The launch skill handles this automatically. For manual CLI launches, use `realpath` or `$PWD/...`.

### WSL-specific tips

- Store the repo on the Linux filesystem (`~/...`), not `/mnt/c/...` — file permissions and `chmod` behave more reliably.
- Business Manager and Ads Manager run in your Windows browser; the CLI runs in WSL. That split is normal.
- If `uv` was installed in WSL, use WSL terminal sessions consistently — don't mix Windows and WSL installs of the CLI.

### Linux troubleshooting

| Error | Fix |
| --- | --- |
| `sips: command not found` | Use `identify` (ImageMagick) — see above |
| `identify: command not found` | `sudo apt install imagemagick` |
| `permission denied: bin/meta` | `chmod +x bin/meta` |
| `uv: command not found` | Install uv in your Linux/WSL shell, then restart the terminal |

---

## Fork and private-repo workflow

The public [Seeking Leverage repo](https://github.com/Seeking-Leverage/automated-meta-ads-toolkit) ships harness code, docs, and an **example** client — not your real credentials or client campaigns. Agencies and in-house teams should keep operational data in a **private** repository.

### Why use a private repo?

| Keep in private git | Keep out of git entirely |
| --- | --- |
| `campaign.yaml`, creative assets, `goals.md` | `clients/<client>/.env` (tokens) |
| `state.json`, `launch.log` (team resumability) | Raw access tokens in shell history |
| Custom skill/script edits your team makes | |

This gives you version-controlled campaign specs and audit trails without exposing credentials or client work on a public GitHub page.

### Recommended setup: clone upstream → push to private remote

Do **not** rely on a public GitHub fork if you plan to commit real client folders — public forks are visible to everyone. Instead:

```bash
# 1. Clone the public harness
git clone https://github.com/Seeking-Leverage/automated-meta-ads-toolkit.git
cd automated-meta-ads-toolkit

# 2. Create an empty private repo in GitHub/GitLab/Bitbucket
#    (e.g. your-org/meta-ads-harness)

# 3. Point origin at YOUR private remote
git remote rename origin upstream
git remote add origin git@github.com:your-org/meta-ads-harness.git

# 4. Push the harness code to your private repo
git push -u origin main
```

Your remotes should look like:

```
origin    git@github.com:your-org/meta-ads-harness.git   (your private repo)
upstream  https://github.com/Seeking-Leverage/automated-meta-ads-toolkit.git
```

### Day-one workflow for your team

```bash
# Each team member:
git clone git@github.com:your-org/meta-ads-harness.git
cd meta-ads-harness
chmod +x bin/meta
export PATH="$PWD/bin:$PATH"

# Create client config locally (never committed)
cp -r clients/client-example clients/acme-co
cp clients/acme-co/.env.example clients/acme-co/.env
# Fill in .env — from 1Password, Vault, or a secure handoff, not git
```

### What to commit after customizing

```bash
git add clients/acme-co/goals.md
git add clients/acme-co/campaigns/summer-sale-jul26/campaign.yaml
git add clients/acme-co/campaigns/summer-sale-jul26/images/
git add clients/acme-co/campaigns/summer-sale-jul26/state.json   # optional
git commit -m "Add acme-co summer sale campaign spec"
git push
```

**Before every commit**, confirm no `.env` files are staged:

```bash
git status
# Should NOT list clients/*/\.env

# Safety check
git diff --cached --name-only | grep '\.env' && echo "STOP — .env staged!" || echo "OK"
```

The repo `.gitignore` already excludes `clients/*/.env`, but always verify — especially if you add new ignore rules.

### Pulling harness improvements from Seeking Leverage

When the public repo gets doc fixes, skill updates, or script improvements:

```bash
git fetch upstream
git merge upstream/main
# Resolve conflicts if you edited the same files
git push origin main
```

Do this monthly or when release notes mention changes you want. Your `clients/` data merges cleanly in most cases because upstream only touches `client-example`.

### Alternative: GitHub private fork

GitHub lets you fork into a **private** repo (if your org plan allows it):

1. Fork `Seeking-Leverage/automated-meta-ads-toolkit` → private fork under your org
2. Clone your private fork
3. Add the public repo as `upstream` (same merge workflow as above)

This is fine as long as the fork visibility is **Private**.

### Credential handoff between teammates

`.env` never goes in git. Options teams use in practice:

| Method | Notes |
| --- | --- |
| **Secrets manager** (1Password, Vault) | Best for agencies — one vault item per client |
| **Secure DM / encrypted share** | OK for small teams; rotate after handoff |
| **Each person generates their own token** | Create separate system users or tokens per operator in Business Manager |

Every teammate still runs their own local setup (Part 1 + Part 4) — the private repo syncs **specs**, not **tokens**.

### Private-repo checklist

- [ ] Private remote created; `upstream` points at Seeking Leverage public repo
- [ ] `clients/<client>/.env` exists locally, never staged in git
- [ ] Real client folders committed to private repo (not `client-example` placeholders only)
- [ ] Team knows to `git fetch upstream && git merge upstream/main` periodically
- [ ] Credentials distributed via secrets manager, not Slack/email in plaintext

---

## Complete checklist

Use this to confirm you are ready to launch:

- [ ] `uv` and `jq` installed
- [ ] Repo cloned; `chmod +x bin/meta`; `bin/` on PATH
- [ ] Meta Ads CLI installed at `~/meta-ads-cli` (or custom path in `.env`)
- [ ] System user created in Business Manager
- [ ] Ad account, Page, and Pixel assigned to system user
- [ ] Token generated with `ads_management` + `ads_read`
- [ ] Client folder created: `clients/your-client-name/.env` filled in
- [ ] `meta your-client-name auth status` succeeds
- [ ] `meta your-client-name -o json --no-input ads campaign list` succeeds
- [ ] Campaign folder exists with edited `campaign.yaml`
- [ ] Creative image ≥ 1080×1080 at the path in `campaign.yaml`
- [ ] `goals.md` edited (optional)
- [ ] Launch completed; [02-review-and-launch.md](02-review-and-launch.md) checklist passed before activation

**Linux / WSL additionally:**

- [ ] `imagemagick` installed; `identify` works on your creative file
- [ ] Repo on Linux filesystem (not `/mnt/c/...`) if using WSL

**Private repo additionally:**

- [ ] Private `origin` remote set; `upstream` points at Seeking Leverage public repo
- [ ] `git status` never shows `clients/*/.env` before push

---

## Where to go next

| Doc | Purpose |
| --- | --- |
| [getting-started.md](getting-started.md) | Shorter setup path (same steps, less customization detail) |
| [new-campaign-playbook.md](new-campaign-playbook.md) | Repeat launches after your first |
| [04-campaign-spec-schema.md](04-campaign-spec-schema.md) | Full `campaign.yaml` reference |
| [HARNESS.md](HARNESS.md) | Architecture and CLI quirks |
| [clients/README.md](../clients/README.md) | Multi-client management |

**In this guide:** [Linux and WSL notes](#linux-and-wsl-notes) · [Fork and private-repo workflow](#fork-and-private-repo-workflow)

---

## About this project

This toolkit was created by **[Seeking Leverage](https://www.seekingleverage.com)** — a growth and paid media consultancy. It is open-sourced so agencies and in-house teams can run Meta Ads safely and repeatably without building a harness from scratch.

If this toolkit helps your team, we'd love to hear from you:

- **Website:** [seekingleverage.com](https://www.seekingleverage.com)
- **Issues:** [GitHub repo](https://github.com/Seeking-Leverage/automated-meta-ads-toolkit/issues)

You are free to fork, customize, and use it internally. Attribution is appreciated but not required.

---

## Getting help

- **CLI issues:** [meta-ads on PyPI](https://pypi.org/project/meta-ads/) and Graph API docs
- **Harness issues:** Open an issue on the [GitHub repo](https://github.com/Seeking-Leverage/automated-meta-ads-toolkit/issues)
- **Meta permissions:** Re-check Part 2b asset assignments — most failures trace back to missing Page or Pixel access