extends SceneTree
# A developer tool, not a test: captures every Location by day and at night at several heights
# above its pad, then measures the surface's frame time at the pad and 1000 px up. It sets the
# planet clock and places the ship only through the game's own functions, never touching scenery.
# Needs a real window (it renders), so run it without --headless; see the README.

const MAIN_SCENE := "res://main.tscn"
const WINDOW_SIZE := Vector2i(1152, 648)
# Local times, in in-game minutes since midnight, and their names in the file names.
const TIMES := {"day": 13 * 60, "night": 1 * 60}
# Heights of the ship above its resting place on the pad, in px.
const HEIGHTS: Array[int] = [0, 300, 700, 1200, 1800]
# Where the ship hovers beside each Mountain, to show its look: just inside each foot, at mid-face.
const MOUNTAIN_VIEWS := {"left": Vector2(330, 420), "right": Vector2(World.WORLD_WIDTH - 330, 420)}
const MEASURE_TIME := "day"
const MEASURE_HEIGHTS: Array[int] = [0, 1000]
# Frames to let the camera, the sky and moving decor settle before a shot or a measurement.
const SETTLE_FRAMES := 10
const MEASURE_FRAMES := 300

var out_dir := ""


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	out_dir = output_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(WINDOW_SIZE)
	change_scene_to_file(MAIN_SCENE)
	await process_frame
	await process_frame
	var main: Node = current_scene
	var office: Office = main.get_node("Office")
	await frames(SETTLE_FRAMES)
	office.close()
	var clock: PlanetClock = main.get_node("PlanetClock")
	var lander: Lander = main.get_node("Lander")

	var shots := 0
	for location: Location in Location.ALL:
		clock.move_to(location)
		for time_name: String in TIMES:
			for height in HEIGHTS:
				await place(clock, lander, TIMES[time_name], height)
				var file := "%s_%s_%04d.png" % [location.name.to_lower(), time_name, height]
				root.get_texture().get_image().save_png(out_dir.path_join(file))
				shots += 1
			for side: String in MOUNTAIN_VIEWS:
				await place_at(clock, lander, TIMES[time_name], MOUNTAIN_VIEWS[side])
				var file := "%s_%s_mountains_%s.png" % [location.name.to_lower(), time_name, side]
				root.get_texture().get_image().save_png(out_dir.path_join(file))
				shots += 1
	print("Saved %d screenshots to %s" % [shots, out_dir])

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	print("\nFrame time at %s (%d frames each, %dx%d window, vsync off):" % [
		MEASURE_TIME, MEASURE_FRAMES, WINDOW_SIZE.x, WINDOW_SIZE.y])
	print("%-12s %6s %10s %10s %10s" % ["location", "height", "mean ms", "p95 ms", "render ms"])
	for location: Location in Location.ALL:
		clock.move_to(location)
		for height in MEASURE_HEIGHTS:
			await place(clock, lander, TIMES[MEASURE_TIME], height)
			var result := await measure()
			print("%-12s %6d %10.2f %10.2f %10.2f" % [location.name.to_lower(), height,
				result.mean, result.p95, result.render])
	quit()


# Sets the local time and holds the ship upright at a height above its resting place on the pad.
func place(clock: PlanetClock, lander: Lander, minutes: float, height: int) -> void:
	lander.reset_to_pad()
	await place_at(clock, lander, minutes, lander.position - Vector2(0.0, height))


# Sets the local time and holds the ship upright at a point in the world.
func place_at(clock: PlanetClock, lander: Lander, minutes: float, at: Vector2) -> void:
	lander.fly_from(at)
	lander.hold()
	clock.minutes = minutes
	await frames(SETTLE_FRAMES)
	# The clock ran on while settling; set it back so every shot shows exactly this time.
	clock.minutes = minutes
	await physics_frame
	await process_frame


# Wall-clock time per frame, plus the renderer's own CPU time, in ms (the Compatibility renderer
# doesn't measure GPU time).
func measure() -> Dictionary:
	var rid := root.get_viewport_rid()
	var times: Array[float] = []
	var render := 0.0
	var last := Time.get_ticks_usec()
	for i in MEASURE_FRAMES:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		render += RenderingServer.viewport_get_measured_render_time_cpu(rid) \
			+ RenderingServer.get_frame_setup_time_cpu()
	var sum := 0.0
	for t in times:
		sum += t
	times.sort()
	return {
		"mean": sum / times.size(),
		"p95": times[int(times.size() * 0.95)],
		"render": render / MEASURE_FRAMES,
	}


func frames(count: int) -> void:
	for i in count:
		await process_frame


# The folder from `-- --out=<dir>`, by default `captures/` in the user data folder.
func output_dir() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			return arg.trim_prefix("--out=")
	return OS.get_user_data_dir().path_join("captures")
