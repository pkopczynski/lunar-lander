extends "res://tests/scene_test.gd"
# The Mine's Backdrop at scale: its tall far walls, upper benches and structures (the ropeway
# across the sky) stay around the ship well above the pad. Read through World.shown_decor().

# The window the capture tool (and a player's default window) shows the game in.
const WINDOW := Vector2(1152, 648)
# Heights of the camera above the pad's top, in px, at which the Mine should still be in view.
const HEIGHTS: Array[int] = [700, 1200]
# The least screen area, in px², a wall or structure must cover in the window to count as in view.
const MIN_SHOWN := 40.0 * 40.0


# The window, on screen, for a camera centred on the viewport's centre.
func window() -> PackedVector2Array:
	var view := Rect2(world().get_viewport_rect().size / 2.0 - WINDOW / 2.0, WINDOW)
	return PackedVector2Array([view.position, Vector2(view.end.x, view.position.y), view.end,
		Vector2(view.position.x, view.end.y)])


func area(polygon: PackedVector2Array) -> float:
	var twice := 0.0
	for i in polygon.size():
		twice += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return absf(twice) / 2.0


# How much of a piece's outline, on screen, the window shows, in px².
func shown_area(piece: World.Decor) -> float:
	var total := 0.0
	for part in Geometry2D.intersect_polygons(piece.screen_outline, window()):
		total += area(part)
	return total


# A Mine wall or structure: a Backdrop silhouette (the ropeway, conveyors), or a ridge nearer
# than the Himalaya-like peaks (the far walls and upper benches, with their facilities).
func is_wall_or_structure(piece: World.Decor) -> bool:
	return piece.layer == World.DecorLayer.BACKDROP and (piece.part == World.DecorPart.SILHOUETTE
		or piece.scroll_scale.x > Backdrop.HIMALAYA_NEAR_SCROLL.x)


func test_the_mines_walls_or_structures_are_in_view_700_and_1200_px_above_the_pad() -> void:
	await choose_ship()
	clock().move_to(Location.MINE)
	await frames(1)
	for height in HEIGHTS:
		var camera := Vector2(pad_x(), world().location.ground_y - Lander.PAD_HEIGHT - height)
		var shown := 0.0
		for piece in world().shown_decor(camera, FollowCamera.SURFACE_ZOOM):
			if is_wall_or_structure(piece):
				shown += shown_area(piece)
		check(shown >= MIN_SHOWN,
			"%d px above the Mine's pad the window should show its walls or structures (at least %d px²), shows %d px²"
			% [height, MIN_SHOWN, shown])


func test_the_mines_ropeway_and_other_backdrop_structures_have_no_collider() -> void:
	await choose_ship()
	clock().move_to(Location.MINE)
	await frames(1)
	var structures := 0
	for piece in world().shown_decor(Vector2(pad_x(), world().location.ground_y), 1.0):
		if piece.layer == World.DecorLayer.BACKDROP and piece.part == World.DecorPart.SILHOUETTE:
			structures += 1
			check(not piece.has_collider, "a Mine Backdrop structure shouldn't have a collider")
	check(structures > 0, "the Mine's Backdrop should list its structures (the ropeway) as silhouettes")
