class_name ExpandableList
extends RefCounted
# A Terminal list whose rows open to show details, several at once, and one cursor that
# walks a flat list: each row, followed by its button when the row is open and has one.
# Open rows and the cursor are kept by item, not index, so they stay with their item as
# rows above come and go; items that leave the list drop out. The caller gives the current
# items, whether an open item's button can be selected, and each item's heights.
# It also keeps what the list's drawing shares: open details grow open over OPEN_TIME, the
# list scrolls to keep the cursor in view, and drawn ▲/▼ markers (Silkscreen has no arrow
# glyphs) show when content lies above or below.

# Opening animation: seconds the details take to grow open, and its ease (below 1 eases out).
const OPEN_TIME := 0.15
const OPEN_EASE := 0.5
# ▲/▼ markers: triangle size, and their gap from the list's right edge.
const MARKER_SIZE := Vector2(10, 7)
const MARKER_GAP := 8.0

# Pixels the list is scrolled down, as of the last follow().
var scroll := 0.0
# items() gives the current items; has_button(item) whether an open item's button can be
# selected; measure(item) gives Vector2(row height, details height when fully open); an open
# item's button takes the bottom button_height of its details.
var _items: Callable
var _has_button: Callable
var _measure: Callable
var _button_height: float
var _expanded: Array[Object] = []
# The cursor's item and row, and whether it's on that row's button instead. The row is kept
# so that when the item leaves, the cursor stays at its place.
var _item: Object
var _row := 0
var _on_button := false
# The content and view heights and the cursor's span (top, bottom) in content pixels, as of
# the last follow().
var _content_height := 0.0
var _view_height := 0.0
var _cursor := Vector2.ZERO
# Seconds since each open item opened.
var _opened: Dictionary[Object, float] = {}


func _init(items: Callable, has_button: Callable, measure: Callable, button_height: float) -> void:
	_items = items
	_has_button = has_button
	_measure = measure
	_button_height = button_height


# Follows the cursor's item and drops open items that left; moving, opening and following
# call it themselves.
func sync() -> void:
	var items: Array = _items.call()
	_expanded.assign(_expanded.filter(func(item: Object) -> bool: return item in items))
	for item: Object in _opened.keys():
		if not item in _expanded:
			_opened.erase(item)
	_item = selected()
	_row = selected_index()
	_on_button = on_button()


func selected() -> Object:
	var items: Array = _items.call()
	var row := selected_index()
	return items[row] if row >= 0 and row < items.size() else null


func selected_index() -> int:
	var items: Array = _items.call()
	var row := items.find(_item) if _item != null else -1
	return row if row != -1 else clampi(_row, 0, items.size() - 1)


func on_button() -> bool:
	return _on_button and _has_open_button(selected())


# The open rows, top to bottom.
func expanded_rows() -> Array[int]:
	var open: Array[int] = []
	var items: Array = _items.call()
	for i in items.size():
		if items[i] in _expanded:
			open.append(i)
	return open


func move(step: int) -> void:
	sync()
	var items: Array = _items.call()
	var stops: Array[Array] = []
	for item: Object in items:
		stops.append([item, false])
		if _has_open_button(item):
			stops.append([item, true])
	if stops.is_empty():
		return
	var at := clampi(stops.find([_item, _on_button]) + step, 0, stops.size() - 1)
	_item = stops[at][0]
	_on_button = stops[at][1]
	_row = items.find(_item)


# Return on a row opens or closes it; the cursor stays on the row.
func toggle() -> void:
	sync()
	if _item == null:
		return
	if _item in _expanded:
		_expanded.erase(_item)
	else:
		_expanded.append(_item)
		_opened[_item] = 0.0
	_on_button = false


# Escape on an open row or its button closes it and puts the cursor on the row. Returns
# whether anything closed.
func close_selected() -> bool:
	sync()
	if not _item in _expanded:
		return false
	_expanded.erase(_item)
	_on_button = false
	return true


func tick(delta: float) -> void:
	for item: Object in _opened:
		_opened[item] += delta


# How far the item's details are open: 0 closed, 1 fully open.
func open_share(item: Object) -> float:
	if not item in _expanded:
		return 0.0
	return ease(clampf(_opened.get(item, OPEN_TIME) / OPEN_TIME, 0.0, 1.0), OPEN_EASE)


# Scrolls just enough to keep the cursor in a view_height tall view. On an open item with no
# button to stop on, the details can't be reached by moving down, so they're kept in view
# with the row, as far as the view's height allows.
func follow(view_height: float) -> void:
	sync()
	var top := 0.0
	_cursor = Vector2.ZERO
	var kept := Vector2.ZERO
	for item: Object in _items.call():
		var heights: Vector2 = _measure.call(item)
		var bottom := top + heights.x + heights.y * open_share(item)
		if item == _item:
			_cursor = Vector2(bottom - _button_height, bottom) if _on_button else Vector2(top, top + heights.x)
			kept = _cursor
			if item in _expanded and not _has_button.call(item):
				kept = Vector2(top, minf(bottom, top + view_height))
		top = bottom
	_content_height = top
	_view_height = view_height
	scroll = clampf(scroll, kept.y - view_height, kept.x)
	scroll = clampf(scroll, 0.0, maxf(_content_height - view_height, 0.0))


func more_above() -> bool:
	return scroll > 0.0


func more_below() -> bool:
	return scroll + _view_height < _content_height


# Whether the row or button under the cursor lies wholly in the view.
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


# Draws a filled rect cut to the clip area; drawing has no clipping of its own.
static func draw_clipped_rect(canvas: CanvasItem, rect: Rect2, clip: Rect2, color: Color) -> void:
	var visible := rect.intersection(clip)
	if visible.has_area():
		canvas.draw_rect(visible, color)


# Whether a line of text at this baseline lies wholly in the clip area; lines that don't are skipped.
static func line_fits(baseline_y: float, font_size: int, clip: Rect2) -> bool:
	return baseline_y - font_size >= clip.position.y and baseline_y <= clip.end.y


func _has_open_button(item: Object) -> bool:
	return item != null and item in _expanded and _has_button.call(item)
