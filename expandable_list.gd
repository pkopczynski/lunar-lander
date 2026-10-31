class_name ExpandableList
extends RefCounted
# A Terminal list whose rows open to show details, several at once, and one cursor that
# walks a flat list: each row, followed by its button when the row is open and has one.
# Open rows and the cursor are kept by item, not index, so they stay with their item as
# rows above come and go; items that leave the list drop out. The caller passes the
# current items, and whether an open item's button can be selected.
# It also keeps what the list's drawing shares: open details grow open over OPEN_TIME, the
# list scrolls to keep the cursor in view, and drawn ▲/▼ markers (Silkscreen has no arrow
# glyphs) show when content lies above or below. Row tints are Office colours.

# Opening animation: seconds the details take to grow open, and its ease (below 1 eases out).
const OPEN_TIME := 0.15
const OPEN_EASE := 0.5
# ▲/▼ markers: triangle size, and their gap from the list's right edge.
const MARKER_SIZE := Vector2(10, 7)
const MARKER_GAP := 8.0

var expanded: Array = []
# The row under the cursor, and whether the cursor is on that row's button instead.
var row := 0
var on_button := false
var _item: Object
# Pixels the list is scrolled down, with the content and view heights and the cursor's span
# (top, bottom) in content pixels from the last follow().
var scroll := 0.0
var _content_height := 0.0
var _view_height := 0.0
var _cursor := Vector2.ZERO
# Seconds since each open item opened.
var _opened := {}


# Follows the cursor's item and drops open items that left; call before reading or moving.
func sync(items: Array, has_button: Callable) -> void:
	expanded = expanded.filter(func(item: Object) -> bool: return item in items)
	for item: Object in _opened.keys():
		if not item in expanded:
			_opened.erase(item)
	if _item in items:
		row = items.find(_item)
	row = clampi(row, 0, items.size() - 1)
	_item = items[row] if not items.is_empty() else null
	on_button = on_button and _has_open_button(_item, has_button)


func selected() -> Object:
	return _item


func move(items: Array, step: int, has_button: Callable) -> void:
	sync(items, has_button)
	var stops: Array[Array] = []
	for item: Object in items:
		stops.append([item, false])
		if _has_open_button(item, has_button):
			stops.append([item, true])
	if stops.is_empty():
		return
	var at := clampi(stops.find([_item, on_button]) + step, 0, stops.size() - 1)
	_item = stops[at][0]
	on_button = stops[at][1]
	row = items.find(_item)


# Return on a row opens or closes it; the cursor stays on the row.
func toggle() -> void:
	if _item == null:
		return
	if _item in expanded:
		expanded.erase(_item)
	else:
		expanded.append(_item)
		_opened[_item] = 0.0
	on_button = false


# Escape on an open row or its button closes it and puts the cursor on the row. Returns
# whether anything closed.
func close_selected() -> bool:
	if not _item in expanded:
		return false
	expanded.erase(_item)
	on_button = false
	return true


func tick(delta: float) -> void:
	for item: Object in _opened:
		_opened[item] += delta


# How far the item's details are open: 0 closed, 1 fully open.
func open_share(item: Object) -> float:
	if not item in expanded:
		return 0.0
	return ease(clampf(_opened.get(item, OPEN_TIME) / OPEN_TIME, 0.0, 1.0), OPEN_EASE)


# Scrolls just enough to keep the cursor in a view_height tall view. measure(item) gives
# Vector2(row height, details height when fully open); an open item's button takes the
# bottom button_height of its details.
func follow(items: Array, measure: Callable, view_height: float, button_height: float) -> void:
	var top := 0.0
	_cursor = Vector2.ZERO
	for item: Object in items:
		var heights: Vector2 = measure.call(item)
		var bottom := top + heights.x + heights.y * open_share(item)
		if item == _item:
			_cursor = Vector2(bottom - button_height, bottom) if on_button else Vector2(top, top + heights.x)
		top = bottom
	_content_height = top
	_view_height = view_height
	scroll = clampf(scroll, _cursor.y - view_height, _cursor.x)
	scroll = clampf(scroll, 0.0, maxf(_content_height - view_height, 0.0))


func more_above() -> bool:
	return scroll > 0.0


func more_below() -> bool:
	return scroll + _view_height < _content_height


func cursor_in_view() -> bool:
	return _cursor.x >= scroll and _cursor.y <= scroll + _view_height


# ▲ at the top and ▼ at the bottom, just right of the list's area, where content lies beyond.
func draw_markers(canvas: CanvasItem, area: Rect2, color: Color) -> void:
	var x := area.end.x + MARKER_GAP
	var half := MARKER_SIZE.x / 2.0
	if more_above():
		var top := area.position.y
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x + half, top), Vector2(x + MARKER_SIZE.x, top + MARKER_SIZE.y),
			Vector2(x, top + MARKER_SIZE.y)]), color)
	if more_below():
		var bottom := area.end.y
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x, bottom - MARKER_SIZE.y),
			Vector2(x + MARKER_SIZE.x, bottom - MARKER_SIZE.y), Vector2(x + half, bottom)]), color)


# Alternating faint row tints, lighter on even rows.
static func row_tint(index: int) -> Color:
	return Office.ROW_TINT_LIGHT if index % 2 == 0 else Office.ROW_TINT_DARK


# Draws a filled rect cut to the clip area; drawing has no clipping of its own.
static func draw_clipped_rect(canvas: CanvasItem, rect: Rect2, clip: Rect2, color: Color) -> void:
	var visible := rect.intersection(clip)
	if visible.has_area():
		canvas.draw_rect(visible, color)


# Whether a line of text at this baseline lies wholly in the clip area; lines that don't are skipped.
static func line_fits(baseline_y: float, font_size: int, clip: Rect2) -> bool:
	return baseline_y - font_size >= clip.position.y and baseline_y <= clip.end.y


func _has_open_button(item: Object, has_button: Callable) -> bool:
	return item != null and item in expanded and has_button.call(item)
