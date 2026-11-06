extends "res://tests/scene_test.gd"
# The Approach corridor: the column above the pad, Foreground.CORRIDOR_MARGIN wider than the pad
# on each side, which no Foreground piece covers at any camera height from the pad up to the
# Border. Beside it, each Location keeps a Foreground piece in view on each side through the last
# ~500 px of the approach. Read through the World's decor listing, World.shown_decor().

# The zooms the fairness tests use: the widest, the surface zoom and the zoom punch.
const ZOOMS := [0.85, FollowCamera.SURFACE_ZOOM, FollowCamera.SURFACE_ZOOM * FollowCamera.PUNCH_ZOOM]
# The zooms a landing is flown at: the widest and the surface zoom (the punch only follows touchdown).
const APPROACH_ZOOMS := [0.85, FollowCamera.SURFACE_ZOOM]
const HEIGHT_STEP := 20.0
# How far above the pad's top a Foreground piece stays in view on each side of the corridor.
const BESIDE_HEIGHT := 500.0
# How much of a piece must be on screen, in screen px each way, to count as in view.
const MIN_IN_VIEW := 40.0
# Locations whose Foreground doesn't yet keep a piece in view on each side of the corridor through
# the last BESIDE_HEIGHT. A Location's Foreground ticket takes its name off this list; the test
# fails if a Location listed here already meets the check, so the list stays honest.
const BESIDE_PENDING: Array[String] = ["VALLEY", "MINE"]


func pad_top() -> Vector2:
	return Vector2(pad_x(), world().location.ground_y - Lander.PAD_HEIGHT)


func foreground(camera_center: Vector2, zoom: float) -> Array[World.Decor]:
	var pieces: Array[World.Decor] = []
	for piece in world().shown_decor(camera_center, zoom):
		if piece.layer == World.DecorLayer.FOREGROUND:
			pieces.append(piece)
	return pieces


# The corridor on screen for a camera at camera_center: from the pad's top up past the screen's top.
func corridor_on_screen(camera_center: Vector2, zoom: float) -> Rect2:
	var screen_center := world().get_viewport_rect().size / 2.0
	var half_width: float = Lander.PAD_WIDTH / 2.0 + Foreground.CORRIDOR_MARGIN
	var bottom_left := (pad_top() + Vector2(-half_width, 0.0) - camera_center) * zoom + screen_center
	var top := minf(0.0, bottom_left.y) - 1.0
	return Rect2(bottom_left.x, top, 2.0 * half_width * zoom, bottom_left.y - top)


# Camera heights above the pad's top, from the pad up to the Border.
func heights_to_the_border() -> Array[float]:
	var heights: Array[float] = []
	var height := 0.0
	var to_border := pad_top().y - World.BORDER_Y
	while height < to_border:
		heights.append(height)
		height += HEIGHT_STEP
	heights.append(to_border)
	return heights


func at(location: Location) -> void:
	if world().location != location:
		clock().move_to(location)
		await frames(1)


func test_the_foreground_never_covers_the_approach_corridor_from_the_pad_to_the_border() -> void:
	await choose_ship()
	for location in [Location.VALLEY, Location.MINE, Location.METROPOLIS]:
		await at(location)
		var half_pad := Lander.PAD_WIDTH / 2.0
		for zoom in ZOOMS:
			for height in heights_to_the_border():
				for side in [-half_pad, 0.0, half_pad]:
					var camera := pad_top() + Vector2(side, -height)
					var corridor := corridor_on_screen(camera, zoom)
					for piece in foreground(camera, zoom):
						check(not piece.screen_area.intersects(corridor),
							"at the %s a Foreground piece %s covers the Approach corridor %s, camera %s above the pad's top (%+.0f px sideways) at zoom %s"
							% [location.name, piece.screen_area, corridor, height, side, zoom])


# Whether, all through the last BESIDE_HEIGHT above the pad, at every zoom, at least one Foreground
# piece is in view left of the corridor and one right of it, at the zooms a landing is flown at. Lists what's missing in missing.
func foreground_beside_corridor(missing: Array[String]) -> bool:
	var view := world().get_viewport_rect()
	var height := 0.0
	while height <= BESIDE_HEIGHT:
		for zoom in APPROACH_ZOOMS:
			var camera := pad_top() + Vector2(0.0, -height)
			var corridor := corridor_on_screen(camera, zoom)
			var left := false
			var right := false
			for piece in foreground(camera, zoom):
				var shown := piece.screen_area.intersection(view)
				if shown.size.x < MIN_IN_VIEW or shown.size.y < MIN_IN_VIEW:
					continue
				left = left or piece.screen_area.end.x <= corridor.position.x
				right = right or piece.screen_area.position.x >= corridor.end.x
			if not left:
				missing.append("left at %s px, zoom %s" % [height, zoom])
			if not right:
				missing.append("right at %s px, zoom %s" % [height, zoom])
		height += HEIGHT_STEP
	return missing.is_empty()


func test_a_foreground_piece_stays_in_view_on_each_side_of_the_corridor_through_the_last_of_the_approach() -> void:
	await choose_ship()
	for location in [Location.VALLEY, Location.MINE, Location.METROPOLIS]:
		await at(location)
		var missing: Array[String] = []
		var met := foreground_beside_corridor(missing)
		if location.name in BESIDE_PENDING:
			pending("the %s's Foreground on each side of the corridor (missing %d of the views, e.g. %s)"
				% [location.name, missing.size(), missing[0] if not missing.is_empty() else "none"])
			check(not met, "the %s's Foreground now stays in view on each side of the corridor: take it off BESIDE_PENDING" % location.name)
		else:
			check(met, "at the %s no Foreground piece is in view on each side of the corridor: %s" % [location.name, ", ".join(missing.slice(0, 6))])
