extends "res://tests/scene_test.gd"
# Tonal depth: at every Location and hour, each depth of scenery reads apart from its neighbours,
# and solid terrain always looks different from decor. Read through World.shown_decor() and the
# solid visuals' colours as drawn.

# The agreed least difference in luminance between neighbouring depths, at every hour.
const MIN_STEP := 0.03
# The hours the sky tests use, plus 01:00, deep in the night.
const HOURS := [1, 3, 8, 13, 19, 23]
# The agreed least distance between solid terrain's colour and any decor's, in RGB.
const MIN_DISTINCT := 0.1


func locations() -> Array[Location]:
	return [Location.VALLEY, Location.MINE, Location.METROPOLIS]


func pad_top() -> Vector2:
	return Vector2(pad_x(), world().location.ground_y - Lander.PAD_HEIGHT)


func at_hour(hour: int) -> void:
	clock().minutes = hour * 60 + 30
	await frames(1)


func at_location(index: int) -> void:
	clock().move_to(locations()[index])
	await frames(1)


# The decor in layer as drawn for a camera on the pad.
func pieces_in(layer: World.DecorLayer) -> Array[World.Decor]:
	var pieces: Array[World.Decor] = []
	for piece in world().shown_decor(pad_top(), 1.0):
		if piece.layer == layer:
			pieces.append(piece)
	return pieces


# The Backdrop's depths, farther first: its pieces, the flying Vehicles' hulls and the slow movers
# grouped by how fast they scroll sideways (the slower, the farther), then the Foreground's opaque
# silhouettes as the nearest depth (the clouds' translucent wisps aren't a depth).
func depths() -> Array[Array]:
	var by_scroll := {}
	var stepped := pieces_in(World.DecorLayer.BACKDROP) + pieces_in(World.DecorLayer.PARALLAX).filter(
		func(piece: World.Decor) -> bool: return piece.part in [World.DecorPart.VEHICLE, World.DecorPart.MOVER])
	for piece: World.Decor in stepped:
		if not by_scroll.has(piece.scroll_scale.x):
			by_scroll[piece.scroll_scale.x] = []
		by_scroll[piece.scroll_scale.x].append(piece)
	var scrolls := by_scroll.keys()
	scrolls.sort()
	var ordered: Array[Array] = []
	for scroll: float in scrolls:
		ordered.append(by_scroll[scroll])
	ordered.append(pieces_in(World.DecorLayer.FOREGROUND).filter(
		func(piece: World.Decor) -> bool: return piece.part == World.DecorPart.SILHOUETTE))
	return ordered


func test_each_depth_is_clearly_darker_than_the_one_behind_it_at_every_hour() -> void:
	await choose_ship()
	for index in locations().size():
		await at_location(index)
		var where: String = world().location.name
		for hour: int in HOURS:
			await at_hour(hour)
			var ordered := depths()
			check(ordered.size() >= 3, "the %s should show at least two Backdrop depths and a Foreground" % where)
			for i in ordered.size() - 1:
				for farther: World.Decor in ordered[i]:
					for nearer: World.Decor in ordered[i + 1]:
						var step := farther.color.get_luminance() - nearer.color.get_luminance()
						check(step >= MIN_STEP,
							"at the %s at %02d:30, depth %d should be at least %s darker than depth %d, the step is %.3f (%s, %s)"
							% [where, hour, i + 1, MIN_STEP, i, step, nearer.color, farther.color])


# The solid visuals as drawn: the ground, the Mountains and the location's terrain.
func solid_colors() -> Array[Color]:
	var colors: Array[Color] = [shown_color(ground())]
	for visual in main().get_node("Mountains").get_children() + main().get_node("Terrain").get_children():
		if visual is Polygon2D:
			colors.append(shown_color(visual))
	return colors


# The decor that could be mistaken for a surface: the Backdrop, the parallax layers and the
# Foreground. Lights (windows, neon, the Beacon, the glows in some crowns) are small glowing points
# on top of things.
func scenery_decor() -> Array[World.Decor]:
	return world().shown_decor(pad_top(), 1.0).filter(func(piece: World.Decor) -> bool:
		return piece.layer in [World.DecorLayer.BACKDROP, World.DecorLayer.PARALLAX, World.DecorLayer.FOREGROUND])


func distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


# Not only at the sky tests' hours: the sky-tinted decor sweeps through many colours in between
# (grey before dawn, orange-brown in the evening), and solid terrain must never match it. Each
# solid visual (the ground, each of the Mountains' colours, each terrain polygon) is reported with
# the closest it came to any decor all day.
func test_solid_terrain_always_looks_different_from_every_decor_piece_all_day() -> void:
	await choose_ship()
	for index in locations().size():
		await at_location(index)
		var where: String = world().location.name
		var closest: Array[float] = []
		var closest_at: Array[String] = []
		for minute in range(0, 24 * 60, 15):
			clock().minutes = minute + 0.5
			await frames(1)
			var solids := solid_colors()
			closest.resize(solids.size())
			closest_at.resize(solids.size())
			var decor := scenery_decor()
			for i in solids.size():
				check(solids[i].a == 1.0, "solid terrain at the %s should be opaque, its colour %s" % [where, solids[i]])
				if minute == 0:
					closest[i] = INF
				for piece in decor:
					if distance(solids[i], piece.color) < closest[i]:
						closest[i] = distance(solids[i], piece.color)
						closest_at[i] = "%02d:%02d, solid %s, decor (layer %d, part %d) %s" % [
							minute / 60, minute % 60, solids[i], piece.layer, piece.part, piece.color]
		for i in closest.size():
			check(closest[i] >= MIN_DISTINCT,
				"at the %s solid visual %d should look different from every decor piece all day, closest %.3f at %s"
				% [where, i, closest[i], closest_at[i]])
