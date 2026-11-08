extends SceneTree
# Times and fuels real flights with the autopilot: station → pad loaded, pad → station empty.

const Pilot := preload("res://research/money-today/pilot.gd")
var main: Node
var lander: Lander
var clock: PlanetClock
var station: Station
var pilot

func phys(n := 1) -> void:
	for i in n: await physics_frame

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	change_scene_to_file("res://main.tscn")
	await process_frame; await process_frame
	main = current_scene
	lander = main.get_node("Lander")
	clock = main.get_node("PlanetClock")
	station = main.get_node("Station")
	var office = main.get_node("Office")
	while office.powering: await process_frame
	office.close()
	pilot = Pilot.new(); pilot.lander = lander; root.add_child(pilot)
	var spot := station.parking_spot.get_center()
	print("spot ", spot)
	for t in (ShipType.ALL if not OS.has_environment("TRACE") else [ShipType.SPARROW]):
		var typical: float = {"Sparrow": 3500.0, "Mule": 12700.0, "Halo": 3260.0}[t.name]
		var loads := [0.0, typical, t.full_tank_cargo(), t.cargo_capacity]
		for loc in (Location.ALL if not OS.has_environment("TRACE") else [Location.VALLEY]):
			for L in (loads if not OS.has_environment("TRACE") else [0.0]):
				clock.move_to(loc)
				await phys(2)
				lander.start_docked(t)
				lander.load_mass = L
				lander.fuel = lander.fuel_cap_for(L)
				lander.release()
				var fuel0 := lander.fuel
				await phys(2)
				var pad := Vector2(loc.pad_center_x, lander.ground_top())
				pilot.waypoints = [
					{pos = Vector2(1000, spot.y), vmax = 120.0, tol = 12.0, arrive = 25.0},
					{pos = Vector2(1000, World.SPACE_TOP_Y + 80), vmax = 200.0, tol = 30.0, arrive = 400.0, min_speed = 40.0},
					{pos = Vector2(pad.x, World.BORDER_Y + 400), vmax = 450.0, tol = 60.0, arrive = 1000.0, min_speed = 200.0},
					{pos = pad, vmax = 400.0, land = true},
				]
				pilot.active = true
				var t0 := 0.0
				var outcome := "timeout"
				while t0 < 400.0:
					await phys()
					t0 += 1.0 / 60.0
					if lander.state == Lander.State.LANDED: outcome = "landed"; break
					if lander.state == Lander.State.CRASHED: outcome = "CRASHED"; break
					if OS.has_environment("TRACE") and int(t0 * 60) % 30 == 0: print("  t%5.1f wp%d pos %s vel %s rot %.2f fuel %.0f st %d" % [t0, 4 - pilot.waypoints.size(), lander.position.round(), lander.velocity.round(), lander.rotation, lander.fuel, lander.state])
				pilot.stop()
				var down_time := t0
				var down_fuel := fuel0 - lander.fuel
				var out_of_fuel := lander.fuel <= 0.0
				var up_time := -1.0; var up_fuel := -1.0; var up_outcome := "-"
				if outcome == "landed" and L == loads[0] or (outcome == "landed" and L == loads[1]):
					# Way back: empty, full tank (refuelled on the pad).
					await phys(30)
					lander.load_mass = 0.0
					lander.fuel = t.tank
					var f1 := lander.fuel
					pilot.waypoints = [
						{pos = Vector2(1000, World.SPACE_TOP_Y + 120), vmax = 450.0, tol = 40.0, arrive = 120.0},
						{pos = Vector2(1000, spot.y), vmax = 150.0, tol = 10.0, arrive = 20.0},
						{pos = spot, vmax = 120.0, tol = 5.0, arrive = 10.0, dock = true},
					]
					pilot.active = true
					var t1 := 0.0
					up_outcome = "timeout"
					while t1 < 400.0:
						await phys()
						t1 += 1.0 / 60.0
						if lander.state == Lander.State.DOCKED: up_outcome = "docked"; break
						if lander.state == Lander.State.CRASHED: up_outcome = "CRASHED"; break
					pilot.stop()
					up_time = t1; up_fuel = f1 - lander.fuel
				print("%-7s %-10s load %6.0f fuel0 %6.0f | down %-7s %5.1fs fuel %6.0f%s | up %-7s %5.1fs fuel %6.0f" % [t.name, loc.name, L, fuel0, outcome, down_time, down_fuel, " (EMPTY)" if out_of_fuel else "", up_outcome, up_time, up_fuel])
	quit()
