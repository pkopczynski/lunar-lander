extends "res://tests/scene_test.gd"

const MULE_HULL := [Vector2(-21, -34), Vector2(21, -34), Vector2(21, 34), Vector2(-21, 34)]


func test_the_mule_offer_is_next_to_the_sparrow() -> void:
	await press(&"ui_right")
	check(office().selected_offer().name == "Mule", "Right from the Sparrow should show the Mule, got %s" % office().selected_offer().name)
	var lines := office().offer_lines()
	for expected: String in ["MULE", "TANK 12 000 KG", "DRY MASS 20 000 KG", "MAX WEIGHT 35 000 KG"]:
		check(expected in lines, "the Mule Offer should show %s, shows %s" % [expected, lines])
	check(office().offer_picture() == PackedVector2Array(MULE_HULL), "the Offer picture should be the Mule's 42×68 hull")
	await press(&"ui_left")
	check(office().selected_offer().name == "Sparrow", "Left from the Mule should go back to the Sparrow")
