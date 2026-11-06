class_name AnchoredParallax
extends Parallax2D
# A parallax layer anchored on a point (the current pad's top): with the camera centred there,
# everything in it sits exactly where it was designed; elsewhere it's shifted by how far the
# camera is from the anchor, times (1 - scroll_scale). Below 1 it moves more slowly than the world
# (behind it), above 1 faster (in front of it). Godot's Parallax2D follows the camera itself.

var anchor := Vector2.ZERO


func _init(scale := Vector2.ONE, at := Vector2.ZERO) -> void:
	scroll_scale = scale
	anchor = at


func _ready() -> void:
	get_viewport().size_changed.connect(fit_anchor)
	fit_anchor()


# Parallax2D places itself at (camera centre - half the viewport) * (1 - scroll_scale) +
# scroll_offset, whatever the zoom; this offset cancels it out with the camera on the anchor.
func fit_anchor() -> void:
	scroll_offset = -(anchor - get_viewport_rect().size / 2.0) * (Vector2.ONE - scroll_scale)


# Where the layer is placed for a camera centred on camera_center.
func offset_for(camera_center: Vector2) -> Vector2:
	return (camera_center - anchor) * (Vector2.ONE - scroll_scale)
