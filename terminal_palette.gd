class_name TerminalPalette
extends RefCounted
# The Terminal's colours, a parameter of the one Terminal (the Office) rather than a second
# implementation: `OFFICE` is green on black, `WORKSHOP` (a pad's Workshop) orange on black. Both
# have white values and accents (a warmer white in the Workshop) and red errors; black is the background in both. The Office draws its
# frame, header, popups and building blocks, and the screens the Workshop shows (the Ship page and
# the FUEL screen), with `Office.palette`. Screens shown only in the Office (the Shipyard, Transport
# offers, the Bank account) still use `Office`'s green constants, the Office palette's values.
# Named like constants, as `ShipType`'s are: never reassign them.

const ORANGE := Color(1.0, 0.62, 0.15)
const WARM_WHITE := Color(1.0, 0.96, 0.9)
const WARM_GLOW := Color(1.0, 0.88, 0.7)

# Lines, labels and lit buttons, and their dimmed form for blocked items and empty rows.
var ink: Color
var dim_ink: Color
# Values next to labels, and prices.
var value: Color
var dim_value: Color
# Errors, losses and debt.
var error: Color
var dim_error: Color
# Faint alternating list rows.
var row_light: Color
var row_dark: Color
# The CRT power-on/off line and glow.
var glow: Color

static var OFFICE := office()
static var WORKSHOP := workshop()


static func office() -> TerminalPalette:
	return from_colors(Office.GREEN, Office.WHITE, Office.GLOW)


static func workshop() -> TerminalPalette:
	return from_colors(ORANGE, WARM_WHITE, WARM_GLOW)


static func from_colors(main: Color, white: Color, glow_color: Color) -> TerminalPalette:
	var palette := TerminalPalette.new()
	palette.ink = main
	palette.dim_ink = Color(main, Office.DIM_GREEN.a)
	palette.value = white
	palette.dim_value = Color(white, Office.DIM_WHITE.a)
	palette.error = Office.RED
	palette.dim_error = Office.DIM_RED
	palette.row_light = Color(main, Office.ROW_TINT_LIGHT.a)
	palette.row_dark = Color(main, Office.ROW_TINT_DARK.a)
	palette.glow = glow_color
	return palette


# Alternating faint list row tints, lighter on even rows.
func row_tint(index: int) -> Color:
	return row_light if index % 2 == 0 else row_dark
