# Domain Docs

How the engineering skills consume this repo's domain documentation. Layout: **single-context**. `docs/README.md` says which document owns which kind of knowledge.

## Before exploring, read these

- **`GLOSSARY.md`** at the repo root: the domain terms.
- **`docs/architecture/overview.md`** and **`docs/architecture/domain-model.md`** when the work touches how systems depend on each other, who owns state, a lifecycle or an invariant.
- **`docs/adr/`**: the ADRs that touch the area you're about to work in.

These, the root `README.md` and the code on `main` are the source of truth. An issue written earlier describes intent at the time it was written; where it disagrees with them, follow `docs/agents/workflow.md` → "Stale specs".

## Use the glossary's vocabulary

When your output names a domain concept (an issue title, a spec, a test name), use the term as defined in `GLOSSARY.md`. If the concept you need isn't there yet, either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0003 (run state in scene nodes), but worth reopening because…_
