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

## Ship states

**Landed**:
The ship is resting on the pad after a safe touchdown.
_Avoid_: Touched down, parked

**Docked**:
The ship is resting inside the parking spot. This is the deep-space counterpart of Landed.
_Avoid_: Parked, landed (in deep space)

**Crashed**:
The ship hit something it shouldn't have, or touched down unsafely. A crash is final until restart.
_Avoid_: Destroyed, dead
