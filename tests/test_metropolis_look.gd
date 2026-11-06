extends "res://tests/scene_test.gd"
# The Metropolis at night: a skyline in several depths with megastructures as its Backdrop, lit
# windows, neon signs, warning lights and distant flying vehicles. Read through the World's decor listing,
# World.shown_decor().


func pad_top() -> Vector2:
	return Vector2(pad_x(), world().location.ground_y - Lander.PAD_HEIGHT)


func pieces(layer: World.DecorLayer, part := -1, camera_center := pad_top(), zoom := 1.0) -> Array[World.Decor]:
	var found: Array[World.Decor] = []
	for piece in world().shown_decor(camera_center, zoom):
		if piece.layer == layer and (part == -1 or piece.part == part):
			found.append(piece)
	return found


func at_metropolis() -> void:
	await choose_ship()
	clock().move_to(Location.METROPOLIS)
	await frames(1)


func at_hour(hour: int) -> void:
	clock().minutes = hour * 60 + 30
	await frames(1)


# A world y as it appears on screen for a camera centred on the pad's top at zoom 1.
func screen_y(world_y: float) -> float:
	return world_y - pad_top().y + world().get_viewport_rect().size.y / 2.0


# The Backdrop's depths, farther first: their scroll scales, sideways ones sorted (slower is farther).
func backdrop_scrolls() -> Array[float]:
	var scrolls: Array[float] = []
	for piece in pieces(World.DecorLayer.BACKDROP):
		if not piece.scroll_scale.x in scrolls:
			scrolls.append(piece.scroll_scale.x)
	scrolls.sort()
	return scrolls


func test_the_backdrop_is_a_skyline_in_several_depths_with_megastructures_far_above_it() -> void:
	await at_metropolis()
	var scrolls := backdrop_scrolls()
	check(scrolls.size() >= 4, "the Metropolis's Backdrop should be a skyline in at least four depths, got %d" % scrolls.size())
	check(scrolls[-1] < 1.0, "even the nearest skyline should scroll more slowly than the world: %s" % scrolls[-1])
	var highest := INF
	for ridge in Location.METROPOLIS.backdrop:
		for point in ridge.top_edge:
			highest = minf(highest, point.y)
	var above_pad := pad_top().y - highest
	check(above_pad > 1300.0 and above_pad < 1700.0,
		"the megastructures should rise about 1500 px above the pad, the highest reaches %s" % above_pad)
	for piece in pieces(World.DecorLayer.BACKDROP):
		check(not piece.has_collider, "no skyline piece should have a collider")


func test_skyline_or_megastructure_silhouettes_stay_in_view_as_the_ship_climbs() -> void:
	await at_metropolis()
	var view := Rect2(Vector2.ZERO, world().get_viewport_rect().size)
	for height in [700.0, 1200.0]:
		for zoom in [0.85, FollowCamera.SURFACE_ZOOM]:
			var camera := pad_top() - Vector2(0, height)
			var shown := pieces(World.DecorLayer.BACKDROP, -1, camera, zoom).filter(
				func(piece: World.Decor) -> bool: return piece.screen_area.intersects(view))
			check(not shown.is_empty(), "%s px above the pad at zoom %s, some skyline should be in view" % [height, zoom])


# The Backdrop's lights of part, by depth: a dictionary from a scroll scale's x to its pieces.
func skyline_lights(part: World.DecorPart) -> Dictionary:
	var by_scroll := {}
	for piece in pieces(World.DecorLayer.LIGHTS, part):
		if not by_scroll.has(piece.scroll_scale.x):
			by_scroll[piece.scroll_scale.x] = []
		by_scroll[piece.scroll_scale.x].append(piece)
	return by_scroll


func test_lit_windows_on_the_three_nearest_depths_get_dimmer_sparser_and_smaller_with_distance() -> void:
	await at_metropolis()
	await at_hour(1)
	var scrolls := backdrop_scrolls()
	var windows := skyline_lights(World.DecorPart.SKYLINE_WINDOWS)
	var lit_scrolls: Array = windows.keys()
	lit_scrolls.sort()
	check(lit_scrolls == scrolls.slice(scrolls.size() - 3),
		"windows should light exactly the three nearest skyline depths %s, got %s" % [scrolls.slice(scrolls.size() - 3), lit_scrolls])
	if lit_scrolls.size() != 3:
		return
	for i in 2:
		var farther: World.Decor = windows[lit_scrolls[i]][0]
		var nearer: World.Decor = windows[lit_scrolls[i + 1]][0]
		check(farther.color.get_luminance() < nearer.color.get_luminance(),
			"depth %d's windows (%s) should be dimmer than the nearer depth's (%s)" % [i, farther.color, nearer.color])
	# From the location table: the windows each skyline depth holds, farther first.
	var ridges := Location.METROPOLIS.backdrop
	var lit := ridges.filter(func(ridge: Backdrop.Ridge) -> bool: return not ridge.windows.is_empty())
	check(lit.size() == 3, "three skyline depths should hold windows, got %d" % lit.size())
	check(ridges[0].windows.is_empty(), "the farthest skyline should hold no windows")
	var solid_window: Rect2 = Location.METROPOLIS.windows[0]
	for i in lit.size():
		var ridge: Backdrop.Ridge = lit[i]
		for window in ridge.windows:
			check(window.size.x < solid_window.size.x and window.size.y < solid_window.size.y,
				"skyline windows should be smaller than the buildings' (%s), got %s" % [solid_window.size, window.size])
		if i > 0:
			var nearer: Backdrop.Ridge = lit[i]
			var farther: Backdrop.Ridge = lit[i - 1]
			check(farther.windows.size() < nearer.windows.size(),
				"a farther depth should have fewer windows (%d) than the nearer one (%d)" % [farther.windows.size(), nearer.windows.size()])
			check(farther.windows[0].size.x <= nearer.windows[0].size.x and farther.windows[0].size.y <= nearer.windows[0].size.y,
				"a farther depth's windows (%s) should be no bigger than the nearer one's (%s)" % [farther.windows[0].size, nearer.windows[0].size])


func test_skyline_windows_are_paler_than_the_buildings_windows() -> void:
	await at_metropolis()
	for hour in [1, 13]:
		await at_hour(hour)
		var solid: World.Decor = lights_of(World.DecorPart.WINDOWS)[0]
		for piece in lights_of(World.DecorPart.SKYLINE_WINDOWS):
			check(piece.color.get_luminance() < solid.color.get_luminance(),
				"at %02d:30 skyline windows (%s) should be dimmer than the buildings' (%s)" % [hour, piece.color, solid.color])
			check(piece.color.s < solid.color.s,
				"at %02d:30 skyline windows (%s) should be paler than the buildings' (%s)" % [hour, piece.color, solid.color])


func test_the_farthest_skyline_and_megastructures_carry_only_sparse_beacons() -> void:
	await at_metropolis()
	var scrolls := backdrop_scrolls()
	var beacons := skyline_lights(World.DecorPart.SKYLINE_BEACON)
	check(beacons.keys() == [scrolls[0]], "beacons should light only the farthest skyline %s, got %s" % [scrolls[0], beacons.keys()])
	var count := Location.METROPOLIS.backdrop[0].beacons.size()
	check(count >= 3 and count <= 16, "the farthest skyline should carry a few sparse beacons, got %d" % count)
	for piece in pieces(World.DecorLayer.LIGHTS):
		check(not piece.has_collider, "no skyline light should have a collider")


func test_haze_lies_between_the_skyline_depths() -> void:
	await at_metropolis()
	var scrolls := backdrop_scrolls()
	var haze := pieces(World.DecorLayer.PARALLAX, World.DecorPart.HAZE)
	var haze_scrolls: Array[float] = []
	for band in haze:
		check(band.opacity > 0.0 and band.opacity < 0.8, "a haze band should be translucent, got %s" % band.opacity)
		check(not band.has_collider, "a haze band shouldn't have a collider")
		haze_scrolls.append(band.scroll_scale.x)
	haze_scrolls.sort()
	check(haze_scrolls == scrolls.slice(1), "a haze band should lie behind each skyline depth but the farthest %s, got %s"
		% [scrolls.slice(1), haze_scrolls])


func lights() -> Array[World.Decor]:
	return pieces(World.DecorLayer.LIGHTS)


func lights_of(part: World.DecorPart) -> Array[World.Decor]:
	return pieces(World.DecorLayer.LIGHTS, part)


func test_the_city_shows_lit_windows_neon_signs_and_warning_lights_without_colliders() -> void:
	await at_metropolis()
	check(lights_of(World.DecorPart.WINDOWS).size() == 1, "the Metropolis's windows should be one piece (one mesh), got %d"
		% lights_of(World.DecorPart.WINDOWS).size())
	check(lights_of(World.DecorPart.NEON).size() >= 2, "the Metropolis should show some neon signs, got %d" % lights_of(World.DecorPart.NEON).size())
	var warning := lights_of(World.DecorPart.WARNING_LIGHT)
	check(warning.size() >= 3 and warning.size() <= 10, "the Metropolis should show a handful of warning lights, got %d" % warning.size())
	# One on the antenna's tip.
	var on_antenna := warning.filter(func(piece: World.Decor) -> bool:
		return absf(piece.screen_area.get_center().y - screen_y(Location.ANTENNA_TOP_Y)) < 8.0)
	check(not on_antenna.is_empty(), "a warning light should sit on the antenna's tip")
	for piece in lights():
		check(not piece.has_collider, "no city light should have a collider (part %d)" % piece.part)


func test_the_valley_shows_no_city_lights() -> void:
	await choose_ship()
	# Its only lights are the faint night glows in some of its Foreground crowns.
	var city := lights().filter(func(piece: World.Decor) -> bool: return piece.part != World.DecorPart.GLOW)
	check(city.is_empty(), "the Valley should show no city lights, got %d" % city.size())


# The brightest each light gets over a few seconds (the warning lights blink), by part and index.
func light_luminances() -> Array[float]:
	var brightest: Array[float] = []
	for frame in 4:
		var shown := lights()
		brightest.resize(shown.size())
		for i in shown.size():
			brightest[i] = maxf(brightest[i], shown[i].color.get_luminance() * shown[i].color.a)
		await seconds(0.5)
	return brightest


func test_city_lights_are_brighter_at_night_and_never_dimmed() -> void:
	await at_metropolis()
	await at_hour(13)
	var day := await light_luminances()
	check(not day.is_empty(), "the Metropolis should show its lights")
	for part in [World.DecorPart.SKYLINE_WINDOWS, World.DecorPart.SKYLINE_BEACON]:
		check(not lights_of(part).is_empty(), "the skyline's lights (part %d) should be among the city lights" % part)
	for hour in [3, 8, 19, 23]:
		await at_hour(hour)
		var then := await light_luminances()
		for i in mini(day.size(), then.size()):
			check(then[i] >= day[i] - 0.001, "city light %d should never be dimmer than by day (%s), at %d:30 it's %s" % [i, day[i], hour, then[i]])
			if hour == 3:
				check(then[i] > day[i] * 1.3, "city light %d should be clearly brighter at night (%s) than by day (%s)" % [i, then[i], day[i]])


func test_the_buildings_dim_with_the_scenery_at_night() -> void:
	await at_metropolis()
	var buildings := main().get_node("Terrain").get_children().filter(func(node: Node) -> bool: return node is Polygon2D)
	check(buildings.size() >= 5, "the Metropolis should have its buildings")
	await at_hour(13)
	var day := buildings.map(func(visual: Polygon2D) -> float: return shown_color(visual).get_luminance())
	await at_hour(3)
	for i in buildings.size():
		check(shown_color(buildings[i]).get_luminance() < day[i], "building %d should be darker at night than by day" % i)


func vehicles() -> Array[World.Decor]:
	return pieces(World.DecorLayer.PARALLAX, World.DecorPart.VEHICLE)


func test_distant_flying_vehicles_move_by_themselves_behind_the_city_without_colliders() -> void:
	await at_metropolis()
	var before := vehicles()
	check(before.size() >= 2, "the Metropolis should show flying vehicles, got %d" % before.size())
	await seconds(1.0)
	var after := vehicles()
	check(after.size() == before.size(), "the vehicles should stay listed as they fly")
	for i in mini(before.size(), after.size()):
		var moved := after[i].screen_area.position - before[i].screen_area.position
		check(absf(moved.x) > 5.0, "vehicle %d should fly sideways with the camera still, moved %s" % [i, moved])
		check(after[i].scroll_scale.x < 1.0, "vehicle %d should be distant, scrolling more slowly than the world: %s" % [i, after[i].scroll_scale])
		check(not after[i].has_collider, "vehicle %d shouldn't have a collider" % i)
	for piece in pieces(World.DecorLayer.LIGHTS, World.DecorPart.VEHICLE_LIGHT):
		check(not piece.has_collider, "a vehicle's light shouldn't have a collider")
	check(pieces(World.DecorLayer.LIGHTS, World.DecorPart.VEHICLE_LIGHT).size() == before.size(), "each vehicle should carry a light")


func test_the_valley_and_the_mine_show_no_flying_vehicles_or_trails() -> void:
	await choose_ship()
	for location in [Location.VALLEY, Location.MINE]:
		clock().move_to(location)
		await frames(1)
		check(vehicles().is_empty(), "%s should show no flying vehicles, got %d" % [location.name, vehicles().size()])
		check(pieces(World.DecorLayer.LIGHTS, World.DecorPart.TRAIL).is_empty(), "%s should show no Vehicle trails" % location.name)
