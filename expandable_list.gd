class_name ExpandableList
extends RefCounted
# A Terminal list whose rows open to show details, several at once, and one cursor that
# walks a flat list: each row, followed by its button when the row is open and has one.
# Open rows and the cursor are kept by item, not index, so they stay with their item as
# rows above come and go; items that leave the list drop out. The caller passes the
# current items, and whether an open item's button can be selected.

var expanded: Array = []
# The row under the cursor, and whether the cursor is on that row's button instead.
var row := 0
var on_button := false
var _item: Object


# Follows the cursor's item and drops open items that left; call before reading or moving.
func sync(items: Array, has_button: Callable) -> void:
	expanded = expanded.filter(func(item: Object) -> bool: return item in items)
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
	on_button = false


# Escape on an open row or its button closes it and puts the cursor on the row. Returns
# whether anything closed.
func close_selected() -> bool:
	if not _item in expanded:
		return false
	expanded.erase(_item)
	on_button = false
	return true


func _has_open_button(item: Object, has_button: Callable) -> bool:
	return item != null and item in expanded and has_button.call(item)
