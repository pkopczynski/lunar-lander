extends "res://tests/scene_test.gd"
# A location can give its clouds and its flying Vehicles several depths, each scrolling at its own
# parallax and moving at its own speed, and every decor piece reports its opacity. Read through the
# World's decor listing, World.shown_decor().

const FAR := Vector2(0.3, 0.9)
const NEAR := Vector2(0.6, 0.97)


func pad_top() -> Vector2:
	return Vector2(pad_x(), world().location.ground_y - Lander.PAD_HEIGHT)


func parts(part: World.DecorPart) -> Array[World.Decor]:
	var pieces: Array[World.Decor] = []
	for piece in world().shown_decor(pad_top(), 1.0):
		if piece.part == part:
			pieces.append(piece)
	return pieces


# The Valley, with its clouds and vehicles swapped for the given ones.
func show_valley_with(clouds: Array[Clouds.Cloud], vehicles: Array[Vehicles.Vehicle]) -> void:
	var location := Location.valley()
	location.clouds = clouds
	location.vehicles = vehicles
	world().show_location(location)
	await frames(1)


func test_clouds_in_two_depths_each_scroll_and_drift_at_their_own_pace() -> void:
	await choose_ship()
	var clouds: Array[Clouds.Cloud] = [
		Clouds.Cloud.new(Vector2(900, -600), Vector2(120, 30), FAR, 4.0),
		Clouds.Cloud.new(Vector2(1300, -300), Vector2(120, 30), NEAR, 20.0),
	]
	await show_valley_with(clouds, [])
	var before := parts(World.DecorPart.CLOUD)
	check(before.size() == 2, "both clouds should be listed, got %d" % before.size())
	if before.size() != 2:
		return
	check(before[0].scroll_scale == FAR, "the far cloud should scroll at %s, got %s" % [FAR, before[0].scroll_scale])
	check(before[1].scroll_scale == NEAR, "the near cloud should scroll at %s, got %s" % [NEAR, before[1].scroll_scale])
	await seconds(2.0)
	var after := parts(World.DecorPart.CLOUD)
	var far_moved := after[0].screen_area.position.x - before[0].screen_area.position.x
	var near_moved := after[1].screen_area.position.x - before[1].screen_area.position.x
	check(far_moved > 1.0 and near_moved > 1.0, "both clouds should drift on the wind, moved %s and %s" % [far_moved, near_moved])
	check(near_moved > 3.0 * far_moved, "the near cloud's wind should carry it much faster (%s) than the far one (%s)" % [near_moved, far_moved])


func test_vehicles_in_two_depths_each_scroll_at_their_own_parallax() -> void:
	await choose_ship()
	var vehicles: Array[Vehicles.Vehicle] = [
		Vehicles.Vehicle.new(Vector2(900, 200), 30.0, FAR),
		Vehicles.Vehicle.new(Vector2(1300, 100), -50.0, NEAR),
	]
	await show_valley_with([], vehicles)
	var hulls := parts(World.DecorPart.VEHICLE)
	check(hulls.size() == 2, "both vehicles should be listed, got %d" % hulls.size())
	if hulls.size() != 2:
		return
	check(hulls[0].scroll_scale == FAR, "the far vehicle should scroll at %s, got %s" % [FAR, hulls[0].scroll_scale])
	check(hulls[1].scroll_scale == NEAR, "the near vehicle should scroll at %s, got %s" % [NEAR, hulls[1].scroll_scale])
	var lights := parts(World.DecorPart.VEHICLE_LIGHT)
	check(lights.size() == 2, "each vehicle should still carry its light, got %d" % lights.size())
	for i in mini(lights.size(), 2):
		check(lights[i].scroll_scale == hulls[i].scroll_scale, "vehicle %d's light should scroll with its hull" % i)


func test_every_decor_piece_reports_its_opacity() -> void:
	await choose_ship()
	for piece in world().shown_decor(pad_top(), 1.0):
		check(piece.opacity >= 0.0 and piece.opacity <= 1.0, "a piece's opacity should be between 0 and 1, got %s" % piece.opacity)
	for part in [World.DecorPart.RIDGE, World.DecorPart.CLOUD, World.DecorPart.SILHOUETTE]:
		for piece in parts(part):
			check_near(piece.opacity, 1.0, 0.001, "a ridge, cloud or silhouette should be opaque (part %d)" % part)
	var glows := parts(World.DecorPart.GLOW).filter(
		func(piece: World.Decor) -> bool: return piece.layer == World.DecorLayer.BEACON)
	check(not glows.is_empty(), "the Beacon should list its glows")
	for glow in glows:
		check(glow.opacity > 0.0 and glow.opacity < 0.5, "the Beacon's glow should be translucent, got %s" % glow.opacity)
