class_name Skyline
extends RefCounted
# The Metropolis's skyline: its Backdrop, a dense city in several depths behind its buildings.
# Each depth is a row of towers, in clusters of varied heights with lower districts between them,
# their roofs flat, sloped, crowned with a spire or a radio mast, or stacked in modern pagoda-like
# tiers. Monumental megastructures rise far above the farthest row. The three nearest depths hold
# pale lit windows, fewer, smaller and dimmer with distance; the farthest row and the
# megastructures carry only sparse beacons; a band of haze lies behind each nearer depth. The rows
# come from a seeded generator, so the city is the same every run. Tuning, expected to change in
# playtests.

# How far past the world's sides each row is built, so a slow layer shifted sideways still shows
# towers rather than the Backdrop's level carry-on.
const ROW_MARGIN := 1000.0
const ROW_LEFT := -World.SIDE_OVERHANG - ROW_MARGIN
const ROW_RIGHT := World.WORLD_WIDTH + World.SIDE_OVERHANG + ROW_MARGIN
# How far down a facade's windows go below its roof: lower ones are hidden by the nearer depths.
const FACADE_HEIGHT := 200.0
# Windows sit this far inside a tower's walls and below its roof.
const FACADE_INSET := Vector2(5, 8)
# The skyline's pale window tint, multiplied by each depth's brightness. Paler than the
# buildings' warm windows (CityLights.WINDOW_TINTS).
const WINDOW_TINT := Color(0.93, 0.92, 0.86)
const BEACON_COLOR := Color(1.0, 0.3, 0.25)
const BEACON_SIZE := Vector2(3, 3)
# The most beacons the farthest row's tallest towers carry, besides the megastructures'.
const ROW_BEACONS := 5
# The haze behind a depth: how far above its tallest roofs it fades out.
const HAZE_RISE := 160.0
const SEED := 77


# One depth of the skyline, farther first in DEPTHS.
class Depth:
	var scroll: Vector2
	var darkening: float
	# The roof heights (world y): a cluster's tallest towers, its edges, and the low districts.
	var cluster_peak_y: float
	var cluster_edge_y: float
	var district_y: float
	# A tower's width range.
	var widths: Vector2
	# Its windows (none when the size is zero): size, spacing, lit share and brightness.
	var window_size: Vector2
	var window_spacing: Vector2
	var lit_share: float
	var brightness: float

	func _init(scroll_scale: Vector2, darker: float, roofs: Vector3, tower_widths: Vector2,
			window := Vector2.ZERO, spacing := Vector2.ZERO, lit := 0.0, bright := 0.0) -> void:
		scroll = scroll_scale
		darkening = darker
		cluster_peak_y = roofs.x
		cluster_edge_y = roofs.y
		district_y = roofs.z
		widths = tower_widths
		window_size = window
		window_spacing = spacing
		lit_share = lit
		brightness = bright


static var DEPTHS: Array[Depth] = [
	Depth.new(Vector2(0.4, 0.95), 0.08, Vector3(170, 260, 300), Vector2(24, 50)),
	Depth.new(Vector2(0.52, 0.962), 0.2, Vector3(200, 300, 360), Vector2(28, 60),
		Vector2(3, 4), Vector2(11, 14), 0.16, 0.45),
	Depth.new(Vector2(0.64, 0.972), 0.32, Vector3(250, 360, 430), Vector2(32, 70),
		Vector2(4, 5), Vector2(12, 15), 0.24, 0.6),
	Depth.new(Vector2(0.76, 0.982), 0.44, Vector3(310, 420, 500), Vector2(36, 80),
		Vector2(5, 7), Vector2(13, 17), 0.32, 0.75),
]

# The megastructures in the farthest row: centre x, half width at the base and top (with its
# spire) in world y. The pad's top is at y 494: the tallest rises about 1500 px above it, right
# behind the pad, so one is in view as the ship climbs.
const MEGASTRUCTURES: Array[Vector3] = [
	Vector3(330, 85, -760), Vector3(1080, 110, -1000), Vector3(1760, 90, -620),
]
const MEGA_BASE_Y := 600.0
const MEGA_LEDGE := 16.0
const MEGA_SPIRE := 140.0
const MEGA_CHAMFER := 12.0


# The skyline, farther first.
static func metropolis() -> Array[Backdrop.Ridge]:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var ridges: Array[Backdrop.Ridge] = []
	for i in DEPTHS.size():
		var depth := DEPTHS[i]
		var row := Row.new()
		var megas: Array[Vector3] = []
		if i == 0:
			megas = MEGASTRUCTURES
		row.build(depth, megas, rng)
		var ridge := Backdrop.Ridge.new(row.edge, depth.darkening, depth.scroll)
		if depth.window_size != Vector2.ZERO:
			ridge.windows = windows_on(row.facades, depth, rng)
			ridge.window_color = WINDOW_TINT * depth.brightness
			ridge.window_color.a = 1.0
		else:
			ridge.beacons = row.beacons
		if i > 0:
			ridge.haze_top_y = depth.cluster_peak_y - HAZE_RISE
			ridge.haze_bottom_y = depth.district_y
		ridges.append(ridge)
	return ridges


# The lit windows in a grid on each facade, some lit and some not.
static func windows_on(facades: Array[Rect2], depth: Depth, rng: RandomNumberGenerator) -> Array[Rect2]:
	var windows: Array[Rect2] = []
	for facade in facades:
		var columns := floori((facade.size.x - depth.window_size.x) / depth.window_spacing.x) + 1
		var rows := floori((facade.size.y - depth.window_size.y) / depth.window_spacing.y) + 1
		for row in rows:
			for column in columns:
				if rng.randf() < depth.lit_share:
					windows.append(Rect2(facade.position + Vector2(column, row) * depth.window_spacing, depth.window_size))
	return windows


# One row of towers as it's built, left to right: its top edge, the facades that may hold windows
# and the spots for beacons.
class Row:
	enum Roof { FLAT, SHED, GABLE, SPIRE, MAST, PAGODA }
	# A cluster tower's roof is drawn from these, flat twice as often.
	const CLUSTER_ROOFS: Array[Roof] = [Roof.FLAT, Roof.FLAT, Roof.SHED, Roof.SPIRE, Roof.MAST, Roof.PAGODA]

	var edge: Array[Vector2] = []
	var facades: Array[Rect2] = []
	var beacons := PackedVector2Array()
	# Every tower's highest point: the tallest carry beacons on the farthest row.
	var tops: Array[Vector2] = []
	var in_cluster := false

	func build(depth: Depth, megas: Array[Vector3], rng: RandomNumberGenerator) -> void:
		var x := ROW_LEFT
		in_cluster = rng.randf() < 0.5
		for mega in megas:
			x = towers(x, mega.x - mega.y, depth, rng)
			x = megastructure(mega)
		towers(x, ROW_RIGHT, depth, rng)
		tops.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
		for top in tops.slice(0, ROW_BEACONS):
			beacons.append(top)

	# Towers from x to the end x, alternating clusters and low districts; returns where it stopped.
	func towers(x: float, end: float, depth: Depth, rng: RandomNumberGenerator) -> float:
		while x < end:
			var span := rng.randf_range(220, 420) if in_cluster else rng.randf_range(120, 260)
			var stretch_end := minf(x + span, end)
			var start := x
			while x < stretch_end:
				var width := minf(rng.randf_range(depth.widths.x, depth.widths.y), stretch_end - x)
				if stretch_end - x - width < depth.widths.x:
					width = stretch_end - x
				var roof: float
				var kind: Roof
				if in_cluster:
					# Tallest in the cluster's middle.
					var middle := 1.0 - absf((x + width / 2.0 - start) / (stretch_end - start) * 2.0 - 1.0)
					roof = lerpf(depth.cluster_edge_y, depth.cluster_peak_y, middle) + rng.randf_range(-25, 25)
					kind = CLUSTER_ROOFS[rng.randi() % CLUSTER_ROOFS.size()]
				else:
					roof = depth.district_y + rng.randf_range(-20, 20)
					kind = Roof.GABLE if rng.randf() < 0.4 else Roof.FLAT
				tower(x, x + width, roof, kind, rng)
				x += width
			in_cluster = not in_cluster
		return x

	func tower(left: float, right: float, roof: float, kind: Roof, rng: RandomNumberGenerator) -> void:
		var middle := (left + right) / 2.0
		var width := right - left
		var top := Vector2(middle, roof)
		match kind:
			Roof.SHED:
				var drop := minf(width * 0.5, 24.0)
				if rng.randf() < 0.5:
					edge.append_array([Vector2(left, roof + drop), Vector2(right, roof)])
				else:
					edge.append_array([Vector2(left, roof), Vector2(right, roof + drop)])
			Roof.GABLE:
				var rise := minf(width * 0.3, 14.0)
				edge.append_array([Vector2(left, roof), Vector2(middle, roof - rise), Vector2(right, roof)])
			Roof.SPIRE:
				var half := maxf(width * 0.15, 2.0)
				top = Vector2(middle, roof - rng.randf_range(45, 90))
				edge.append_array([Vector2(left, roof), Vector2(middle - half, roof), top,
					Vector2(middle + half, roof), Vector2(right, roof)])
			Roof.MAST:
				top = Vector2(middle, roof - rng.randf_range(40, 70))
				edge.append_array([Vector2(left, roof), Vector2(middle - 1.5, roof), Vector2(middle - 1.5, top.y),
					Vector2(middle + 1.5, top.y), Vector2(middle + 1.5, roof), Vector2(right, roof)])
			Roof.PAGODA:
				top = Vector2(middle, roof - 16)
				edge.append_array(pagoda(left, right, roof))
			_:
				edge.append_array([Vector2(left, roof), Vector2(right, roof)])
		facades.append(Rect2(left + FACADE_INSET.x, roof + FACADE_INSET.y + (40.0 if kind == Roof.PAGODA else 0.0),
			width - 2.0 * FACADE_INSET.x, FACADE_HEIGHT))
		tops.append(top)

	# Three stacked tiers, each roof sloping down to upturned eaves, narrowing to a finial.
	func pagoda(left: float, right: float, roof: float) -> Array[Vector2]:
		var middle := (left + right) / 2.0
		var half := (right - left) / 2.0
		var tier := clampf(half * 0.6, 10.0, 18.0)
		var tiers := 3
		var side: Array[Vector2] = []
		for k in tiers:
			var eave := half * (1.0 - 0.25 * k)
			var base := roof + (tiers - k) * tier
			side.append(Vector2(middle - eave, base - 4.0))
			side.append(Vector2(middle - eave + 3.0, base))
			side.append(Vector2(middle - eave * 0.75, base - tier * 0.55))
			side.append(Vector2(middle - eave * 0.75, base - tier))
		side.append(Vector2(middle - 1.5, roof))
		side.append(Vector2(middle, roof - 16.0))
		return side + mirrored(side, middle)

	# A megastructure: a shaft tapering up from its base, a broad sky ledge part way up, then
	# narrower chamfered tiers crowned with a spire; beacons on the ledge's ends and the spire's tip.
	# Returns its right side's x.
	func megastructure(mega: Vector3) -> float:
		var middle := mega.x
		var half := mega.y
		var body_top := mega.z + MEGA_SPIRE
		var at := func(share: float) -> float: return lerpf(MEGA_BASE_Y, body_top, share)
		var ledge: float = at.call(0.42)
		var shoulder: float = at.call(0.78)
		var crown: float = at.call(0.92)
		var side: Array[Vector2] = [
			Vector2(middle - half, MEGA_BASE_Y), Vector2(middle - half * 0.78, ledge),
			Vector2(middle - half * 0.95, ledge), Vector2(middle - half * 0.95, ledge - MEGA_LEDGE),
			Vector2(middle - half * 0.6, ledge - MEGA_LEDGE), Vector2(middle - half * 0.6, shoulder),
			Vector2(middle - half * 0.45, shoulder - MEGA_CHAMFER), Vector2(middle - half * 0.45, crown),
			Vector2(middle - half * 0.28, crown - MEGA_CHAMFER), Vector2(middle - half * 0.28, body_top),
			Vector2(middle - 3.0, body_top), Vector2(middle, mega.z),
		]
		for x in [middle - half * 0.95, middle + half * 0.95]:
			beacons.append(Vector2(x, ledge - MEGA_LEDGE - 2.0))
		beacons.append(Vector2(middle, mega.z + 2.0))
		edge.append_array(side + mirrored(side, middle))
		return middle + half

	# A left side's points mirrored about middle, left to right, without its last (middle) point.
	static func mirrored(side: Array[Vector2], middle: float) -> Array[Vector2]:
		var right: Array[Vector2] = []
		for i in range(side.size() - 2, -1, -1):
			right.append(Vector2(2.0 * middle - side[i].x, side[i].y))
		return right
