class_name Economy
extends Node
# The run's economy: for now, the pilot's Bank account balance. It lives in the scene,
# so a restart (a scene reload) wipes it, and it keeps running while the Office pauses the world.

const PILOT := "PILOT"

# In whole euros. It may go negative.
var balance := 0


# Euros with the sign first, as -€120; never €-0.
static func eur(amount: int) -> String:
	return ("-€%d" if amount < 0 else "€%d") % absi(amount)
