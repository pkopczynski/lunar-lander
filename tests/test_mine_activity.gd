extends "res://tests/scene_test.gd"
# Signs of work in the Mine: red warning lights blinking on its Backdrop's structures, brighter at
# night, and a few slow movers (a crane trolley, a hauler, a conveyor's marks) moving by themselves.
# None has a collider, and no other Location shows them. Read through World.shown_decor().


func pad_top() -> Vector2:
	return Vector2(pad_x(), world().location.ground_y - Lander.PAD_HEIGHT)


func pieces(layer: World.DecorLayer, part: World.DecorPart) -> Array[World.Decor]:
	var found: Array[World.Decor] = []
	for piece in world().shown_decor(pad_top(), 1.0):
		if piece.layer == layer and piece.part == part:
			found.append(piece)
	return found


# The warning lights on the Mine's Backdrop: unlike the city's, they scroll with its far layers.
func mine_lights() -> Array[World.Decor]:
	return pieces(World.DecorLayer.LIGHTS, World.DecorPart.WARNING_LIGHT).filter(
		func(piece: World.Decor) -> bool: return piece.scroll_scale.x < 1.0)


func movers() -> Array[World.Decor]:
	return pieces(World.DecorLayer.BACKDROP, World.DecorPart.MOVER)


func at(location: Location) -> void:
	clock().move_to(location)
	await frames(1)


func at_hour(hour: int) -> void:
	clock().minutes = hour * 60 + 30
	await frames(1)


# Each light's brightness as drawn (luminance times opacity), sampled over a couple of blinks.
func light_samples() -> Array[PackedFloat32Array]:
	var samples: Array[PackedFloat32Array] = []
	for frame in 12:
		var shown := mine_lights()
		samples.resize(shown.size())
		for i in shown.size():
			samples[i].append(shown[i].color.get_luminance() * shown[i].color.a)
		await seconds(0.25)
	return samples


func brightest(samples: PackedFloat32Array) -> float:
	var most := 0.0
	for sample in samples:
		most = maxf(most, sample)
	return most


func test_the_mine_lists_warning_lights_that_blink_by_themselves_and_are_brighter_at_night() -> void:
	await choose_ship()
	await at(Location.MINE)
	await at_hour(13)
	var day := await light_samples()
	check(day.size() >= 3 and day.size() <= 12, "the Mine should show a handful of warning lights, got %d" % day.size())
	for i in day.size():
		var dimmest := INF
		for sample in day[i]:
			dimmest = minf(dimmest, sample)
		check(brightest(day[i]) > dimmest * 2.0, "Mine warning light %d should blink on and off by itself, %s" % [i, day[i]])
	for piece in mine_lights():
		check(piece.color.r > 2.0 * piece.color.g and piece.color.r > 2.0 * piece.color.b, "a Mine warning light should be red, got %s" % piece.color)
	await at_hour(3)
	var night := await light_samples()
	for i in mini(day.size(), night.size()):
		check(brightest(night[i]) > brightest(day[i]) * 1.3,
			"Mine warning light %d should be clearly brighter at night (%s) than by day (%s)" % [i, brightest(night[i]), brightest(day[i])])


func test_the_mines_slow_movers_move_by_themselves_on_its_backdrop() -> void:
	await choose_ship()
	await at(Location.MINE)
	var before := movers()
	check(before.size() >= 3 and before.size() <= 10, "the Mine should show a few slow movers, got %d" % before.size())
	await seconds(2.0)
	var after := movers()
	check(after.size() == before.size(), "the movers should stay listed as they move")
	for i in mini(before.size(), after.size()):
		var moved := after[i].screen_area.get_center().distance_to(before[i].screen_area.get_center())
		check(moved > 2.0, "mover %d should move by itself with the camera still, moved %.1f px in 2 s" % [i, moved])
		check(moved < 80.0, "mover %d should move slowly, moved %.1f px in 2 s" % [i, moved])
		check(after[i].scroll_scale.x < 1.0, "mover %d should be on the Backdrop, scrolling more slowly than the world: %s"
			% [i, after[i].scroll_scale])


func test_no_mine_light_or_mover_has_a_collider() -> void:
	await choose_ship()
	await at(Location.MINE)
	var signs := mine_lights() + movers()
	check(not signs.is_empty(), "the Mine should list its lights and movers")
	for piece in signs:
		check(not piece.has_collider, "a Mine light or mover shouldn't have a collider (part %d)" % piece.part)


func test_the_valley_and_the_metropolis_show_none_of_the_mines_lights_or_movers() -> void:
	await choose_ship()
	# Shown after the Mine, so its pieces must go when another Location is built.
	await at(Location.MINE)
	for location: Location in [Location.VALLEY, Location.METROPOLIS]:
		await at(location)
		check(movers().is_empty(), "the %s should show no movers, got %d" % [location.name, movers().size()])
		check(mine_lights().is_empty(), "the %s should show none of the Mine's warning lights, got %d" % [location.name, mine_lights().size()])
