class_name Location
extends RefCounted
# The location table: every place on the planet the station can be above, with its pad and
# terrain, its ground's height and its Backdrop. The mountain side walls, deep space and station
# are shared.

# The open-pit mine's benches step down from the Valley's ground level, three steps a side, the
# last one onto the pit floor.
const BENCH_STEP := 60.0
const PIT_DEPTH := 3.0 * BENCH_STEP

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
# The clouds drifting in its sky; by default none.
var clouds: Array[Clouds.Cloud] = []
# The silhouettes in front of the ship; by default none. They must leave its pad and the ship's
# last FAIR_HEIGHT of approach uncovered (see Foreground).
var foreground: Array[Foreground.Silhouette] = []

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
# In drift order: the location after the last one is the first.
static var ALL: Array[Location] = [VALLEY, MINE]


# The location after this one in drift order, wrapping to the first.
func next() -> Location:
	return ALL[(ALL.find(self) + 1) % ALL.size()]


static func valley() -> Location:
	var location := Location.new()
	location.name = "VALLEY"
	location.pad_center_x = World.WORLD_WIDTH / 2.0
	location.clouds = Clouds.valley()
	location.foreground = Foreground.valley()
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
