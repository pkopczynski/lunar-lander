extends SceneTree
# Offer statistics: per destination and kind, and best-fill missions per ship type.

const N := 200000
const POOLS := 20000
const POOL_SIZE := 6

func pct(arr: Array, p: float) -> float:
	return arr[clampi(int(p * arr.size()), 0, arr.size() - 1)]

func summary(label: String, arr: Array) -> void:
	if arr.is_empty():
		return
	arr.sort()
	var s := 0.0
	for v in arr: s += v
	print("%-34s n=%6d mean=%7.0f p10=%6.0f p50=%6.0f p90=%6.0f min=%6.0f max=%6.0f" % [label, arr.size(), s / arr.size(), pct(arr, .1), pct(arr, .5), pct(arr, .9), arr[0], arr[-1]])

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var seats := Economy.largest_seats()
	var cargo := Economy.largest_cargo()
	var by: Dictionary = {}
	var pax: Dictionary = {}
	var kg: Dictionary = {}
	var dl: Array = []
	for i in N:
		var o := TransportOffer.generate(rng, i, seats, cargo)
		var key := "%s %s" % [o.destination.name, TransportOffer.KIND_LABELS[o.kind()]]
		by.get_or_add(key, []).append(float(o.reward()))
		by.get_or_add(o.destination.name + " ALL", []).append(float(o.reward()))
		by.get_or_add("ALL", []).append(float(o.reward()))
		if o.passengers > 0: pax.get_or_add(o.destination.name, []).append(float(o.passengers))
		if o.cargo_mass > 0: kg.get_or_add(o.destination.name, []).append(o.cargo_mass)
		dl.append(o.deadline)
	print("== Reward per offer (EUR), all offers generated (up to Halo seats / Mule cargo)")
	var keys := by.keys(); keys.sort()
	for k in keys: summary(k, by[k])
	print("== Passengers per offer"); for k in pax: summary(k, pax[k])
	print("== Cargo kg per offer"); for k in kg: summary(k, kg[k])
	summary("deadline s", dl)
	# Which offers fit each ship at all, and their reward
	print("== Offers that fit an empty ship, reward")
	rng.seed = 2
	var fit: Dictionary = {}
	var fit_share: Dictionary = {}
	for i in N:
		var o := TransportOffer.generate(rng, i, seats, cargo)
		for t in ShipType.ALL:
			var ok := o.passengers <= t.passenger_seats and o.cargo_mass <= t.cargo_capacity
			fit_share[t.name] = fit_share.get(t.name, 0) + (1 if ok else 0)
			if ok: fit.get_or_add(t.name, []).append(float(o.reward()))
			var okf := ok and o.cargo_mass <= t.full_tank_cargo(o.passengers)
			fit_share[t.name + " full-tank"] = fit_share.get(t.name + " full-tank", 0) + (1 if okf else 0)
	for t in ShipType.ALL:
		print("%s fits %.0f%% of offers (%.0f%% with a full tank)" % [t.name, 100.0 * fit_share[t.name] / N, 100.0 * fit_share[t.name + " full-tank"] / N])
		summary(t.name + " fitting offer", fit[t.name])
	# Best mission from a pool of POOL_SIZE: best subset sharing one destination that fits.
	print("== Best mission from a %d-offer pool (one destination, fits capacity)" % POOL_SIZE)
	for mode in ["capacity", "full-tank"]:
		for t in ShipType.ALL:
			rng.seed = 3
			var best_r: Array = []
			var best_dl: Array = []
			var best_n: Array = []
			var best_load: Array = []
			var best_dest: Dictionary = {}
			for p in POOLS:
				var pool: Array = []
				for i in POOL_SIZE: pool.append(TransportOffer.generate(rng, i, seats, cargo))
				var best := 0; var bd := 0.0; var bn := 0; var bl := 0.0; var bdest := ""
				for mask in range(1, 1 << POOL_SIZE):
					var dest: Location = null; var ok := true; var ps := 0; var cg := 0.0; var r := 0; var d := INF; var n := 0; var lm := 0.0
					for i in POOL_SIZE:
						if mask & (1 << i):
							var o: TransportOffer = pool[i]
							if dest != null and o.destination != dest: ok = false; break
							dest = o.destination; ps += o.passengers; cg += o.cargo_mass; r += o.reward(); d = minf(d, o.deadline); n += 1; lm += o.load_mass()
					if not ok or ps > t.passenger_seats or cg > t.cargo_capacity: continue
					if mode == "full-tank" and cg > t.full_tank_cargo(ps): continue
					if r > best: best = r; bd = d; bn = n; bl = lm; bdest = dest.name
				best_r.append(float(best)); best_dl.append(bd); best_n.append(float(bn)); best_load.append(bl)
				best_dest[bdest] = best_dest.get(bdest, 0) + 1
			summary("%s [%s] reward" % [t.name, mode], best_r)
			summary("%s [%s] shortest deadline" % [t.name, mode], best_dl)
			summary("%s [%s] contracts" % [t.name, mode], best_n)
			summary("%s [%s] load kg" % [t.name, mode], best_load)
			print("   destinations: ", best_dest)
	quit()
