class_name World
extends Node2D

const WORLD_WIDTH := 2000.0
# Background drawn past the side edges, for windows wider than the world.
const SIDE_OVERHANG := 1200.0
# The Valley's ground; a location can lower it (the Mine's pit floor), keeping its depth.
const GROUND_TOP_Y := 608.0
const GROUND_BOTTOM_Y := 648.0
const GROUND_DEPTH := GROUND_BOTTOM_Y - GROUND_TOP_Y
# A ground spanning the whole world reaches past both sides, under the mountains.
const FULL_GROUND_COLLIDER_WIDTH := 4000.0
const FULL_GROUND_DRAWN_WIDTH := 2600.0
# About 7 s of full thrust straight up from the pad.
const BORDER_Y := -1660.0
const SPACE_TOP_Y := -4260.0

const MOUNTAIN_TOP_Y := 208.0
# Left mountain outline; the right one is its mirror image.
const MOUNTAIN_OUTLINE := [
	Vector2(-SIDE_OVERHANG, 640), Vector2(-SIDE_OVERHANG, MOUNTAIN_TOP_Y), Vector2(30, MOUNTAIN_TOP_Y),
	Vector2(70, 260), Vector2(110, 240), Vector2(150, 320), Vector2(130, 370), Vector2(190, 410),
	Vector2(170, 460), Vector2(230, 500), Vector2(210, 550), Vector2(250, 600), Vector2(250, 640),
]
# A location's terrain, such as the Mine's benches: warmer than the ground, like cut rock.
const TERRAIN_COLOR := Color(0.6, 0.42, 0.3)

# The solid scenery the sky's darkness dims (the ground, the mountains, a location's terrain);
# the pad isn't in it, so it stays easy to find at night.
const SCENERY_GROUP := &"scenery"

const STAR_SEED := 7
# Area of deep space per star, in px².
const STAR_SPACING := 6000.0
const STAR_RADIUS_MIN := 1.0
const STAR_RADIUS_MAX := 2.0
# Sides of the polygon each star is drawn as.
const STAR_SIDES := 8
const SURFACE_STAR_DEPTH := 300.0
const SURFACE_STAR_SHARE := 0.4
# The surface's night stars cover the whole surface sky, sparser than deep space, drawn at the
# sky's star brightness behind the Backdrop.
const NIGHT_STAR_SPACING := 12000.0

# The location below the station, whose pad and terrain the surface shows. The planet
# clock owns it; the World follows.
var location: Location:
	get:
		return clock.location
var sky := SkyLook.at(0.0)
# The whole local minute the sky was last taken for; it's taken again once a minute.
var sky_minute := -1
var star_positions := PackedVector2Array()
var star_radii := PackedFloat32Array()
var star_alphas := PackedFloat32Array()
var night_star_positions := PackedVector2Array()
var night_star_radii := PackedFloat32Array()
# Each star layer is one mesh built once, so neither a sky change nor a frame redraws its stars
# one by one; the night stars' brightness is their layer's modulate.
var deep_star_layer := MeshInstance2D.new()
var night_star_layer := MeshInstance2D.new()
# The current location's Backdrop, clouds and Foreground, built afresh by show_location().
var backdrop := Backdrop.new()
# The current location's Moons, drawn behind its clouds and Backdrop.
var moons := Moons.new()
var clouds := Clouds.new()
var foreground := Foreground.new()
# The current location's city lights, drawn over its buildings.
var city_lights := CityLights.new()
# Its distant flying vehicles, drawn behind its buildings.
var vehicles := Vehicles.new()
# Its signs of work (warning lights and slow movers) on its Backdrop's structures, drawn just over the Backdrop.
var activity := Activity.new()
# The pad's Beacon; a child of the pad, so it follows it to every location.
var beacon := Beacon.new()
# The left and the right mountain's outline, the same at every location.
var mountain_outlines: Array[PackedVector2Array] = []

@onready var mountains: StaticBody2D = $Mountains
@onready var terrain: StaticBody2D = $Terrain
@onready var ground: StaticBody2D = $Ground
@onready var ground_visual: Polygon2D = $Ground/Polygon2D
@onready var ground_shape: CollisionShape2D = $Ground/CollisionShape2D
@onready var pad: Polygon2D = $Ground/Pad
@onready var clock: PlanetClock = $PlanetClock
@onready var lander: Lander = $Lander


func _ready() -> void:
	var outline := PackedVector2Array(MOUNTAIN_OUTLINE)
	var mirrored := PackedVector2Array()
	for point in outline:
		mirrored.append(Vector2(WORLD_WIDTH - point.x, point.y))
	mountain_outlines = [outline, mirrored]
	for side in mountain_outlines:
		var shape := CollisionPolygon2D.new()
		shape.polygon = side
		mountains.add_child(shape)
	var half := Lander.PAD_WIDTH / 2.0
	pad.polygon = PackedVector2Array([
		Vector2(-half, -Lander.PAD_HEIGHT), Vector2(half, -Lander.PAD_HEIGHT),
		Vector2(half, 0), Vector2(-half, 0),
	])
	pad.add_child(beacon)
	clock.location_changed.connect(show_location)
	show_location(location)
	add_scenery(ground_visual)
	# Drawn over the gradient and under everything in the scene: the stars, the Moons, the clouds,
	# then the Backdrop and its signs of work. The Foreground, then the clouds' near wisps, are drawn
	# over everything, the ship included.
	var layers: Array[CanvasItem] = [deep_star_layer, night_star_layer, moons, clouds, backdrop, activity, vehicles]
	for i in layers.size():
		add_child(layers[i])
		move_child(layers[i], i)
	add_child(city_lights)
	move_child(city_lights, terrain.get_index() + 1)
	add_child(foreground)
	add_child(clouds.near)

	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	var width := WORLD_WIDTH + 2.0 * SIDE_OVERHANG
	var deep := Rect2(-SIDE_OVERHANG, SPACE_TOP_Y, width, BORDER_Y - SPACE_TOP_Y)
	add_stars(rng, deep, roundi(deep.get_area() / STAR_SPACING))
	var surface := Rect2(-SIDE_OVERHANG, BORDER_Y, width, SURFACE_STAR_DEPTH)
	add_stars(rng, surface, roundi(surface.get_area() / STAR_SPACING * SURFACE_STAR_SHARE))
	var surface_sky := Rect2(-SIDE_OVERHANG, BORDER_Y, width, GROUND_BOTTOM_Y - BORDER_Y)
	for i in roundi(surface_sky.get_area() / NIGHT_STAR_SPACING):
		night_star_positions.append(Vector2(rng.randf_range(surface_sky.position.x, surface_sky.end.x),
			rng.randf_range(surface_sky.position.y, surface_sky.end.y)))
		night_star_radii.append(rng.randf_range(STAR_RADIUS_MIN, STAR_RADIUS_MAX))
	var opaque := PackedFloat32Array()
	opaque.resize(night_star_positions.size())
	opaque.fill(1.0)
	deep_star_layer.mesh = star_mesh(star_positions, star_radii, star_alphas)
	night_star_layer.mesh = star_mesh(night_star_positions, night_star_radii, opaque)
	show_sky()


# The world redraws as the local time passes, and the location drifts.
func _physics_process(delta: float) -> void:
	if floori(clock.minutes) != sky_minute:
		show_sky()
	clock.count_drift(delta, lander.in_deep_space, surface_in_view())


# Whether any part of the surface (everything below the Border) is inside the visible area.
func surface_in_view() -> bool:
	var view := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	return view.end.y > BORDER_Y


# Takes the sky look for the current local time: redraws the gradient and Backdrop from it and
# dims the scenery.
func show_sky() -> void:
	sky = SkyLook.at(clock.minutes)
	sky_minute = floori(clock.minutes)
	for visual in get_tree().get_nodes_in_group(SCENERY_GROUP):
		dim(visual)
	night_star_layer.modulate.a = sky.star_brightness
	night_star_layer.visible = sky.star_brightness > 0.0
	beacon.show_sky(sky)
	backdrop.show_sky(sky, background_color)
	moons.show_sky(sky)
	clouds.show_sky(sky, background_color)
	foreground.show_sky(sky)
	city_lights.show_sky(sky)
	vehicles.show_sky(sky)
	activity.show_sky(sky, backdrop)
	queue_redraw()


# Makes a solid visual part of the scenery, dimmed by the sky's darkness from now on; a
# location's terrain goes through here too.
func add_scenery(visual: CanvasItem) -> void:
	visual.add_to_group(SCENERY_GROUP)
	dim(visual)


func dim(visual: CanvasItem) -> void:
	visual.self_modulate = Color.WHITE.darkened(sky.darkness)


# Moves the surface to the clock's new location: its ground's height and width (the pad sits on
# it), its pad, and its terrain built afresh.
func show_location(to: Location) -> void:
	ground.position.y = to.ground_y + GROUND_DEPTH / 2.0
	show_ground_width(to)
	pad.position.x = to.pad_center_x - ground.position.x
	queue_redraw()
	var anchor := to.pad_top()
	backdrop.build(to.backdrop, to.lowest_y, anchor)
	backdrop.show_sky(sky, background_color)
	moons.build(to.moons, anchor)
	moons.show_sky(sky)
	clouds.build(to.clouds, anchor)
	clouds.show_sky(sky, background_color)
	foreground.build(to.foreground, to.lowest_y, anchor)
	foreground.show_sky(sky)
	city_lights.build(to)
	city_lights.show_sky(sky)
	vehicles.build(to.vehicles, anchor)
	vehicles.show_sky(sky)
	activity.build(to.activity_lights, to.movers, anchor)
	activity.show_sky(sky, backdrop)
	dress_mountains(to.mountains)
	for child in terrain.get_children():
		terrain.remove_child(child)
		child.queue_free()
	for outline in to.terrain:
		var shape := CollisionPolygon2D.new()
		shape.polygon = outline
		terrain.add_child(shape)
		var visual := Polygon2D.new()
		visual.polygon = outline
		visual.color = TERRAIN_COLOR
		terrain.add_child(visual)
		add_scenery(visual)


# A full-width ground spans the world and past its sides; a narrowed one is centred on the pad.
func show_ground_width(to: Location) -> void:
	var shape := RectangleShape2D.new()
	var half_drawn: float
	if is_inf(to.ground_width):
		ground.position.x = WORLD_WIDTH / 2.0
		shape.size = Vector2(FULL_GROUND_COLLIDER_WIDTH, GROUND_DEPTH)
		half_drawn = FULL_GROUND_DRAWN_WIDTH / 2.0
	else:
		ground.position.x = to.pad_center_x
		shape.size = Vector2(to.ground_width, GROUND_DEPTH)
		half_drawn = to.ground_width / 2.0
	ground_shape.shape = shape
	var half_depth := GROUND_DEPTH / 2.0
	ground_visual.polygon = PackedVector2Array([
		Vector2(-half_drawn, -half_depth), Vector2(half_drawn, -half_depth),
		Vector2(half_drawn, half_depth), Vector2(-half_drawn, half_depth),
	])


# The lowest the current location's surface reaches: the camera's bottom limit.
func lowest_point() -> float:
	return location.lowest_y


# Dresses the Mountains in a location's look: each mountain's outline filled with its base colour,
# then its dressings over it, clipped to the outline; all solid scenery, dimmed by the sky.
func dress_mountains(look: MountainLook) -> void:
	for child in mountains.get_children():
		if child is Polygon2D:
			mountains.remove_child(child)
			child.queue_free()
	for side in mountain_outlines.size():
		var base := Polygon2D.new()
		base.polygon = mountain_outlines[side]
		base.color = look.base
		mountains.add_child(base)
		add_scenery(base)
		for dressing in look.dressed(side, mountain_outlines[side]):
			var visual := Polygon2D.new()
			var points := PackedVector2Array()
			var shapes: Array[PackedInt32Array] = []
			for shape: PackedVector2Array in dressing[1]:
				var indices := PackedInt32Array()
				for point in shape:
					indices.append(points.size())
					points.append(point)
				shapes.append(indices)
			visual.polygon = points
			visual.polygons = shapes
			visual.color = dressing[0]
			mountains.add_child(visual)
			add_scenery(visual)


func add_stars(rng: RandomNumberGenerator, area: Rect2, count: int) -> void:
	for i in count:
		var star := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		star_positions.append(star)
		star_radii.append(rng.randf_range(STAR_RADIUS_MIN, STAR_RADIUS_MAX))
		# Stars below the border fade out toward the bright surface.
		star_alphas.append(1.0 - clampf((star.y - BORDER_Y) / SURFACE_STAR_DEPTH, 0.0, 1.0))


# One mesh of small white polygons, each star's alpha in its vertex colours.
func star_mesh(positions: PackedVector2Array, radii: PackedFloat32Array, alphas: PackedFloat32Array) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	for i in positions.size():
		if alphas[i] <= 0.0:
			continue
		var color := Color(1, 1, 1, alphas[i])
		for side in STAR_SIDES:
			vertices.append(positions[i])
			vertices.append(positions[i] + Vector2.from_angle(TAU * side / STAR_SIDES) * radii[i])
			vertices.append(positions[i] + Vector2.from_angle(TAU * (side + 1) / STAR_SIDES) * radii[i])
			for corner in 3:
				colors.append(color)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


class Star:
	var position: Vector2
	var radius: float
	var color: Color

	func _init(at: Vector2, size: float, tint: Color) -> void:
		position = at
		radius = size
		color = tint


# Every star the World draws: the surface's night stars (none by day), then the deep-space
# stars. Fully transparent ones are left out.
func shown_stars() -> Array[Star]:
	return night_stars() + deep_space_stars()


func night_stars() -> Array[Star]:
	var stars: Array[Star] = []
	if night_star_layer.visible:
		for i in night_star_positions.size():
			stars.append(Star.new(night_star_positions[i], night_star_radii[i], Color(1, 1, 1, night_star_layer.modulate.a)))
	return stars


func deep_space_stars() -> Array[Star]:
	var stars: Array[Star] = []
	for i in star_positions.size():
		if star_alphas[i] > 0.0:
			stars.append(Star.new(star_positions[i], star_radii[i], Color(1, 1, 1, star_alphas[i])))
	return stars


# Which part of the scene a decor piece belongs to.
enum DecorLayer { BACKDROP, PARALLAX, FOREGROUND, BEACON, LIGHTS }
# What a decor piece is within its layer: a light, the glow around one, a ridge, a cloud, a
# silhouette, one of a city's lights (all its windows, one mesh; a neon sign; a warning light; a
# flying vehicle's light) or a flying vehicle; then a Moon, a Vehicle's trail and a translucent
# cloud wisp in front of the ship; then a skyline depth's lit windows (one mesh), its beacons (one
# mesh) and a band of haze between skyline depths; then a slow mover on the Backdrop's structures
# (a crane's trolley, a hauler, a conveyor's marks). New kinds of decor add their part at the end.
enum DecorPart { LIGHT, GLOW, RIDGE, CLOUD, SILHOUETTE, WINDOWS, NEON, WARNING_LIGHT, VEHICLE_LIGHT, VEHICLE, MOON, TRAIL, WISP, SKYLINE_WINDOWS, SKYLINE_BEACON, HAZE, MOVER }


# One decor piece as drawn: its layer and part, whether it has a collider, its colour as drawn
# (tinted by its own and its ancestors' modulate; a piece filled with a gradient gives the average
# of its vertex colours), its opacity as drawn (its colour's alpha: 1 opaque, 0 invisible), how fast
# it scrolls with the camera (its parallax layer's scroll scale; the world's, 1, if it's in none)
# and where it appears on screen: its outline (a mesh's is its bounding box) and that outline's
# bounding box.
class Decor:
	var layer: DecorLayer
	var part: DecorPart
	var has_collider: bool
	var color: Color
	var opacity: float:
		get:
			return color.a
	var scroll_scale := Vector2.ONE
	var screen_outline: PackedVector2Array
	var screen_area: Rect2


# One decor piece as its module lists it (each decor module's listed_decor()): its visual (a
# Polygon2D or MeshInstance2D), layer and part.
class Listing:
	var visual: Node2D
	var layer: DecorLayer
	var part: DecorPart

	func _init(piece: Node2D, in_layer: DecorLayer, as_part: DecorPart) -> void:
		visual = piece
		layer = in_layer
		part = as_part


# The listings of pieces, all in one layer and part.
static func listings(pieces: Array, layer: DecorLayer, part: DecorPart) -> Array[Listing]:
	var listed: Array[Listing] = []
	for piece: Node2D in pieces:
		listed.append(Listing.new(piece, layer, part))
	return listed


# Every decor piece the World draws, as it appears on screen for a camera centred on
# camera_center at zoom (the viewport's centre is the camera's). Read-only, for tests.
func shown_decor(camera_center: Vector2, zoom: float) -> Array[Decor]:
	var pieces: Array[Decor] = []
	for module in [backdrop, moons, clouds, vehicles, beacon, foreground, city_lights, activity]:
		for listing: Listing in module.listed_decor():
			pieces.append(decor(listing.visual, listing.layer, listing.part, camera_center, zoom))
	return pieces


# visual is a Polygon2D, or a MeshInstance2D (listed as its mesh's bounding box, coloured by the
# average of its vertex colours).
func decor(visual: Node2D, layer: DecorLayer, part: DecorPart, camera_center: Vector2, zoom: float) -> Decor:
	var piece := Decor.new()
	piece.layer = layer
	piece.part = part
	# A Polygon2D is never itself a collider; it would have one only through a child.
	piece.has_collider = visual.get_children().any(
		func(child: Node) -> bool: return child is CollisionObject2D or child is CollisionShape2D or child is CollisionPolygon2D)
	var outline: PackedVector2Array
	var vertex_colors: PackedColorArray
	if visual is MeshInstance2D:
		var mesh := (visual as MeshInstance2D).mesh
		var box := mesh.get_aabb()
		outline = PackedVector2Array([Vector2(box.position.x, box.position.y), Vector2(box.end.x, box.position.y),
			Vector2(box.end.x, box.end.y), Vector2(box.position.x, box.end.y)])
		piece.color = visual.self_modulate
		vertex_colors = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	else:
		var polygon := visual as Polygon2D
		outline = polygon.polygon
		piece.color = polygon.color * polygon.self_modulate
		vertex_colors = polygon.vertex_colors
	if not vertex_colors.is_empty():
		var total := Color(0, 0, 0, 0)
		for color in vertex_colors:
			total += color
		piece.color *= total / vertex_colors.size()
	# A piece in a parallax layer is drawn where that layer would be for this camera, not the
	# actual one.
	var shift := Vector2.ZERO
	var node: Node = visual
	while node is CanvasItem:
		piece.color *= (node as CanvasItem).modulate
		if node is AnchoredParallax:
			var parallax := node as AnchoredParallax
			piece.scroll_scale = parallax.scroll_scale
			shift = parallax.offset_for(camera_center) - parallax.position
		node = node.get_parent()
	var screen_center := get_viewport_rect().size / 2.0
	var area := Rect2()
	for i in outline.size():
		var on_screen := (visual.to_global(outline[i]) + shift - camera_center) * zoom + screen_center
		piece.screen_outline.append(on_screen)
		area = Rect2(on_screen, Vector2.ZERO) if i == 0 else area.expand(on_screen)
	piece.screen_area = area
	return piece


func _draw() -> void:
	var left := -SIDE_OVERHANG
	var right := WORLD_WIDTH + SIDE_OVERHANG
	draw_polygon(PackedVector2Array([
		Vector2(left, BORDER_Y), Vector2(right, BORDER_Y),
		Vector2(right, GROUND_BOTTOM_Y), Vector2(left, GROUND_BOTTOM_Y),
	]), PackedColorArray([Color.BLACK, Color.BLACK, sky.ground_color, sky.ground_color]))
	# Down to the location's lowest point below the Valley's ground (the open-pit mine), the sky
	# keeps its ground colour.
	if lowest_point() > GROUND_BOTTOM_Y:
		draw_rect(Rect2(left, GROUND_BOTTOM_Y, right - left, lowest_point() - GROUND_BOTTOM_Y), sky.ground_color)


func background_color(y: float) -> Color:
	return Color.BLACK.lerp(sky.ground_color, clampf(inverse_lerp(BORDER_Y, GROUND_BOTTOM_Y, y), 0.0, 1.0))
