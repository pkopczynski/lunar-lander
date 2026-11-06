class_name Clouds
extends Node2D
# A location's clouds, in three depths (see sky()): high cirrus streaks and lower puffy cumulus
# behind the scenery, and near translucent wisps in front of everything, the ship included. The
# cirrus and cumulus fill the sky from just above the pad to just below the Border, fixed in the
# world (no parallax), so they stay in their spot in the sky as the ship flies around and none ever
# shows in deep space. They drift slowly
# sideways on their own wind, tinted by the sky colour behind them. Each cloud wraps around from one side to the other well outside the view, so none ever
# pops in sight. No collider. Moving a cloud only changes its position (and a wisp's modulate), and
# the sky only its tint (self_modulate), so nothing is rebuilt as they drift or the hour passes:
# each one's shading is set once, when it's built.
#
# A cloud in front of the world (scroll scale above 1 sideways) is a wisp: translucent, drawn in
# front of the ship, and kept beside the Approach corridor. A wisp left of the pad drifts in a lane
# from far out of sight on the left up to the corridor, one right of it from the corridor out of
# sight on the right; it fades out toward the corridor's end of its lane, so it wraps there unseen.

# The kind of a location's clouds, which tints them and stretches their shape: white (the Valley),
# grey smog (the Metropolis) or dust (the Mine).
enum Kind { CUMULUS, SMOG, DUST }
# A cloud's form: a thin, fibrous streak high up, or a heap of puffs with a flat base.
enum Form { CIRRUS, CUMULUS }

# Tuning, expected to change in playtests.
# A cloud's depth (how fast it scrolls with the camera, the world's being 1) and wind by default.
const SCROLL := Vector2.ONE
# The wind, in px/s; rightwards (negative: leftwards).
const WIND_SPEED := 6.0
# How much of the sky's own colour (at ground level) lights a cloud over the gradient behind it, so
# even a cloud high in the dark upper sky takes the hour's colour; then how much lighter than that
# it is. At night it darkens with the sky.
const SKY_LIGHT := 0.6
const LIGHTENING := 0.45
# How much of that lightening is left at full night, and how much the clouds darken with the sky:
# faintly moonlit, so they still read against the night sky high up, without glowing.
const NIGHT_LIGHTENING := 0.3
const NIGHT_DARKENING := 0.75
# A cumulus is lit from above: its top this much lighter, its flat base this much darker.
const PUFF_TOP_LIGHT := 0.18
const PUFF_BASE_SHADE := 0.3
# A cumulus's shading, top to base, as a texture filling it (its colour tints it).
const SHADING_HEIGHT := 64
# A cirrus is lit along its upper edge, this much lighter than its colour, its underside and fibres
# a little darker.
const CIRRUS_TOP_LIGHT := 0.1
const CIRRUS_UNDERSIDE_SHADE := -0.03
# A cirrus is translucent: its body this opaque, the tips of its fibres fading to this.
const CIRRUS_ALPHA := 0.8
const FIBRE_TIP_ALPHA := 0.15
# Points around each puff, and along a cirrus streak.
const PUFF_SIDES := 24
# How many times a cumulus's outline is rounded off (Chaikin's corner cutting), softening the
# notches between its puffs.
const ROUNDING := 2
const STREAK_POINTS := 26
# Points along each side of a cirrus fibre.
const FIBRE_POINTS := 6
# A wisp's opacity, before it fades toward the corridor.
const WISP_OPACITY := 0.32
# How far from the Approach corridor a wisp's lane ends, and over how much of its lane's end it
# fades out, in px of its layer.
const WISP_CLEARANCE := 40.0
const WISP_FADE := 260.0

# The two far depths of sky(), highest first: [form, scroll scale, wind (px/s), how many per 100 px
# of the heights they're scattered between, those heights above the pad's top (as shares of the
# climb from the pad's top to the Border, the highest one leaving room for the cloud below it), the
# smallest and largest half size].
const DEPTHS := [
	# Cirrus streaks high in the sky.
	[Form.CIRRUS, Vector2.ONE, 3.0, 3.6, Vector2(0.5, 0.94), Vector2(150, 6), Vector2(300, 12)],
	# Cumulus heaps lower down, the lowest partly behind the scenery.
	[Form.CUMULUS, Vector2.ONE, 6.0, 2.7, Vector2(0.01, 0.5), Vector2(60, 26), Vector2(130, 48)],
]
# The near wisps in front of the ship, high above the pad: [scroll scale, wind (px/s), how many,
# the heights above the pad's top they're scattered between (as shares of the climb from the pad's
# top to the Border), the smallest and largest half size].
const WISPS := [Vector2(1.15, 1.12), 16.0, 10, Vector2(0.39, 0.88), Vector2(110, 16), Vector2(200, 30)]
# Each kind's half size scale and the colour it's drawn toward, by how much.
const KINDS := {
	Kind.CUMULUS: [Vector2(1.0, 1.0), Color.WHITE, 0.0],
	Kind.SMOG: [Vector2(1.3, 0.75), Color(0.55, 0.53, 0.5), 0.3],
	Kind.DUST: [Vector2(1.15, 0.85), Color(0.78, 0.62, 0.42), 0.3],
}


# One cloud: its centre and half size, as designed (with the camera on the pad, before it drifts),
# its depth (its parallax layer's scroll scale), the wind carrying it, in px/s, its kind, its form
# and the seed its outline is drawn from.
class Cloud:
	var center: Vector2
	var half_size: Vector2
	var scroll: Vector2
	var wind: float
	var kind: Kind
	var form: Form
	var shape_seed: int

	func _init(at: Vector2, half: Vector2, scroll_scale := SCROLL, wind_speed := WIND_SPEED, of_kind := Kind.CUMULUS,
			of_form := Form.CUMULUS, from_seed := 0) -> void:
		center = at
		half_size = half
		scroll = scroll_scale
		wind = wind_speed
		kind = of_kind
		form = of_form
		shape_seed = from_seed

	# A wisp: in front of the world.
	func is_wisp() -> bool:
		return scroll.x > 1.0


# A location's clouds of kind: the far DEPTHS, then the WISPS, scattered evenly across the span they
# wrap around, the same each time for a variety.
static func sky(kind: Kind, pad_top: Vector2, variety: int) -> Array[Cloud]:
	var rng := RandomNumberGenerator.new()
	rng.seed = variety
	var shape: Vector2 = KINDS[kind][0]
	var clouds: Array[Cloud] = []
	var to_border := pad_top.y - World.BORDER_Y
	for depth: Array in DEPTHS:
		var heights: Vector2 = depth[4] * to_border
		var count := roundi(depth[3] * (heights.y - heights.x) / 100.0)
		scatter(clouds, rng, kind, depth[0], depth[1], depth[2], count, heights, depth[5] * shape, depth[6] * shape, pad_top)
	scatter(clouds, rng, kind, Form.CUMULUS, WISPS[0], WISPS[1], WISPS[2], WISPS[3] * to_border, WISPS[4] * shape, WISPS[5] * shape, pad_top)
	return clouds


static func scatter(clouds: Array[Cloud], rng: RandomNumberGenerator, kind: Kind, form: Form, scroll: Vector2, wind: float,
		count: int, heights: Vector2, smallest: Vector2, largest: Vector2, pad_top: Vector2) -> void:
	var slot := DecorKit.WRAP_WIDTH / count
	for i in count:
		var half := Vector2(rng.randf_range(smallest.x, largest.x), rng.randf_range(smallest.y, largest.y))
		var at := Vector2(DecorKit.WRAP_LEFT + slot * (i + rng.randf_range(0.15, 0.85)),
			pad_top.y - rng.randf_range(heights.x, heights.y))
		clouds.append(Cloud.new(at, half, scroll, wind, kind, form, rng.randi()))


# The cumulus's shading, shared by all of them.
static var shading_texture := shading()

# The clouds behind the scenery, and the wisps, as drawn.
var pieces: Array[Polygon2D] = []
var wisps: Array[Polygon2D] = []
# The wisps' node, drawn in front of the ship: the World adds it over everything.
var near := Node2D.new()
# How long the wind has carried the clouds since they were built, in s.
var drifted := 0.0
# Every cloud and wisp as drawn, in the order given, each with its designed x, wind, the span its x
# wraps around (x: left end, y: width), kind and whether it's a wisp.
var drawn: Array[Polygon2D] = []
var designed_x := PackedFloat32Array()
var winds := PackedFloat32Array()
var lanes := PackedVector2Array()
var kinds: Array[Kind] = []
var translucent: Array[bool] = []


# Builds the clouds afresh, each depth in its own layer anchored on anchor (the pad's top).
func build(from: Array[Cloud], anchor: Vector2) -> void:
	DecorKit.clear(self)
	DecorKit.clear(near)
	pieces.clear()
	wisps.clear()
	designed_x.clear()
	winds.clear()
	lanes.clear()
	kinds.clear()
	translucent.clear()
	drawn.clear()
	drifted = 0.0
	var layers := DecorKit.Depths.new(self, anchor)
	var near_layers := DecorKit.Depths.new(near, anchor)
	for cloud in from:
		var visual := Polygon2D.new()
		var shaped := outline(cloud)
		visual.polygon = shaped[0]
		if cloud.form == Form.CUMULUS:
			visual.texture = shading_texture
			visual.uv = shading_uv(visual.polygon)
		else:
			visual.vertex_colors = shading_colors(shaped[1], shaped[2])
		visual.position = cloud.center
		if cloud.is_wisp():
			near_layers.at(cloud.scroll).add_child(visual)
			wisps.append(visual)
			lanes.append(wisp_lane(cloud, anchor))
		else:
			layers.at(cloud.scroll).add_child(visual)
			pieces.append(visual)
			lanes.append(Vector2(DecorKit.WRAP_LEFT, DecorKit.WRAP_WIDTH))
		drawn.append(visual)
		designed_x.append(cloud.center.x)
		winds.append(cloud.wind)
		kinds.append(cloud.kind)
		translucent.append(cloud.is_wisp())
	drift()


# The span a wisp's centre wraps around: from far out of sight up to the Approach corridor on its
# side of the pad, keeping it WISP_CLEARANCE clear of it.
static func wisp_lane(cloud: Cloud, anchor: Vector2) -> Vector2:
	var corridor_half := Lander.PAD_WIDTH / 2.0 + Foreground.CORRIDOR_MARGIN + WISP_CLEARANCE + cloud.half_size.x
	if cloud.center.x < anchor.x:
		var end := anchor.x - corridor_half
		return Vector2(DecorKit.WRAP_LEFT, end - DecorKit.WRAP_LEFT)
	var start := anchor.x + corridor_half
	return Vector2(start, DecorKit.WRAP_LEFT + DecorKit.WRAP_WIDTH - start)


func _process(delta: float) -> void:
	drifted += delta
	drift()


# Places each cloud where the wind has carried it, and fades each wisp near its lane's ends.
func drift() -> void:
	for i in drawn.size():
		var lane := lanes[i]
		var x := fposmod(designed_x[i] + winds[i] * drifted - lane.x, lane.y) + lane.x
		drawn[i].position.x = x
		if translucent[i]:
			drawn[i].modulate.a = clampf(minf(x - lane.x, lane.x + lane.y - x) / WISP_FADE, 0.0, 1.0)


# The clouds behind the scenery, then the wisps in front, for World.shown_decor().
func listed_decor() -> Array[World.Listing]:
	var listed := World.listings(pieces, World.DecorLayer.PARALLAX, World.DecorPart.CLOUD)
	listed.append_array(World.listings(wisps, World.DecorLayer.FOREGROUND, World.DecorPart.WISP))
	return listed


# Tints each cloud (its self_modulate) from the background gradient behind it (background_color: a
# world y to its colour) and the sky's colour, lighter, drawn a little toward its kind's colour (by
# day: it fades into the night sky like the rest) and darker as the sky darkens, so at night it
# never comes close to solid terrain's colour; its shading, set when it was built, darkens it from
# there (a cumulus's base by its texture, a cirrus's underside by its vertex colours).
func show_sky(sky: SkyLook, background_color: Callable) -> void:
	for i in drawn.size():
		var cloud := drawn[i]
		var kind: Array = KINDS[kinds[i]]
		var behind: Color = background_color.call(cloud.position.y)
		var lightening := LIGHTENING * lerpf(1.0, NIGHT_LIGHTENING, sky.night())
		var color := behind.lerp(sky.ground_color, SKY_LIGHT).lerp(Color.WHITE, lightening).lerp(kind[1], kind[2] * (1.0 - sky.night())).darkened(sky.darkness * NIGHT_DARKENING)
		# Its lit top's (or lit upper edge's) colour.
		var tint := color.lightened(PUFF_TOP_LIGHT if cloud.vertex_colors.is_empty() else CIRRUS_TOP_LIGHT)
		tint.a = WISP_OPACITY if translucent[i] else 1.0
		cloud.self_modulate = tint


# A cirrus's shading as vertex colours, set once: per point, how much lighter (above 0) or darker
# (below 0) than the cloud's colour (shade), and how opaque (alpha); white at its lit upper edge
# (CIRRUS_TOP_LIGHT lighter), so its tint gives that edge's colour, and darker below it.
static func shading_colors(shade: PackedFloat32Array, alpha: PackedFloat32Array) -> PackedColorArray:
	var colors := PackedColorArray()
	for point in shade.size():
		var level := 1.0 - (CIRRUS_TOP_LIGHT - shade[point])
		colors.append(Color(level, level, level, alpha[point]))
	return colors


# A cloud's outline around its centre, shaped by its form, and per point its shading and opacity
# (see shading_colors()): [outline, shading, opacity].
static func outline(cloud: Cloud) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = cloud.shape_seed
	if cloud.form == Form.CIRRUS:
		return cirrus(cloud.half_size, rng)
	return cumulus(cloud.half_size, rng)


# A heap of overlapping puffs cut flat along its base: rows of puffs, each narrower than the one
# below it, up to a crown or two, biggest in the middle (cauliflower-like); lit from above, its base in shade.
static func cumulus(half: Vector2, rng: RandomNumberGenerator) -> Array:
	var base_y := half.y * 0.6
	var heap := PackedVector2Array()
	# [the fewest puffs, spread (share of the half width), radius (share of the half height), centre
	# height above the base (share of the half height)]; each row has as many puffs as it takes for
	# neighbours of a usual radius to overlap well, at least the fewest.
	var tiers := [
		[5, 0.85, Vector2(0.35, 0.6), Vector2(0.25, 0.4)],
		[3, 0.55, Vector2(0.45, 0.7), Vector2(0.75, 1.0)],
		[2, 0.35, Vector2(0.4, 0.6), Vector2(1.3, 1.55)],
		[1, 0.15, Vector2(0.35, 0.5), Vector2(1.75, 1.95)],
	]
	for tier: Array in tiers:
		var spread: float = tier[1] * half.x
		var usual: float = half.y * (tier[2].x + tier[2].y) / 2.0
		var count: int = maxi(tier[0], ceili(2.0 * spread / (1.2 * usual)) + rng.randi_range(0, 1)) if tier[0] > 1 else rng.randi_range(1, 2)
		for i in count:
			var u := 0.0 if count == 1 else -1.0 + 2.0 * i / (count - 1)
			var radius := half.y * rng.randf_range(tier[2].x, tier[2].y) * (1.0 - 0.3 * u * u)
			# Neighbouring puffs always overlap, so the heap holds together.
			if count > 1:
				radius = maxf(radius, 2.0 * spread / (count - 1) * 0.65)
			var at := Vector2(u * spread + rng.randf_range(-0.06, 0.06) * half.x, base_y - half.y * rng.randf_range(tier[3].x, tier[3].y))
			heap = merged(heap, DecorKit.disc(at, radius, PUFF_SIDES))
	var below := PackedVector2Array([Vector2(-4.0 * half.x, -8.0 * half.y), Vector2(4.0 * half.x, -8.0 * half.y),
		Vector2(4.0 * half.x, base_y), Vector2(-4.0 * half.x, base_y)])
	heap = rounded(largest(Geometry2D.intersect_polygons(heap, below)), ROUNDING)
	# Shaded by the texture filling it (see shading()), not point by point.
	return [heap, PackedFloat32Array(), PackedFloat32Array()]


# outline with its corners cut times over (Chaikin's corner cutting): each pass replaces every
# corner with two points a quarter of the way along its sides.
static func rounded(outline: PackedVector2Array, times: int) -> PackedVector2Array:
	for pass_number in times:
		var cut := PackedVector2Array()
		for i in outline.size():
			var a := outline[i]
			var b := outline[(i + 1) % outline.size()]
			cut.append(a.lerp(b, 0.25))
			cut.append(a.lerp(b, 0.75))
		outline = cut
	return outline


# The texture shading a cumulus from top to base: its lit top white, its base in shade, so its
# colour (the lit top's) tints it.
static func shading() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color.WHITE.darkened((PUFF_TOP_LIGHT + PUFF_BASE_SHADE) / (1.0 + PUFF_TOP_LIGHT)))
	gradient.set_offset(0, 0.25)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 1
	texture.height = SHADING_HEIGHT
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	return texture


# The texture coordinates filling outline with the shading: its top at the texture's top, its
# bottom at the texture's bottom.
static func shading_uv(outline: PackedVector2Array) -> PackedVector2Array:
	var top := DecorKit.top_of(outline)
	var bottom := -INF
	for point in outline:
		bottom = maxf(bottom, point.y)
	var uv := PackedVector2Array()
	for point in outline:
		uv.append(Vector2(0.5, inverse_lerp(top, bottom, point.y) * SHADING_HEIGHT))
	return uv


# A long, thin, gently curved streak, tapering at both ends, with a few long fibres falling from its
# underside and sweeping back (mares' tails); translucent, the fibres fading out toward their tips.
static func cirrus(half: Vector2, rng: RandomNumberGenerator) -> Array:
	var bend := half.y * rng.randf_range(-0.8, 0.8)
	var tilt := half.y * rng.randf_range(-0.6, 0.6)
	# Every fibre of a streak has the same shape (only its length differs), falling more steeply
	# than the streak ever does, so no fibre crosses another or the streak.
	var trail := -1.0 if rng.randf() < 0.5 else 1.0
	var down := maxf(half.y * 2.5, half.x * rng.randf_range(0.09, 0.15))
	var across := down * rng.randf_range(0.8, 1.4) * trail
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for i in STREAK_POINTS:
		var u := float(i) / (STREAK_POINTS - 1)
		var x := lerpf(-half.x, half.x, u)
		var y := bend * (4.0 * (u - 0.5) * (u - 0.5) - 1.0) + tilt * (u - 0.5) * 2.0
		var thickness := half.y * pow(sin(PI * u), 0.8) * rng.randf_range(0.7, 1.2)
		upper.append(Vector2(x, y - thickness * 0.55))
		lower.append(Vector2(x, y + thickness * 0.45))
	var points := PackedVector2Array()
	var shade := PackedFloat32Array()
	var alpha := PackedFloat32Array()
	var ends := func(i: int) -> float: return 0.3 if i == 0 or i == STREAK_POINTS - 1 else 1.0
	for i in STREAK_POINTS:
		points.append(upper[i])
		shade.append(CIRRUS_TOP_LIGHT)
		alpha.append(CIRRUS_ALPHA * ends.call(i))
	var fibres := 0
	# Its ends are points (no thickness), already on the upper edge.
	for i in range(STREAK_POINTS - 2, 0, -1):
		points.append(lower[i])
		shade.append(CIRRUS_UNDERSIDE_SHADE)
		alpha.append(CIRRUS_ALPHA * ends.call(i))
		# Now and then a fibre falls from between this point and the next one back.
		if i > 3 and i < STREAK_POINTS - 3 and fibres < 6 and rng.randf() < 0.4:
			fibres += 1
			fibre(points, shade, alpha, lower[i], lower[i - 1], across, down, rng.randf_range(0.6, 1.0))
	return [points, shade, alpha]


# A fibre's outline from root (where it leaves the streak) to back (where it rejoins it), into points
# with its shading and opacity: it falls down, curling across sideways, thinning toward its tip;
# length is how much of that curve it runs along (1: all of it).
static func fibre(points: PackedVector2Array, shade: PackedFloat32Array, alpha: PackedFloat32Array, root: Vector2, back: Vector2,
		across: float, down: float, length: float) -> void:
	var middle := root.lerp(back, 0.5)
	var root_half := absf(root.x - back.x) * 0.25
	# Its curl is never tighter than twice its width, so its sides never cross (the curve's tightest
	# radius, at its root, is down² / (2·across)).
	across = signf(across) * minf(absf(across), down * down / (4.0 * root_half))
	var along := func(t: float) -> Vector2: return middle + Vector2(across * t * t, down * t)
	var normal := func(t: float) -> Vector2: return Vector2(down, -2.0 * across * t).normalized()
	for side: float in [1.0, -1.0]:
		for step in FIBRE_POINTS:
			var share := float(step + 1) / (FIBRE_POINTS + 1)
			if side < 0.0:
				share = 1.0 - share
			var t := share * length
			points.append(along.call(t) + normal.call(t) * root_half * (1.0 - share) * side)
			shade.append(CIRRUS_UNDERSIDE_SHADE)
			alpha.append(lerpf(CIRRUS_ALPHA, FIBRE_TIP_ALPHA, share))


# outline merged into heap: the outer outline of both, the largest if they fall apart.
static func merged(heap: PackedVector2Array, outline: PackedVector2Array) -> PackedVector2Array:
	if heap.is_empty():
		return outline
	return largest(Geometry2D.merge_polygons(heap, outline))


# The largest of outlines (an outer outline: a hole is always smaller than the outline around it).
static func largest(outlines: Array[PackedVector2Array]) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := 0.0
	for outline in outlines:
		var area := absf(area_of(outline))
		if area > best_area:
			best = outline
			best_area = area
	return best


static func area_of(outline: PackedVector2Array) -> float:
	var total := 0.0
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		total += a.x * b.y - b.x * a.y
	return total / 2.0
