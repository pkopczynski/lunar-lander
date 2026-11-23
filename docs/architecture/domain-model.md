# Domain model

How the game's concepts relate, how they change over time, and which rules always hold. Each term's definition lives in [`GLOSSARY.md`](../../GLOSSARY.md) and isn't repeated here; the rules live in [`docs/gameplay/`](../gameplay/) and the numbers in the scripts' constants.

## Relationships

```
Career (a fresh start → on, through crashes and Recovery)
├── Bank account ──< Transaction          one per change of the balance, newest first
├── Transport offer pool ──< Transport offer
│                               │ accept            ▲ remove (before loading)
│                               ▼                   │
├── Contracts ──────────────< Contract ─────────────┘
│       all share one Destination
├── Hangar ──< Owned ship ──► Ship type        name counted per type, never reused
│     └── in service ──► Ship (Lander): one Ship state, Load; flies the
│                        owned ship's effective numbers and its fuel in tank
└── Planet clock: Local time + current Location + drift count

Mission = Destination + Start period + 0..n Contracts (0 = Free flight)
Location table: Valley → Mine → Metropolis (also the drift order)
  each Location: pad, ground, terrain, Mountains' look, decor, Location profile
```

- **Transport offer and Contract are the same object** (`TransportOffer`); accepting moves it from `Economy.offers` to `Economy.contracts`. Settling it makes a `Transaction`, which is also what a ship purchase or sale makes.
- **Current location and Destination are different things.** The current location is the clock's (`PlanetClock.location`); the destination is the Contracts' (`Economy.destination()`) or, on a free flight, the Office's choice. Drift can separate them mid-delivery.
- **The ship in service is an Owned ship, not a Ship type.** The Lander flies it; its numbers are the owned ship's effective numbers (for now its Ship type's). Owned ships live in the Hangar's berths (four); the Shipyard adds one (full tank, not in service), selling takes one away, and a Ship swap puts another owned ship in service, each keeping its own fuel. Only the ship in service is in the world (the parking spot); the others exist only as Hangar state.
- **A crash doesn't end the Career.** It makes the ship in service a Wreck (Condition 0%) and is settled at once; R is Recovery, in place, with no scene reload ([ADR 0008](../adr/0008-career-replaces-the-run.md)).
- **A Mission has no single object in code.** It's the Office's `start_mission()` (destination and start period applied to the clock), the Economy's phase, and the Lander's Load together.

## Where each concept lives

| Concept | Code |
|---|---|
| Ship type, Sparrow / Mule / Halo | `ShipType`, `ShipType.ALL` |
| Owned ship, Hangar, in service | `OwnedShip`, `Hangar.ships`, `Hangar.in_service` |
| Ship states | `Lander.State`, changed by `Lander.enter()` |
| Location, Valley / Mine / Metropolis, Location profile | `Location`, `Location.ALL`, `Location.Profile` |
| Local time, Start period, drift | `PlanetClock.minutes`, `PlanetClock.StartPeriod`, `PlanetClock.drift` |
| Transport offer, Contract | `TransportOffer` |
| Transaction | `Transaction` (a settled, cancelled or Failed contract, a ship purchase or sale, a recovery fee, a repair) |
| Ship price, value, sale price | `ShipType.price`, `OwnedShip.value()`, `OwnedShip.sale_price()` |
| Wreck, recovery fee, repair cost | `OwnedShip.is_wreck()`, `recovery_fee()`, `repair_cost(place)` |
| Workshop, place markup | `Office` with its `place` (a pad's `Location`) and `TerminalPalette.WORKSHOP`; `Location.markup` |
| Crash settlement, Recovery, Repair | `Economy.settle_crash()`, `Hangar.wreck()` / `recover()` / `repair()`, `Office.recover()` |
| Bank account, offer pool, Contracts, delivery phase | `Economy` |
| Load | `Lander.load_mass` (once loading finishes); `Economy.contract_load_mass()` before that |
| Sky look | `SkyLook` |

## Lifecycles

### Mission and delivery phase

`Economy.Phase`; each transition is one function that returns early unless it's in the phase it leaves.

```
NONE ──start_loading()──► LOADING ──finish_loading()──► DELIVERING ──start_unloading()──► UNLOADING
 ▲                                                         │                                   │
 ├───────────────── cancel_mission() (at the station) ─────┤                                   │
 └───────────────── settle_crash() (a crash) ──────────────┘                                   │
 └────────────────────────────────────── finish_unloading() ───────────────────────────────────┘
```

- A free flight never leaves NONE: the Office releases the ship and nothing is loaded.
- Contracts can be accepted and removed only in NONE. Nothing can be accepted while DELIVERING (`MISSION UNDER WAY`).
- `start_unloading()` fires on the first landing on any current pad while DELIVERING; later landings are ignored.

### Transport offer

Generated (destination drawn first by pool share, the rest from that destination's Location profile) → listed with a time left → **expires**, or is **accepted** as a Contract (its time stops) → **removed** before loading (back to the pool in number order, same number, same time left) or **settled** at unloading, cancellation or a crash while it's aboard (gone for good, one Transaction).

### Owned ship

Bought (full tank, 100%) → in service or in a berth → **damaged** by hits and Hard landings while in service (each takes some Condition; the Lander wears it, as it burns the fuel) → **wrecked** by a crash while in service (0%, still in service) → **repaired** (always back to 100%) → … → **sold** (never while in service). A Wreck can't be put in service, and the Office can't be left while the ship in service is one.

### Ship states

Exactly one of Flying, Landed, Docked, Crashed, Stranded, changed only by `Lander.enter()`, which starts each state fresh. Four flags sit beside the state and are set from outside:

| Flag | Set by | Effect |
|---|---|---|
| `held` | Office (`hold()` / `release()`) | Frozen: no input. Set while "ENTER THE OFFICE?" or "ENTER THE WORKSHOP?" asks, while a pad's Workshop shows, and in the Office or a Workshop entered with O (`Office.can_open_by_key()`: Docked and free, or Landed and free). Cleared by `enter()`. |
| `loading` | Economy via `start_loading()` / `finish_loading()` | Docked ship can't turn or undock. Adds no fuel. |
| `pump_time_left` | Hangar's pump (`refuel()`, ticked even behind the Office) | While above 0 the ship can't undock or lift off; the message shows `Pumping fuel… 6s`. Not cleared by `enter()`. |
| `lift_off_blocked` | Economy (unloading) | Landed ship can't lift off. Not cleared by `enter()`, so a ship settling back stays grounded. |

A ship touching the pad's ground stays Flying while it settles: the landing bands are judged when it comes onto the pad (from the air or sliding), and it enters Landed once at rest there inside the bands' tilt (`Lander.rest_on_ground()`), carrying a Hard landing's loss into the Landed title. A ship resting on a solid off the pad stays Flying and can take off again; resting tipped over (90° or more for 2 s) anywhere enters Crashed. Resting there with an empty tank (and not tipped over) enters Stranded. Crashed and Stranded last until R: Recovery puts the ship (a Wreck after a crash) Docked at the station (`Lander.start_docked()`), which starts Docked fresh.

## Invariants

Each rule below holds in the code today; the parenthesis says where it's enforced.

- **One destination per mission.** All Contracts share it; an offer for another destination is a misfit (`TransportOffer.misfit_reason()`, rechecked in `Economy.accept()`).
- **Capacity counts the Contracts.** Seats and maximum capacity are checked against what's left after accepted Contracts; fuel never blocks an offer (`Economy.misfit_reason()`).
- **No ship swap while there are Contracts** (`HangarScreen.action_reason()`). Buying is allowed with Contracts: it doesn't change the ship in service.
- **The floor: the ship in service can't be sold**, so the player always owns at least one ship, and it can always be repaired on credit (`HangarScreen.action_reason()`, asserted in `Hangar.sell()`). There is no game over.
- **Debt only through Recovery, Repair and fuel (except Tester adjustments):** they may take the balance below €0 (`Economy.settle_crash()`, `pay_for_repair()`, `pay_for_fuel()`). Buying a ship needs the balance to stay ≥ €0 after paying, and a free berth (`ShipyardScreen.reason()`, `Economy.shortfall()`, `Hangar.full()`). Selling is allowed in debt.
- **No flight in a Wreck:** a Wreck can't be put in service, and the Office can't be left (Escape, START, START LOADING) while the ship in service is one (`HangarScreen.action_reason()`, `Office.leave_reason()`).
- **Every change of the balance is one Transaction** (`Economy.record()`; Tester adjustments too, `Economy.make_tester_adjustment()`), and names are never reused: each Ship type counts its owned ships' numbers up, past sold ones (`Hangar.last_numbers`).
- **Mass:** total = dry mass + fuel + Load, and fuel ≤ fuel cap = min(Tank, Maximum weight − dry mass − Load) (`Lander.total_mass()`, `OwnedShip.fuel_cap()`). Fuel is kept in kg and shown in litres at 0.8 kg/l (`OwnedShip.KG_PER_LITRE`), so the cap in litres is the same rule. Buying never goes past the cap (`FuelScreen.highest()`, counting fuel still being pumped); START LOADING sells back and pumps out the fuel above the cap for the Load (`Economy.start_loading()`), so it can sit above the new cap only until pumping ends, with the ship held docked meanwhile. The Load joins the mass only when loading finishes.
- **Fuel is never free (except Tester mode's Auto-refuel, `Hangar.top_up()`):** only the Hangar adds fuel, paid first, one Transaction per purchase or sell-back (`FuelScreen.confirm()`, `Economy.pay_for_fuel()`, `Hangar.refuel()`), bought at the station or in a pad's Workshop for the Landed ship. Docking, landing, loading, Recovery and a Ship swap add none. Only the station buys fuel back (`FuelScreen.lowest()` is 0 in a Workshop).
- **Prices are base × Ship type × place:** fuel per litre is `FUEL_PRICE_CENTS` × the place markup × the type's fuel multiplier, rounded to the cent; a repair is missing Condition × repair rate × value × the place markup (`OwnedShip.fuel_price(place)`, `repair_cost(place)`). The place is a pad's `Location` (`Location.markup`: Valley 1.5, Metropolis 1.75, Mine 2) or null for the station (1). Transactions record the place and its markup.
- **A ship Landed on a pad is never Stranded,** even with an empty tank: Stranded needs resting off the pad (`Lander.rest_on_ground()`), and the pad's Workshop sells it fuel.
- **The current location changes only through `PlanetClock.move_to()`**, and a location change never changes the local time. Only starting a mission re-rolls the time ([ADR 0002](../adr/0002-one-planet-clock.md)).
- **Drift never swaps a visible surface** (`PlanetClock.count_drift()` waits for `World.surface_in_view()` to be false).
- **Time is presentation only.** It sets the sky and how deadlines are shown; deadlines and penalties count real seconds from the end of loading (`Economy.delivery_time`).
- **Settlement:** a delivered Contract pays its reward less the overdue penalty, never below €0, and €0 away from its destination; a cancelled one pays minus its cancellation fee (25%); a Failed contract (aboard in a crash or when Stranded) pays minus its failure fee (50%). Each is settled on its own, one Transaction each (`TransportOffer.settlement()`, `cancellation()`, `failure()`). A crash or Stranded also charges the recovery fee (5% of the Ship type's price), one Transaction; a free flight's costs only that (`Economy.settle_crash()`, on `crashed` and `stranded`).
- **Only the pad is landed on.** Coming down onto the ground on the pad is judged by the landing bands: safe, a Hard landing (losing up to 25% Condition by the worst touchdown; to 0% is a crash) or crashed (`Lander.touch_down()`); the ship lands once it settles. Any other contact (the ground off the pad, Mountains, terrain, station) damages the ship by the impact speed of its hardest-hitting point and bounces it as a rigid body, and is a crash only above the crash speed or when it takes Condition to 0% (`Lander.touch()`); the ship stays Flying. The pad and all decor have no collider ([ADR 0005](../adr/0005-solid-terrain-vs-decor.md), [ADR 0009](../adr/0009-contact-damages-and-bounces.md)).
- **Condition changes only by a hit, a Hard landing, a crash (0%) or a repair (100%)** (`Lander.touch()`, `Lander.touch_down()`, `Hangar.wreck()`, `Hangar.repair()`). Stranded keeps it. Tester mode's Auto-repair is a free repair after each loss, and its Immune (`Lander.immune`) stops every loss and crash.
- **Every Career starts the same:** the Office, SPARROW 1 in service and Docked, €20 000 in the Bank account, a fresh offer pool from `#001`, the Valley at an Evening minute ([ADR 0003](../adr/0003-run-state-in-scene-nodes.md)). Only a fresh start (a scene reload) begins one; a crash and Recovery never do ([ADR 0008](../adr/0008-career-replaces-the-run.md)).
