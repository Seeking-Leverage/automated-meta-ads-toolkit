# Launch log schema

Every campaign launched via `launch-meta-campaign` produces a `launch.log` at:

```
clients/<client>/campaigns/<slug>/launch.log
```

The log is append-only JSONL — one JSON object per line.

## Three companion files

| File | Role | Who writes |
| --- | --- | --- |
| `campaign.yaml` | Intent — what we want | Human |
| `state.json` | Outcomes — final IDs | Launch skill (overwrite) |
| `launch.log` | Launch timeline | Launch skill (append) |
| `ops.log` | Post-launch operations | Ops skills/scripts (append) |

## Common fields (every event)

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `ts` | string | yes | ISO 8601 UTC timestamp |
| `kind` | string | yes | Event kind (see below) |
| `ts_approx` | boolean | no | `true` if timestamp is interpolated |

## Event kinds

### `launch_start`

Fires once at the beginning, before any CLI call.

| Field | Required | Description |
| --- | --- | --- |
| `client` | yes | Client folder name |
| `slug` | yes | Campaign slug |
| `spec_path` | yes | Path to `campaign.yaml` |
| `ad_account_id` | yes | Account being billed |

### `step_attempt`

Fires before each CLI call.

| Field | Required | Description |
| --- | --- | --- |
| `step` | yes | `campaign_create`, `adset_create`, `creative_create`, or `ad_create` |
| `attempt` | yes | Retry counter, starting at 1 |
| `cmd` | yes | Exact command (redact `access_token=***REDACTED***`) |

### `step_success`

Fires after a successful attempt.

| Field | Required | Description |
| --- | --- | --- |
| `step` | yes | Same as `step_attempt` |
| `attempt` | yes | Matching attempt number |
| `id` | yes | Meta object ID returned |
| `duration_sec` | no | Wall-clock seconds for this attempt |

### `step_fail`

Fires after a failed attempt.

| Field | Required | Description |
| --- | --- | --- |
| `step` | yes | Same as `step_attempt` |
| `attempt` | yes | Matching attempt number |
| `error` | yes | Verbatim error from CLI |
| `root_cause` | no | Human-readable diagnosis |

### `out_of_band_patch`

Fires for Graph API calls outside the CLI chain.

| Field | Required | Description |
| --- | --- | --- |
| `target` | yes | `campaign`, `adset`, `creative`, or `ad` |
| `id` | yes | Meta object ID |
| `method` | yes | `graph_api`, `ads_manager`, or `other` |
| `result` | yes | What happened |
| `note` | no | Why this was necessary |

### `launch_complete`

Fires once at the end.

| Field | Required | Description |
| --- | --- | --- |
| `duration_sec` | yes | Total wall-clock time |
| `steps_total` | yes | Steps that should have run |
| `steps_succeeded` | yes | Steps with `step_success` |
| `retries_total` | yes | Sum of extra attempts |
| `out_of_band_patches` | yes | Count of out-of-band events |
| `final_state` | yes | `all_paused`, `partial`, or `failed` |

## Writing events

```bash
LOG="clients/<client>/campaigns/<slug>/launch.log"
jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{ts: $ts, kind: "launch_start", client: "<client>", slug: "<slug>", ...}' \
  >> "$LOG"
```

Always append (`>>`), never overwrite (`>`).

## Querying

```bash
# All failures with root causes
jq -r 'select(.kind == "step_fail") | "\(.step): \(.root_cause // .error)"' launch.log

# Launch summary
jq -r 'select(.kind == "launch_complete") | "\(.final_state) in \(.duration_sec)s"' launch.log
```