extends "res://tests/scene_test.gd"
# The sky follows the local time: read through the World's sky readings.

# Today's evening surface orange, the sky's 19:00 keyframe.
const EVENING_ORANGE := Color(0.9, 0.4, 0.1)


# Sets the local time to hh:mm and lets the World redraw from it.
func sky_at(hours: int, minutes: int) -> SkyLook:
	clock().minutes = hours * 60 + minutes
	await frames(1)
	return world().sky


func check_color(actual: Color, expected: Color, description: String) -> void:
	check(actual.is_equal_approx(expected), "%s: expected %s, got %s" % [description, expected, actual])


func test_the_evening_sky_is_todays_orange() -> void:
	await choose_ship()
	var sky := await sky_at(19, 0)
	check_color(sky.ground_color, EVENING_ORANGE, "the ground-level sky at 19:00")


func test_the_day_sky_is_blue_the_night_dark_navy_and_the_morning_pale_yellow() -> void:
	await choose_ship()
	var day := (await sky_at(13, 0)).ground_color
	check(day.b > day.r and day.b > day.g, "the ground-level sky at 13:00 should be blue-dominant, got %s" % day)
	var night := (await sky_at(3, 0)).ground_color
	check(night.b > night.r and night.b > night.g, "the ground-level sky at 03:00 should be navy (blue-dominant), got %s" % night)
	check(night.get_luminance() < 0.15, "the ground-level sky at 03:00 should be dark, got %s" % night)
	var morning := (await sky_at(7, 30)).ground_color
	check(morning.r > 0.8 and morning.g > 0.8, "the ground-level sky at 07:30 should be pale yellow (bright red and green), got %s" % morning)
	check(morning.b < morning.g and morning.b > 0.4, "the ground-level sky at 07:30 should be pale yellow (a pastel, less blue), got %s" % morning)


# The largest change in any channel between two colours.
func difference(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))


func test_the_sky_blends_smoothly_through_the_whole_day_and_across_midnight() -> void:
	await choose_ship()
	var largest := 0.0
	var where := ""
	var previous := (await sky_at(23, 50)).ground_color
	# Every minute from 23:51 round to 23:50 the next day.
	for step in range(1, 24 * 60 + 1):
		var minute := (23 * 60 + 50 + step) % (24 * 60)
		var color := (await sky_at(minute / 60, minute % 60)).ground_color
		if difference(previous, color) > largest:
			largest = difference(previous, color)
			where = "%02d:%02d" % [minute / 60, minute % 60]
		previous = color
	check(largest < 0.01, "colours one minute apart should differ only slightly, largest step %s at %s" % [largest, where])


func test_the_sky_changes_as_the_clock_advances() -> void:
	await choose_ship()
	var before := (await sky_at(9, 0)).ground_color
	await seconds(30.0)
	var after := world().sky.ground_color
	check(difference(before, after) > 0.02, "an in-game hour later the sky should have changed, %s then %s" % [before, after])


func test_deep_space_is_the_same_black_at_every_hour() -> void:
	await choose_ship()
	for hour in 24:
		await sky_at(hour, 0)
		check_color(world().background_color(World.BORDER_Y), Color.BLACK, "the background at the Border at %02d:00" % hour)


func test_scenery_dims_at_night_while_the_pad_stays_at_full_brightness() -> void:
	await choose_ship()
	var pad: Polygon2D = main().get_node("Ground/Pad")
	var day := await sky_at(13, 0)
	check_near(day.darkness, 0.0, 0.001, "the scenery's darkness at 13:00")
	var ground_by_day := shown_color(ground())
	var mountain_by_day := shown_color(mountain())
	var pad_by_day := shown_color(pad)
	var night := await sky_at(3, 0)
	check(night.darkness > 0.3, "the scenery should be darkened at 03:00, darkness %s" % night.darkness)
	check(shown_color(ground()).get_luminance() < ground_by_day.get_luminance() * 0.7,
		"the ground should dim at night: %s by day, %s at 03:00" % [ground_by_day, shown_color(ground())])
	check(shown_color(mountain()).get_luminance() < mountain_by_day.get_luminance() * 0.7,
		"the mountains should dim at night: %s by day, %s at 03:00" % [mountain_by_day, shown_color(mountain())])
	check_color(shown_color(pad), pad_by_day, "the pad at 03:00 should be as bright as by day")


func test_night_stars_are_faint_and_fade_in_late_in_the_evening_and_out_at_dawn() -> void:
	await choose_ship()
	check_near((await sky_at(13, 0)).star_brightness, 0.0, 0.001, "star brightness at 13:00")
	check_near((await sky_at(19, 0)).star_brightness, 0.0, 0.001, "star brightness at 19:00")
	var night := (await sky_at(2, 0)).star_brightness
	check(night > 0.0 and night <= 0.6, "stars at 02:00 should be out but faint, brightness %s" % night)
	var evening := (await sky_at(21, 30)).star_brightness
	check(evening > 0.0 and evening < night, "stars at 21:30 should be fading in, brightness %s (%s at 02:00)" % [evening, night])
	var dawn := (await sky_at(6, 0)).star_brightness
	check(dawn > 0.0 and dawn < night, "stars at 06:00 should be fading out, brightness %s (%s at 02:00)" % [dawn, night])
	check_near((await sky_at(7, 30)).star_brightness, 0.0, 0.001, "star brightness at 07:30")


# The shown stars (as World.shown_stars() gives them) with a centre inside an area.
func stars_in(stars: Array[World.Star], area: Rect2) -> Array[World.Star]:
	return stars.filter(func(star: World.Star) -> bool: return area.has_point(star.position))


# A star's position, size and colour, to compare stars from two readings.
func star_key(star: World.Star) -> String:
	return "%s %s %s" % [star.position, star.radius, star.color]


func test_faint_stars_cover_the_whole_surface_sky_at_night_and_are_gone_by_day() -> void:
	await choose_ship()
	var night := await sky_at(2, 0)
	var stars := world().shown_stars()
	# The surface sky, split into a grid; every cell should have a star at night.
	var columns := 8
	var rows := 6
	var width := World.WORLD_WIDTH / columns
	var height := (World.GROUND_BOTTOM_Y - World.BORDER_Y) / rows
	for column in columns:
		for row in rows:
			var cell := Rect2(column * width, World.BORDER_Y + row * height, width, height)
			check(not stars_in(stars, cell).is_empty(), "at 02:00 a star should show in the surface sky at %s" % cell)
	# Low in the surface sky, far below the deep-space stars' fade, the stars are the night stars.
	var low := Rect2(-World.SIDE_OVERHANG, 0.0, World.WORLD_WIDTH + 2.0 * World.SIDE_OVERHANG, World.GROUND_BOTTOM_Y)
	for star: World.Star in stars_in(stars, low):
		check_near(star.color.a, night.star_brightness, 0.001, "a low surface star's opacity at 02:00")
	check(night.star_brightness <= 0.6, "the night stars should be faint, brightness %s" % night.star_brightness)
	var dawn := await sky_at(6, 0)
	var fading := stars_in(world().shown_stars(), low)
	check(not fading.is_empty(), "at 06:00 the night stars should still show, fading")
	for star: World.Star in fading:
		check_near(star.color.a, dawn.star_brightness, 0.001, "a low surface star's opacity at 06:00")
	await sky_at(13, 0)
	var below_fade := Rect2(-World.SIDE_OVERHANG, World.BORDER_Y + World.SURFACE_STAR_DEPTH,
		World.WORLD_WIDTH + 2.0 * World.SIDE_OVERHANG, World.GROUND_BOTTOM_Y - World.BORDER_Y)
	check(stars_in(world().shown_stars(), below_fade).is_empty(), "no stars should show low in the surface sky at 13:00")


func test_deep_space_stars_are_the_same_at_every_hour() -> void:
	await choose_ship()
	# By day only the deep-space stars show, with their fade just below the Border.
	var by_day := (await sky_at(13, 0)).star_brightness
	check_near(by_day, 0.0, 0.001, "star brightness at 13:00")
	var deep := world().shown_stars()
	check(not deep.is_empty(), "the deep-space stars should show at 13:00")
	for hour in 24:
		await sky_at(hour, 0)
		var shown := world().shown_stars().map(star_key)
		var missing := deep.filter(func(star: World.Star) -> bool: return not shown.has(star_key(star)))
		check(missing.is_empty(), "at %02d:00 every deep-space star should show as at 13:00, %d differ" % [hour, missing.size()])


func test_night_lights_fade_in_from_none_by_day_to_full_at_night() -> void:
	check_near(SkyLook.at(13 * 60).night(), 0.0, 0.001, "night at 13:00")
	check_near(SkyLook.at(19 * 60).night(), 0.0, 0.001, "night at 19:00")
	check_near(SkyLook.at(3 * 60).night(), 1.0, 0.001, "night at 03:00")
	check_near(SkyLook.at(23 * 60).night(), 1.0, 0.001, "night at 23:00")
	# At 07:30 the scenery is darkened 0.1 of the night's 0.6.
	check_near(SkyLook.at(7 * 60 + 30).night(), 1.0 / 6.0, 0.001, "night at 07:30")
