extends "res://tests/scene_test.gd"
# The Valley's Foreground: sequoia stands, among other trees and shrubs, rising from one continuous
# near ground on each side of the Approach corridor, the tallest crowns reaching well above the
# pad and some glowing faintly at night. Read through the World's decor listing,
# World.shown_decor(), and the Valley's Foreground silhouettes.

# How far above the pad's top the tallest crowns still reach the ship's height on screen.
const CROWN_REACH := 600.0


func pad_top() -> Vector2:
	return Vector2(pad_x(), world().location.ground_y - Lander.PAD_HEIGHT)


func foreground(part: World.DecorPart, camera_center := pad_top(), zoom := 1.0) -> Array[World.Decor]:
	var pieces: Array[World.Decor] = []
	for piece in world().shown_decor(camera_center, zoom):
		if piece.layer == World.DecorLayer.FOREGROUND and piece.part == part:
			pieces.append(piece)
	return pieces


func at_hour(hour: int) -> void:
	clock().minutes = hour * 60 + 30
	await frames(1)


func test_the_valley_foreground_rises_from_a_near_ground_that_never_shows_a_side() -> void:
	await choose_ship()
	# The camera never shows below the location's lowest point, and the Foreground only ever moves
	# down from where it was designed, so an edge starting and ending below it never shows a side.
	var lowest := world().location.lowest_y
	check(not Location.VALLEY.foreground.is_empty(), "the Valley should have Foreground silhouettes")
	for silhouette in Location.VALLEY.foreground:
		var edge := silhouette.top_edge
		check(edge[0].y > lowest and edge[-1].y > lowest,
			"a Valley Foreground silhouette should start and end below the lowest point %s, its ends %s and %s" % [lowest, edge[0], edge[-1]])


func test_the_tallest_crowns_reach_the_ship_well_above_the_pad() -> void:
	await choose_ship()
	var camera := pad_top() + Vector2(0.0, -CROWN_REACH)
	var ship_y := world().get_viewport_rect().size.y / 2.0
	for zoom in [0.85, FollowCamera.SURFACE_ZOOM]:
		var reaching := foreground(World.DecorPart.SILHOUETTE, camera, zoom).filter(
			func(piece: World.Decor) -> bool: return piece.screen_area.position.y < ship_y)
		check(not reaching.is_empty(), "a Valley crown should reach the ship's height %s px above the pad at zoom %s" % [CROWN_REACH, zoom])


func test_some_crowns_glow_faintly_at_night_and_not_by_day() -> void:
	await choose_ship()
	await at_hour(13)
	var by_day := foreground(World.DecorPart.GLOW)
	await at_hour(1)
	var at_night := foreground(World.DecorPart.GLOW)
	check(by_day.size() >= 2, "some Valley crowns should have a glow, got %d" % by_day.size())
	for glow in by_day:
		check(glow.opacity == 0.0, "a crown's glow should be off by day, its opacity %s" % glow.opacity)
	for glow in at_night:
		check(glow.opacity > 0.05 and glow.opacity < 0.5, "a crown's glow should be faint at night, its opacity %s" % glow.opacity)
