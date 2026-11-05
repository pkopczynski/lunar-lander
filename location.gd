class_name Location
extends RefCounted
# The location table: every place on the planet the station can be above, with its pad and
# terrain, its ground's height and its Backdrop. The mountain side walls, deep space and station
# are shared.

# The open-pit mine's benches step down from the Valley's ground level, three steps a side, the
# last one onto the pit floor.
const BENCH_STEP := 60.0
const PIT_DEPTH := 3.0 * BENCH_STEP

# The Metropolis: the pad's roof at about mid-height between the mountain tops and the street,
# which lies well below the Valley's ground. Gaps between buildings are at least ~2.5× the
# Mule's 68 px length.
const ROOF_Y := 500.0
const STREET_Y := 800.0
# The landing surface: a little wider than the pad, and only part of the pad building's roof.
const PAD_ROOF_WIDTH := 140.0
const PAD_BUILDING_LEFT := 1100.0
const PAD_BUILDING_RIGHT := 1400.0
const ANTENNA_TOP_Y := 380.0
const ANTENNA_WIDTH := 10.0

# Shown in the HUD.
var name: String
var pad_center_x: float
# The top of the ground here, where the pad sits and ships land, in world y.
var ground_y := World.GROUND_TOP_Y
# How wide the ground (the landing surface) is, centred on the pad; by default it spans the whole
# world. Narrowed, ships beside it fall past its height onto whatever terrain lies below.
var ground_width := INF
# The lowest the surface reaches here, in world y: the camera's bottom limit, and how far down
# the sky fills. By default the ground's bottom.
var lowest_y := NAN:
	get:
		return ground_y + World.GROUND_DEPTH if is_nan(lowest_y) else lowest_y
# Solid polygons added to the shared ground and mountains; touching them crashes the ship.
var terrain: Array[PackedVector2Array] = []
# The ridges behind the surface, farther first, with no collision; by default the Tatra-like ones.
var backdrop: Array[Backdrop.Ridge] = Backdrop.tatras()

# The location profile: what the Transport offers to it are like.
# Its weight in the pool: offers go to each location in proportion to their shares.
var pool_share := 1.0
# How often its offers are passengers only, cargo only or both, indexed by TransportOffer.Kind.
var kind_weights := PackedFloat32Array([1.0, 1.0, 1.0])
# Passengers and cargo (kg) per offer; each also capped by the largest ship type's seats and
# maximum capacity.
var min_passengers := 1
var max_passengers := 1000
var min_cargo := 500.0
var max_cargo := INF
# Its offers' titles, by TransportOffer.Kind.
var titles := {}
# Its offers' rewards are multiplied by this.
var reward_factor := 1.0

# Named like constants: GDScript can't build objects in a const, so never reassign these.
static var VALLEY := valley()
static var MINE := mine()
static var METROPOLIS := metropolis()
# In drift order: the location after the last one is the first.
static var ALL: Array[Location] = [VALLEY, MINE, METROPOLIS]


# The location after this one in drift order, wrapping to the first.
func next() -> Location:
	return ALL[(ALL.find(self) + 1) % ALL.size()]


static func valley() -> Location:
	var location := Location.new()
	location.name = "VALLEY"
	location.pad_center_x = World.WORLD_WIDTH / 2.0
	location.pool_share = 0.4
	location.titles = {
		TransportOffer.Kind.PASSENGERS: ["Tourist party", "Crew rotation", "Survey team", "Medical staff",
			"School trip"],
		TransportOffer.Kind.CARGO: ["Hydroponics kit", "Water ice", "General supplies", "Spare parts",
			"Mail and parcels"],
		TransportOffer.Kind.MIXED: ["Tourists and luggage", "Field camp", "Relief mission", "Science outpost",
			"Settlers and supplies"],
	}
	return location


# An open-pit mine: stepped benches cut down into the ground on both sides to a pit floor below
# the Valley's ground, wider steps on the left, with the pad off-centre on the pit floor toward
# the right. Each side reaches under its mountain and down to the ground's bottom, so no sky
# shows below the Valley's ground outside the open-pit mine.
static func mine() -> Location:
	var location := Location.new()
	location.name = "MINE"
	location.pad_center_x = 1300.0
	location.ground_y = World.GROUND_TOP_Y + PIT_DEPTH
	location.pool_share = 0.3
	location.kind_weights = PackedFloat32Array([0.1, 0.6, 0.3])
	location.max_passengers = 4
	location.min_cargo = 3000.0
	location.reward_factor = 1.35
	location.titles = {
		TransportOffer.Kind.PASSENGERS: ["Mining shift", "Blasting crew", "Maintenance crew"],
		TransportOffer.Kind.CARGO: ["Drill bits", "Spare parts", "Industrial supplies", "Conveyor parts",
			"Heavy tools"],
		TransportOffer.Kind.MIXED: ["Drill crew and rig", "Repair team", "Crane crew and parts"],
	}
	var top := World.GROUND_TOP_Y
	var bottom := location.ground_y + World.GROUND_DEPTH
	var left := -World.SIDE_OVERHANG
	var right := World.WORLD_WIDTH + World.SIDE_OVERHANG
	location.terrain = [
		PackedVector2Array([
			Vector2(left, top), Vector2(450, top), Vector2(450, top + BENCH_STEP),
			Vector2(650, top + BENCH_STEP), Vector2(650, top + 2.0 * BENCH_STEP),
			Vector2(850, top + 2.0 * BENCH_STEP), Vector2(850, bottom), Vector2(left, bottom),
		]),
		PackedVector2Array([
			Vector2(1450, bottom), Vector2(1450, top + 2.0 * BENCH_STEP),
			Vector2(1550, top + 2.0 * BENCH_STEP), Vector2(1550, top + BENCH_STEP),
			Vector2(1650, top + BENCH_STEP), Vector2(1650, top), Vector2(right, top), Vector2(right, bottom),
		]),
	]
	return location


# A city of rooftops: tall towers on the left, the pad on a roof at about mid-height right of
# centre, and lower roofs stepping down on its right, forming the approach. The pad's roof is the
# only landing surface; the buildings, the street below them and the antenna are solid terrain.
static func metropolis() -> Location:
	var location := Location.new()
	location.name = "METROPOLIS"
	location.pad_center_x = 1250.0
	location.pool_share = 0.3
	location.kind_weights = PackedFloat32Array([0.6, 0.1, 0.3])
	location.max_cargo = 3000.0
	location.reward_factor = 1.35
	location.titles = {
		TransportOffer.Kind.PASSENGERS: ["Tourist group", "Corporate team", "Business delegation",
			"Conference guests", "Shift workers"],
		TransportOffer.Kind.CARGO: ["Mail and parcels", "Shop supplies", "Electronics", "Restaurant supplies"],
		TransportOffer.Kind.MIXED: ["Office move", "Film crew and kit", "Hotel guests", "Pop-up shop", "Expo team"],
	}
	location.ground_y = ROOF_Y
	location.ground_width = PAD_ROOF_WIDTH
	location.lowest_y = STREET_Y + World.GROUND_DEPTH
	var left := -World.SIDE_OVERHANG
	var right := World.WORLD_WIDTH + World.SIDE_OVERHANG
	var street := STREET_Y
	var bottom := location.lowest_y
	# The pad's building is wider than its landing surface; the surface sits in a notch in its roof.
	var roof_left := location.pad_center_x - PAD_ROOF_WIDTH / 2.0
	var roof_right := location.pad_center_x + PAD_ROOF_WIDTH / 2.0
	var under_roof := ROOF_Y + World.GROUND_DEPTH
	location.terrain = [
		# The street, across the whole world.
		PackedVector2Array([Vector2(left, street), Vector2(right, street), Vector2(right, bottom), Vector2(left, bottom)]),
		# A tall tower against the left mountain, with the rock below that mountain.
		PackedVector2Array([
			Vector2(140, 330), Vector2(420, 330), Vector2(420, street), Vector2(left, street), Vector2(left, 640),
			Vector2(140, 640),
		]),
		# The tallest tower, with streets on both sides.
		PackedVector2Array([Vector2(600, 260), Vector2(820, 260), Vector2(820, street), Vector2(600, street)]),
		# The pad's building.
		PackedVector2Array([
			Vector2(PAD_BUILDING_LEFT, ROOF_Y), Vector2(roof_left, ROOF_Y), Vector2(roof_left, under_roof),
			Vector2(roof_right, under_roof), Vector2(roof_right, ROOF_Y), Vector2(PAD_BUILDING_RIGHT, ROOF_Y),
			Vector2(PAD_BUILDING_RIGHT, street), Vector2(PAD_BUILDING_LEFT, street),
		]),
		# The antenna, on the pad building's far left corner.
		PackedVector2Array([
			Vector2(PAD_BUILDING_LEFT, ANTENNA_TOP_Y), Vector2(PAD_BUILDING_LEFT + ANTENNA_WIDTH, ANTENNA_TOP_Y),
			Vector2(PAD_BUILDING_LEFT + ANTENNA_WIDTH, ROOF_Y), Vector2(PAD_BUILDING_LEFT, ROOF_Y),
		]),
		# Two lower roofs stepping down on the pad's right, the last one reaching under the right
		# mountain.
		PackedVector2Array([
			Vector2(PAD_BUILDING_RIGHT, 580), Vector2(1560, 580), Vector2(1560, street),
			Vector2(PAD_BUILDING_RIGHT, street),
		]),
		PackedVector2Array([
			Vector2(1560, 660), Vector2(1750, 660), Vector2(1750, 640), Vector2(right, 640), Vector2(right, street),
			Vector2(1560, street),
		]),
	]
	return location
