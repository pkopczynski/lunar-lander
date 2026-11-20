# Lunar Lander

A 2D lander game: the ship lifts off a planet's surface, climbs into gravity-free deep space and parks at a space station.

## Career

**Career**:
The one continuing game: the bank account and its transactions, the owned ships, the transport offers and contracts, and the planet clock. A crash doesn't end it; only a fresh start begins a new one.
_Avoid_: Run, save, game

**Recovery**:
Bringing the ship back to the station after a crash or when Stranded, for a recovery fee of 5% of its ship type's price: R after a crash or while Stranded. It happens in place: the ship (a wreck after a crash, keeping its condition when Stranded) is Docked at the station, still in service, and the office opens; the clock, location and transport offers carry on.
_Avoid_: Respawn, retry, restart, towing

## World

**Surface**:
The bottom area of the world, where gravity pulls the ship down. It holds the ground, the pad and the mountains.
_Avoid_: Bottom space, atmosphere, planet area

**Deep space**:
The top area of the world, with no gravity. It holds the station.
_Avoid_: Top space, space, orbit

**Border**:
The horizontal line between the surface and deep space.
_Avoid_: Boundary, edge, atmosphere line

**Mountains**:
Solid side walls of the lower surface, the same shape at every location but dressed in each location's own look. Touching them damages the ship by its impact speed.
_Avoid_: Side borders, cliffs

**Backdrop**:
The scenery drawn behind a location's surface, with no collision, each location its own: distant ranges, Tatra-like peaks and forested hills behind the Valley, Himalaya-like peaks behind the Mine, a far skyline behind the Metropolis.
_Avoid_: Mountains (the solid side walls), background mountains

**Foreground**:
Scenery drawn in front of the ship, with no collision. It may hide the ship, or the pad, for a moment as the view moves.
_Avoid_: Overlay, front layer

**Moons**:
The other bodies in the planet's sky, seen from the surface: the same few at every location, each location showing them in its own place in the sky. Faint by day, clear at night. They stay in their spot in the sky as the ship flies around, sinking out of view as it climbs, long before the Border, so deep space never shows them.
_Avoid_: Planets (the planet is the one the ship lands on), sky bodies

**Approach corridor**:
The column above the pad, a little wider than the pad on each side, which the Foreground never covers at any height, so the way down to the pad always stays in sight. Outside it the Foreground may hide the ship.
_Avoid_: Landing zone, safe zone

**Vehicles**:
The Metropolis's distant flying craft, in lanes at several heights and depths of its sky, each leaving a fading trail of light. Only scenery: the ship flies through them.
_Avoid_: Aircraft, traffic (on its own), trails (a trail is part of a vehicle)

**Border band**:
The strip around the border where gravity fades out. A ship too slow to cross is bounced back to the side it came from.

**Disturbance**:
The brief jolt of crossing the border: for a moment the controls don't respond while the nose wobbles, and the ship ends up turned a little, nose and path together. Slower crossings are disturbed more.
_Avoid_: Turbulence, glitch, shake (that's the camera)
_Avoid_: Transition zone, atmosphere

**Soft wall**:
A world edge that steers the ship back inside instead of crashing it.
_Avoid_: Bumper, invisible wall

**Steering**:
The world briefly slowing the ship down: it damps the ship's speed and pushes it back, but never turns its nose, so the player keeps Left/Right control. (Crossing the border also brings a disturbance, which does turn it.) This happens at soft walls and just after crossing the border.
_Avoid_: Autopilot, assist

**Zoom punch**:
The brief, dramatic camera zoom-in when the ship crosses the border, easing back out afterwards.
_Avoid_: Zoom pulse, dolly

**Pad**:
The marked spot where the ship can land: on the ground, or on a rooftop in the Metropolis. Every location has one, and landing on the destination's pad delivers the contracts.
_Avoid_: Landing zone, base

**Beacon**:
The pulsing lights on a pad's edges that show where it is. Never dimmed by the sky's darkness; their glow is faint by day and strongest at night. Scenery only: they have no collision.
_Avoid_: Landing lights, marker

**Location**:
The place on the planet currently below the station, whose surface the ship flies down to: the Valley, the Mine or the Metropolis. It changes when a mission starts, and by itself after the ship has spent two whole days in deep space, to the next one in turn.
_Avoid_: Level, map, destination (that's where a contract is to be delivered)

**Valley**:
The location the game started with: flat ground between the mountains, with the pad in the middle and the backdrop behind.
_Avoid_: Mountains (that's the solid side walls), Tatras

**Mine**:
The open-pit mine location: stepped benches cut down into the ground, with the pad on the pit floor, and one solid crane whose arm reaches over the left benches. The benches and the crane are solid: touching them damages the ship by its impact speed; the cranes in its Backdrop are only scenery.
_Avoid_: Quarry, pit

**Metropolis**:
The futuristic city location: buildings of several heights, with the pad on a rooftop, the only place the ship can land there. A solid building, the street, the antenna and the pad's roof beside the pad are solid but not landed on: touching them damages the ship by its impact speed. It comes after the Mine in drift order.
_Avoid_: City (on its own), downtown

**Location profile**:
What a location's transport offers are like: its share of the pool, how often they carry passengers, cargo or both, how many passengers and how much cargo, their titles, and how well they pay compared with the Valley.
_Avoid_: Offer table, difficulty

**Local time**:
The planet's clock at the current location, shown in the HUD as HH:MM. A whole day lasts twelve real minutes. It runs whenever the office isn't showing, and carries on unchanged when the location changes. It decides how the sky looks, and nothing else.
_Avoid_: Clock (on its own), game time, mission time

**Start period**:
The part of the day a mission starts in, chosen in the office: Morning, Day, Evening or Night, each six hours long. Starting loading sets the local time to a random minute within it.
_Avoid_: Time of day, start time

**Station**:
The structure spanning the top of deep space and forming the world's ceiling. Inside is a maze leading to the parking spot. Touching any of its walls damages the ship by its impact speed.
_Avoid_: Space station maze, base

**Parking spot**:
The box inside the station where the ship docks.
_Avoid_: Dock, slot, destination

## Office

**Office**:
The player's transport company office on the station, where every career begins and where recovery after a crash brings the player back. There the player buys ships in the shipyard, chooses the ship in service in the hangar, takes on transport offers and checks the bank account.
_Avoid_: Menu, shop

**Terminal**:
The retro green-on-black screen in the office that shows the shipyard, the hangar, transport offers and the bank account, with the balance always in its header.
_Avoid_: Monitor, display, console

**Main screen**:
The terminal's home screen, with four tiles: shipyard, hangar, transport offers and bank account. Every visit to the office starts here, and the player leaves the office from here.
_Avoid_: Menu, home, dashboard

**Shipyard**:
The terminal screen where ship offers are bought. A bought ship goes into a free berth of the hangar with a full tank, not into service.
_Avoid_: Shop, ship selection

**Ship page**:
The hangar's screen for one owned ship, with its status, its fitted upgrades and its actions (put in service, sell).
_Avoid_: Ship details, garage

**Ship selection**:
Retired: replaced by the shipyard (buying) and the hangar (choosing the ship in service).

**In service**:
The owned ship (not the ship type) currently in the parking spot: the one the player flies when leaving the office. It can't be sold.
_Avoid_: Current ship, active ship

**Bank account**:
The pilot's money, in euros, and the transactions that made it. It starts at €20 000 with every career. Recovery and repair may take it below €0 (debt); buying never does.
_Avoid_: Wallet, credits, score

**Ship offer**:
One ship type on sale in the shipyard, with its picture, characteristics and price (a full tank included).
_Avoid_: Offer (on its own), listing, card, product

**Ship swap**:
Putting another owned ship in service from its ship page: free and instant, and each ship keeps its own fuel. The ship swapped out stays in its berth. Not possible while the player has contracts.
_Avoid_: Respawn, change ship

## Transport

**Transport offer**:
A job on the terminal, not yet accepted: carry passengers, cargo or both from the station to its destination's pad. It is only available for a limited time.
_Avoid_: Offer (on its own), job, mission

**Contract**:
A transport offer the player has accepted. All contracts accepted together share one destination and are delivered in one flight. A contract stays accepted when transport offers expire or the player leaves the office; before loading, the player can remove it, and it goes back to the transport offers.
_Avoid_: Order, accepted offer

**Cancellation**:
Giving up all of a mission's contracts at once, back in the office after loading, for a cancellation fee instead of a payout: 25% of each contract's reward, taken from the bank account. The load comes off at once, the mission ends, and the contracts are gone for good (they don't go back to the transport offers).
_Avoid_: Removing (that's dropping one contract before loading), abort, refund

**Failed contract**:
A contract aboard a ship that crashed or was stranded, settled for a failure fee instead of a payout: 50% of its reward, taken from the bank account, one transaction each, marked failed. A free flight charges none.
_Avoid_: Lost contract, cancellation (that's on purpose, in the office)

**Mission**:
Everything from the start of loading until the player next enters the office: loading, the delivery flight, unloading and the way back. A mission has one destination and a start period chosen in the office.
_Avoid_: Delivery (that's only the flight from loading to landing), trip, run (retired: the whole game is the career)

**Free flight**:
A mission with no contracts: the player picks its destination and start period in the office and flies wherever they like, with nothing to deliver.
_Avoid_: Practice, sandbox, empty mission

**Destination**:
Where a mission goes: the location its contracts are to be delivered to, fixed when each transport offer appears, or, on a free flight, the location the player chose. Starting the mission takes the ship's surface there.
_Avoid_: Target, location (that's wherever the surface is right now)

**Deadline**:
How long the player has to deliver a contract, counted from when loading finishes.
_Avoid_: Time limit, expiry (that's how long a transport offer stays available)

**Overdue**:
A delivery still under way after its deadline has passed.
_Avoid_: Late (on its own), expired

**Loading**:
Putting the load aboard at the parking spot, after the player accepts their contracts. The ship stays docked and held until it finishes, refuelling meanwhile, and the deadline starts counting then.
_Avoid_: Boarding, embarking

**Unloading**:
Taking the load off on the destination's pad, which starts by itself when the ship lands there with contracts aboard. Landing on any other location's pad unloads too, but the contracts pay nothing. The ship can refuel meanwhile but can't lift off until it finishes.
_Avoid_: Delivery (the whole flight), disembarking

**Payout**:
What a contract pays into the bank account once unloaded: its reward less a penalty for each whole second overdue, never below €0, and nothing at all when unloaded away from its destination. Each contract is settled on its own.
_Avoid_: Reward (that's before the penalty), income, score

**Transaction**:
One line in the bank account for anything that changed the balance: a ship purchase or sale (naming the owned ship, opening to show its price, or its value, the selling share and the repair cost), a recovery fee (naming the owned ship, opening to show its ship type's price and the fee's share), a repair (naming the owned ship, opening to show the condition restored, the repair rate and the value), or a delivered, cancelled or failed contract: its payout (negative for a cancellation fee), opening to show its reward, penalty (or, when unloaded away from its destination, the wrong destination taking the whole reward), the flight's deadline it was settled against and the landing, both as local times, and the location it was delivered to (and its destination, when they differ). A cancelled contract's shows its reward, the cancellation fee and that it was cancelled instead; a failed contract's its reward, the failure fee and that it failed.
_Avoid_: Receipt, entry, log

**Load**:
Everything carried for the contracts: passengers and cargo together.
_Avoid_: Cargo (for the whole load), payload, freight

**Cargo**:
Goods carried for a contract, measured only by mass.
_Avoid_: Load (for goods alone), freight

## Ship

**Ship type**:
A kind of ship with its own shape, dry mass, maximum weight, tank, passenger seats, maximum capacity, thrust and turn rate. The game has three: the Sparrow, the Mule and the Halo.
_Avoid_: Model, class, variant

**Owned ship**:
A ship the player owns: its ship type, its name (the type and a number counting up per type, never reused, even after a sale: SPARROW 1, MULE 2), its fuel in tank and its condition. It flies with its ship type's numbers. Its value is its ship type's price.
_Avoid_: Fleet ship

**Hangar**:
Where the player's owned ships are kept at the station, seen only on the terminal as a table of berths. Only the ship in service shows in the parking spot.
_Avoid_: Fleet, garage

**Berth**:
One place for an owned ship in the hangar, which has four; the ship in service takes one too. Buying needs a free berth.
_Avoid_: Slot

**Wreck**:
An owned ship that crashed: condition 0%. It is recovered to the station, can't fly or be put in service until repaired, and keeps everything else. While the ship in service is a wreck, the player can't leave the office.
_Avoid_: Destroyed ship, dead ship

**Condition**:
How undamaged an owned ship is, from 100% (new) to 0% (a wreck). Hits and hard landings wear it down; it has no effect on flight and never harms cargo.
_Avoid_: Health, HP, hull

**Impact speed**:
The ship's speed into a surface it touches, which sets the damage: none below 15 px/s, then rising in a straight line up to 50% of condition just under the crash speed.

**Crash speed**:
The impact speed above which touching a solid is a crash: 120 px/s.

**Hard landing**:
A touchdown on the pad past a safe landing limit but inside every crash limit (falling 50 → 80 px/s, sideways 25 → 40 px/s, tilt 15° → 25°). The ship lands and delivers, but loses up to 25% of its condition, by the worst of the three bands.
_Avoid_: Rough landing, bad landing

**Repair**:
Restoring an owned ship's condition, from its ship page: instant and always back to 100%, for the missing condition × its ship type's repair rate × its value. Allowed with contracts and in debt.
_Avoid_: Fix, service

**Repair rate**:
The share of an owned ship's value that a whole 100% of condition costs to repair: Sparrow 25%, Mule 15%, Halo 30%.
_Avoid_: Repair cost (that's the euros for one repair)

**Selling a ship**:
Giving up an owned ship that isn't in service for half its value less its repair cost, never below €0. The fuel in its tank earns nothing. Allowed in debt.
_Avoid_: Scrapping, trading in

**Sparrow**:
The small, light, quick triangle ship. It's the ship type the game started with.
_Avoid_: Triangle, default ship

**Mule**:
The long, heavy, slow boxy cargo ship with a rounded nose, with the engine on a short side.
_Avoid_: Cargo ship, rectangle

**Halo**:
The ring-shaped ship. It's open at the front and has its engine at the back, and sits between the other two on every characteristic.
_Avoid_: Doughnut, ring

**Dry mass**:
The ship's mass without fuel.
_Avoid_: Empty weight, base mass

**Maximum weight**:
The heaviest a ship type may be in total: dry mass, fuel and load together. Load comes first, so a heavy load leaves less room for fuel.
_Avoid_: Max load, payload

**Tank**:
How much fuel a ship type holds when full.
_Avoid_: Capacity (on its own), fuel max

**Maximum capacity**:
The most cargo a ship type can take at all. A transport offer that would go past it is overloaded and can't be accepted.
_Avoid_: Cargo capacity (on its own), max load

**Full-Tank cargo**:
The most cargo a ship can carry and still have room for a full tank under its maximum weight, given the passengers aboard. It shrinks with each passenger and is never above the maximum capacity. Cargo past it is allowed, but limits the fuel.
_Avoid_: Cargo limit, comfortable load, safe cargo

## Ship states

A ship is always in exactly one of these five states.

**Flying**:
The ship is in free flight, under the player's control. It's the state between leaving the pad or the parking spot and landing, docking or crashing, and it includes resting on a solid off the pad, from where the ship can take off again.
_Avoid_: Airborne, in flight, free

**Landed**:
The ship is resting on the pad after a touchdown that went past no landing band: a safe one, or a hard landing.
_Avoid_: Touched down, parked

**Docked**:
The ship is resting inside the parking spot. This is the deep-space counterpart of Landed. From the moment the office popup shows (once the ship has finished easing upright after docking) until the player declines to enter the office or leaves it, a Docked ship is held: it ignores the controls and doesn't refuel. During loading it also ignores the controls, but refuels.
_Avoid_: Parked, landed (in deep space)

**Crashed**:
The ship hit a solid above the crash speed, took a hit or a hard landing that left its condition at 0%, touched down on the pad past a landing band, or rested tipped over (past 90° for 2 s). Simply touching a solid is no longer a crash. The ship in service becomes a wreck, the crash is settled at once (the recovery fee, and failed contracts for any contracts aboard), and the ship stays Crashed until the player presses R for recovery.
_Avoid_: Destroyed, dead

**Stranded**:
Resting on a solid off the pad with an empty tank, which ends only by recovery. The stop is settled at once like a crash (the recovery fee, and failed contracts for any contracts aboard), but the ship keeps its condition and isn't a wreck.
_Avoid_: Stuck, out of gas
