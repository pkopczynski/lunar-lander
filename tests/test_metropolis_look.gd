extends "res://tests/scene_test.gd"
# The Metropolis at night: a far skyline in two depths as its Backdrop, lit windows, neon signs,
# warning lights and distant flying vehicles. Read through the World's decor listing,
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


func test_the_backdrop_is_a_skyline_in_two_depths_not_the_tatras() -> void:
	await at_metropolis()
	var layers := pieces(World.DecorLayer.BACKDROP)
	check(layers.size() == 2, "the Metropolis's Backdrop should be two layers, got %d" % layers.size())
	if layers.size() != 2:
		return
	check(layers[0].scroll_scale.x < layers[1].scroll_scale.x and layers[1].scroll_scale.x < 1.0,
		"the farther skyline should scroll more slowly than the nearer, both more slowly than the world: %s, %s"
		% [layers[0].scroll_scale, layers[1].scroll_scale])
	for i in 2:
		var skyline: Backdrop.Ridge = Location.METROPOLIS.backdrop[i]
		var highest := INF
		for j in skyline.top_edge.size() - 1:
			var step := skyline.top_edge[j + 1] - skyline.top_edge[j]
			check(step.x == 0.0 or step.y == 0.0,
				"a skyline's top edge should be only flat roofs and straight walls, segment %d of layer %d is %s" % [j, i, step])
			highest = minf(highest, skyline.top_edge[j].y)
		check(highest > World.MOUNTAIN_TOP_Y, "the skyline should stay below the mountain tops, its highest roof at %s" % highest)
		check_near(layers[i].screen_area.position.y, screen_y(highest), 0.01, "skyline layer %d's top on screen" % i)
		check(not layers[i].has_collider, "a skyline layer shouldn't have a collider")


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
	check(lights().is_empty(), "the Valley should show no city lights, got %d" % lights().size())


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
