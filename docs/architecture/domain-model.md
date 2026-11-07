# Domain model

How the game's concepts relate, how they change over time, and which rules always hold. Each term's definition lives in [`GLOSSARY.md`](../../GLOSSARY.md) and isn't repeated here; the numbers live in the README's Gameplay rules and the scripts' constants.

## Relationships

```
Run (restart → restart)
├── Bank account ──< Transaction          one per settled Contract, newest first
├── Transport offer pool ──< Transport offer
│                               │ accept            ▲ remove (before loading)
│                               ▼                   │
├── Contracts ──────────────< Contract ─────────────┘
│       all share one Destination
├── Ship type in service ──► Ship (Lander): one Ship state, fuel, Load
└── Planet clock: Local time + current Location + drift count

Mission = Destination + Start period + 0..n Contracts (0 = Free flight)
Location table: Valley → Mine → Metropolis (also the drift order)
  each Location: pad, ground, terrain, Mountains' look, decor, Location profile
```

- **Transport offer and Contract are the same object** (`TransportOffer`); accepting moves it from `Economy.offers` to `Economy.contracts`. Settling it makes a `TransportOffer.Transaction`.
- **Current location and Destination are different things.** The current location is the clock's (`PlanetClock.location`); the destination is the Contracts' (`Economy.destination()`) or, on a free flight, the Office's choice. Drift can separate them mid-delivery.
- **A Mission has no single object in code.** It's the Office's `start_mission()` (destination and start period applied to the clock), the Economy's phase, and the Lander's Load together.

## Where each concept lives

| Concept | Code |
|---|---|
| Ship type, Sparrow / Mule / Halo | `ShipType`, `ShipType.ALL` |
| Ship states | `Lander.State`, changed by `Lander.enter()` |
| Location, Valley / Mine / Metropolis, Location profile | `Location`, `Location.ALL`, `Location.Profile` |
| Local time, Start period, drift | `PlanetClock.minutes`, `PlanetClock.StartPeriod`, `PlanetClock.drift` |
| Transport offer, Contract, Transaction | `TransportOffer`, `TransportOffer.Transaction` |
| Bank account, offer pool, Contracts, delivery phase | `Economy` |
| Load | `Lander.load_mass` (once loading finishes); `Economy.contract_load_mass()` before that |
| Sky look | `SkyLook` |

## Lifecycles

### Mission and delivery phase

`Economy.Phase`; each transition is one function that returns early unless it's in the phase it leaves.

```
NONE ──start_loading()──► LOADING ──finish_loading()──► DELIVERING ──start_unloading()──► UNLOADING
 ▲                                                         │                                   │
 └───────────────── cancel_mission() (at the station) ─────┘                                   │
 └────────────────────────────────────── finish_unloading() ───────────────────────────────────┘
```

- A free flight never leaves NONE: the Office releases the ship and nothing is loaded.
- Contracts can be accepted and removed only in NONE. Nothing can be accepted while DELIVERING (`MISSION UNDER WAY`).
- `start_unloading()` fires on the first landing on any current pad while DELIVERING; later landings are ignored.

### Transport offer

Generated (destination drawn first by pool share, the rest from that destination's Location profile) → listed with a time left → **expires**, or is **accepted** as a Contract (its time stops) → **removed** before loading (back to the pool in number order, same number, same time left) or **settled** at unloading or cancellation (gone for good, one Transaction).

### Ship states

Exactly one of Flying, Landed, Docked, Crashed, changed only by `Lander.enter()`, which starts each state fresh. Three flags sit beside the state and are set from outside:

| Flag | Set by | Effect |
|---|---|---|
| `held` | Office (`hold()` / `release()`) | Frozen: no input, no refuel timer. Cleared by `enter()`. |
| `loading` | Economy via `start_loading()` / `finish_loading()` | Docked ship can't turn or undock, refuels to the fuel cap. |
| `lift_off_blocked` | Economy (unloading) | Landed ship can't lift off. Not cleared by `enter()`, so a ship settling back stays grounded. |

Crashed is final until restart.

## Invariants

Each rule below holds in the code today; the parenthesis says where it's enforced.

- **One destination per mission.** All Contracts share it; an offer for another destination is a misfit (`TransportOffer.misfit_reason()`, rechecked in `Economy.accept()`).
- **Capacity counts the Contracts.** Seats and maximum capacity are checked against what's left after accepted Contracts; fuel never blocks an offer (`Economy.misfit_reason()`).
- **No ship swap while there are Contracts** (`Office.ship_locked_shown()`).
- **Mass:** total = dry mass + fuel + Load, and fuel ≤ fuel cap = min(Tank, Maximum weight − dry mass − Load) (`Lander.total_mass()`, `fuel_cap_for()`). The Load joins the mass only when loading finishes.
- **The current location changes only through `PlanetClock.move_to()`**, and a location change never changes the local time. Only starting a mission re-rolls the time ([ADR 0002](../adr/0002-one-planet-clock.md)).
- **Drift never swaps a visible surface** (`PlanetClock.count_drift()` waits for `World.surface_in_view()` to be false).
- **Time is presentation only.** It sets the sky and how deadlines are shown; deadlines and penalties count real seconds from the end of loading (`Economy.delivery_time`).
- **Settlement:** a delivered Contract pays its reward less the overdue penalty, never below €0, and €0 away from its destination; a cancelled one pays minus its cancellation fee. Each is settled on its own, one Transaction each (`TransportOffer.settlement()`, `cancellation()`).
- **Only the ground is landed on.** Any other contact (Mountains, terrain, station) is a crash; the pad and all decor have no collider ([ADR 0005](../adr/0005-solid-terrain-vs-decor.md)).
- **Every run starts the same:** the Office, the Sparrow Docked, €0, a fresh offer pool from `#001`, the Valley at an Evening minute ([ADR 0003](../adr/0003-run-state-in-scene-nodes.md)).
