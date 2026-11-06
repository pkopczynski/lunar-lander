extends "res://tests/scene_test.gd"
# The Moons: four other bodies in the surface sky at every location, read through the World's
# decor listing, World.shown_decor().


func pad_top() -> Vector2:
	return Vector2(pad_x(), world().location.ground_y - Lander.PAD_HEIGHT)


func moons(camera_center := pad_top(), zoom := 1.0) -> Array[World.Decor]:
	var listed: Array[World.Decor] = []
	for piece in world().shown_decor(camera_center, zoom):
		if piece.part == World.DecorPart.MOON:
			listed.append(piece)
	return listed


func test_every_location_lists_four_moons_without_colliders() -> void:
	await choose_ship()
	for location in Location.ALL:
		clock().move_to(location)
		await frames(1)
		var listed := moons()
		check(listed.size() == 4, "the %s should list four Moons, got %d" % [location.name, listed.size()])
		for moon in listed:
			check(not moon.has_collider, "a Moon at the %s shouldn't have a collider" % location.name)
			check(moon.layer == World.DecorLayer.PARALLAX, "a Moon at the %s should sit behind the surface" % location.name)


func in_view(piece: World.Decor) -> bool:
	return piece.screen_area.intersects(world().get_viewport_rect())


# Shown: in view and not faded out.
func shown(piece: World.Decor) -> bool:
	return piece.opacity > 0.0 and in_view(piece)


# The Moons are very far away: they barely move up or down, or sideways, as the ship flies around.
const MAX_SCROLL := 0.05


func test_the_moons_hang_almost_still_as_the_ship_climbs() -> void:
	await choose_ship()
	for location in Location.ALL:
		clock().move_to(location)
		await frames(1)
		for moon in moons():
			check(moon.scroll_scale.x <= MAX_SCROLL + 0.001 and moon.scroll_scale.y <= MAX_SCROLL + 0.001,
				"a Moon at the %s should barely scroll with the camera, its scale %s" % [location.name, moon.scroll_scale])
		var on_pad := moons(pad_top(), FollowCamera.SURFACE_ZOOM)
		var higher := moons(pad_top() + Vector2(0.0, -1000.0), FollowCamera.SURFACE_ZOOM)
		for i in mini(on_pad.size(), higher.size()):
			var moved := higher[i].screen_area.position - on_pad[i].screen_area.position
			check(absf(moved.y) <= MAX_SCROLL * 1000.0 * FollowCamera.SURFACE_ZOOM,
				"Moon %d at the %s should stay almost still on screen as the ship climbs 1000 px, moved %s" % [i, location.name, moved])
			check(shown(higher[i]) == shown(on_pad[i]),
				"Moon %d at the %s should still show 1000 px above the pad if it shows on the pad" % [i, location.name])


func test_the_giant_moon_is_in_view_from_the_pad() -> void:
	await choose_ship()
	for location in Location.ALL:
		clock().move_to(location)
		await frames(1)
		for zoom in [0.85, FollowCamera.SURFACE_ZOOM]:
			var listed := moons(pad_top(), zoom)
			var largest: World.Decor = null
			for moon in listed:
				if largest == null or moon.screen_area.get_area() > largest.screen_area.get_area():
					largest = moon
			check(largest != null and in_view(largest),
				"the %s's giant Moon should be in view with the camera on the pad at zoom %s" % [location.name, zoom])


func test_the_moons_have_faded_out_at_the_border_and_stay_out_in_deep_space() -> void:
	await choose_ship()
	var size := world().get_viewport_rect().size
	for location in Location.ALL:
		clock().move_to(location)
		await frames(1)
		for zoom in [0.85, FollowCamera.SURFACE_ZOOM]:
			# The camera keeps the view inside the world sideways.
			var half_view: float = size.x / zoom / 2.0
			for x in [half_view, pad_x(), World.WORLD_WIDTH - half_view]:
				for y in [World.BORDER_Y, World.BORDER_Y - 500.0, World.SPACE_TOP_Y]:
					for moon in moons(Vector2(x, y), zoom):
						check(not shown(moon), "no Moon should show at the %s with the camera at %s, zoom %s: %s"
							% [location.name, Vector2(x, y), zoom, moon.screen_area])


func at_hour(hour: int) -> void:
	clock().minutes = hour * 60 + 30
	await frames(1)


func test_the_moons_are_fainter_by_day_than_at_night() -> void:
	await choose_ship()
	for location in Location.ALL:
		clock().move_to(location)
		await at_hour(13)
		var by_day := moons()
		await at_hour(1)
		var at_night := moons()
		check(by_day.size() == 4 and at_night.size() == 4, "the %s should list its four Moons by day and at night" % location.name)
		for i in mini(by_day.size(), at_night.size()):
			check(by_day[i].color.a < at_night[i].color.a,
				"Moon %d at the %s should be fainter by day (%s) than at night (%s)" % [i, location.name, by_day[i].color, at_night[i].color])


# A tall window shows far more sky below the camera than the standard one, and the fast zoom shows
# the most; even then the Moons have faded out at the Border.
const TALL_WINDOW := Vector2i(1152, 1600)


func test_the_moons_have_faded_out_at_the_border_on_a_tall_window() -> void:
	await choose_ship()
	var window := world().get_window()
	var standard := window.size
	window.size = TALL_WINDOW
	await frames(1)
	var view := world().get_viewport_rect()
	check(view.size.y > view.size.x * 1.3, "the view should be tall for this check, got %s" % view.size)
	var zoom := FollowCamera.SURFACE_ZOOM * FollowCamera.FAST_ZOOM_FACTOR
	for location in Location.ALL:
		clock().move_to(location)
		await frames(1)
		var half_view: float = view.size.x / zoom / 2.0
		for x in [half_view, pad_x(), World.WORLD_WIDTH - half_view]:
			for moon in moons(Vector2(x, World.BORDER_Y), zoom):
				check(not shown(moon), "no Moon should show at the %s at the Border on a %s window, camera x %d: %s"
					% [location.name, TALL_WINDOW, x, moon.screen_area])
	window.size = standard
	await frames(1)
