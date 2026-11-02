# Lunar Lander

A 2D lander game: the ship lifts off a planet's surface, climbs into gravity-free deep space and parks at a space station.

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
Solid side walls of the lower surface. Touching them crashes the ship.
_Avoid_: Side borders, cliffs

**Backdrop**:
The two Tatra-like mountain ridges drawn behind the surface. Scenery only: they have no collision.
_Avoid_: Mountains (the solid side walls), background mountains, skyline

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
The marked spot on the ground where the ship can land. Every location has one, and landing on the one below delivers the contracts.
_Avoid_: Landing zone, base

**Location**:
The place on the planet currently below the station, whose surface the ship flies down to: the Valley or the Mine. It changes when a mission starts, and by itself after the ship has spent two whole days in deep space, to the next one in turn.
_Avoid_: Level, map, destination (that's the location chosen for a mission)

**Valley**:
The location the game started with: flat ground between the mountains, with the pad in the middle and the backdrop behind.
_Avoid_: Mountains (that's the solid side walls), Tatras

**Mine**:
The open-pit mine location: stepped benches cut down into the ground, with the pad on the pit floor. Touching the benches crashes the ship.
_Avoid_: Quarry, pit

**Local time**:
The planet's clock at the current location, shown in the HUD as HH:MM. A whole day lasts twelve real minutes. It runs whenever the office isn't showing, and carries on unchanged when the location changes. It decides how the sky looks, and nothing else.
_Avoid_: Clock (on its own), game time, mission time

**Start period**:
The part of the day a mission starts in, chosen in the office: Morning, Day, Evening or Night, each six hours long. Starting loading sets the local time to a random minute within it.
_Avoid_: Time of day, start time

**Station**:
The structure spanning the top of deep space and forming the world's ceiling. Inside is a maze leading to the parking spot. Touching any of its walls crashes the ship.
_Avoid_: Space station maze, base

**Parking spot**:
The box inside the station where the ship docks.
_Avoid_: Dock, slot, destination

## Office

**Office**:
The player's transport company office on the station, where every run begins. There the player picks a ship type, takes on transport offers and checks the bank account.
_Avoid_: Menu, shop, hangar

**Terminal**:
The retro green-on-black screen in the office that shows ship offers, transport offers and the bank account.
_Avoid_: Monitor, display, console

**Main screen**:
The terminal's home screen, with one tile each for ship selection, transport offers and the bank account. Every visit to the office starts here, and the player leaves the office from here.
_Avoid_: Menu, home, dashboard

**Ship selection**:
The terminal screen for browsing ship offers and choosing a ship type.
_Avoid_: Shop, hangar, fleet screen

**In service**:
The ship type currently in the parking spot: the one the player flies when leaving the office.
_Avoid_: Current ship, active ship

**Bank account**:
The pilot's money, in euros, and the transactions that made it. It starts at €0 every run.
_Avoid_: Wallet, credits, score

**Ship offer**:
One ship type shown on the terminal, with its picture and characteristics. Taking a ship offer costs nothing.
_Avoid_: Offer (on its own), listing, card, product

**Ship swap**:
Entering the office from the parking spot and choosing another ship type in ship selection. The new ship takes the old one's place in the parking spot with a full tank. Not possible while the player has contracts.
_Avoid_: Respawn, change ship

## Transport

**Transport offer**:
A job on the terminal, not yet accepted: carry passengers, cargo or both from the station to the pad. It is only available for a limited time.
_Avoid_: Offer (on its own), job, mission

**Contract**:
A transport offer the player has accepted. All contracts accepted together are delivered in one flight. A contract stays accepted when transport offers expire or the player leaves the office; before loading, the player can remove it for good.
_Avoid_: Order, accepted offer

**Mission**:
Everything from the start of loading until the player next enters the office: loading, the delivery flight, unloading and the way back. A mission has one destination, chosen in the office together with its start period.
_Avoid_: Delivery (that's only the flight from loading to landing), trip, run (that's from restart to crash)

**Destination**:
The location chosen in the office for a mission. Starting loading takes the ship's surface there.
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
Taking the load off on the pad, which starts by itself when the ship lands there with contracts aboard. The ship can refuel meanwhile but can't lift off until it finishes.
_Avoid_: Delivery (the whole flight), disembarking

**Payout**:
What a contract pays into the bank account once unloaded: its reward less a penalty for each whole second overdue, never below €0. Each contract is settled on its own.
_Avoid_: Reward (that's before the penalty), income, score

**Transaction**:
One line in the bank account per delivered contract: its payout, opening to show its reward, penalty, the flight's deadline it was settled against and the delivery time.
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

A ship is always in exactly one of these four states.

**Flying**:
The ship is in free flight, under the player's control. It's the state between leaving the pad or the parking spot and landing, docking or crashing.
_Avoid_: Airborne, in flight, free

**Landed**:
The ship is resting on the pad after a safe touchdown.
_Avoid_: Touched down, parked

**Docked**:
The ship is resting inside the parking spot. This is the deep-space counterpart of Landed. From docking until the player declines to enter the office or leaves it, a Docked ship is held: it ignores the controls and doesn't refuel. During loading it also ignores the controls, but refuels.
_Avoid_: Parked, landed (in deep space)

**Crashed**:
The ship hit something it shouldn't have, or touched down unsafely. A crash is final until restart.
_Avoid_: Destroyed, dead
