extends "res://tests/scene_test.gd"
# The Mountains: the same solid side walls at every Location, dressed in each Location's own look.

# The agreed least distance between solid terrain's colour and any decor's, in RGB (as in
# test_tonal_depth.gd).
const MIN_DISTINCT := 0.1


func locations() -> Array[Location]:
	return [Location.VALLEY, Location.MINE, Location.METROPOLIS]


func at_location(location: Location) -> void:
	clock().move_to(location)
	await frames(1)


# Every colour the Mountains are drawn in, as drawn.
func mountain_colors() -> Array[Color]:
	var colors: Array[Color] = []
	for visual in main().get_node("Mountains").get_children():
		if visual is Polygon2D and not shown_color(visual) in colors:
			colors.append(shown_color(visual))
	return colors


func test_each_location_dresses_the_mountains_in_its_own_look() -> void:
	await choose_ship()
	clock().minutes = 13 * 60 + 30
	var looks := {}
	for location in locations():
		await at_location(location)
		var colors := mountain_colors()
		check(colors.size() >= 2, "the %s's Mountains should be dressed, not one flat colour: %s" % [location.name, colors])
		for other: String in looks:
			check(looks[other] != colors, "the %s's Mountains should look different from the %s's" % [location.name, other])
		looks[location.name] = colors


# The decor that could be mistaken for a surface, as drawn for a camera on the pad: the Backdrop,
# the parallax layers and the Foreground.
func scenery_decor() -> Array[World.Decor]:
	var pad_top := Vector2(pad_x(), world().location.ground_y - Lander.PAD_HEIGHT)
	return world().shown_decor(pad_top, 1.0).filter(func(piece: World.Decor) -> bool:
		return piece.layer in [World.DecorLayer.BACKDROP, World.DecorLayer.PARALLAX, World.DecorLayer.FOREGROUND])


func distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


# Not only at the hours the sky tests read: the sky-tinted decor sweeps through many colours in
# between (grey before dawn, orange-brown in the evening), and the Mountains must never match it.
func test_the_mountains_look_different_from_every_decor_piece_all_day() -> void:
	await choose_ship()
	for location in locations():
		await at_location(location)
		var closest := INF
		var closest_at := ""
		for minute in range(0, 24 * 60, 15):
			clock().minutes = minute + 0.5
			await frames(1)
			for color in mountain_colors():
				for piece in scenery_decor():
					if distance(color, piece.color) < closest:
						closest = distance(color, piece.color)
						closest_at = "%02d:%02d, Mountains %s, decor (layer %d, part %d) %s" % [
							minute / 60, minute % 60, color, piece.layer, piece.part, piece.color]
		check(closest >= MIN_DISTINCT, "at the %s the Mountains should look different from every decor piece all day, closest %.3f at %s"
			% [location.name, closest, closest_at])


# Beside the right mountain's face below its tops, where it leans furthest in at x 1850 (y 320);
# no location's terrain reaches this high there.
const FACE_Y := 300.0
const BESIDE_FACE_X := 1826.0


func test_the_mountains_crash_the_ship_at_every_location_with_the_same_outline() -> void:
	await choose_ship()
	for location in locations():
		await at_location(location)
		place(Vector2(BESIDE_FACE_X, FACE_Y))
		await seconds(0.25)
		check(lander().state == Lander.State.FLYING,
			"at the %s the ship should fly just beside the Mountains' face without touching it, got %s" % [location.name, message()])
		place(Vector2(BESIDE_FACE_X, FACE_Y), Vector2(200, 0))
		await seconds(0.5)
		check(message().begins_with("Crashed"), "at the %s flying into the Mountains should crash, got %s" % [location.name, message()])
