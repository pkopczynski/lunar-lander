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
_Avoid_: Transition zone, atmosphere

**Soft wall**:
A world edge that steers the ship back inside instead of crashing it.
_Avoid_: Bumper, invisible wall

**Steering**:
The world briefly taking over: it damps the ship's speed and turns its nose up or down. This happens at soft walls and just after crossing the border.
_Avoid_: Autopilot, assist

**Zoom punch**:
The brief, dramatic camera zoom-in when the ship crosses the border, easing back out afterwards.
_Avoid_: Zoom pulse, dolly

**Pad**:
The marked spot on the ground where the ship can land.
_Avoid_: Landing zone, base

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
The pilot's money, in euros. It starts at €0 every run.
_Avoid_: Wallet, credits, score

**Ship offer**:
One ship type shown on the terminal, with its picture and characteristics. Taking a ship offer costs nothing.
_Avoid_: Offer (on its own), listing, card, product

**Ship swap**:
Entering the office from the parking spot and choosing another ship type in ship selection. The new ship takes the old one's place in the parking spot with a full tank.
_Avoid_: Respawn, change ship

## Transport

**Transport offer**:
A job on the terminal, not yet accepted: carry passengers, cargo or both from the station to the pad. It is only available for a limited time.
_Avoid_: Offer (on its own), job, mission

**Contract**:
A transport offer the player has accepted. All contracts accepted together are delivered in one flight.
_Avoid_: Order, accepted offer

**Load**:
Everything carried for the contracts: passengers and cargo together.
_Avoid_: Cargo (for the whole load), payload, freight

**Cargo**:
Goods carried for a contract, measured only by mass.
_Avoid_: Load (for goods alone), freight

## Ship

**Ship type**:
A kind of ship with its own shape, dry mass, maximum weight, tank, passenger seats, cargo capacity, thrust and turn rate. The game has three: the Sparrow, the Mule and the Halo.
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

## Ship states

A ship is always in exactly one of these four states.

**Flying**:
The ship is in free flight, under the player's control. It's the state between leaving the pad or the parking spot and landing, docking or crashing.
_Avoid_: Airborne, in flight, free

**Landed**:
The ship is resting on the pad after a safe touchdown.
_Avoid_: Touched down, parked

**Docked**:
The ship is resting inside the parking spot. This is the deep-space counterpart of Landed. From docking until the player declines to enter the office or leaves it, a Docked ship is held: it ignores the controls and doesn't refuel.
_Avoid_: Parked, landed (in deep space)

**Crashed**:
The ship hit something it shouldn't have, or touched down unsafely. A crash is final until restart.
_Avoid_: Destroyed, dead
