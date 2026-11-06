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


func shown(piece: World.Decor) -> bool:
	return piece.opacity > 0.0 and in_view(piece)


# The Moons are fixed in the world: they pass by on screen like the ground as the ship flies around.
func test_the_moons_stay_in_their_spot_in_the_sky_as_the_ship_flies_around() -> void:
	await choose_ship()
	var zoom := FollowCamera.SURFACE_ZOOM
	var flown := Vector2(300.0, -1000.0)
	for location in Location.ALL:
		clock().move_to(location)
		await frames(1)
		var on_pad := moons(pad_top(), zoom)
		var elsewhere := moons(pad_top() + flown, zoom)
		for i in mini(on_pad.size(), elsewhere.size()):
			var moved := elsewhere[i].screen_area.position - on_pad[i].screen_area.position
			check(on_pad[i].scroll_scale == Vector2.ONE, "Moon %d at the %s should have no parallax, its scale %s" % [i, location.name, on_pad[i].scroll_scale])
			check(moved.distance_to(-flown * zoom) < 0.5,
				"Moon %d at the %s should pass by like the ground as the ship flies 1000 px up and 300 px across, moved %s" % [i, location.name, moved])


func test_the_moons_are_out_of_view_at_the_border_and_in_deep_space() -> void:
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
# the most; even then the Moons have sunk out of view by the Border.
const TALL_WINDOW := Vector2i(1152, 1600)


func test_the_moons_are_out_of_view_at_the_border_on_a_tall_window() -> void:
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
