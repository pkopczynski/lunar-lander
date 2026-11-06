extends "res://tests/scene_test.gd"
# The whole surface sky: however high the ship hovers above a pad, up to just below the Border,
# some scenery is in view, and what's in view moves past at clearly different vertical speeds.
# Read through the World's decor listing, World.shown_decor().

# The zooms a climb is flown at: fast and slow.
const ZOOMS := [FollowCamera.SURFACE_ZOOM * FollowCamera.FAST_ZOOM_FACTOR, FollowCamera.SURFACE_ZOOM]
# The hours the sky tests use for full day and full night.
const HOURS := [13, 1]
const HEIGHT_STEP := 50.0
# How far below the Border the sweep stops, so the camera is still on the surface.
const BELOW_BORDER := 50.0
# How much of a piece must be on screen, in screen px each way, to count as in view.
const MIN_IN_VIEW := 20.0
# How visible a piece must be drawn to count as in view (a Moon is faint by day, but shows).
const MIN_OPACITY := 0.1
# How far, in RGB, a piece as seen (blended over the sky by its opacity) must be from the sky behind
# it to count as in view: a cloud drawn as dark as the night sky isn't seen.
const MIN_CONTRAST := 0.1
# How far apart two vertical scroll factors must be to read as clearly different speeds.
const DISTINCT_SCROLL := 0.05
# The heights the capture tool reviews, in px above the pad's top, where the scenery in view must
# move at two clearly different vertical speeds.
const REVIEWED_HEIGHTS := [0.0, 300.0, 700.0, 1200.0, 1800.0]


func pad_top() -> Vector2:
	return Vector2(pad_x(), world().location.ground_y - Lander.PAD_HEIGHT)


# Camera heights above the pad's top, from the pad up to just below the Border.
func heights() -> Array[float]:
	var list: Array[float] = []
	var top := pad_top().y - World.BORDER_Y - BELOW_BORDER
	var height := 0.0
	while height < top:
		list.append(height)
		height += HEIGHT_STEP
	list.append(top)
	return list


# The scenery in view for a camera at camera_center: every decor piece but the pad's Beacon,
# drawn visibly enough, far enough on screen, and standing out from the sky behind it.
func in_view(camera_center: Vector2, zoom: float) -> Array[World.Decor]:
	var view := world().get_viewport_rect().grow(-MIN_IN_VIEW)
	var pieces: Array[World.Decor] = []
	for piece in world().shown_decor(camera_center, zoom):
		if piece.layer == World.DecorLayer.BEACON or piece.opacity < MIN_OPACITY:
			continue
		if piece.screen_area.intersects(view) and contrast(piece, camera_center, zoom) >= MIN_CONTRAST:
			pieces.append(piece)
	return pieces


# How far a piece as seen is from the sky behind the middle of its part on screen, in RGB.
func contrast(piece: World.Decor, camera_center: Vector2, zoom: float) -> float:
	var view := world().get_viewport_rect()
	var screen_y := piece.screen_area.intersection(view).get_center().y
	var sky := world().background_color(camera_center.y + (screen_y - view.size.y / 2.0) / zoom)
	var seen := sky.lerp(Color(piece.color, 1.0), piece.opacity)
	return Vector3(seen.r - sky.r, seen.g - sky.g, seen.b - sky.b).length()


# The clearly different vertical scroll factors among pieces, each at least DISTINCT_SCROLL apart.
func distinct_vertical_scrolls(pieces: Array[World.Decor]) -> Array[float]:
	var scrolls: Array[float] = []
	for piece in pieces:
		scrolls.append(piece.scroll_scale.y)
	scrolls.sort()
	var distinct: Array[float] = []
	for scroll in scrolls:
		if distinct.is_empty() or scroll - distinct.back() >= DISTINCT_SCROLL:
			distinct.append(scroll)
	return distinct


func at(location: Location, hour: int) -> void:
	if world().location != location:
		clock().move_to(location)
	clock().minutes = hour * 60
	await frames(1)


func test_some_scenery_is_in_view_at_every_height_up_to_the_border() -> void:
	await choose_ship()
	for location in Location.ALL:
		for hour in HOURS:
			await at(location, hour)
			for zoom in ZOOMS:
				for height in heights():
					var camera := pad_top() + Vector2(0.0, -height)
					check(not in_view(camera, zoom).is_empty(),
						"at the %s at %02d:00 no scenery is in view with the camera %.0f px above the pad at zoom %s"
						% [location.name, hour, height, zoom])


func test_the_scenery_in_view_moves_at_two_clearly_different_vertical_speeds_at_several_heights() -> void:
	await choose_ship()
	for location in Location.ALL:
		for hour in HOURS:
			await at(location, hour)
			for zoom in ZOOMS:
				for height: float in REVIEWED_HEIGHTS:
					var camera := pad_top() + Vector2(0.0, -height)
					var scrolls := distinct_vertical_scrolls(in_view(camera, zoom))
					check(scrolls.size() >= 2,
						"at the %s at %02d:00 the scenery in view %.0f px above the pad at zoom %s moves at only one vertical speed: %s"
						% [location.name, hour, height, zoom, scrolls])
