class_name Location
extends RefCounted
# The location table: every place on the planet the station can be above, with its pad and
# terrain. The mountain side walls, ground, backdrop, deep space and station are shared.

# Shown in the HUD.
var name: String
# The pad's centre, in world x.
var pad_center_x: float
# Solid polygons added to the shared ground and mountains; touching them crashes the ship.
var terrain: Array[PackedVector2Array] = []

# Named like constants: GDScript can't build objects in a const, so never reassign these.
static var VALLEY := valley()
# In drift order: the location after the last one is the first.
static var ALL: Array[Location] = [VALLEY]


static func valley() -> Location:
	var location := Location.new()
	location.name = "VALLEY"
	location.pad_center_x = World.WORLD_WIDTH / 2.0
	return location
