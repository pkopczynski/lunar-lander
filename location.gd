class_name Location
extends RefCounted
# The location table: every place on the planet the station can be above, with its pad and
# terrain, its ground's height and its Backdrop. The mountain side walls, deep space and station
# are shared.

# The open-pit mine's benches step down from the Valley's ground level, three steps a side, the
# last one onto the pit floor.
const BENCH_STEP := 60.0
const PIT_DEPTH := 3.0 * BENCH_STEP
# The Mine's one solid crane: its mast stands on the top left bench, its counter-jib reaches left
# and its arm right, over the left benches, well above them and away from the pad's approach.
# Touching it crashes the ship.
const CRANE := [
	Vector2(375, World.GROUND_TOP_Y), Vector2(375, 462), Vector2(330, 462), Vector2(330, 450),
	Vector2(375, 450), Vector2(375, 430), Vector2(385, 430), Vector2(385, 450), Vector2(760, 450),
	Vector2(760, 462), Vector2(385, 462), Vector2(385, World.GROUND_TOP_Y),
]

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
# The Metropolis's lit facades: the faces of its buildings that hold windows, left to right, inside
# their walls and clear of the left mountain and the neon signs.
const METROPOLIS_FACADES: Array[Rect2] = [
	Rect2(270, 380, 140, 400), Rect2(640, 280, 168, 500), Rect2(1120, 590, 260, 190),
	Rect2(1412, 600, 108, 180), Rect2(1572, 680, 166, 100),
]
# The Metropolis's neon signs: the bar each lights on a building's face, and its colour.
const NEON_ORANGE := Color(1.0, 0.6, 0.15)
const NEON_PINK := Color(1.0, 0.2, 0.8)
const NEON_CYAN := Color(0.2, 0.95, 1.0)
const METROPOLIS_NEON_SIGNS := [
	[Rect2(290, 352, 110, 10), NEON_ORANGE], [Rect2(614, 300, 10, 130), NEON_PINK],
	[Rect2(1130, 562, 240, 10), NEON_CYAN], [Rect2(1530, 610, 8, 90), NEON_PINK],
]
# The Metropolis's flying vehicles: where each is as designed and its speed in px/s (negative:
# leftwards). Tuning, expected to change in playtests.
const METROPOLIS_VEHICLES := [
	[Vector2(300, 180), 45.0], [Vector2(1500, 120), -60.0], [Vector2(900, 330), 30.0], [Vector2(-400, 240), -38.0],
]

# Location profiles (see Profile): what the Transport offers to each location are like. Kind
# weights are passengers only, cargo only and both. Tuning, expected to change in playtests.
# The Valley: every kind alike, varied passengers and supplies, the base pay.
const VALLEY_POOL_SHARE := 0.4
const VALLEY_TITLES: Dictionary[TransportOffer.Kind, Array] = {
	TransportOffer.Kind.PASSENGERS: ["Tourist party", "Crew rotation", "Survey team", "Medical staff",
		"School trip"],
	TransportOffer.Kind.CARGO: ["Hydroponics kit", "Water ice", "General supplies", "Spare parts",
		"Mail and parcels"],
	TransportOffer.Kind.MIXED: ["Tourists and luggage", "Field camp", "Relief mission", "Science outpost",
		"Settlers and supplies"],
}
# The Mine: heavy cargo and small crews, paying well above the Valley for the heavy loads.
const MINE_POOL_SHARE := 0.3
const MINE_KIND_WEIGHTS: Array[float] = [0.1, 0.6, 0.3]
const MINE_MAX_PASSENGERS := 4
const MINE_MIN_CARGO := 3000.0
const MINE_REWARD_FACTOR := 1.6
const MINE_TITLES: Dictionary[TransportOffer.Kind, Array] = {
	TransportOffer.Kind.PASSENGERS: ["Mining shift", "Blasting crew", "Maintenance crew"],
	TransportOffer.Kind.CARGO: ["Drill bits", "Spare parts", "Industrial supplies", "Conveyor parts",
		"Heavy tools"],
	TransportOffer.Kind.MIXED: ["Drill crew and rig", "Repair team", "Crane crew and parts"],
}
# The Metropolis: mostly passengers, with light cargo only.
const METROPOLIS_POOL_SHARE := 0.3
const METROPOLIS_KIND_WEIGHTS: Array[float] = [0.6, 0.1, 0.3]
const METROPOLIS_MAX_CARGO := 3000.0
const METROPOLIS_REWARD_FACTOR := 1.35
const METROPOLIS_TITLES: Dictionary[TransportOffer.Kind, Array] = {
	TransportOffer.Kind.PASSENGERS: ["Tourist group", "Corporate team", "Business delegation",
		"Conference guests", "Shift workers"],
	TransportOffer.Kind.CARGO: ["Mail and parcels", "Shop supplies", "Electronics", "Restaurant supplies"],
	TransportOffer.Kind.MIXED: ["Office move", "Film crew and kit", "Hotel guests", "Pop-up shop", "Expo team"],
}

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
# The Mountains' look here (their outline and collision are the same everywhere); by default the
# Valley's forested slopes.
var mountains := MountainLook.valley()
# Solid polygons added to the shared ground and mountains; touching them crashes the ship.
var terrain: Array[PackedVector2Array] = []
# The ridges (or skyline) behind the surface, farther first, with no collision; by default the
# Tatra-like ones.
var backdrop: Array[Backdrop.Ridge] = Backdrop.tatras()
# The clouds drifting in its sky; by default none.
var clouds: Array[Clouds.Cloud] = []
# The silhouettes in front of the ship; by default none. They must leave its pad and the ship's
# last FAIR_HEIGHT of approach uncovered (see Foreground).
var foreground: Array[Foreground.Silhouette] = []
# Its city lights, drawn over its buildings with no collision (see CityLights); by default none.
var windows: Array[Rect2] = []
var neon_signs: Array[CityLights.Sign] = []
var warning_lights := PackedVector2Array()
# The distant vehicles flying in its sky behind the buildings; by default none.
var vehicles: Array[Vehicles.Vehicle] = []

# Its location profile: what the Transport offers to it are like.
var profile := Profile.new()

# Named like constants: GDScript can't build objects in a const, so never reassign these.
static var VALLEY := valley()
static var MINE := mine()
static var METROPOLIS := metropolis()
# In drift order: the location after the last one is the first.
static var ALL: Array[Location] = [VALLEY, MINE, METROPOLIS]


# A location profile: what the Transport offers to a location are like.
class Profile:
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
	var titles: Dictionary[TransportOffer.Kind, Array] = {}
	# Its offers' rewards are multiplied by this.
	var reward_factor := 1.0


# The location after this one in drift order, wrapping to the first.
func next() -> Location:
	return ALL[(ALL.find(self) + 1) % ALL.size()]


static func valley() -> Location:
	var location := Location.new()
	location.name = "VALLEY"
	location.pad_center_x = World.WORLD_WIDTH / 2.0
	location.clouds = Clouds.valley()
	location.foreground = Foreground.valley()
	location.profile.pool_share = VALLEY_POOL_SHARE
	location.profile.titles = VALLEY_TITLES
	return location


# An open-pit mine: stepped benches cut down into the ground on both sides to a pit floor below
# the Valley's ground, wider steps on the left, with the pad off-centre on the pit floor toward
# the right, and one solid crane over the left benches. Each side reaches under its mountain and
# down to the ground's bottom, so no sky shows below the Valley's ground outside the open-pit mine.
# Behind it, Himalaya-like peaks and its far walls; in front, its Foreground.
static func mine() -> Location:
	var location := Location.new()
	location.name = "MINE"
	location.pad_center_x = 1300.0
	location.ground_y = World.GROUND_TOP_Y + PIT_DEPTH
	location.backdrop = Backdrop.mine()
	location.mountains = MountainLook.mine()
	location.foreground = Foreground.mine()
	location.profile.pool_share = MINE_POOL_SHARE
	location.profile.kind_weights = PackedFloat32Array(MINE_KIND_WEIGHTS)
	location.profile.max_passengers = MINE_MAX_PASSENGERS
	location.profile.min_cargo = MINE_MIN_CARGO
	location.profile.reward_factor = MINE_REWARD_FACTOR
	location.profile.titles = MINE_TITLES
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
		PackedVector2Array(CRANE),
	]
	return location


# A city of rooftops: tall towers on the left, the pad on a roof at about mid-height right of
# centre, and lower roofs stepping down on its right, forming the approach. The pad's roof is the
# only landing surface; the buildings, the street below them and the antenna are solid terrain.
static func metropolis() -> Location:
	var location := Location.new()
	location.name = "METROPOLIS"
	location.pad_center_x = 1250.0
	location.profile.pool_share = METROPOLIS_POOL_SHARE
	location.profile.kind_weights = PackedFloat32Array(METROPOLIS_KIND_WEIGHTS)
	location.profile.max_cargo = METROPOLIS_MAX_CARGO
	location.profile.reward_factor = METROPOLIS_REWARD_FACTOR
	location.profile.titles = METROPOLIS_TITLES
	location.backdrop = Backdrop.skyline()
	location.mountains = MountainLook.metropolis()
	location.foreground = Foreground.metropolis()
	location.windows = CityLights.windows_on(METROPOLIS_FACADES)
	for neon in METROPOLIS_NEON_SIGNS:
		location.neon_signs.append(CityLights.Sign.new(neon[0], neon[1]))
	# On the towers' and the lower roof's corners, and the antenna's tip.
	location.warning_lights = PackedVector2Array([
		Vector2(414, 325), Vector2(606, 255), Vector2(814, 255),
		Vector2(PAD_BUILDING_LEFT + ANTENNA_WIDTH / 2.0, ANTENNA_TOP_Y - CityLights.WARNING_RADIUS), Vector2(1554, 575),
	])
	for vehicle in METROPOLIS_VEHICLES:
		location.vehicles.append(Vehicles.Vehicle.new(vehicle[0], vehicle[1]))
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
