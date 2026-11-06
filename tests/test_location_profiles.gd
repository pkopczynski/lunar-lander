extends "res://tests/scene_test.gd"
# Each destination's location profile shapes the Transport offers generated for it.

const SAMPLE := 1000
# Average pay is compared over pools from several seeds, so no single lucky pool decides it.
const PAY_SEEDS := [1, 2, 3, 4, 5]


# SAMPLE offers from one seeded generator, as the Economy draws them, grouped by destination.
func sample_by_destination(pool_seed := 62) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = pool_seed
	var by_destination := {}
	for location in Location.ALL:
		by_destination[location] = []
	for i in SAMPLE:
		var offer := TransportOffer.generate(rng, i + 1, Economy.largest_seats(), Economy.largest_cargo())
		by_destination[offer.destination].append(offer)
	return by_destination


func share_of(offers: Array, kind: TransportOffer.Kind) -> float:
	return offers.filter(func(offer: TransportOffer) -> bool: return offer.kind() == kind).size() \
		/ float(offers.size())


func test_each_destinations_offers_mix_passengers_cargo_and_both_by_its_weights() -> void:
	var by_destination := sample_by_destination()
	var expected := {
		Location.VALLEY: [1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0],
		Location.MINE: [0.1, 0.6, 0.3],
		Location.METROPOLIS: [0.6, 0.1, 0.3],
	}
	for location: Location in expected:
		var offers: Array = by_destination[location]
		for kind in [TransportOffer.Kind.PASSENGERS, TransportOffer.Kind.CARGO, TransportOffer.Kind.MIXED]:
			check_near(share_of(offers, kind), expected[location][kind], 0.06,
				"%s: share of %s offers" % [location.name, TransportOffer.KIND_LABELS[kind]])


func test_offers_go_to_the_valley_the_mine_and_the_metropolis_by_their_pool_shares() -> void:
	var by_destination := sample_by_destination()
	check_near(by_destination[Location.VALLEY].size() / float(SAMPLE), 0.4, 0.05, "Valley share of offers")
	check_near(by_destination[Location.MINE].size() / float(SAMPLE), 0.3, 0.05, "Mine share of offers")
	check_near(by_destination[Location.METROPOLIS].size() / float(SAMPLE), 0.3, 0.05, "Metropolis share of offers")


func test_mine_offers_carry_at_most_four_passengers_and_at_least_3000_kg() -> void:
	var largest := 0.0
	for offer: TransportOffer in sample_by_destination()[Location.MINE]:
		check(offer.passengers <= 4, "Mine offer #%03d has %d passengers" % [offer.number, offer.passengers])
		check(offer.cargo_mass == 0.0 or offer.cargo_mass >= 3000.0,
			"Mine offer #%03d has %.0f kg of cargo" % [offer.number, offer.cargo_mass])
		largest = maxf(largest, offer.cargo_mass)
	check(largest > 11000.0, "some Mine cargo should need more than the Halo's 11 000 kg, largest %.0f" % largest)


func test_every_offer_fits_the_largest_ship_types_seats_and_maximum_capacity() -> void:
	var seen_passengers := {}
	for location: Location in Location.ALL:
		for offer: TransportOffer in sample_by_destination()[location]:
			check(offer.passengers <= 10 and offer.cargo_mass <= 16000.0,
				"%s offer #%03d: %d passengers, %.0f kg" % [location.name, offer.number, offer.passengers, offer.cargo_mass])
			check(offer.cargo_mass == 0.0 or offer.cargo_mass >= 500.0,
				"%s offer #%03d has only %.0f kg of cargo" % [location.name, offer.number, offer.cargo_mass])
			if location == Location.VALLEY:
				seen_passengers[offer.passengers] = true
	check(seen_passengers.has(1) and seen_passengers.has(10), "Valley offers should range from 1 to 10 passengers")


func test_metropolis_offers_carry_up_to_ten_passengers_and_at_most_3000_kg() -> void:
	var seen_passengers := {}
	for offer: TransportOffer in sample_by_destination()[Location.METROPOLIS]:
		check(offer.cargo_mass == 0.0 or (offer.cargo_mass >= 500.0 and offer.cargo_mass <= 3000.0),
			"Metropolis offer #%03d has %.0f kg of cargo" % [offer.number, offer.cargo_mass])
		seen_passengers[offer.passengers] = true
	check(seen_passengers.has(1) and seen_passengers.has(10), "Metropolis offers should range from 1 to 10 passengers")


func average_reward(offers: Array) -> float:
	var total := 0
	for offer: TransportOffer in offers:
		total += offer.reward()
	return total / float(offers.size())


# In every pool, the Mine's average pay beats the Valley's by at least this share (its offers are
# the heaviest to fly).
const MINE_PAY_MARGIN := 0.05


func test_mine_offers_pay_clearly_more_than_valley_offers_on_average() -> void:
	for pool_seed: int in PAY_SEEDS:
		var by_destination := sample_by_destination(pool_seed)
		var valley := average_reward(by_destination[Location.VALLEY])
		var mine := average_reward(by_destination[Location.MINE])
		check(mine >= valley * (1.0 + MINE_PAY_MARGIN),
			"seed %d: the Mine should pay clearly more on average than the Valley: Mine €%.0f, Valley €%.0f"
			% [pool_seed, mine, valley])


func test_metropolis_offers_pay_more_than_valley_offers_on_average() -> void:
	for pool_seed: int in PAY_SEEDS:
		var by_destination := sample_by_destination(pool_seed)
		var valley := average_reward(by_destination[Location.VALLEY])
		var metropolis := average_reward(by_destination[Location.METROPOLIS])
		check(metropolis > valley,
			"seed %d: the Metropolis should pay more on average than the Valley: Metropolis €%.0f, Valley €%.0f"
			% [pool_seed, metropolis, valley])


func test_titles_come_from_the_destinations_own_list() -> void:
	var valley_words := ["tourist", "crew", "survey", "medical", "school", "luggage", "supplies", "hydroponics",
		"water", "parts", "mail", "camp", "relief", "science", "settlers"]
	var mine_words := ["mining", "blasting", "maintenance", "drill", "parts", "industrial", "conveyor", "tools",
		"crane", "repair"]
	var by_destination := sample_by_destination()
	for offer: TransportOffer in by_destination[Location.VALLEY]:
		check(valley_words.any(func(word: String) -> bool: return word in offer.title.to_lower()),
			"Valley title '%s' should be Valley work" % offer.title)
	for offer: TransportOffer in by_destination[Location.MINE]:
		check(mine_words.any(func(word: String) -> bool: return word in offer.title.to_lower()),
			"Mine title '%s' should be Mine work" % offer.title)
		check(not "tourist" in offer.title.to_lower(), "no tourists go to the Mine: '%s'" % offer.title)
	var metropolis_words := ["tourist", "corporate", "business", "conference", "shift", "mail", "shop", "electronics",
		"restaurant", "office", "film", "hotel", "expo"]
	for offer: TransportOffer in by_destination[Location.METROPOLIS]:
		check(metropolis_words.any(func(word: String) -> bool: return word in offer.title.to_lower()),
			"Metropolis title '%s' should be city work" % offer.title)


func test_deadlines_and_expiry_stay_the_same_everywhere() -> void:
	for location: Location in Location.ALL:
		for offer: TransportOffer in sample_by_destination()[location]:
			check(offer.deadline >= 60 and offer.deadline <= 180,
				"%s offer #%03d deadline %.0f s" % [location.name, offer.number, offer.deadline])
			check(offer.time_left >= 180 and offer.time_left <= 600,
				"%s offer #%03d open for %.0f s" % [location.name, offer.number, offer.time_left])
