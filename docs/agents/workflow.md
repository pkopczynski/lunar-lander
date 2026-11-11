# Workflow: from roadmap to merged code

How a long-term product direction becomes merged code, and how an agent or developer picks up any step of it from GitHub Issues alone. Issue shapes, labels and `gh` commands are in `docs/agents/issue-tracker.md`.

## The pipeline

1. **Explore** (`/wayfinder`): the product owner charts a direction as a map issue with decision tickets (research, prototype, grilling, task), resolved one per session. Each decision is a resolution comment on its ticket; architectural ones are marked `ADR candidate:`.
2. **Specify** (`/to-spec`): once the map's way is clear, each spec is published as a `spec` issue whose **Origin** links the map and the decision tickets it rests on, and whose **Architecture and ADRs** section carries the ADR candidates forward. Comment on the map with a link to each spec.
3. **Slice** (`/to-tickets <spec>`): implementation tickets are created as sub-issues of the spec, with native blocking edges, using the portable ticket body.
4. **Implement** (`/implement <ticket>` or `/implement-spec <spec>`): one ticket, one PR, following "Starting from an issue" below.
5. **Merge**: the merged code and the docs it updated become the source of truth for every later ticket.

Each step reads only what the previous one left in GitHub and the repo. Conversation history is never the only home of a decision: if a planning session settles something, it lands in an issue comment or body before the session ends.

## Starting from an issue

Done when you can state, for this ticket: what to build, how it will be checked, what the codebase looks like there now, and which documents the PR will change.

1. Read the ticket with its comments. Find its parent (`.../issues/<n>/parent`) and read the spec with its comments, then the decision tickets and map its **Origin** links, as far as the ticket needs.
2. Read the ticket's blockers (`.../dependencies/blocked_by`). Each should be closed; for each, read the PR that closed it, since it may have changed what this ticket builds on.
3. Read the documents the ticket's **Context** names, plus `docs/agents/domain.md`'s list for the area.
4. Verify against `main`: the code, scenes and tests the ticket touches, and `git log` since the spec was opened for that area. Then run "Stale specs" below. A comment from another PR (see "Notify affected tickets" under Pull requests) counts only once that PR has merged; until then, the ticket stands as written.

## Stale specs

A spec or ticket is a snapshot of intent; `main` and its docs move on. Before writing code, compare the ticket with what you found. A **discrepancy** is any place where the ticket assumes something that is no longer true: a term renamed, a system restructured, a behaviour changed by a merged PR, a newer decision or ADR that supersedes it, a blocker that shipped differently than planned.

- **Mechanical** (a renamed file or node, a moved helper; the intended behaviour and scope are unchanged): adapt, and record the discrepancy in the PR body.
- **Changes scope or accepted behaviour**: stop before implementing. Comment on the ticket naming the discrepancy, its impact, and the options, then ask the user. When working as an AFK agent, also swap `ready-for-agent` for `ready-for-human`.

Either way, when the spec itself is now wrong for later tickets, comment on the spec so the next agent reads the correction.

## Pull requests

- Title and type per `CLAUDE.md`; body starts with `Closes #<ticket>`.
- Update the documents listed under the ticket's **Documentation to update**, and any other the change touches per "Keeping docs current" in `docs/README.md`, in the same PR.
- Land each ADR candidate the ticket delivers as a new ADR in `docs/adr/`, linking the decision ticket it came from, and add it to the table in `docs/README.md`.
- Record every discrepancy you adapted to, and anything the next ticket should know.
- **Notify affected tickets.** When you open the PR, find every other open implementation ticket that the change will make wrong: one that assumes something this PR makes untrue (the "Stale specs" test). Look at the parent spec's other tickets, and at open tickets in every area the PR touches (`gh issue list --search 'is:open label:ready-for-agent,ready-for-human label:"area:<feature>"'`). On each one, comment: link the PR, say what changes once it merges, and what the ticket now has to do differently. Leave the ticket body alone. When the change shifts that ticket's scope or accepted behaviour, also swap `ready-for-agent` for `ready-for-human`. List the tickets you notified in the PR body, or write "Notified: none".

## After merge

Later tickets build on `main`, not on the plan: when a ticket body and the merged code or docs disagree, the merged state wins and the disagreement is a discrepancy (above). When the last ticket of a spec merges, close the spec; when every spec of a map is closed, close the map.
