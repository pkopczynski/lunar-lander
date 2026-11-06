extends "res://tests/scene_test.gd"
# Every Location's clouds in three depths: high cirrus streaks and lower cumulus heaps behind the
# scenery, filling the sky up to the Border, fixed in the world, and near translucent wisps in the Foreground, in
# front of the ship, kept out of the Approach corridor.
# Each depth drifts on its own wind, wraps around only out of sight and is tinted by the sky.
# Read through the World's decor listing, World.shown_decor().

const LOCATIONS := ["VALLEY", "MINE", "METROPOLIS"]


func pad_top() -> Vector2:
	return Vector2(pad_x(), world().location.ground_y - Lander.PAD_HEIGHT)


func location_named(location_name: String) -> Location:
	for location in Location.ALL:
		if location.name == location_name:
			return location
	return null


func at(location_name: String) -> void:
	var location := location_named(location_name)
	if world().location != location:
		clock().move_to(location)
		await frames(1)


func is_cloud(piece: World.Decor) -> bool:
	return piece.part == World.DecorPart.CLOUD or piece.part == World.DecorPart.WISP


# Every cloud and wisp, for a camera at camera_center (by default on the pad's top) at zoom.
func clouds(camera_center := pad_top(), zoom := 1.0) -> Array[World.Decor]:
	var pieces: Array[World.Decor] = []
	for piece in world().shown_decor(camera_center, zoom):
		if is_cloud(piece):
			pieces.append(piece)
	return pieces


func test_every_location_has_far_clouds_and_near_wisps() -> void:
	await choose_ship()
	for location_name in LOCATIONS:
		await at(location_name)
		var wisps := 0
		var far := 0
		for piece in clouds():
			check(not piece.has_collider, "a %s cloud should have no collider" % location_name)
			if piece.part == World.DecorPart.WISP:
				wisps += 1
				check(piece.layer == World.DecorLayer.FOREGROUND, "a %s wisp should be in the Foreground" % location_name)
				check(piece.scroll_scale.y > 1.0, "a %s wisp should scroll faster than the world, its scale %s" % [location_name, piece.scroll_scale])
			else:
				far += 1
				check(piece.layer == World.DecorLayer.PARALLAX, "a %s cloud should be behind the scenery" % location_name)
		check(wisps > 0, "the %s should have near wisps" % location_name)
		check(far > 0, "the %s should have far clouds" % location_name)


# How opaque a wisp may be at most, so the ship stays visible through it.
const WISP_MAX_OPACITY := 0.5


func test_the_wisps_are_the_only_translucent_foreground_pieces_and_the_ship_shows_through_them() -> void:
	await choose_ship()
	for location_name in LOCATIONS:
		await at(location_name)
		var seen := false
		for piece in world().shown_decor(pad_top(), 1.0):
			if piece.part == World.DecorPart.WISP:
				check(piece.opacity <= WISP_MAX_OPACITY, "a %s wisp should let the ship show through, its opacity %s" % [location_name, piece.opacity])
				seen = seen or piece.opacity > 0.1
			elif piece.layer == World.DecorLayer.FOREGROUND:
				check_near(piece.opacity, 1.0, 0.001, "a %s Foreground piece other than a wisp should be opaque (part %d)" % [location_name, piece.part])
		check(seen, "the %s's wisps should be visible, not fully faded" % location_name)


# The drift is watched sped up, each physics frame DRIFT_STEP s of wind, for up to DRIFT_LIMIT s,
# until every cloud has wrapped around at least once.
const DRIFT_STEP := 2.0
const DRIFT_LIMIT := 2500.0
# How far a cloud must jump on screen between two frames to count as wrapped around, in screen px.
const WRAP_JUMP := 1000.0
# The cameras the wraps must stay out of sight of: over the pad, at its top, midway and high up.
const VIEW_HEIGHTS := [0.0, 800.0, 1600.0]
const VIEW_ZOOM := 0.85
# The cameras the wisps must stay out of the Approach corridor for, as they drift: a little to
# either side of the pad, at heights where wisps are about.
const CORRIDOR_HEIGHTS := [800.0, 1400.0, 2000.0]
const CORRIDOR_SIDE := 60.0
# A wisp fading in or out this faintly, as it wraps, doesn't pop into view. (The drift is watched
# in steps of DRIFT_STEP, so a wisp is caught a little into its fade.)
const OPACITY_UNSEEN := 0.05


# The corridor on screen for a camera at camera_center: from the pad's top up past the screen's top.
func corridor_on_screen(camera_center: Vector2, zoom: float) -> Rect2:
	var screen_center := world().get_viewport_rect().size / 2.0
	var half_width: float = Lander.PAD_WIDTH / 2.0 + Foreground.CORRIDOR_MARGIN
	var bottom_left := (pad_top() + Vector2(-half_width, 0.0) - camera_center) * zoom + screen_center
	var top := minf(0.0, bottom_left.y) - 1.0
	return Rect2(bottom_left.x, top, 2.0 * half_width * zoom, bottom_left.y - top)


func shown(piece: World.Decor) -> bool:
	return piece.opacity > OPACITY_UNSEEN and piece.screen_area.intersects(world().get_viewport_rect())


func check_wisps_beside_the_corridor(location_name: String, drifted: float) -> void:
	var to_border := pad_top().y - World.BORDER_Y
	for height: float in CORRIDOR_HEIGHTS:
		for side in [-CORRIDOR_SIDE, CORRIDOR_SIDE]:
			var camera := pad_top() + Vector2(side, -minf(height, to_border))
			var corridor := corridor_on_screen(camera, VIEW_ZOOM)
			for piece in clouds(camera, VIEW_ZOOM):
				if piece.part == World.DecorPart.WISP and piece.screen_area.intersects(corridor):
					check(false, "at the %s a wisp %s drifts into the Approach corridor %s after %s s, camera %s"
						% [location_name, piece.screen_area, corridor, drifted, camera])
					return


func test_the_clouds_drift_wrap_around_only_out_of_sight_and_the_wisps_never_enter_the_corridor() -> void:
	await choose_ship()
	for location_name in LOCATIONS:
		await at(location_name)
		# Held on the pad, so the location never drifts on.
		lander().reset_to_pad()
		lander().hold()
		var cameras: Array[Vector2] = []
		for height: float in VIEW_HEIGHTS:
			cameras.append(pad_top() + Vector2(0.0, -height))
		var before: Array = cameras.map(func(camera: Vector2) -> Array[World.Decor]: return clouds(camera, VIEW_ZOOM))
		var wrapped: Array[bool] = []
		wrapped.resize(before[0].size())
		wrapped.fill(false)
		var drifted := 0.0
		Engine.time_scale = DRIFT_STEP * PHYSICS_FPS
		while drifted < DRIFT_LIMIT and not wrapped.all(func(done: bool) -> bool: return done):
			await frames(1)
			drifted += DRIFT_STEP
			var after: Array = cameras.map(func(camera: Vector2) -> Array[World.Decor]: return clouds(camera, VIEW_ZOOM))
			for i in wrapped.size():
				if absf(after[0][i].screen_area.position.x - before[0][i].screen_area.position.x) < WRAP_JUMP:
					continue
				wrapped[i] = true
				for c in cameras.size():
					check(not shown(before[c][i]) and not shown(after[c][i]),
						"at the %s a cloud wraps around in sight, from %s to %s, camera %s"
						% [location_name, before[c][i].screen_area, after[c][i].screen_area, cameras[c]])
			check_wisps_beside_the_corridor(location_name, drifted)
			before = after
		Engine.time_scale = 1.0
		check(wrapped.all(func(done: bool) -> bool: return done),
			"at the %s every cloud should drift on the wind and wrap around within %s s" % [location_name, DRIFT_LIMIT])


func at_hour(hour: int) -> void:
	clock().minutes = hour * 60 + 30
	await frames(1)


# How yellow a colour is: its red and green over its blue.
func yellowness(color: Color) -> float:
	return (color.r + color.g) / 2.0 - color.b


func test_every_cloud_depth_is_tinted_by_the_sky_at_every_hour() -> void:
	await choose_ship()
	for location_name in LOCATIONS:
		await at(location_name)
		var by_hour := {}
		for hour in [3, 8, 13, 19]:
			await at_hour(hour)
			by_hour[hour] = clouds()
		var day: Array[World.Decor] = by_hour[13]
		for i in day.size():
			var night: World.Decor = by_hour[3][i]
			var dawn: World.Decor = by_hour[8][i]
			var evening: World.Decor = by_hour[19][i]
			var what := "a %s %s" % [location_name, "wisp" if day[i].part == World.DecorPart.WISP else "cloud"]
			check(day[i].color.b > day[i].color.r, "%s should be bluish by day, %s" % [what, day[i].color])
			check(yellowness(dawn.color) > yellowness(day[i].color),
				"%s should turn yellow at dawn (%s) from blue by day (%s)" % [what, dawn.color, day[i].color])
			check(evening.color.r > day[i].color.r and evening.color.b < day[i].color.b,
				"%s should turn orange in the evening (%s) from blue by day (%s)" % [what, evening.color, day[i].color])
			check(night.color.get_luminance() < 0.5 * day[i].color.get_luminance(),
				"%s should darken with the sky at night (%s) from by day (%s)" % [what, night.color, day[i].color])


# The zooms the camera can show the sky at: the widest a fast ship in deep space gets, the widest
# on the surface and the surface zoom.
const SKY_ZOOMS := [FollowCamera.DEEP_SPACE_ZOOM * FollowCamera.FAST_ZOOM_FACTOR, 0.85, FollowCamera.SURFACE_ZOOM]
const SPACE_HEIGHT_STEP := 40.0
const SPACE_REACH := 2500.0


func test_no_cloud_ever_shows_in_deep_space() -> void:
	await choose_ship()
	var view := world().get_viewport_rect()
	for location_name in LOCATIONS:
		await at(location_name)
		for zoom: float in SKY_ZOOMS:
			var above := 0.0
			while above <= SPACE_REACH:
				var camera := Vector2(pad_x(), World.BORDER_Y - above)
				var border_on_screen := (World.BORDER_Y - camera.y) * zoom + view.size.y / 2.0
				for piece in clouds(camera, zoom):
					if piece.opacity > 0.0 and piece.screen_area.intersects(view):
						check(piece.screen_area.position.y >= border_on_screen,
							"at the %s a cloud %s shows above the Border (screen y %s), camera %s px above it at zoom %s"
							% [location_name, piece.screen_area, border_on_screen, above, zoom])
				above += SPACE_HEIGHT_STEP


# The far clouds are fixed in the world: they pass by on screen like the ground as the ship flies
# around (only the wind carries them).
func test_the_far_clouds_stay_in_their_spot_in_the_sky_as_the_ship_flies_around() -> void:
	await choose_ship()
	var flown := Vector2(300.0, -1000.0)
	for location_name in LOCATIONS:
		await at(location_name)
		var on_pad := clouds()
		var elsewhere := clouds(pad_top() + flown)
		for i in mini(on_pad.size(), elsewhere.size()):
			if on_pad[i].part != World.DecorPart.CLOUD:
				continue
			var moved := elsewhere[i].screen_area.position - on_pad[i].screen_area.position
			check(on_pad[i].scroll_scale == Vector2.ONE, "a %s cloud should have no parallax, its scale %s" % [location_name, on_pad[i].scroll_scale])
			check(moved.distance_to(-flown) < 0.5,
				"a %s cloud should pass by like the ground as the ship flies 1000 px up and 300 px across, moved %s" % [location_name, moved])


# The far clouds fill the sky as the ship climbs: some in the lower, middle and upper part of the
# climb from the pad's top to the Border.
func test_the_far_clouds_fill_the_sky_up_to_the_border() -> void:
	await choose_ship()
	for location_name in LOCATIONS:
		await at(location_name)
		var to_border := pad_top().y - World.BORDER_Y
		var thirds := [0, 0, 0]
		for piece in clouds():
			if piece.part != World.DecorPart.CLOUD:
				continue
			# Seen with the camera on the pad's top at zoom 1, the screen's middle is the pad's top.
			var above := (world().get_viewport_rect().size.y / 2.0 - piece.screen_area.get_center().y) / to_border
			thirds[clampi(floori(above * 3.0), 0, 2)] += 1
		for third in 3:
			check(thirds[third] > 5, "the %s should have far clouds in each third of its climb to the Border, got %s" % [location_name, thirds])


# How flat a cloud is: its height over its width on screen.
func flatness(piece: World.Decor) -> float:
	return piece.screen_area.size.y / piece.screen_area.size.x


# A cirrus streak is far flatter than any cumulus heap.
const STREAK_FLATNESS := 0.15


func mean_center_y(pieces: Array[World.Decor]) -> float:
	var total := 0.0
	for piece in pieces:
		total += piece.screen_area.get_center().y
	return total / maxi(pieces.size(), 1)


func test_thin_cirrus_streaks_sit_above_heaped_cumulus() -> void:
	await choose_ship()
	for location_name in LOCATIONS:
		await at(location_name)
		var cirrus: Array[World.Decor] = []
		var cumulus: Array[World.Decor] = []
		for piece in clouds():
			if piece.part == World.DecorPart.CLOUD:
				if flatness(piece) < STREAK_FLATNESS:
					cirrus.append(piece)
				else:
					cumulus.append(piece)
		check(not cirrus.is_empty() and not cumulus.is_empty(),
			"the %s should have both thin streaks (%d) and heaps (%d)" % [location_name, cirrus.size(), cumulus.size()])
		check(mean_center_y(cirrus) < mean_center_y(cumulus),
			"the %s's thin streaks should sit higher (screen y %.0f) than its heaps (%.0f)" % [location_name, mean_center_y(cirrus), mean_center_y(cumulus)])
		for piece in cirrus:
			check(piece.opacity < 1.0, "a %s cirrus streak should be translucent, its opacity %s" % [location_name, piece.opacity])


# A cloud whose outline crosses itself can't be filled, and isn't drawn at all.
func test_every_cloud_is_drawn() -> void:
	await choose_ship()
	for location_name in LOCATIONS:
		await at(location_name)
		for piece in clouds():
			check(piece.screen_outline.size() >= 3 and not Geometry2D.triangulate_polygon(piece.screen_outline).is_empty(),
				"a %s cloud's outline should be fillable, at %s" % [location_name, piece.screen_area])
