extends "res://tests/scene_test.gd"
# The Metropolis's Vehicles fly in lanes at several heights and depths, up to about two-thirds of
# the way from the pad to the Border, each leaving a fading trail of light. Read through the
# World's decor listing, World.shown_decor().

# How high the highest lane may be, as a share of the way from the pad to the Border.
const HIGHEST_LANE_MIN := 0.55
const HIGHEST_LANE_MAX := 0.75


func pad_top() -> Vector2:
	return Vector2(pad_x(), world().location.ground_y - Lander.PAD_HEIGHT)


func parts(part: World.DecorPart, camera_center := pad_top()) -> Array[World.Decor]:
	var found: Array[World.Decor] = []
	for piece in world().shown_decor(camera_center, 1.0):
		if piece.part == part:
			found.append(piece)
	return found


func at_metropolis() -> void:
	await choose_ship()
	clock().move_to(Location.METROPOLIS)
	await frames(1)


func pad_to_border() -> float:
	return pad_top().y - World.BORDER_Y


# How high above the pad's top the camera must climb for a piece to sit at the middle of the screen
# (the camera's height): a piece in a parallax layer comes down the screen more slowly than the
# world as the camera climbs, by its vertical scroll scale.
func lane_height(piece: World.Decor) -> float:
	var screen_middle := world().get_viewport_rect().size.y / 2.0
	return (screen_middle - piece.screen_area.get_center().y) / piece.scroll_scale.y


func test_vehicles_fly_in_lanes_at_several_heights_and_depths_up_to_two_thirds_of_the_way_to_the_border() -> void:
	await at_metropolis()
	var hulls := parts(World.DecorPart.VEHICLE)
	var heights: Array[float] = []
	var depths: Array[Vector2] = []
	for hull in hulls:
		var height := lane_height(hull)
		if not heights.any(func(other: float) -> bool: return absf(other - height) < 40.0):
			heights.append(height)
		if not depths.has(hull.scroll_scale):
			depths.append(hull.scroll_scale)
	check(heights.size() >= 5, "the Vehicles should fly in lanes at several heights, got %d: %s" % [heights.size(), heights])
	check(depths.size() >= 3, "the Vehicles should fly at several depths, got %d: %s" % [depths.size(), depths])
	var highest: float = heights.max() if not heights.is_empty() else 0.0
	check(highest > HIGHEST_LANE_MIN * pad_to_border() and highest < HIGHEST_LANE_MAX * pad_to_border(),
		"the highest lane should be about two-thirds of the way to the Border (%d px), got %d px" % [pad_to_border(), highest])


func test_climbing_to_two_thirds_of_the_way_to_the_border_a_vehicle_lane_is_always_in_view() -> void:
	await at_metropolis()
	var view_height := world().get_viewport_rect().size.y
	var top := HIGHEST_LANE_MIN * pad_to_border()
	for step in range(0, int(top) + 1, 50):
		var camera := pad_top() - Vector2(0, step)
		var in_view := parts(World.DecorPart.VEHICLE, camera).any(
			func(hull: World.Decor) -> bool: return hull.screen_area.position.y > 0.0 and hull.screen_area.end.y < view_height)
		check(in_view, "a Vehicle lane should be in view with the camera %d px above the pad" % step)


func test_each_vehicle_leaves_a_fading_trail_of_light_behind_it_without_a_collider() -> void:
	await at_metropolis()
	var before_hulls := parts(World.DecorPart.VEHICLE)
	var before_trails := parts(World.DecorPart.TRAIL)
	check(before_trails.size() == before_hulls.size(),
		"each of the %d Vehicles should have one trail, got %d trails" % [before_hulls.size(), before_trails.size()])
	if before_trails.size() != before_hulls.size():
		return
	await seconds(0.5)
	var hulls := parts(World.DecorPart.VEHICLE)
	var trails := parts(World.DecorPart.TRAIL)
	var lengths: Array[int] = []
	for i in hulls.size():
		var hull := hulls[i]
		var trail := trails[i]
		check(trail.scroll_scale == hull.scroll_scale, "trail %d should be at its Vehicle's depth" % i)
		var flew := hull.screen_area.position.x - before_hulls[i].screen_area.position.x
		var trail_moved := trail.screen_area.position.x - before_trails[i].screen_area.position.x
		check_near(trail_moved, flew, 0.01, "trail %d should fly with its Vehicle" % i)
		# Behind the Vehicle: on the side it flies away from, starting at its hull.
		var behind := trail.screen_area.get_center().x < hull.screen_area.get_center().x if flew > 0.0 \
			else trail.screen_area.get_center().x > hull.screen_area.get_center().x
		check(behind, "trail %d should stream behind its Vehicle" % i)
		check(trail.screen_area.intersects(hull.screen_area, true), "trail %d should start at its Vehicle's hull" % i)
		check(trail.screen_area.size.x > 2.0 * hull.screen_area.size.x, "trail %d should be long, got %s" % [i, trail.screen_area.size])
		check(trail.opacity > 0.0 and trail.opacity < 0.6, "trail %d should fade out, as drawn %s" % [i, trail.opacity])
		check(not trail.has_collider, "trail %d shouldn't have a collider" % i)
		if not lengths.has(int(trail.screen_area.size.x / 10.0)):
			lengths.append(int(trail.screen_area.size.x / 10.0))
	check(lengths.size() >= 3, "the trails should vary in length, got %s (tens of px)" % [lengths])


# A Vehicle and its trail, as one area on screen.
func whole(hull: World.Decor, trail: World.Decor) -> Rect2:
	return hull.screen_area.merge(trail.screen_area)


func test_vehicles_wrap_around_with_their_trails_out_of_sight() -> void:
	await choose_ship()
	# Two Vehicles about to wrap around, one each way, at the Metropolis's fastest lane's speed.
	var location := Location.valley()
	location.vehicles = [
		Vehicles.Vehicle.new(Vector2(DecorKit.WRAP_LEFT + DecorKit.WRAP_WIDTH - 20.0, 100), 80.0, Location.VEHICLE_NEAR),
		Vehicles.Vehicle.new(Vector2(DecorKit.WRAP_LEFT + 20.0, 200), -80.0, Location.VEHICLE_FAR),
	]
	world().show_location(location)
	await frames(1)
	var view := Rect2(Vector2.ZERO, world().get_viewport_rect().size)
	var cameras: Array[Vector2] = [Vector2(0, pad_top().y), pad_top(), Vector2(World.WORLD_WIDTH, pad_top().y)]
	var zooms: Array[float] = [0.8, 1.0]
	var previous := {}
	var wrapped := [false, false]
	for frame in 40:
		for camera in cameras:
			for zoom in zooms:
				var pieces := world().shown_decor(camera, zoom)
				var hulls := pieces.filter(func(piece: World.Decor) -> bool: return piece.part == World.DecorPart.VEHICLE)
				var trails := pieces.filter(func(piece: World.Decor) -> bool: return piece.part == World.DecorPart.TRAIL)
				for i in hulls.size():
					var now := whole(hulls[i], trails[i])
					var key := [camera, zoom, i]
					if previous.has(key) and absf(now.position.x - previous[key].position.x) > 100.0:
						wrapped[i] = true
						check(not now.intersects(view) and not previous[key].intersects(view),
							"Vehicle %d should wrap around out of sight (camera %s, zoom %s): %s to %s" % [i, camera, zoom, previous[key], now])
					previous[key] = now
		await frames(1)
	check(wrapped == [true, true], "both Vehicles should have wrapped around, got %s" % [wrapped])
