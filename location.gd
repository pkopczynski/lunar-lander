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
static var MINE := mine()
# In drift order: the location after the last one is the first.
static var ALL: Array[Location] = [VALLEY, MINE]


static func valley() -> Location:
	var location := Location.new()
	location.name = "VALLEY"
	location.pad_center_x = World.WORLD_WIDTH / 2.0
	return location


# An open pit: stepped benches on both sides down to a pit floor at ground level, wider steps on
# the left, with the pad off-centre on the floor toward the right. Each side reaches into its
# mountain and down to the ground's bottom, so the benches read as ground the pit is cut into.
static func mine() -> Location:
	var location := Location.new()
	location.name = "MINE"
	location.pad_center_x = 1300.0
	var bottom := World.GROUND_BOTTOM_Y
	location.terrain = [
		PackedVector2Array([
			Vector2(100, 428), Vector2(450, 428), Vector2(450, 488), Vector2(650, 488),
			Vector2(650, 548), Vector2(850, 548), Vector2(850, bottom), Vector2(100, bottom),
		]),
		PackedVector2Array([
			Vector2(1450, bottom), Vector2(1450, 548), Vector2(1550, 548), Vector2(1550, 488),
			Vector2(1650, 488), Vector2(1650, 428), Vector2(1900, 428), Vector2(1900, bottom),
		]),
	]
	return location
