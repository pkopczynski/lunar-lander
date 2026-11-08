# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the label strings used in this repo's issue tracker.

| Role | Label in our tracker | Meaning |
|---|---|---|
| `needs-triage` | `needs-triage` | Maintainer needs to evaluate this issue |
| `needs-info` | `needs-info` | Waiting on reporter for more information |
| `ready-for-agent` | `ready-for-agent` | Implementation ticket an AFK agent can finish alone |
| `ready-for-human` | `ready-for-human` | Needs a human: playtests, judgement calls, or an open question |
| `wontfix` | `wontfix` | Will not be actioned |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label string from this table. Triage labels go on implementation tickets only; maps, decision tickets and specs carry their own labels (`docs/agents/issue-tracker.md` → "Issue kinds").
