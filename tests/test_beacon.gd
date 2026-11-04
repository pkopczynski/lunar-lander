extends "res://tests/scene_test.gd"
# The pad's Beacon: pulsing lights on its edges, never dimmed, glowing more at night, with no
# collider. Read through the World's decor listing, World.shown_decor().


# The Beacon's pieces as drawn for a camera centred on the current pad's top at a zoom.
func beacon(zoom := 1.0) -> Array[World.Decor]:
	var pieces: Array[World.Decor] = []
	for piece in world().shown_decor(pad_top(), zoom):
		if piece.layer == World.DecorLayer.BEACON:
			pieces.append(piece)
	return pieces


func lights(zoom := 1.0) -> Array[World.Decor]:
	return beacon(zoom).filter(func(piece: World.Decor) -> bool: return piece.part == World.DecorPart.LIGHT)


func glows() -> Array[World.Decor]:
	return beacon().filter(func(piece: World.Decor) -> bool: return piece.part == World.DecorPart.GLOW)


# The middle of the pad's top edge, in world coordinates.
func pad_top() -> Vector2:
	return Vector2(pad_x(), world().location.ground_y - Lander.PAD_HEIGHT)


# Sets the local time to hh:30 and lets the World redraw from it.
func at_hour(hour: int) -> void:
	clock().minutes = hour * 60 + 30
	await frames(1)


# Checks that one Beacon light sits on each of the pad's two edges, on screen for a camera
# centred on the pad's top at zoom 1, just above the pad.
func check_lights_on_the_pad_edges(where: String) -> void:
	var screen_center := world().get_viewport_rect().size / 2.0
	var shown := lights()
	check(shown.size() == 2, "the Beacon at the %s should have two lights, got %d" % [where, shown.size()])
	for edge in [-Lander.PAD_WIDTH / 2.0, Lander.PAD_WIDTH / 2.0]:
		var expected_x: float = screen_center.x + edge
		var on_edge := shown.filter(func(piece: World.Decor) -> bool:
			return absf(piece.screen_area.get_center().x - expected_x) <= 2.0)
		check(on_edge.size() == 1, "at the %s a Beacon light should sit on the pad edge at screen x %s, lights at %s"
			% [where, expected_x, shown.map(func(piece: World.Decor) -> Rect2: return piece.screen_area)])
		for piece: World.Decor in on_edge:
			var area := piece.screen_area
			check(area.end.y <= screen_center.y + 0.5 and area.end.y >= screen_center.y - 20.0,
				"at the %s a Beacon light should stand on the pad's top (screen y %s), its area %s" % [where, screen_center.y, area])


func test_the_valley_pad_shows_a_beacon_light_on_each_edge() -> void:
	await choose_ship()
	check_lights_on_the_pad_edges("Valley")


func test_the_beacon_follows_the_pad_to_the_mine() -> void:
	await choose_ship()
	clock().move_to(Location.MINE)
	await frames(1)
	check_lights_on_the_pad_edges("Mine")


func test_the_beacon_grows_and_shrinks_with_the_zoom_around_the_screen_centre() -> void:
	await choose_ship()
	var near := lights(2.0)
	var far := lights(1.0)
	var screen_center := world().get_viewport_rect().size / 2.0
	for i in near.size():
		check_near(near[i].screen_area.size.x, far[i].screen_area.size.x * 2.0, 0.01, "a Beacon light's width at zoom 2")
		var offset_far := far[i].screen_area.get_center() - screen_center
		var offset_near := near[i].screen_area.get_center() - screen_center
		check(offset_near.is_equal_approx(offset_far * 2.0),
			"a Beacon light at zoom 2 should be twice as far from the screen centre: %s at zoom 1, %s at zoom 2" % [offset_far, offset_near])


func test_no_beacon_piece_has_a_collider() -> void:
	await choose_ship()
	var pieces := beacon()
	check(not pieces.is_empty(), "the decor listing should report the Beacon")
	for piece in pieces:
		check(not piece.has_collider, "a Beacon piece at %s shouldn't have a collider" % piece.screen_area)


func test_flying_through_a_beacon_light_does_not_crash_the_ship() -> void:
	await choose_ship()
	# The Sparrow's hull reaches 14 px below its centre: put its bottom between the pad's top and
	# the top of the light on the pad's left edge, drifting right and up through the light.
	var light_top := pad_top().y - 2.0 * Beacon.LIGHT_RADIUS
	var at := Vector2(pad_x() - Lander.PAD_WIDTH / 2.0, light_top + 2.0 - 14.0)
	place(at, Vector2(40.0, -40.0))
	await seconds(0.25)
	check(lander().state == Lander.State.FLYING, "flying through the Beacon light should leave the ship Flying, got %s (%s)"
		% [Lander.State.keys()[lander().state], message()])
	check(lander().position.x > at.x + 5.0, "the ship should carry on through the Beacon light, from x %s to %s" % [at.x, lander().position.x])


func test_the_beacon_lights_are_never_dimmed_and_glow_more_at_night() -> void:
	await choose_ship()
	await at_hour(13)
	var day_light := lights()[0].color
	var day_glow := glows()[0].color.a
	await at_hour(3)
	check(world().sky.darkness > 0.3, "03:30 should be night, darkness %s" % world().sky.darkness)
	var night_light := lights()[0].color
	var night_glow := glows()[0].color.a
	check(Color(night_light, 1.0).is_equal_approx(Color(day_light, 1.0)),
		"a Beacon light should be the same colour at 03:30 as at 13:30: %s by day, %s at night" % [day_light, night_light])
	check(night_light.get_luminance() > 0.7, "a Beacon light should be bright at night, got %s" % night_light)
	check(night_glow > day_glow * 2.0, "the Beacon's glow should be much stronger at night: %s by day, %s at 03:30" % [day_glow, night_glow])
	check(day_glow > 0.0, "the Beacon should still glow faintly by day, got %s" % day_glow)


func test_the_beacon_pulses_slowly_and_never_goes_out() -> void:
	await choose_ship()
	var lowest := INF
	var highest := 0.0
	var largest_step := 0.0
	var previous := lights()[0].color.a
	for i in roundi(3.0 * PHYSICS_FPS):
		await frames(1)
		var alpha := lights()[0].color.a
		lowest = minf(lowest, alpha)
		highest = maxf(highest, alpha)
		largest_step = maxf(largest_step, absf(alpha - previous))
		previous = alpha
	check(highest - lowest > 0.3, "over 3 s a Beacon light should pulse, opacity %s to %s" % [lowest, highest])
	check(lowest > 0.4, "a Beacon light should never go out, lowest opacity %s" % lowest)
	check(largest_step < 0.05, "the pulse should be slow, largest change in one frame %s" % largest_step)
