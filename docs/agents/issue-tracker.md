# Issue tracker: GitHub

GitHub Issues on `pkopczynski/lunar-lander` are the one backlog for human developers and agents alike: wayfinder maps, decision tickets, specs and implementation tickets all live there. Use the `gh` CLI for every operation. Relationships use GitHub's native features (sub-issues, issue dependencies), so the backlog reads the same in the GitHub UI as it does to an agent.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --json number,title,body,labels,comments,state`. Read the comments too: resolutions and later corrections live there.
- **List issues**: `gh issue list --state open --json number,title,labels --jq '.[] | {number, title, labels: [.labels[].name]}'` with `--label` and `--state` filters.
- **Sub-issues**: `gh issue create --parent <parent> ...`, or `gh issue edit <parent> --add-sub-issue <child>` afterwards. List a parent's children with `gh api repos/pkopczynski/lunar-lander/issues/<parent>/sub_issues --jq '.[] | {number, title, state}'`; find a child's parent with `gh api repos/pkopczynski/lunar-lander/issues/<child>/parent --jq '{number, title}'`.
- **Blocking**: native issue dependencies. Add an edge with `gh api --method POST repos/pkopczynski/lunar-lander/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, where `<blocker-db-id>` is the blocker's **database id** (`gh api repos/pkopczynski/lunar-lander/issues/<n> --jq .id`), never its `#number`. Read a ticket's blockers with `gh api repos/pkopczynski/lunar-lander/issues/<n>/dependencies/blocked_by --jq '.[] | {number, title, state}'`. A ticket is unblocked when every blocker is closed.
- **Comment**: `gh issue comment <number> --body "..."`
- **Labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

## Issue kinds

| Kind | Made by | Labels | Parent |
|---|---|---|---|
| Map | `/wayfinder` | `wayfinder:map` | none |
| Decision ticket | `/wayfinder` | `wayfinder:research` / `prototype` / `grilling` / `task` | sub-issue of its map |
| Spec | `/to-spec` | `spec`, plus its `area:` labels | none; links its map in **Origin** |
| Implementation ticket | `/to-tickets` | `ready-for-agent` or `ready-for-human`, plus its `area:` labels | sub-issue of its spec |

A spec is **not** a sub-issue of its map: as an open, unassigned child it would show up on the wayfinder frontier as a decision to take. Link it from the body instead, and comment on the map with a link to each spec made from it.

A spec carries `spec`, never `ready-for-agent`: it is a parent, not a unit of work. `ready-for-agent` marks only an implementation ticket an agent can pick up and finish alone. (Specs before this convention, like #51, carry `ready-for-agent`; read them as specs.)

## Area labels

An `area:<feature>` label (`area:money-loop`, `area:scenery`) names the player-facing feature an issue touches, so anyone can see and filter the work on a feature across specs: `gh issue list --search 'is:open label:"area:money-loop"'`.

- **Who carries them:** specs and implementation tickets, and bugs or requests once `/triage` knows the feature. Maps and decision tickets never do: their only labels are `wayfinder:` ones.
- **Choosing one:** `/to-spec` picks the spec's areas. Reuse an existing label (`gh label list --search area:`) before creating one with `gh label create "area:<feature>" --description "<the feature, in a player's words>"`. Name the feature, not the code: `area:money-loop`, not `area:bank-account`.
- **On tickets:** `/to-tickets` copies the spec's areas onto every ticket, and adds another area when a ticket also changes that feature.
- An issue may carry several areas. The area says what a ticket touches; its parent still says which spec it belongs to.

## Spec body

Use the `/to-spec` template, with three extra sections placed before **Out of Scope**:

```markdown
## Origin

The map this spec came from and the decision tickets it rests on, each as a linked title. "None" if it came straight from a conversation.

## Architecture and ADRs

- Existing ADRs this work must respect, each linked, with one line on how it applies.
- **ADR candidates**: each new architectural decision this spec makes, the ticket that decided it, and the gist. The implementation PR that lands it adds the ADR file.

## Documentation impact

Which documents the implementation changes, per the "Keeping docs current" list in `docs/README.md`: README sections, GLOSSARY terms, `docs/architecture/` sections, new ADRs.
```

## Implementation ticket body

Use this instead of the `/to-tickets` issue template. The test for every ticket: a developer or agent who never saw the planning conversation can start from the issue alone. Link the material rather than copying it, so it can't go stale in two places; copy only what lives nowhere else.

```markdown
## Parent

The spec, as a linked title.

## What to build

The end-to-end behaviour this ticket makes work, from the player's perspective: the problem and the intended outcome.

## Acceptance criteria

- [ ] Each criterion observable in the game or in a test through the main scene (ADR 0004).
- [ ] The documentation listed below is updated in the same PR.

## Context

- The parent spec's user stories and implementation decisions this ticket delivers, by number or heading.
- Decision tickets and ADRs that bind it, each linked.
- The README, GLOSSARY and `docs/architecture/` sections to read before starting.

## Documentation to update

The documents this ticket changes, and any ADR candidate from the spec it lands.

## Open questions

Anything still unresolved, and who decides it. "None" when there are none. A ticket with an open question that changes scope or behaviour gets `ready-for-human` until it is answered.
```

Blockers are native dependency edges; add a `## Blocked by` section only if an edge could not be created.

## When a skill says "publish to the issue tracker"

Create a GitHub issue of the right kind (table above).

## When a skill says "fetch the relevant ticket"

Read it as in **Read an issue**, then follow `docs/agents/workflow.md` → "Starting from an issue".

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Destination / Notes / Decisions-so-far / Not-yet-specified / Out-of-scope body. `gh issue create --label wayfinder:map`.
- **Child ticket**: a sub-issue of the map, labelled `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, it is assigned to the driving dev.
- **Blocking**: native issue dependencies, as in **Blocking** above.
- **Frontier query**: list the map's open sub-issues, drop any with an open blocker or an assignee; first in map order wins.
- **Claim**: `gh issue edit <n> --add-assignee @me`, the session's first write.
- **Resolve**: `gh issue comment <n> --body "<answer>"`, then `gh issue close <n>`, then append a context pointer (gist + link) to the map's Decisions-so-far. When the answer is an architectural decision that would earn an ADR (see `docs/README.md`), start the resolution comment with a line `ADR candidate: <one-line decision>`, and mark the Decisions-so-far line `(ADR candidate)`, so `/to-spec` carries it forward.
