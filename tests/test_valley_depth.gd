extends "res://tests/scene_test.gd"
# The Valley's depth: its Backdrop ridges in parallax layers moving more slowly than the world,
# clouds drifting on the wind, and a near-black Foreground moving faster than the world, in front
# of the ship. Read through the World's decor listing, World.shown_decor().


func pad_top() -> Vector2:
	return Vector2(pad_x(), world().location.ground_y - Lander.PAD_HEIGHT)


func pieces_in(layer: World.DecorLayer, camera_center := pad_top(), zoom := 1.0) -> Array[World.Decor]:
	var pieces: Array[World.Decor] = []
	for piece in world().shown_decor(camera_center, zoom):
		if piece.layer == layer:
			pieces.append(piece)
	return pieces


func test_the_valley_lists_parallax_ridges_clouds_and_a_foreground_without_colliders() -> void:
	await choose_ship()
	var ridges := pieces_in(World.DecorLayer.BACKDROP)
	var clouds := pieces_in(World.DecorLayer.PARALLAX).filter(
		func(piece: World.Decor) -> bool: return piece.part == World.DecorPart.CLOUD)
	var foreground := pieces_in(World.DecorLayer.FOREGROUND)
	check(ridges.size() == 2, "the Valley should show two Backdrop ridges, got %d" % ridges.size())
	check(clouds.size() >= 3, "the Valley should show some clouds, got %d" % clouds.size())
	check(foreground.size() >= 2, "the Valley should show some Foreground pieces, got %d" % foreground.size())
	for piece in ridges + clouds:
		check(piece.scroll_scale.x < 1.0, "a ridge or cloud should scroll more slowly than the world, its scale %s" % piece.scroll_scale)
	for piece in foreground:
		check(piece.scroll_scale.x > 1.0, "a Foreground piece should scroll faster than the world, its scale %s" % piece.scroll_scale)
	for piece in world().shown_decor(pad_top(), 1.0):
		check(not piece.has_collider, "no decor piece should have a collider (layer %d, part %d)" % [piece.layer, piece.part])


# The bounding box of a designed top edge, closed down out of sight, as it appears on screen for a
# camera centred on the pad's top: x and the top only (the bottom is below the view).
func designed_top_area(top_edge: Array, zoom: float) -> Rect2:
	var screen_center := world().get_viewport_rect().size / 2.0
	var area := Rect2()
	for i in top_edge.size():
		var on_screen: Vector2 = (top_edge[i] - pad_top()) * zoom + screen_center
		area = Rect2(on_screen, Vector2.ZERO) if i == 0 else area.expand(on_screen)
	return area


func test_with_the_camera_on_the_pad_every_layer_sits_where_it_was_designed() -> void:
	await choose_ship()
	for zoom in [0.85, FollowCamera.SURFACE_ZOOM, FollowCamera.SURFACE_ZOOM * FollowCamera.PUNCH_ZOOM]:
		var stands := pieces_in(World.DecorLayer.FOREGROUND, pad_top(), zoom)
		var designed := [designed_top_area(Foreground.VALLEY_LEFT_STAND, zoom), designed_top_area(Foreground.VALLEY_RIGHT_STAND, zoom)]
		check(stands.size() == designed.size(), "the Valley should show its two spruce stands, got %d" % stands.size())
		for i in mini(stands.size(), designed.size()):
			var area := stands[i].screen_area
			check_near(area.position.x, designed[i].position.x, 0.01, "spruce stand %d's left edge at zoom %s" % [i, zoom])
			check_near(area.end.x, designed[i].end.x, 0.01, "spruce stand %d's right edge at zoom %s" % [i, zoom])
			check_near(area.position.y, designed[i].position.y, 0.01, "spruce stand %d's top at zoom %s" % [i, zoom])
		var ridges := pieces_in(World.DecorLayer.BACKDROP, pad_top(), zoom)
		var tops := ridges.map(func(piece: World.Decor) -> float: return piece.screen_area.position.y)
		tops.sort()
		var screen_center_y := world().get_viewport_rect().size.y / 2.0
		check_near(tops[0], (World.MOUNTAIN_TOP_Y - pad_top().y) * zoom + screen_center_y, 0.01, "the farther ridge's peak at zoom %s" % zoom)
		check_near(tops[1], (248.0 - pad_top().y) * zoom + screen_center_y, 0.01, "Giewont's peak at zoom %s" % zoom)


# How far a piece moves on screen when the camera moves by camera_move from the pad's top.
func screen_shift(piece_index: int, layer: World.DecorLayer, camera_move: Vector2) -> Vector2:
	var before := pieces_in(layer, pad_top())[piece_index].screen_area.position
	var after := pieces_in(layer, pad_top() + camera_move)[piece_index].screen_area.position
	return after - before


func test_ridges_move_more_slowly_than_the_world_and_the_foreground_faster() -> void:
	await choose_ship()
	# At zoom 1 the world itself shifts on screen by exactly as much as the camera moves, the other way.
	var sideways := Vector2(300, 0)
	for i in 2:
		var ridge := screen_shift(i, World.DecorLayer.BACKDROP, sideways)
		check(ridge.x < 0.0 and -ridge.x < 300.0 * 0.9, "ridge %d should move left, but well under the world's 300 px: %s" % [i, ridge])
		check_near(ridge.y, 0.0, 0.01, "ridge %d shouldn't move up or down when the camera moves sideways" % i)
		var stand := screen_shift(i, World.DecorLayer.FOREGROUND, sideways)
		check(-stand.x > 300.0 * 1.1, "spruce stand %d should move left more than the world's 300 px: %s" % [i, stand])
	# Climbing, the layers move almost as the world does: the ridges barely rise into the sky.
	var up := Vector2(0, -1000)
	for i in 2:
		var ridge := screen_shift(i, World.DecorLayer.BACKDROP, up)
		check(ridge.y > 1000.0 * 0.9 and ridge.y < 1000.0, "ridge %d should sink a little less than the world's 1000 px: %s" % [i, ridge])
		var stand := screen_shift(i, World.DecorLayer.FOREGROUND, up)
		check(stand.y > 1000.0 and stand.y < 1000.0 * 1.1, "spruce stand %d should sink a little more than the world's 1000 px: %s" % [i, stand])


# Room around the ship, which the camera centres on, in world px: more than any ship type's size.
const SHIP_ROOM := 40.0


# How far to either side of the pad the edge of solid terrain counts as near it, in world px.
const TERRAIN_EDGE_REACH := 250.0
const TERRAIN_EDGE_STEP := 5.0


# Points along the edge of the solid surface near the pad: the outlines of the location's terrain
# (and the top of its ground) within TERRAIN_EDGE_REACH to either side of the pad and from
# Foreground.FAIR_HEIGHT above its top down to the ground's top.
func terrain_edge_near_pad() -> PackedVector2Array:
	var near := Rect2(pad_top() + Vector2(-TERRAIN_EDGE_REACH, -Foreground.FAIR_HEIGHT),
		Vector2(2.0 * TERRAIN_EDGE_REACH, Foreground.FAIR_HEIGHT + Lander.PAD_HEIGHT + 0.01))
	var outlines: Array[PackedVector2Array] = world().location.terrain.duplicate()
	var half_ground := minf(TERRAIN_EDGE_REACH, world().location.ground_width / 2.0)
	var ground_y := world().location.ground_y
	outlines.append(PackedVector2Array([Vector2(pad_x() - half_ground, ground_y), Vector2(pad_x() + half_ground, ground_y)]))
	var points := PackedVector2Array()
	for outline in outlines:
		for i in outline.size():
			var from := outline[i]
			var to := outline[(i + 1) % outline.size()]
			var steps := maxi(1, ceili(from.distance_to(to) / TERRAIN_EDGE_STEP))
			for step in steps + 1:
				var point := from.lerp(to, float(step) / steps)
				if near.has_point(point):
					points.append(point)
	return points


# Checks that, with the camera following the ship anywhere in the last Foreground.FAIR_HEIGHT above
# the pad (a little to either side too), no Foreground piece covers the pad, the ship or the edge
# of solid terrain near the pad, at the widest zoom, the surface zoom and the zoom punch.
func check_foreground_is_fair(where: String) -> void:
	var screen_center := world().get_viewport_rect().size / 2.0
	var half_pad := Lander.PAD_WIDTH / 2.0
	var edge := terrain_edge_near_pad()
	for zoom in [0.85, FollowCamera.SURFACE_ZOOM, FollowCamera.SURFACE_ZOOM * FollowCamera.PUNCH_ZOOM]:
		for height in [0.0, Foreground.FAIR_HEIGHT / 2.0, Foreground.FAIR_HEIGHT]:
			for side in [-half_pad, 0.0, half_pad]:
				var camera := pad_top() + Vector2(side, -height)
				var pad_area := Rect2((Vector2(-half_pad, 0) + pad_top() - camera) * zoom + screen_center,
					Vector2(Lander.PAD_WIDTH, Lander.PAD_HEIGHT) * zoom)
				var ship_area := Rect2(screen_center - Vector2.ONE * SHIP_ROOM * zoom, Vector2.ONE * 2.0 * SHIP_ROOM * zoom)
				for piece in pieces_in(World.DecorLayer.FOREGROUND, camera, zoom):
					check(not piece.screen_area.intersects(pad_area),
						"at the %s a Foreground piece %s covers the pad %s, camera %s above its top at zoom %s"
						% [where, piece.screen_area, pad_area, height, zoom])
					check(not piece.screen_area.intersects(ship_area),
						"at the %s a Foreground piece %s covers the ship %s, camera %s above the pad at zoom %s"
						% [where, piece.screen_area, ship_area, height, zoom])
					for point in edge:
						var on_screen: Vector2 = (point - camera) * zoom + screen_center
						if piece.screen_area.has_point(on_screen):
							check(false, "at the %s a Foreground piece %s covers the terrain's edge at %s, camera %s above the pad at zoom %s"
								% [where, piece.screen_area, point, height, zoom])
							break


func test_the_foreground_never_covers_the_pad_or_the_ship_in_the_last_of_the_approach() -> void:
	await choose_ship()
	check_foreground_is_fair("Valley")


func at_hour(hour: int) -> void:
	clock().minutes = hour * 60 + 30
	await frames(1)


# Checks that every Foreground piece is opaque and darker than every other piece of scenery (the
# Backdrop, parallax layers, ground, mountains and terrain) at night, in the morning, by day and in
# the evening, and a little darker at night than by day.
func check_foreground_is_darkest(where: String) -> void:
	var by_day: Array[float] = []
	var at_night: Array[float] = []
	for hour in [3, 8, 13, 19]:
		await at_hour(hour)
		var others: Array[Color] = [shown_color(ground())]
		for visual in main().get_node("Mountains").get_children() + main().get_node("Terrain").get_children():
			if visual is Polygon2D:
				others.append(shown_color(visual))
		for piece in world().shown_decor(pad_top(), 1.0):
			if piece.layer == World.DecorLayer.BACKDROP or piece.layer == World.DecorLayer.PARALLAX:
				others.append(piece.color)
		var darkest_other := INF
		for color in others:
			darkest_other = minf(darkest_other, color.get_luminance())
		var foreground := pieces_in(World.DecorLayer.FOREGROUND)
		check(not foreground.is_empty(), "the %s should have a Foreground" % where)
		for piece in foreground:
			check(piece.color.a == 1.0, "a %s Foreground piece should be opaque at %d:30, its colour %s" % [where, hour, piece.color])
			check(piece.color.get_luminance() < darkest_other,
				"a %s Foreground piece (%s) should be darker than all other scenery (darkest %s) at %d:30"
				% [where, piece.color.get_luminance(), darkest_other, hour])
			if hour == 13:
				by_day.append(piece.color.get_luminance())
			elif hour == 3:
				at_night.append(piece.color.get_luminance())
	for i in mini(by_day.size(), at_night.size()):
		check(at_night[i] < by_day[i], "a %s Foreground piece should be darker at night (%s) than by day (%s)" % [where, at_night[i], by_day[i]])


func test_the_foreground_is_darker_than_all_other_scenery_at_every_hour() -> void:
	await choose_ship()
	await check_foreground_is_darkest("Valley")


func clouds() -> Array[World.Decor]:
	return pieces_in(World.DecorLayer.PARALLAX).filter(
		func(piece: World.Decor) -> bool: return piece.part == World.DecorPart.CLOUD)


func test_the_clouds_drift_on_the_wind_by_themselves() -> void:
	await choose_ship()
	var before := clouds()
	await seconds(2.0)
	var after := clouds()
	check(before.size() == after.size() and not before.is_empty(), "the Valley's clouds should stay listed as they drift")
	for i in mini(before.size(), after.size()):
		var moved := after[i].screen_area.position - before[i].screen_area.position
		check(moved.x > 1.0, "cloud %d should drift sideways on the wind with the camera still, moved %s" % [i, moved])
		check_near(moved.y, 0.0, 0.01, "cloud %d shouldn't drift up or down" % i)


func test_the_clouds_are_tinted_by_the_sky() -> void:
	await choose_ship()
	await at_hour(13)
	var day := clouds()
	await at_hour(19)
	var evening := clouds()
	for i in mini(day.size(), evening.size()):
		check(evening[i].color.r > day[i].color.r and evening[i].color.b < day[i].color.b,
			"cloud %d should turn from blue by day (%s) to orange in the evening (%s)" % [i, day[i].color, evening[i].color])


# Checks that each Backdrop ridge covers the whole width of the view, and reaches below the
# location's lowest point, wherever the camera can be on the surface: at the widest zoom, the
# surface zoom and the zoom punch, and on a window as wide as the world and its side overhang.
func check_layers_cover_the_view(where: String) -> void:
	var size := world().get_viewport_rect().size
	var widest := size.x / (World.WORLD_WIDTH + 2.0 * World.SIDE_OVERHANG)
	for zoom in [widest, 0.85, FollowCamera.SURFACE_ZOOM, FollowCamera.SURFACE_ZOOM * FollowCamera.PUNCH_ZOOM]:
		# The camera keeps the view inside the world, or centres a view wider than it.
		var half_view: float = size.x / zoom / 2.0
		var xs := [World.WORLD_WIDTH / 2.0] if half_view * 2.0 >= World.WORLD_WIDTH else [half_view, World.WORLD_WIDTH - half_view]
		var lowest_center: float = world().location.lowest_y - size.y / zoom / 2.0
		for x in xs:
			for y in [lowest_center, World.BORDER_Y]:
				var camera := Vector2(x, y)
				var lowest_on_screen: float = (world().location.lowest_y - y) * zoom + size.y / 2.0
				for piece in pieces_in(World.DecorLayer.BACKDROP, camera, zoom):
					var area := piece.screen_area
					check(area.position.x <= 0.0 and area.end.x >= size.x,
						"at the %s a ridge %s should cover the view's width %s, camera %s at zoom %s" % [where, area, size.x, camera, zoom])
					check(area.end.y >= lowest_on_screen,
						"at the %s a ridge %s should reach below the lowest point (%s), camera %s at zoom %s" % [where, area, lowest_on_screen, camera, zoom])


func test_the_layers_cover_the_view_at_every_zoom_and_on_wide_windows() -> void:
	await choose_ship()
	check_layers_cover_the_view("Valley")
	clock().move_to(Location.MINE)
	await frames(1)
	check_layers_cover_the_view("Mine")
	clock().move_to(Location.METROPOLIS)
	await frames(1)
	check_layers_cover_the_view("Metropolis")


# The Mine's depth: the same rules as the Valley's, with stronger parallax.

func scroll_scales(layer: World.DecorLayer) -> Array[Vector2]:
	var scales: Array[Vector2] = []
	for piece in pieces_in(layer):
		scales.append(piece.scroll_scale)
	return scales


func test_the_mines_parallax_is_stronger_than_the_valleys() -> void:
	await choose_ship()
	var valley_backdrop := scroll_scales(World.DecorLayer.BACKDROP)
	var valley_foreground := scroll_scales(World.DecorLayer.FOREGROUND)
	clock().move_to(Location.MINE)
	await frames(1)
	var mine_backdrop := scroll_scales(World.DecorLayer.BACKDROP)
	var mine_foreground := scroll_scales(World.DecorLayer.FOREGROUND)
	check(not mine_foreground.is_empty(), "the Mine should have a Foreground")
	# Each Backdrop layer, farthest to nearest, moves more slowly than the Valley's; the farthest
	# and the nearest are compared in both directions.
	for axis in 2:
		var valley_min: float = valley_backdrop.map(func(s: Vector2) -> float: return s[axis]).min()
		var valley_max: float = valley_backdrop.map(func(s: Vector2) -> float: return s[axis]).max()
		var mine_min: float = mine_backdrop.map(func(s: Vector2) -> float: return s[axis]).min()
		var mine_max: float = mine_backdrop.map(func(s: Vector2) -> float: return s[axis]).max()
		check(mine_min < valley_min, "the Mine's farthest layer should be slower than the Valley's on axis %d: %s vs %s" % [axis, mine_min, valley_min])
		check(mine_max < valley_max, "the Mine's nearest Backdrop layer should be slower than the Valley's on axis %d: %s vs %s" % [axis, mine_max, valley_max])
		var valley_fastest: float = valley_foreground.map(func(s: Vector2) -> float: return s[axis]).max()
		for scale in mine_foreground:
			check(scale[axis] > valley_fastest, "the Mine's Foreground should be faster than the Valley's on axis %d: %s vs %s" % [axis, scale[axis], valley_fastest])


func test_the_mines_foreground_never_covers_the_pad_the_ship_or_the_benches_near_it() -> void:
	await choose_ship()
	clock().move_to(Location.MINE)
	await frames(1)
	check(terrain_edge_near_pad().size() > 10, "the Mine's benches right of the pad should count as terrain near it")
	check_foreground_is_fair("Mine")


func test_the_mines_foreground_is_darker_than_all_other_scenery_at_every_hour() -> void:
	await choose_ship()
	clock().move_to(Location.MINE)
	await frames(1)
	await check_foreground_is_darkest("Mine")


# The crane's arm is only fair if it's never hidden: wherever the camera is over the Mine, the
# Foreground stays below it on screen.
func test_the_mines_foreground_never_hides_the_crane_arm() -> void:
	await choose_ship()
	clock().move_to(Location.MINE)
	await frames(1)
	var screen_center := world().get_viewport_rect().size / 2.0
	var arm_bottom := 0.0
	for point: Vector2 in Location.CRANE:
		if point.x > 400.0:
			arm_bottom = maxf(arm_bottom, point.y)
	for zoom in [0.85, FollowCamera.SURFACE_ZOOM, FollowCamera.SURFACE_ZOOM * FollowCamera.PUNCH_ZOOM]:
		for x in [200.0, 600.0, 1000.0, pad_x(), 1800.0]:
			for y in [World.BORDER_Y, 0.0, 400.0, pad_top().y]:
				var camera := Vector2(x, y)
				var arm_bottom_on_screen: float = (arm_bottom - y) * zoom + screen_center.y
				for piece in pieces_in(World.DecorLayer.FOREGROUND, camera, zoom):
					check(piece.screen_area.position.y > arm_bottom_on_screen,
						"a Mine Foreground piece %s should stay below the crane arm (screen y %s), camera %s at zoom %s"
						% [piece.screen_area, arm_bottom_on_screen, camera, zoom])
