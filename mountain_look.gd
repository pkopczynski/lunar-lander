class_name MountainLook
extends RefCounted
# The Mountains' look at a location: a base colour filling each mountain's outline, and dressings
# (each one colour and its shapes) drawn over it, clipped to the outline, so the Mountains keep
# the same outline and collision at every location. Every colour is a solid material colour,
# dimmed with the sky like the rest of the solid scenery, and must stay clearly distinct from
# every decor colour at every hour (not only at the hours the tests read): the sky-tinted
# Backdrop sweeps through navy, grey dawn, pale yellow, blue and orange, so the colours here
# are either light or clearly saturated. Tuning, expected to change in playtests.

# The Valley: forested slopes under bare rocky tops.
const VALLEY_FOREST := Color(0.3, 0.5, 0.14)
const VALLEY_TREES := Color(0.1, 0.32, 0.04)
const VALLEY_ROCK := Color(0.74, 0.46, 0.2)
# How far below the mountain tops the forest starts, and the trees' size.
const TREELINE_DEPTH := 70.0
const TREE_SPACING := Vector2(22.0, 26.0)
const TREE_SIZE := Vector2(18.0, 34.0)
# The Mine: rock cut into benches, each with a lighter cut face over a darker ledge.
const MINE_ROCK := Color(0.68, 0.4, 0.24)
const MINE_CUT := Color(0.8, 0.56, 0.3)
const MINE_LEDGE := Color(0.56, 0.4, 0.02)
const CUT_STEP := 44.0
const CUT_HEIGHT := 16.0
const LEDGE_HEIGHT := 5.0
# The Metropolis: a wall of buildings, terracotta facades like the city's own buildings, with
# glass windows and glass between them.
const METROPOLIS_FACADE := Color(0.72, 0.4, 0.26)
const METROPOLIS_GLASS := Color(0.0, 0.46, 0.46)
const BUILDING_WIDTH := Vector2(46.0, 96.0)
const BUILDING_GAP := 6.0
const WINDOW_SIZE := Vector2(8.0, 10.0)
const WINDOW_SPACING := Vector2(16.0, 20.0)

# How far each side's dressing reaches, measured inward from the world's edge: past what the
# widest view shows of a mountain, to just past its foot. The mountains' top is World.MOUNTAIN_TOP_Y
# and their bottom the outline's lowest point.
const DRESSED_FROM := -900.0
const DRESSED_TO := 260.0
const DRESSED_BOTTOM := 660.0
# Each side's dressing is laid out from its own seed, so the two sides don't mirror each other.
const SIDE_SEEDS: Array[int] = [83, 38]

var base: Color
var dressings: Array[Dressing] = []
# Each side's dressings once clipped, by side.
var clipped := {}


# One colour and its shapes for each side: [left, right], in world coordinates, unclipped.
class Dressing:
	var color: Color
	var shapes: Array[Array] = [[], []]

	func _init(with_color: Color) -> void:
		color = with_color


func _init(base_color: Color) -> void:
	base = base_color


# The dressings for one side's mountain (0 left, 1 right), each with only that side's shapes,
# clipped to its outline. Clipped once per side, so showing a location again costs nothing.
func dressed(side: int, outline: PackedVector2Array) -> Array[Dressing]:
	if not clipped.has(side):
		var dressed_side: Array[Dressing] = []
		for dressing in dressings:
			var inside := Dressing.new(dressing.color)
			for shape: PackedVector2Array in dressing.shapes[side]:
				inside.shapes[side].append_array(Geometry2D.intersect_polygons(shape, outline))
			dressed_side.append(inside)
		clipped[side] = dressed_side
	return clipped[side]


# Lays out each side's shapes for a dressing: build(rng, side) returns the shapes as for the left
# mountain (x measured from the world's left edge), mirrored here for the right one.
func dress(color: Color, build: Callable) -> void:
	var dressing := Dressing.new(color)
	for side in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = SIDE_SEEDS[side]
		for shape: PackedVector2Array in build.call(rng, side):
			if side == 1:
				shape = mirrored(shape)
			dressing.shapes[side].append(shape)
	dressings.append(dressing)


static func mirrored(shape: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(shape.size() - 1, -1, -1):
		out.append(Vector2(World.WORLD_WIDTH - shape[i].x, shape[i].y))
	return out


static func rect(at: Vector2, size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(size.x, 0), at + size, at + Vector2(0, size.y)])


# Forested slopes: a forest below a wavy treeline, dotted with darker spruce-like trees, under
# bare rocky tops.
static func valley() -> MountainLook:
	var look := MountainLook.new(VALLEY_ROCK)
	var treeline := World.MOUNTAIN_TOP_Y + TREELINE_DEPTH
	look.dress(VALLEY_FOREST, func(rng: RandomNumberGenerator, _side: int) -> Array:
		var edge := PackedVector2Array()
		var x := DRESSED_FROM
		while x < DRESSED_TO:
			edge.append(Vector2(x, treeline + rng.randf_range(-24.0, 24.0)))
			x += rng.randf_range(30.0, 60.0)
		edge.append(Vector2(DRESSED_TO, treeline))
		return [DecorKit.closed_down(edge, DRESSED_BOTTOM)])
	look.dress(VALLEY_TREES, func(rng: RandomNumberGenerator, _side: int) -> Array:
		var trees := []
		var y := treeline - 30.0
		while y < DRESSED_BOTTOM:
			var x := DRESSED_FROM + rng.randf_range(0.0, TREE_SPACING.x)
			while x < DRESSED_TO:
				if rng.randf() < 0.7:
					var size := TREE_SIZE * rng.randf_range(0.7, 1.3)
					var foot := Vector2(x, y + rng.randf_range(-6.0, 6.0))
					trees.append(PackedVector2Array([
						foot + Vector2(-size.x / 2.0, 0), foot + Vector2(0, -size.y), foot + Vector2(size.x / 2.0, 0),
					]))
				x += TREE_SPACING.x * rng.randf_range(0.8, 1.3)
			y += TREE_SPACING.y
		return trees)
	return look


# Cut rock: benches cut into the rock face, each a lighter cut face over a dark ledge, slightly
# uneven.
static func mine() -> MountainLook:
	var look := MountainLook.new(MINE_ROCK)
	var cut := func(rng: RandomNumberGenerator, _side: int, top_offset: float, height: float) -> Array:
		var bands := []
		var y := World.MOUNTAIN_TOP_Y + CUT_STEP / 2.0
		while y < DRESSED_BOTTOM:
			var x := DRESSED_FROM
			while x < DRESSED_TO:
				var length := rng.randf_range(120.0, 260.0)
				var top := y + top_offset + rng.randf_range(-3.0, 3.0)
				bands.append(rect(Vector2(x, top), Vector2(length + 2.0, height)))
				x += length
			y += CUT_STEP
		return bands
	look.dress(MINE_CUT, cut.bind(0.0, CUT_HEIGHT))
	look.dress(MINE_LEDGE, cut.bind(CUT_HEIGHT, LEDGE_HEIGHT))
	return look


# A wall of buildings: facades of varied widths and heights with rows of glass windows, glass
# showing between them.
static func metropolis() -> MountainLook:
	var look := MountainLook.new(METROPOLIS_GLASS)
	# The buildings, the same for both dressings: [left x, top y, width] per side.
	var buildings: Array[Array] = [[], []]
	for side in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = SIDE_SEEDS[side]
		var x := DRESSED_FROM
		while x < DRESSED_TO:
			var width := rng.randf_range(BUILDING_WIDTH.x, BUILDING_WIDTH.y)
			buildings[side].append([x, World.MOUNTAIN_TOP_Y + rng.randf_range(-10.0, 140.0), width])
			x += width + BUILDING_GAP
	look.dress(METROPOLIS_FACADE, func(_rng: RandomNumberGenerator, side: int) -> Array:
		var facades := []
		for building: Array in buildings[side]:
			facades.append(rect(Vector2(building[0], building[1]), Vector2(building[2], DRESSED_BOTTOM - building[1])))
		return facades)
	look.dress(METROPOLIS_GLASS, func(_rng: RandomNumberGenerator, side: int) -> Array:
		var windows := []
		for building: Array in buildings[side]:
			var columns := floori((building[2] - WINDOW_SPACING.x / 2.0) / WINDOW_SPACING.x)
			var inset: float = (building[2] - columns * WINDOW_SPACING.x) / 2.0 + (WINDOW_SPACING.x - WINDOW_SIZE.x) / 2.0
			var y: float = building[1] + 12.0
			while y < DRESSED_BOTTOM:
				for column in columns:
					windows.append(rect(Vector2(building[0] + inset + column * WINDOW_SPACING.x, y), WINDOW_SIZE))
				y += WINDOW_SPACING.y
		return windows)
	return look
