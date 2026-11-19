# The Career replaces the run; Recovery happens in place, and only a New career reloads the scene

The game is one continuing **Career**, not a run that a crash ends. A crash makes the ship in service a Wreck and is settled at once (the recovery fee, Failed contracts); R then performs **Recovery** in place: the Wreck goes back Docked at the station and the Office opens, with no scene reload, so the Bank account, Transactions, owned ships, the offer pool, the planet clock and its location all carry on. R never restarts anything. Only starting a **New career** reloads the scene (from the Title screen, a later ticket); until then a fresh page load is the only fresh start. Career state still lives in scene nodes ([ADR 0003](0003-run-state-in-scene-nodes.md) holds).

**Status:** accepted. Decided in [#88](https://github.com/pkopczynski/lunar-lander/issues/88) (and its revision comments), landed by [#109](https://github.com/pkopczynski/lunar-lander/issues/109).

## Why

A crash used to wipe everything the player built, so money and ships had no lasting value. Recovering in place keeps the Career and makes a crash cost real money instead. A scene reload for Recovery would have needed every Career node to survive it (an autoload or a save round-trip), against ADR 0003; resetting only the ship and the view is a few lines.

## Consequences

- The crash flow is spread over the nodes that own each part: the Lander emits `crashed` and, on R, `recovery_requested`; the Hangar makes the ship a Wreck and docks it again (`recover()`); the Economy settles the crash (`settle_crash()`); the Office opens and won't close while the ship in service is a Wreck.
- Nothing resets on a crash beyond the ship's place and the Load, so anything new that should reset after a crash has to do it on `crashed` or Recovery itself.
- Debt is possible: Recovery and Repair may take the balance below €0. Buying stays blocked below €0, and there is no game over.
- Tests start over with `start_over()` (a fresh main scene), never with R.
