extends SceneTree
# Steady-state income: event sim of the real offer pool rules and a player flying missions
# back to back. Flight times are the autopilot's measurements; overhead is an assumption.

const HOURS := 200.0  # simulated real hours per case
const OFFICE := 15.0  # s in the Terminal per mission (browse, accept, start)
# Station→pad (loaded) and pad→dock (empty), seconds, autopilot-measured, Valley/Mine/Metropolis mean.
const DOWN := {"Sparrow": 28.5, "Mule": 38.3, "Halo": 30.9}
const UP := {"Sparrow": 27.2, "Mule": 38.4, "Halo": 30.5}
# Seconds on the pad after unloading starts, at least: refuel enough to climb (2 s delay + ~6 s).
const PAD_MIN := 8.0
const WAIT_STEP := 1.0
var next_left := 0.0

func _init() -> void:
	for mode in ["capacity", "full-tank", "autopilot-landable"]:
		for t in ShipType.ALL:
			sim(t, mode)
	quit()

func load_limit(t: ShipType, mode: String, ps: int) -> float:
	match mode:
		"capacity": return t.cargo_capacity
		"full-tank": return t.full_tank_cargo(ps)
		_:
			var cap := {"Sparrow": 5250.0, "Mule": 9000.0, "Halo": 7500.0}[t.name] as float
			return cap - ps * TransportOffer.PASSENGER_MASS
	return 0.0

func sim(t: ShipType, mode: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var seats := Economy.largest_seats()
	var cargo := Economy.largest_cargo()
	var pool: Array = []
	for i in Economy.START_OFFERS: pool.append(TransportOffer.generate(rng, i, seats, cargo))
	next_left = 0.0
	var now := 0.0
	var earned := 0
	var missions := 0
	var waited := 0.0
	var contracts_n := 0
	var end := HOURS * 3600.0
	# Advance the pool by dt seconds (expiry + arrivals), in 1 s steps.
	var advance := func(dt: float) -> void:
		var left := dt
		while left > 0.0:
			var step := minf(1.0, left)
			left -= step
			for o in pool.duplicate():
				o.time_left -= step
				if o.time_left <= 0.0: pool.erase(o)
			if pool.size() >= Economy.MAX_OFFERS:
				next_left = 0.0
			else:
				if next_left <= 0.0: next_left = rng.randf_range(Economy.MIN_OFFER_INTERVAL, Economy.MAX_OFFER_INTERVAL)
				next_left -= step
				if next_left <= 0.0: pool.append(TransportOffer.generate(rng, 0, seats, cargo))
	while now < end:
		# Pick the best-paying subset sharing one destination that fits.
		var best_mask := 0; var best := 0; var bps := 0; var bcg := 0.0
		var n := pool.size()
		for mask in range(1, 1 << n):
			var dest: Location = null; var ok := true; var ps := 0; var cg := 0.0; var r := 0
			for i in n:
				if mask & (1 << i):
					var o: TransportOffer = pool[i]
					if dest != null and o.destination != dest: ok = false; break
					dest = o.destination; ps += o.passengers; cg += o.cargo_mass; r += o.reward()
			if not ok or ps > t.passenger_seats or cg > load_limit(t, mode, ps): continue
			if r > best: best = r; best_mask = mask; bps = ps; bcg = cg
		if best_mask == 0:
			advance.call(WAIT_STEP); now += WAIT_STEP; waited += WAIT_STEP
			continue
		var taken: Array = []
		for i in n:
			if best_mask & (1 << i): taken.append(pool[i])
		for o in taken: pool.erase(o)
		contracts_n += taken.size()
		var loading := Economy.LOADING_TIME + bps * Economy.LOADING_TIME_PER_PASSENGER + bcg / 1000.0 * Economy.LOADING_TIME_PER_TONNE
		var unloading := Economy.UNLOADING_TIME + bps * Economy.UNLOADING_TIME_PER_PASSENGER + bcg / 1000.0 * Economy.UNLOADING_TIME_PER_TONNE
		var cycle: float = OFFICE + loading + DOWN[t.name] + maxf(unloading, PAD_MIN) + UP[t.name]
		advance.call(cycle); now += cycle
		earned += best  # delivered well inside every deadline: no penalty
		missions += 1
	var mins := now / 60.0
	print("%-19s %-7s | EUR/min %5.0f | EUR/mission %5.0f | missions/h %4.1f | contracts/mission %.2f | idle %4.1f%%" % [mode, t.name, earned / mins, float(earned) / missions, missions / (now / 3600.0), float(contracts_n) / missions, 100.0 * waited / now])
