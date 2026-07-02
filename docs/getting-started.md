# Getting Started

Complete setup guide: clone this repo → run your first Meta Ads command → launch your first campaign.

**Time required:** ~30–45 minutes (mostly Meta Business Manager setup).

---

## What you are setting up

This repo is a **harness** around the Meta Ads CLI. It does not contain the CLI itself.

```
Your machine
├── automated-meta-ads-toolkit/     ← this repo (wrapper, docs, skills, client data)
└── ~/meta-ads-cli/                 ← separate uv project (the meta-ads Python package)
```

After setup you will run commands like:

```bash
meta acme-co auth status
meta acme-co -o json --no-input ads campaign list
```

---

## Step 1: Install prerequisites

| Tool | Purpose | Install |
| --- | --- | --- |
| **uv** | Runs the Meta Ads CLI | https://docs.astral.sh/uv/ |
| **Python 3.12+** | Required by meta-ads | `uv` manages this automatically |
| **jq** | Parses state.json in scripts | `brew install jq` (macOS) |
| **sips** | Image dimension checks (macOS) | Preinstalled on macOS |
| **ffprobe** | Video dimension checks (optional) | `brew install ffmpeg` |

---

## Step 2: Clone this repository

```bash
git clone https://github.com/Seeking-Leverage/automated-meta-ads-toolkit.git
cd automated-meta-ads-toolkit
```

Add the wrapper to your PATH (add this to `~/.zshrc` or `~/.bashrc` to make it permanent):

```bash
export PATH="$PWD/bin:$PATH"
```

Verify the wrapper exists:

```bash
which meta
# should print: .../automated-meta-ads-toolkit/bin/meta
```

---

## Step 3: Install the Meta Ads CLI (external project)

The CLI lives in its own directory — **not inside this repo**.

```bash
mkdir -p ~/meta-ads-cli && cd ~/meta-ads-cli
uv init --python 3.12 --no-readme --no-pin-python --bare
uv add meta-ads
uv run meta --version
```

You can install it anywhere. You will point each client at it via `META_ADS_CLI_PROJECT` in that client's `.env` (default: `~/meta-ads-cli`).

---

## Step 4: Set up Meta Business Manager

You need a **system user** token — not a personal Facebook login token.

### 4a. Create or select a system user

1. Go to [Meta Business Manager](https://business.facebook.com)
2. **Business Settings → Users → System Users**
3. Create a system user (or select an existing one)

### 4b. Assign assets to the system user

This is the step most people miss. Without these assignments, commands fail with opaque errors.

| Asset | Required for | Permissions | If missing |
| --- | --- | --- | --- |
| **Ad account** | All ad operations | Manage campaigns | Cannot list or create campaigns |
| **Facebook Page** | `creative create` | Create content + Advertise | `API error (10): Application does not have permission` |
| **Pixel/Dataset** | Conversion campaigns | View + Manage | Ad set creation fails on `OFFSITE_CONVERSIONS` |
| **Instagram account** | IG placements only | Create content + Advertise | Skip if running Facebook-only ads |

To assign: **Business Settings → Accounts → [Ad Accounts / Pages / Pixels]** → Add people → select your system user → grant permissions.

### 4c. Generate a token

1. **System Users → [your user] → Generate New Token**
2. Select your app (or create one)
3. Scopes: `ads_management`, `ads_read`
4. Copy the token immediately — you cannot view it again

### 4d. Collect your IDs

You will need these for the `.env` file:

| ID | Where to find it |
| --- | --- |
| Ad account ID | Ads Manager URL: `act_XXXXXXXXX` (include the `act_` prefix) |
| Page ID | Page Settings → About → Page ID |
| Pixel ID | Events Manager → your pixel → Settings |

---

## Step 5: Create your first client

Each client (business or ad account) gets its own folder.

```bash
cd automated-meta-ads-toolkit

# Copy the example client
cp -r clients/client-example clients/acme-co

# Create the real config file (never commit this)
cp clients/acme-co/.env.example clients/acme-co/.env
```

Edit `clients/acme-co/.env`:

```bash
META_ADS_ACCESS_TOKEN=your_system_user_token_here
META_ADS_ACCOUNT_ID=act_your_ad_account_id
META_PAGE_ID=your_page_id
META_PIXEL_ID=your_pixel_id
# META_ADS_CLI_PROJECT=/custom/path/to/meta-ads-cli   # only if not using ~/meta-ads-cli
```

---

## Step 6: Verify everything works

Run these from the repo root (with `bin/` on your PATH):

```bash
# Check token is valid
meta acme-co auth status

# List campaigns (should return JSON, even if empty)
meta acme-co -o json --no-input ads campaign list
```

**Success looks like:** auth status returns exit code 0; campaign list returns a JSON array (possibly empty).

### If something fails

| Error | Fix |
| --- | --- |
| `No configuration found for client` | Check folder name matches: `clients/acme-co/.env` exists |
| `Meta Ads CLI project not found` | Install CLI at `~/meta-ads-cli` or set `META_ADS_CLI_PROJECT` |
| Auth exit code 3 | Token expired — regenerate in Business Manager |
| `uv: command not found` | Install uv |
| `Error: No such option: -o` | Put flags before subcommand: `meta -o json --no-input ads ...` |

---

## Step 7: Launch your first campaign

There is no `meta campaign launch` command. Campaigns are launched via an **agent skill** (Claude Code) or manually via the CLI.

### Option A: With Claude Code (recommended)

1. Open this repo in Claude Code
2. Scaffold a campaign folder:
   ```
   /scaffold-meta-campaign acme-co summer-sale-jul26
   ```
3. Drop a 1080×1080+ image into `clients/acme-co/campaigns/summer-sale-jul26/images/`
4. Edit `campaign.yaml` with your copy, URLs, and budget
5. Launch:
   ```
   /launch-meta-campaign acme-co summer-sale-jul26
   ```
6. Review in [Meta Ads Manager](https://adsmanager.facebook.com) before activating

### Option B: Manual CLI

Follow [01-campaign-setup-guide.md](01-campaign-setup-guide.md) for step-by-step CLI commands.

### Option C: Follow the playbook

See [new-campaign-playbook.md](new-campaign-playbook.md) for the full workflow.

---

## Step 8: Add more clients

```bash
cp -r clients/client-example clients/another-client
cp clients/another-client/.env.example clients/another-client/.env
# Edit .env with that client's credentials
meta another-client auth status
```

See [clients/README.md](../clients/README.md) for details.

---

## Quick reference

| Task | Command or doc |
| --- | --- |
| List campaigns | `meta <client> -o json --no-input ads campaign list` |
| Scaffold campaign | `/scaffold-meta-campaign <client> <slug>` |
| Launch campaign | `/launch-meta-campaign <client> <slug>` |
| Pause campaign | `./scripts/pause-campaign.sh <client> <slug>` |
| Pull insights | `./scripts/pull-insights.sh <client> <slug>` |
| Campaign YAML schema | [04-campaign-spec-schema.md](04-campaign-spec-schema.md) |
| Architecture | [HARNESS.md](HARNESS.md) |

---

## Checklist

Use this to confirm your setup is complete:

- [ ] `uv` installed
- [ ] Repo cloned, `bin/meta` on PATH
- [ ] Meta Ads CLI installed at `~/meta-ads-cli` (or custom path set in `.env`)
- [ ] System user created in Business Manager
- [ ] Ad account, Page, and Pixel assigned to system user
- [ ] Token generated with `ads_management` + `ads_read` scopes
- [ ] Client folder created with `.env` filled in
- [ ] `meta <client> auth status` succeeds
- [ ] `meta <client> -o json --no-input ads campaign list` succeeds