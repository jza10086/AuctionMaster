extends Control
## Public-snapshot-only presentation. The host owns the reveal clock and pause.
## Nothing is packed, rendered, selectable, or retained before the warehouse opens.
signal selection_changed(item: Dictionary)
signal reveal_progress(revealed: int, total: int)

const GRID_COLUMNS: int = 10
const GRID_ROWS: int = 6
const GRID_SIZE: Vector2 = Vector2(800.0, 480.0)
const REVEAL_SECONDS: float = 0.68
const ITEM_SIZES: Dictionary = {
	"vase": Vector2i(1, 2), "clock": Vector2i(2, 3),
	"radio": Vector2i(2, 2), "gold": Vector2i(2, 1), "gem": Vector2i(1, 1),
}
const TIER_COLORS: Array[Color] = [Color("879892"), Color("729bba"), Color("b19ad2"), Color("d5b978")]
const ITEM_SHORT_NAMES: Dictionary = {
	"vase": "青玉瓷瓶", "clock": "古董座钟", "radio": "老式收音机", "gold": "典藏金条", "gem": "彩色宝石",
}

# Public, read-only-by-convention presentation state for integration and QA.
var items: Array = []
var layout: Array[Rect2i] = []
var revealed_count: int = 0
var selected_index: int = -1
var warehouse: int = -1
var phase: String = ""
var opened: bool = false
var _reveal_elapsed: float = 0.0
var _animation_time: float = 0.0
var _revealed_at: Array[float] = []
var _hovered_index: int = -1
var _textures: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = GRID_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(queue_redraw)
	_load_item_textures()
	queue_redraw()

func _load_item_textures() -> void:
	for kind in ITEM_SIZES:
		var path: String = "res://assets/items/%s.svg" % kind
		if ResourceLoader.exists(path):
			var texture: Texture2D = load(path) as Texture2D
			if texture != null:
				_textures[kind] = texture

func set_snapshot(snap: Dictionary) -> void:
	var next_phase: String = str(snap.get("phase", ""))
	var next_warehouse: int = int(snap.get("warehouse", -1))
	var next_opened: bool = next_phase == "reveal" or next_phase == "finished"
	var public_items: Array = []
	# Ignore even an accidentally supplied inventory while bidding or between rounds.
	if next_opened and snap.get("items", []) is Array:
		for entry in snap.get("items", []):
			if entry is Dictionary:
				public_items.append(entry.duplicate(true))
	var changed: bool = next_warehouse != warehouse or next_opened != opened or public_items != items
	warehouse = next_warehouse
	phase = next_phase
	opened = next_opened
	if changed:
		items = public_items
		layout.clear()
		revealed_count = 0
		selected_index = -1
		_hovered_index = -1
		_reveal_elapsed = 0.0
		_animation_time = 0.0
		_revealed_at.clear()
		if opened:
			_pack_items()
		selection_changed.emit({})
		reveal_progress.emit(0, items.size())
	if opened and phase == "finished":
		skip_reveal()
	queue_redraw()

func _pack_items() -> void:
	# Stable, row-major first fit. Layout depends only on this public inventory.
	var occupied: Array[bool] = []
	occupied.resize(GRID_COLUMNS * GRID_ROWS)
	occupied.fill(false)
	for item in items:
		var footprint: Vector2i = ITEM_SIZES.get(str(item.get("kind", "")), Vector2i.ONE)
		var placed: bool = false
		for row in range(GRID_ROWS - footprint.y + 1):
			for column in range(GRID_COLUMNS - footprint.x + 1):
				var candidate: Rect2i = Rect2i(Vector2i(column, row), footprint)
				if _fits(candidate, occupied):
					layout.append(candidate)
					for y in range(row, row + footprint.y):
						for x in range(column, column + footprint.x):
							occupied[y * GRID_COLUMNS + x] = true
					placed = true
					break
			if placed:
				break
		# A malformed oversized external snapshot still never overlaps existing cells.
		if not placed:
			layout.append(Rect2i())
		_revealed_at.append(-100.0)

func _fits(candidate: Rect2i, occupied: Array[bool]) -> bool:
	for y in range(candidate.position.y, candidate.end.y):
		for x in range(candidate.position.x, candidate.end.x):
			if occupied[y * GRID_COLUMNS + x]:
				return false
	return true

func advance_reveal(delta: float) -> void:
	if not opened or delta <= 0.0:
		return
	_animation_time += delta
	if revealed_count < items.size():
		_reveal_elapsed += delta
		while _reveal_elapsed >= REVEAL_SECONDS and revealed_count < items.size():
			_reveal_elapsed -= REVEAL_SECONDS
			_revealed_at[revealed_count] = _animation_time - _reveal_elapsed
			revealed_count += 1
			reveal_progress.emit(revealed_count, items.size())
			if selected_index < 0:
				select_item(0)
	# Animation has no independent _process, timers, or tweens: pausing the host
	# freezes both discovery and the little scan/highlight effects immediately.
	queue_redraw()

func skip_reveal() -> void:
	if not opened:
		return
	var changed: bool = revealed_count != items.size()
	for index in range(revealed_count, items.size()):
		_revealed_at[index] = _animation_time - 1.0
	revealed_count = items.size()
	_reveal_elapsed = 0.0
	if changed:
		reveal_progress.emit(revealed_count, items.size())
	if selected_index < 0 and revealed_count > 0:
		select_item(0)
	queue_redraw()

func is_reveal_complete() -> bool:
	return opened and revealed_count == items.size()

func select_item(index: int) -> bool:
	if not opened or index < 0 or index >= revealed_count or index >= items.size():
		return false
	if selected_index != index:
		selected_index = index
		selection_changed.emit(get_selected_item())
		queue_redraw()
	return true

func get_selected_item() -> Dictionary:
	if not opened or selected_index < 0 or selected_index >= revealed_count or selected_index >= items.size():
		return {}
	return items[selected_index].duplicate(true)

func get_grid_rect() -> Rect2:
	var available: Vector2 = size if size.x > 0.0 and size.y > 0.0 else GRID_SIZE
	var cell: float = floorf(minf(available.x / GRID_COLUMNS, available.y / GRID_ROWS))
	var extent: Vector2 = Vector2(GRID_COLUMNS * cell, GRID_ROWS * cell)
	return Rect2(((available - extent) * 0.5).floor(), extent)

func get_item_rect(index: int) -> Rect2:
	if not opened or index < 0 or index >= layout.size():
		return Rect2()
	var grid: Rect2 = get_grid_rect()
	var cell: float = grid.size.x / GRID_COLUMNS
	return Rect2(grid.position + Vector2(layout[index].position) * cell, Vector2(layout[index].size) * cell)

func tier_for_value(value: int) -> int:
	if value >= 2500:
		return 3
	if value >= 1800:
		return 2
	if value >= 1000:
		return 1
	return 0

func tier_name(value: int) -> String:
	return ["普通", "稀有", "珍贵", "典藏"][tier_for_value(value)]

func tier_color(value: int) -> Color:
	return TIER_COLORS[tier_for_value(value)]

func _draw() -> void:
	var grid: Rect2 = get_grid_rect()
	var cell: float = grid.size.x / GRID_COLUMNS
	if cell <= 0.0:
		return
	draw_rect(grid, Color("10191c"))
	for row in range(GRID_ROWS):
		for column in range(GRID_COLUMNS):
			var tile: Rect2 = Rect2(grid.position + Vector2(column, row) * cell, Vector2.ONE * cell)
			draw_rect(tile.grow(-1.0), Color("182225"))
			# Every unopened slot is exactly alike, independent of the hidden lot.
			var center: Vector2 = tile.get_center()
			draw_line(center - Vector2(2.0, 0.0), center + Vector2(2.0, 0.0), Color("293438"), 1.0)
			draw_line(center - Vector2(0.0, 2.0), center + Vector2(0.0, 2.0), Color("293438"), 1.0)
	for column in range(GRID_COLUMNS + 1):
		var x: float = grid.position.x + column * cell
		draw_line(Vector2(x, grid.position.y), Vector2(x, grid.end.y), Color("303b3e"), 1.0)
	for row in range(GRID_ROWS + 1):
		var y: float = grid.position.y + row * cell
		draw_line(Vector2(grid.position.x, y), Vector2(grid.end.x, y), Color("303b3e"), 1.0)
	if not opened:
		_draw_sealed(grid)
		return
	for index in range(layout.size()):
		var rect: Rect2 = get_item_rect(index).grow(-3.0)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if index >= revealed_count:
			_draw_unknown(rect, index == revealed_count)
		else:
			_draw_item(rect, index)

func _draw_sealed(grid: Rect2) -> void:
	var panel: Rect2 = Rect2(grid.get_center() - Vector2(156.0, 48.0), Vector2(312.0, 96.0))
	draw_rect(panel, Color("121c20"))
	draw_rect(panel, Color("566058"), false, 1.0)
	draw_rect(Rect2(panel.position, Vector2(3.0, panel.size.y)), Color("c4b778"))
	# Small geometric seal, not a silhouette of the actual inventory.
	var lock_center: Vector2 = panel.position + Vector2(36.0, 45.0)
	draw_arc(lock_center - Vector2(0.0, 5.0), 9.0, PI, TAU, 18, Color("c4b778"), 2.0, true)
	draw_rect(Rect2(lock_center - Vector2(12.0, 5.0), Vector2(24.0, 20.0)), Color("c4b778"), false, 2.0)
	draw_circle(lock_center + Vector2(0.0, 2.0), 2.0, Color("c4b778"))
	draw_line(lock_center + Vector2(0.0, 3.0), lock_center + Vector2(0.0, 8.0), Color("c4b778"), 2.0)
	_draw_text("仓库已封存", panel.position + Vector2(65.0, 39.0), 20, Color("e2e5dc"))
	_draw_text("完成五轮暗标后开启", panel.position + Vector2(65.0, 64.0), 13, Color("a0aaa8"))

func _draw_unknown(rect: Rect2, scanning: bool) -> void:
	draw_rect(rect, Color("253034"))
	draw_rect(rect, Color("74817d") if scanning else Color("414e50"), false, 1.0)
	if scanning:
		var progress: float = clampf(_reveal_elapsed / REVEAL_SECONDS, 0.0, 1.0)
		var scan_y: float = rect.position.y + rect.size.y * progress
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * progress)), Color(0.57, 0.69, 0.64, 0.055))
		draw_line(Vector2(rect.position.x, scan_y), Vector2(rect.end.x, scan_y), Color("a8b9a1"), 1.0)
		_draw_text("检索中", rect.position + Vector2(8.0, rect.size.y - 9.0), 11, Color("b0bcb4"))
	var font: Font = get_theme_default_font()
	var question_size: Vector2 = font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30)
	_draw_text("?", rect.get_center() + Vector2(-question_size.x * 0.5, 10.0), 30, Color("81908e"))

func _draw_item(rect: Rect2, index: int) -> void:
	var item: Dictionary = items[index]
	var value: int = int(item.get("value", 0))
	var rarity: Color = tier_color(value)
	var selected: bool = selected_index == index
	var hovered: bool = _hovered_index == index
	var background: Color = Color("1b282b").lerp(rarity, 0.10 if selected else 0.055)
	draw_rect(rect, background)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3.0)), rarity)
	draw_rect(rect, rarity.darkened(0.44), false, 1.0)
	var kind: String = str(item.get("kind", ""))
	var icon_area: Rect2 = Rect2(rect.position + Vector2(7.0, 8.0), rect.size - Vector2(14.0, 36.0))
	if _textures.has(kind) and icon_area.size.x > 0.0 and icon_area.size.y > 0.0:
		var texture: Texture2D = _textures[kind]
		var texture_size: Vector2 = texture.get_size()
		var scale_factor: float = minf(icon_area.size.x / texture_size.x, icon_area.size.y / texture_size.y)
		var art_size: Vector2 = texture_size * scale_factor
		var art_rect: Rect2 = Rect2(icon_area.get_center() - art_size * 0.5, art_size)
		draw_texture_rect(texture, art_rect, false, Color.WHITE)
	else:
		# Neutral fallback for unknown public item kinds or unavailable artwork.
		var center: Vector2 = icon_area.get_center()
		var half: Vector2 = Vector2(minf(icon_area.size.x, 40.0), minf(icon_area.size.y, 40.0)) * 0.5
		draw_rect(Rect2(center - half, half * 2.0), rarity.darkened(0.45), false, 2.0)
		draw_line(center - half, center + half, rarity.darkened(0.45), 1.0)
	var name_text: String = str(ITEM_SHORT_NAMES.get(kind, item.get("name", "未知藏品")))
	var narrow: bool = rect.size.x < 100.0
	var label_height: float = 30.0 if narrow else 25.0
	draw_rect(Rect2(Vector2(rect.position.x + 1.0, rect.end.y - label_height), Vector2(rect.size.x - 2.0, label_height - 1.0)), Color(0.035, 0.055, 0.06, 0.72))
	var name_size: int = 10 if narrow else 11
	_draw_text(_fit_text(name_text, rect.size.x - 12.0, name_size), Vector2(rect.position.x + 6.0, rect.end.y - (17.0 if narrow else 10.0)), name_size, Color("cbd1c9"))
	var value_text: String = _format_value(value)
	var price_size: int = 11 if narrow else 12
	var price_width: float = get_theme_default_font().get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, price_size).x
	_draw_text(value_text, Vector2(rect.end.x - price_width - 6.0, rect.end.y - (4.0 if narrow else 10.0)), price_size, rarity.lightened(0.13))
	var flash: float = 1.0 - clampf((_animation_time - _revealed_at[index]) / 0.32, 0.0, 1.0)
	if flash > 0.0:
		draw_rect(rect, Color(rarity, flash * 0.14))
	if selected or hovered:
		var border: Color = Color("e8eee1") if selected else Color("a2b6aa")
		draw_rect(rect.grow(1.0), border, false, 1.0)
		if selected:
			_draw_selection_corners(rect.grow(1.0), border)

func _draw_selection_corners(rect: Rect2, color: Color) -> void:
	var length: float = 9.0
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		var horizontal: float = 1.0 if corner.x == rect.position.x else -1.0
		var vertical: float = 1.0 if corner.y == rect.position.y else -1.0
		draw_line(corner, corner + Vector2(length * horizontal, 0.0), color, 2.0)
		draw_line(corner, corner + Vector2(0.0, length * vertical), color, 2.0)

func _draw_text(text: String, baseline: Vector2, font_size: int, color: Color) -> void:
	draw_string(get_theme_default_font(), baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _fit_text(text: String, max_width: float, font_size: int) -> String:
	var font: Font = get_theme_default_font()
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width:
		return text
	while text.length() > 1 and font.get_string_size(text + "…", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > max_width:
		text = text.left(text.length() - 1)
	return text + "…"

func _format_value(value: int) -> String:
	var text: String = str(value)
	var result: String = ""
	for index in range(text.length()):
		if index > 0 and (text.length() - index) % 3 == 0:
			result += ","
		result += text[index]
	return result

func _index_at(point: Vector2) -> int:
	if not opened:
		return -1
	for index in range(revealed_count):
		if get_item_rect(index).has_point(point):
			return index
	return -1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered: int = _index_at(event.position)
		if hovered != _hovered_index:
			_hovered_index = hovered
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered >= 0 else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var index: int = _index_at(event.position)
		if select_item(index):
			grab_focus()
			accept_event()
	elif event is InputEventKey and event.pressed and not event.echo and revealed_count > 0:
		var index: int = selected_index
		match event.keycode:
			KEY_RIGHT, KEY_DOWN:
				index = mini(revealed_count - 1, selected_index + 1)
			KEY_LEFT, KEY_UP:
				index = maxi(0, selected_index - 1)
			KEY_HOME:
				index = 0
			KEY_END:
				index = revealed_count - 1
			_:
				return
		select_item(index)
		accept_event()

func _on_mouse_exited() -> void:
	_hovered_index = -1
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()
