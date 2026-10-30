# CLAUDE.md

`README.md` is the main context for this repo: read it first. This file adds only how commits and releases work.

## Commits & releases

- Every commit message and PR title is a [conventional commit](https://www.conventionalcommits.org/): `type(scope): summary`, scope optional and free-form. Types: `feat`, `fix`, `perf`, `revert`, `refactor`, `test`, `docs`, `chore`, `ci`, `build`, `style`. The `PR title` check flags a bad PR title but can't block the merge (rulesets need GitHub Pro on a private repo), so check the title before merging.
- PRs are squash-merged, so the **PR title** becomes the one commit on `main` and the one changelog line. Write it for a player: what changed in the game, not how the code changed.
- `CHANGELOG.md` is player-facing: only `feat`, `fix` and `perf` appear in it and trigger a release. Pick the type by what the player notices: an internal cleanup is `refactor`, even if it touched gameplay code.
- Versions are SemVer, still in `0.x`: `feat` bumps the minor, `fix`/`perf` the patch, and a breaking change (`feat!:`, e.g. controls or save data changed) also only bumps the minor. Going to 1.0 is deliberate: a `Release-As: 1.0.0` footer in the merged commit.
- Releases are cut by release-please (`.github/workflows/release-please.yml`): every push to `main` updates a standing `chore: release x.y.z` PR that bumps `CHANGELOG.md`, `.release-please-manifest.json` and `GameVersion.VERSION` in `version.gd`. Merging it tags `vx.y.z` and publishes the GitHub Release. These three files belong to release-please; edit release notes in the release PR, never the version by hand.
