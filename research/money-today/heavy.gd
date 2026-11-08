extends SceneTree
# Heavy loads: does a more fuel-efficient descent profile land them? Valley only.
const Pilot := preload("res://research/money-today/pilot.gd")

func phys(n := 1) -> void:
	for i in n: await physics_frame

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	change_scene_to_file("res://main.tscn")
	await process_frame; await process_frame
	var main := current_scene
	var lander: Lander = main.get_node("Lander")
	var clock: PlanetClock = main.get_node("PlanetClock")
	var station: Station = main.get_node("Station")
	var office = main.get_node("Office")
	while office.powering: await process_frame
	office.close()
	var pilot = Pilot.new(); pilot.lander = lander; root.add_child(pilot)
	var spot := station.parking_spot.get_center()
	for t in ShipType.ALL:
		for L in [t.full_tank_cargo() * 0.5, t.full_tank_cargo() * 0.75, t.full_tank_cargo(), t.cargo_capacity]:
			for gentle in [0.6, 0.8, 0.95]:
				for vspace in [150.0, 250.0, 450.0]:
					clock.move_to(Location.VALLEY)
					await phys(2)
					lander.start_docked(t)
					lander.load_mass = L
					lander.fuel = lander.fuel_cap_for(L)
					lander.release()
					pilot.gentle = gentle
					var fuel0 := lander.fuel
					await phys(2)
					var pad := Vector2(Location.VALLEY.pad_center_x, lander.ground_top())
					pilot.waypoints = [
						{pos = Vector2(1000, spot.y), vmax = 120.0, tol = 12.0, arrive = 25.0},
						{pos = Vector2(1000, World.SPACE_TOP_Y + 80), vmax = 200.0, tol = 30.0, arrive = 400.0, min_speed = 40.0},
						{pos = Vector2(pad.x, World.BORDER_Y + 400), vmax = vspace, tol = 60.0, arrive = 1000.0, min_speed = 170.0},
						{pos = pad, vmax = 400.0, land = true},
					]
					pilot.active = true
					var t0 := 0.0
					var outcome := "timeout"
					while t0 < 300.0:
						await phys()
						t0 += 1.0 / 60.0
						if lander.state == Lander.State.LANDED: outcome = "landed"; break
						if lander.state == Lander.State.CRASHED: outcome = "CRASHED"; break
					pilot.stop()
					print("%-7s load %6.0f fuel0 %6.0f gentle %.2f vspace %3.0f | %-7s %5.1fs used %6.0f left %5.0f" % [t.name, L, fuel0, gentle, vspace, outcome, t0, fuel0 - lander.fuel, lander.fuel])
	quit()
