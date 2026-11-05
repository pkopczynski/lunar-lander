extends "res://tests/scene_test.gd"
# The Backdrop: each location's scenery behind its surface, with no collider, built when the
# World shows that location and following the sky. Read through World.shown_decor().


# The Backdrop's pieces as drawn for a camera centred on the current pad's top at zoom 1.
func backdrop() -> Array[World.Decor]:
	var pieces: Array[World.Decor] = []
	for piece in world().shown_decor(pad_top(), 1.0):
		if piece.layer == World.DecorLayer.BACKDROP:
			pieces.append(piece)
	return pieces


func pad_top() -> Vector2:
	return Vector2(pad_x(), world().location.ground_y - Lander.PAD_HEIGHT)


# A world y as it appears on screen for a camera centred on the pad's top at zoom 1.
func screen_y(world_y: float) -> float:
	return world_y - pad_top().y + world().get_viewport_rect().size.y / 2.0


func at_hour(hour: int) -> void:
	clock().minutes = hour * 60 + 30
	await frames(1)


# Checks the two Tatra-like ridges: the farther peaking at the mountain tops (Rysy), the nearer
# at Giewont, both reaching down to the location's lowest point.
func check_tatras(where: String) -> void:
	var pieces := backdrop()
	check(pieces.size() == 2, "the %s's Backdrop should be two ridges, got %d pieces" % [where, pieces.size()])
	if pieces.size() != 2:
		return
	var tops := [pieces[0].screen_area.position.y, pieces[1].screen_area.position.y]
	tops.sort()
	check_near(tops[0], screen_y(World.MOUNTAIN_TOP_Y), 0.01, "the %s's farther ridge's peak on screen" % where)
	check_near(tops[1], screen_y(248.0), 0.01, "the %s's nearer ridge's peak (Giewont) on screen" % where)
	for piece in pieces:
		check_near(piece.screen_area.end.y, screen_y(world().location.lowest_y), 0.01,
			"a %s ridge should reach down to the location's lowest point" % where)
		check(not piece.has_collider, "a %s ridge shouldn't have a collider" % where)


func test_the_valley_backdrop_is_two_tatra_ridges_without_colliders() -> void:
	await choose_ship()
	check_tatras("Valley")


func test_the_mine_shows_the_tatra_ridges_down_to_its_pit_floor() -> void:
	await choose_ship()
	clock().move_to(Location.MINE)
	await frames(1)
	check_tatras("Mine")


func test_changing_the_location_rebuilds_its_backdrop() -> void:
	await choose_ship()
	var bare := Location.new()
	bare.name = "BARE"
	bare.pad_center_x = 900.0
	bare.backdrop = [Backdrop.Ridge.new([Vector2(-World.SIDE_OVERHANG, 400), Vector2(World.WORLD_WIDTH + World.SIDE_OVERHANG, 400)], 0.1)]
	clock().move_to(bare)
	await frames(1)
	var pieces := backdrop()
	check(pieces.size() == 1, "a location with one ridge should show one Backdrop piece, got %d" % pieces.size())
	if pieces.size() == 1:
		check_near(pieces[0].screen_area.position.y, screen_y(400.0), 0.01, "the one ridge's top on screen")
	clock().move_to(Location.VALLEY)
	await frames(1)
	check_tatras("Valley, back again,")


func test_the_backdrop_follows_the_sky_a_shade_darker_than_the_gradient() -> void:
	await choose_ship()
	await at_hour(13)
	var day := backdrop()
	await at_hour(3)
	var night := backdrop()
	for i in day.size():
		check(night[i].color.get_luminance() < day[i].color.get_luminance(),
			"a ridge should be darker at 03:30 than at 13:30: %s by day, %s at night" % [day[i].color, night[i].color])
	# The nearer ridge (listed second) is a shade darker than the farther one.
	check(day[1].color.get_luminance() < day[0].color.get_luminance(),
		"the nearer ridge should be darker than the farther one: %s and %s" % [day[1].color, day[0].color])
