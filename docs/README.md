# Documentation

Where each kind of project knowledge lives. Start here when you need more than the root README.

| Question | Source of truth |
|---|---|
| What the game is, constraints, code conventions, cross-cutting gotchas, a one-line index of files, how to run things | [`README.md`](../README.md) (always read; kept under 16 KB) |
| What the game does now, rule by rule | [`gameplay/`](gameplay/): [`flight.md`](gameplay/flight.md), [`office.md`](gameplay/office.md), [`world-and-scenery.md`](gameplay/world-and-scenery.md) |
| What one script does, its API and its local traps | The header comment at the top of that script |
| How to write a test: the runner, helpers and read-outs | [`tests/README.md`](../tests/README.md) |
| What a domain term means | [`GLOSSARY.md`](../GLOSSARY.md) |
| How the systems fit together: scene tree, dependencies, signals, who owns which state, frame and pause model | [`architecture/overview.md`](architecture/overview.md) |
| How domain concepts relate: lifecycles, invariants, where each lives in code | [`architecture/domain-model.md`](architecture/domain-model.md) |
| Why a significant choice was made | [`adr/`](adr/) (below) |
| What to build next: specs, requirements, tasks | [GitHub Issues](https://github.com/pkopczynski/lunar-lander/issues) |
| What shipped, what is being built and what comes next, at a glance | The [roadmap page](https://pkopczynski.github.io/lunar-lander/), built from Issues (never edited by hand; how it reads them: [`agents/issue-tracker.md`](agents/issue-tracker.md) → "The roadmap page") |
| How work flows from a roadmap map to specs, tickets and PRs; issue conventions for agents | [`agents/`](agents/) (start with [`workflow.md`](agents/workflow.md)) |
| Commits, PR titles, versions, releases | [`CLAUDE.md`](../CLAUDE.md) |
| Onboarding a new contributor (in Polish): setup, ticket to PR, review and the protected `main`, reporting playtest findings | [`CONTRIBUTING.md`](../CONTRIBUTING.md) |
| What changed for the player | [`CHANGELOG.md`](../CHANGELOG.md) (written by release-please) |

## Decisions

| ADR | Decision |
|---|---|
| [0001](adr/0001-bundled-pixel-font.md) | Bundle the Silkscreen font despite the no-external-assets rule |
| [0002](adr/0002-one-planet-clock.md) | One planet clock with drifting locations |
| [0003](adr/0003-run-state-in-scene-nodes.md) | Run state lives in scene nodes, and restart reloads the scene |
| [0004](adr/0004-one-test-seam-the-main-scene.md) | Tests drive the whole main scene and check only what a player could observe |
| [0005](adr/0005-solid-terrain-vs-decor.md) | Solid terrain and decor are kept strictly apart |
| [0006](adr/0006-decor-tinted-never-rebuilt.md) | Decor is built once per location, then only tinted and moved |

An ADR records a decision that is hard to reverse, surprising without context, and the result of a real trade-off. Number it after the highest one in `adr/`. Keep it to a short title and a paragraph, adding Why and Consequences only when they help. Mark rationale reconstructed after the fact as such. To change a decision, amend its ADR (as 0002 does) or supersede it with a new one.

## Keeping docs current

A change updates the documents that describe what it changes, in the same PR:

- **Behaviour and rules** → the matching file in `gameplay/`.
- **A script's role or API** → that script's header comment, and its line in the root README's file index when a file is added, removed or changes role.
- **The scene tree** → `architecture/overview.md`.
- **Test helpers and runner behaviour** → `tests/README.md`.
- **A gotcha tied to one place in the code** → a comment at that code.
- **A cross-cutting gotcha, a constraint, a code convention or a command** → root `README.md`. Every agent reads it on every task, so it stays an index: CI fails when it passes 16 384 bytes. If it's near the limit, move detail out along this list rather than raising the limit.
- **A new or changed term** → `GLOSSARY.md` (definitions only, no implementation).
- **A new system, dependency, signal or owner of state** → `architecture/overview.md`.
- **A new lifecycle step or invariant** → `architecture/domain-model.md`.
- **A significant architectural choice** → a new ADR, proposed in the PR.

Specs stay in Issues. Link to an issue rather than copying its requirements here.
