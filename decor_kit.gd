class_name DecorKit
extends RefCounted
# What the decor (the Backdrop, clouds, Foreground, Beacon, city lights and vehicles) shares in
# building and moving its pieces.

# Moving decor wraps around this span of its layer's x, wider than anything the view can show
# however far the layer is shifted, so no piece ever pops in sight.
const WRAP_LEFT := -World.SIDE_OVERHANG - 1200.0
const WRAP_WIDTH := World.WORLD_WIDTH + 2.0 * (World.SIDE_OVERHANG + 1200.0)


# An x wrapped into the span moving decor wraps around.
static func wrapped_x(x: float) -> float:
	return fposmod(x - WRAP_LEFT, WRAP_WIDTH) + WRAP_LEFT


# A disc's outline: sides points around at, radius away.
static func disc(at: Vector2, radius: float, sides: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for side in sides:
		points.append(at + Vector2.from_angle(TAU * side / sides) * radius)
	return points


# Removes and frees every child of node, ready for building it afresh.
static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


# A top edge, left to right, closed straight down to bottom_y.
static func closed_down(top_edge: PackedVector2Array, bottom_y: float) -> PackedVector2Array:
	var outline := top_edge.duplicate()
	outline.append(Vector2(outline[-1].x, bottom_y))
	outline.append(Vector2(outline[0].x, bottom_y))
	return outline


# Adds a Polygon2D of outline to parent, in its own parallax layer anchored on anchor.
static func add_in_layer(parent: Node, outline: PackedVector2Array, scroll: Vector2, anchor: Vector2) -> Polygon2D:
	var layer := AnchoredParallax.new(scroll, anchor)
	parent.add_child(layer)
	var visual := Polygon2D.new()
	visual.polygon = outline
	layer.add_child(visual)
	return visual


# A parent's parallax layers, one per depth, all anchored on one point: at() gives the layer for a
# scroll scale, adding it to the parent the first time that depth is asked for.
class Depths:
	var parent: Node
	var anchor: Vector2
	var layers: Dictionary[Vector2, AnchoredParallax] = {}

	func _init(to: Node, at: Vector2) -> void:
		parent = to
		anchor = at

	func at(scroll: Vector2) -> AnchoredParallax:
		if not layers.has(scroll):
			layers[scroll] = AnchoredParallax.new(scroll, anchor)
			parent.add_child(layers[scroll])
		return layers[scroll]
