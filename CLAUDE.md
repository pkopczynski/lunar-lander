# CLAUDE.md

`README.md` is the main context for this repo: read it first. This file adds only where architecture docs live and how commits and releases work.

## Architecture docs

- `docs/README.md` indexes the docs and says which one owns which kind of knowledge.
- Before changing how systems depend on each other, who owns state, a lifecycle or an invariant, read `docs/architecture/overview.md`, `docs/architecture/domain-model.md` and the ADRs in `docs/adr/`.
- A change that alters what those documents describe updates them in the same PR. A significant architectural decision (hard to reverse, surprising without context, a real trade-off) gets a new ADR proposed in the PR.

## Commits & releases

- Every commit message and PR title is a [conventional commit](https://www.conventionalcommits.org/): `type(scope): summary`, scope optional and free-form. Types: `feat`, `fix`, `perf`, `revert`, `refactor`, `test`, `docs`, `chore`, `ci`, `build`, `style`. The `PR title` check (job `conventional-commit`) must pass before a merge.
- `main` is protected by the "Protect main" ruleset: no direct or force pushes, every change through a squash-merged PR with 1 approval (the repo admin may merge without one, through a PR only), resolved review threads, and the `test` and `conventional-commit` checks passing. `CONTRIBUTING.md` explains it to new contributors.
- PRs are squash-merged, so the **PR title** becomes the one commit on `main` and the one changelog line. Write it for a player: what changed in the game, not how the code changed.
- `CHANGELOG.md` is player-facing: only `feat`, `fix` and `perf` appear in it and trigger a release. Pick the type by what the player notices: an internal cleanup is `refactor`, even if it touched gameplay code.
- Versions are SemVer, still in `0.x`: `feat` bumps the minor, `fix`/`perf` the patch, and a breaking change (`feat!:`, e.g. controls or save data changed) also only bumps the minor. Going to 1.0 is deliberate: a `Release-As: 1.0.0` footer in the merged commit.
- Releases are cut by release-please (`.github/workflows/release-please.yml`): every push to `main` updates a standing `chore: release x.y.z` PR that bumps `CHANGELOG.md`, `.release-please-manifest.json` and `GameVersion.VERSION` in `version.gd`. Merging it tags `vx.y.z` and publishes the GitHub Release. These three files belong to release-please; edit release notes in the release PR, never the version by hand.

## Agent skills

### Issue tracker

GitHub Issues are the one backlog: maps, decision tickets, specs and implementation tickets, linked with native sub-issues and dependencies. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default roles (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`), on implementation tickets only. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context. See `docs/agents/domain.md`.

### Workflow

Starting work from an issue, stale specs, and what a PR must update: `docs/agents/workflow.md`.
