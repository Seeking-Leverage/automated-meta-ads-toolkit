# Campaign goals template

Copy this file to `clients/<client>/goals.md` and fill in your client's metrics.
Use it when analyzing performance — see [docs/03-performance-analysis.md](../../docs/03-performance-analysis.md).

## The two-metric discipline

Meta optimizes toward one event. Your business measures success on another. **Do not conflate them.**

| | Optimization metric | Success metric |
| --- | --- | --- |
| **What it measures** | What Meta's algorithm learns on | What your business cares about |
| **Volume** | Usually higher (more signal for Meta) | Often lower (closer to revenue) |
| **Has a dollar target?** | Usually no — directional only | Yes — this is your KPI |

### Example (replace with your numbers)

| Metric | Formula | Meta `action_type` | Role |
| --- | --- | --- | --- |
| **CPL** (Cost per Lead) | Spend / leads | `lead` | Meta optimization event. Directional — lower is better. No fixed target. |
| **CPA** (Cost per Acquisition) | Spend / purchases | `purchase` | Business success metric. **Target: $XX.** |

## Your targets

**Primary success metric:** `<name>` = `<formula>`. **Target: $<amount>.**

**Optimization metric:** `<name>` = `<formula>`. Maps to `action_type`: `<type>`. No fixed target.

## How to read results

Every analysis should lead with **actual vs target** on at least two windows:

- **Lifetime:** lifetime spend / lifetime conversions
- **Last 7 days:** last_7d spend / last_7d conversions

Report the optimization metric alongside as a delivery-efficiency signal — never compare it to the success-metric target.

## Notes

<!-- Add campaign-specific context, seasonality, or constraints here -->