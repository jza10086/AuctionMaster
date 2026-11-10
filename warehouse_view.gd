extends Control
## Draw public opened lots or recipient-filtered discovery records. Never receives hidden items.
signal selection_changed(item: Dictionary)
signal reveal_progress(revealed: int, total: int)

const Rules: Script = preload("res://games/minigame/gp_auction_master/rules.gd")
const Catalog: Script = preload("res://games/minigame/gp_auction_master/item_catalog.gd")
const GRID_COLUMNS: int = Catalog.GRID_COLUMNS
const GRID_ROWS: int = Catalog.GRID_ROWS
const CELL_SIZE: float = 60.0
const GRID_SIZE: Vector2 = Vector2(GRID_COLUMNS * CELL_SIZE, GRID_ROWS * CELL_SIZE)
const REVEAL_SECONDS: float = 0.12
const TEXT: Translation = preload("res://games/minigame/gp_auction_master/i18n/zh_Hans.po")
# Public, read-only-by-convention presentation state for integration and QA.
var items: Array = []
var layout: Array[Rect2i] = []
var revealed_count: int = 0
var selected_index: int = -1
var warehouse: int = -1
var phase: String = ""
var opened: bool = false
var _grid_rows: int = GRID_ROWS
var _search_ends: Array[float] = []
var _search_clock: float = 0.0
var _since_search_snapshot: float = 0.0
var _reveal_elapsed: float = 0.0
var _animation_time: float = 0.0
var _revealed_at: Array[float] = []
var _hovered_index: int = -1
var _textures: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(queue_redraw)
	_load_item_textures()
	queue_redraw()

func _load_item_textures() -> void:
	for item: Dictionary in Catalog.new().items:
		var kind: String = item.kind
		var path: String = "res://games/minigame/gp_auction_master/assets/items/realistic/%s.png" % kind
		if ResourceLoader.exists(path):
			var texture: Texture2D = load(path) as Texture2D
			if texture != null:
				_textures[kind] = texture

## Animate only new personal information; public clues and opened lots stay authoritative.
signal assist_search_changed(active: bool)
signal assist_found(item: Dictionary)
@export_range(0.1, 3.0) var assist_search_seconds: float = 0.65
var _assist_warehouse: int = -1
var _received_discoveries: Dictionary = {}
var _displayed_discoveries: Array = []
var _assist_queue: Array[Dictionary] = []
var _assist_elapsed: float = 0.0
var _assist_snapshot: Dictionary = {}

func is_assist_searching() -> bool:
	return not _assist_queue.is_empty()

func get_assist_rect() -> Rect2:
	var rect: Array = _assist_queue[0].rect
	return Rect2(get_grid_rect().position + Vector2(rect[0], rect[1]) * CELL_SIZE, Vector2.ONE * CELL_SIZE)

func set_snapshot(snap: Dictionary, discoveries: Array = [], animate_assists: bool = false) -> void:
	var next_opened: bool = snap.phase in ["settlement", "reveal", "finished"]
	var reset: bool = int(snap.warehouse) != _assist_warehouse or not animate_assists or next_opened
	if reset:
		var was_searching: bool = is_assist_searching()
		_assist_queue.clear()
		_assist_elapsed = 0.0
		_assist_warehouse = int(snap.warehouse)
		_received_discoveries.clear()
		_displayed_discoveries = snap.public_intel.duplicate(true) if animate_assists and not next_opened else discoveries.duplicate(true)
		for item: Dictionary in _displayed_discoveries:
			_received_discoveries[int(item.index)] = item.duplicate(true)
		if was_searching:
			assist_search_changed.emit(false)
	_assist_snapshot = snap
	if animate_assists and not next_opened:
		var was_searching: bool = is_assist_searching()
		for item: Dictionary in discoveries:
			if _received_discoveries.get(int(item.index), {}) != item:
				_assist_queue.append(item.duplicate(true))
				_received_discoveries[int(item.index)] = item.duplicate(true)
		_set_visible_snapshot(snap, _displayed_discoveries)
		if not was_searching and is_assist_searching():
			assist_search_changed.emit(true)
	else:
		_set_visible_snapshot(snap, discoveries)

func _advance_assist_search(delta: float) -> void:
	if not is_assist_searching():
		return
	_assist_elapsed += delta
	_animation_time += delta
	while is_assist_searching() and _assist_elapsed >= assist_search_seconds:
		_assist_elapsed -= assist_search_seconds
		var found: Dictionary = _assist_queue.pop_front()
		var existing: int = -1
		for index: int in _displayed_discoveries.size():
			if int(_displayed_discoveries[index].index) == int(found.index):
				existing = index
				break
		if existing >= 0:
			_displayed_discoveries[existing] = found
		else:
			_displayed_discoveries.append(found)
		_set_visible_snapshot(_assist_snapshot, _displayed_discoveries)
		assist_found.emit(found)
	if not is_assist_searching():
		_assist_elapsed = 0.0
		assist_search_changed.emit(false)
	queue_redraw()

func _set_visible_snapshot(snap: Dictionary, discoveries: Array) -> void:
	var next_opened: bool = snap.phase in ["settlement", "reveal", "finished"]
	var visible_items: Array = snap.items.duplicate(true) if next_opened else discoveries.duplicate(true)
	var changed: bool = int(snap.warehouse) != warehouse or next_opened != opened or visible_items != items
	warehouse = snap.warehouse
	phase = snap.phase
	opened = next_opened
	if phase == "settlement":
		_search_ends.assign(snap.search_ends)
	if changed:
		items = visible_items
		layout.clear()
		selected_index = -1
		_hovered_index = -1
		_reveal_elapsed = 0.0
		_animation_time = 0.0
		_search_clock = 0.0
		_since_search_snapshot = 0.0
		_revealed_at.resize(items.size())
		_revealed_at.fill(-100.0)
		if opened:
			layout = Catalog.pack(items)
		else:
			for item: Dictionary in items:
				var rect: Array = item.rect
				layout.append(Rect2i(rect[0], rect[1], rect[2], rect[3]))
		_grid_rows = GRID_ROWS
		for rect: Rect2i in layout:
			_grid_rows = maxi(_grid_rows, rect.end.y + 1)
		custom_minimum_size = Vector2(GRID_SIZE.x, _grid_rows * CELL_SIZE)
		revealed_count = 0 if opened else items.size()
		selection_changed.emit({})
		reveal_progress.emit(revealed_count, items.size())
	if opened and phase == "finished":
		skip_reveal()
	queue_redraw()

## Synchronize the host clock without exposing animation internals. Repeated/older clocks do not rewind.
func set_reveal_elapsed(elapsed_seconds: float) -> void:
	if phase != "settlement":
		advance_reveal(maxf(0.0, elapsed_seconds - _animation_time))
		return
	_search_clock = maxf(_search_clock, elapsed_seconds)
	_since_search_snapshot = 0.0
	_update_search(_search_clock)

func _process(delta: float) -> void:
	if is_visible_in_tree():
		_advance_assist_search(delta)
	if phase != "settlement" or not is_visible_in_tree():
		return
	_since_search_snapshot += delta
	_update_search(_search_clock + minf(_since_search_snapshot, 0.1))

func _update_search(elapsed: float) -> void:
	_animation_time = maxf(_animation_time, elapsed)
	var target_count: int = Rules.revealed_items(_search_ends, _animation_time)
	while revealed_count < target_count:
		_revealed_at[revealed_count] = _search_ends[revealed_count]
		revealed_count += 1
		reveal_progress.emit(revealed_count, items.size())
	if selected_index < 0 and revealed_count > 0:
		select_item(0)
	queue_redraw()

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
	for index: int in range(revealed_count, items.size()):
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
	if index < 0 or index >= revealed_count or index >= items.size():
		return false
	if selected_index != index:
		selected_index = index
		selection_changed.emit(get_selected_item())
		queue_redraw()
	return true

func get_selected_item() -> Dictionary:
	if selected_index < 0 or selected_index >= revealed_count or selected_index >= items.size():
		return {}
	return items[selected_index].duplicate(true)

func get_grid_rect() -> Rect2:
	return Rect2(Vector2(maxf(0.0, (size.x - GRID_SIZE.x) * 0.5), 0), Vector2(GRID_SIZE.x, _grid_rows * CELL_SIZE))

func get_item_rect(index: int) -> Rect2:
	if index < 0 or index >= layout.size():
		return Rect2()
	return Rect2(get_grid_rect().position + Vector2(layout[index].position) * CELL_SIZE, Vector2(layout[index].size) * CELL_SIZE)

func _draw() -> void:
	var grid: Rect2 = get_grid_rect()
	var cell: float = grid.size.x / GRID_COLUMNS
	if cell <= 0.0:
		return
	# One translucent inventory surface, shared single-pixel grid lines.
	# Sealed geometry is constant and never depends on a hidden lot.
	draw_rect(grid, Color(0.012,0.02,0.025,0.56))
	for column: int in range(GRID_COLUMNS + 1):
		var x: float = grid.position.x + column * cell
		draw_line(Vector2(x, grid.position.y), Vector2(x, grid.end.y), Color(0.67,0.72,0.71,0.17), 1.0)
	for row: int in range(_grid_rows + 1):
		var y: float = grid.position.y + row * cell
		draw_line(Vector2(grid.position.x, y), Vector2(grid.end.x, y), Color(0.67,0.72,0.71,0.17), 1.0)
	if not opened and items.is_empty() and not is_assist_searching():
		_draw_sealed(Rect2(grid.position, GRID_SIZE))
		return
	for index: int in range(layout.size()):
		var rect: Rect2 = get_item_rect(index).grow(-1.0)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if index >= revealed_count:
			_draw_unknown(rect, index == revealed_count)
		elif items[index].has("name"):
			_draw_item(rect, index)
		else:
			_draw_discovery(rect, items[index])
	if is_assist_searching():
		var target: Array = _assist_queue[0].rect
		var position: Vector2 = grid.position + Vector2(target[0], target[1]) * CELL_SIZE
		_draw_unknown(Rect2(position, Vector2.ONE * CELL_SIZE).grow(-1.0), true)

func _draw_discovery(rect: Rect2, item: Dictionary) -> void:
	var color: Color = Catalog.QUALITY_COLORS[int(item.quality)] if item.has("quality") else Color("91a0ad")
	draw_rect(rect, Color(color, 0.12))
	draw_rect(rect, color, false, 2.0)
	if item.has("quality") and int(item.quality) == 6:
		_draw_rainbow_frame(rect)
	var label: String = "TAG" if item.has("tags") else "?"
	_draw_text(label, rect.position + Vector2(7, 25), 14, color)

func _draw_sealed(grid: Rect2) -> void:
	# This fixed lock is an overall seal, never an inventory silhouette.
	var center: Vector2 = grid.get_center()
	var lock_center: Vector2 = center-Vector2(0.0,26.0)
	var ink: Color = Color(0.68,0.75,0.70,0.65)
	draw_arc(lock_center-Vector2(0,7),12,PI,TAU,24,ink,1.5,true)
	draw_rect(Rect2(lock_center-Vector2(15,7),Vector2(30,26)),ink,false,1.5)
	draw_circle(lock_center+Vector2(0,3),2,ink)
	draw_line(lock_center+Vector2(0,4),lock_center+Vector2(0,9),ink,1.5)
	var title: String = TEXT.get_message(&"warehouse.sealed")
	var title_width: float = get_theme_default_font().get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
	_draw_text(title,center+Vector2(-title_width*0.5,32),17,Color("aab7ab"))

func _draw_unknown(rect: Rect2, scanning: bool) -> void:
	draw_rect(rect,Color(0.10,0.14,0.145,0.72))
	draw_rect(rect,Color("74817d") if scanning else Color("414e50"),false,1.0)
	if scanning:
		# Sweep at a fixed speed: neither the bar nor a fill discloses completion time.
		var scan_y: float = rect.position.y + rect.size.y * fposmod(_animation_time * 1.4, 1.0)
		draw_line(Vector2(rect.position.x,scan_y),Vector2(rect.end.x,scan_y),Color("b8c996"),1.0)
		_draw_selection_corners(rect.grow(-3.0), Color("a4c9dd"))
		var center: Vector2 = rect.get_center()
		var radius: float = minf(14.0, rect.size.x * 0.18)
		draw_arc(center, radius, _animation_time * 4.0, _animation_time * 4.0 + 4.5, 24, Color("a4c9dd"), 2.0, true)
	var question_size: Vector2 = get_theme_default_font().get_string_size("?",HORIZONTAL_ALIGNMENT_LEFT,-1,24)
	_draw_text("?",rect.get_center()+Vector2(-question_size.x*0.5,8),24,Color("82918c"))

func _draw_item(rect: Rect2, index: int) -> void:
	var item: Dictionary = items[index]
	var rarity: Color = Catalog.QUALITY_COLORS[clampi(int(item.get("quality", 0)), 0, Catalog.QUALITY_COLORS.size() - 1)]
	var selected: bool = selected_index==index
	var hovered: bool = _hovered_index==index
	var tint: Color = Color("182323").lerp(rarity,0.14 if selected else 0.055)
	tint.a=0.86
	draw_rect(rect,tint)
	draw_rect(rect,Color(rarity,0.65),false,1)
	if int(item.quality) == 6:
		_draw_rainbow_frame(rect)
	var kind: String = str(item.get("kind",""))
	# Narrow slots devote their area to the item; tooltip and selection show full text.
	var compact: bool = rect.size.x < 80.0
	var icon_area: Rect2 = rect.grow(-4.0) if compact else Rect2(rect.position+Vector2(5,21),rect.size-Vector2(10,27))
	if _textures.has(kind) and icon_area.size.x>0 and icon_area.size.y>0:
		var texture: Texture2D = _textures[kind]
		var texture_size: Vector2 = texture.get_size()
		var scale_factor: float = minf(icon_area.size.x/texture_size.x,icon_area.size.y/texture_size.y)
		var art_size: Vector2 = texture_size*scale_factor
		draw_texture_rect(texture,Rect2(icon_area.get_center()-art_size*0.5,art_size),false,Color.WHITE)
	else:
		var center: Vector2 = icon_area.get_center()
		var half: Vector2 = Vector2(minf(icon_area.size.x,40),minf(icon_area.size.y,40))*0.5
		draw_rect(Rect2(center-half,half*2),rarity.darkened(0.45),false,2)
	var name_text: String = item.name
	if not compact:
		_draw_text(_fit_text(name_text,rect.size.x-12,11),rect.position+Vector2(6,16),11,Color("d9dfd4"))
	var flash: float = 1.0 - clampf((_animation_time - _revealed_at[index]) / (0.24 + int(item.quality) * 0.09), 0.0, 1.0)
	if flash > 0.0:
		draw_rect(rect, Color(rarity, flash * 0.32))
		draw_rect(rect.grow(3.0 * (1.0 - flash)), Color(rarity, flash), false, 2.0)
		_draw_selection_corners(rect, Color(rarity, flash))
	if selected or hovered:
		var border: Color = Color("e3ecce") if selected else Color("a2b6aa")
		draw_rect(rect,border,false,1)
		if selected: _draw_selection_corners(rect,border)

func _draw_selection_corners(rect: Rect2, color: Color) -> void:
	var length: float = 9.0
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
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
	for index: int in range(text.length()):
		if index > 0 and (text.length() - index) % 3 == 0:
			result += ","
		result += text[index]
	return result

func _index_at(point: Vector2) -> int:
	for index: int in range(revealed_count):
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

func _draw_rainbow_frame(rect: Rect2) -> void:
	var colors: Array[Color] = Catalog.RAINBOW_COLORS
	for index: int in colors.size():
		var left: float = rect.position.x + rect.size.x * index / colors.size()
		var right: float = rect.position.x + rect.size.x * (index + 1) / colors.size()
		draw_line(Vector2(left, rect.position.y), Vector2(right, rect.position.y), colors[index], 3.0)
		draw_line(Vector2(left, rect.end.y), Vector2(right, rect.end.y), colors[colors.size() - 1 - index], 3.0)
	draw_line(rect.position, Vector2(rect.position.x, rect.end.y), colors[0], 2.0)
	draw_line(Vector2(rect.end.x, rect.position.y), rect.end, colors[-1], 2.0)


func _get_tooltip(at_position: Vector2) -> String:
	var index: int = _index_at(at_position)
	if index < 0:
		return ""
	return describe_item(items[index])

func describe_item(item: Dictionary) -> String:
	if item.has("name"):
		return TEXT.get_message(&"warehouse.tooltip").format({"name": item.name, "quality": Catalog.QUALITY_NAMES[int(item.quality)], "color": Catalog.QUALITY_COLOR_NAMES[int(item.quality)], "width": item.size[0], "height": item.size[1], "value": _format_value(int(item.value)), "tags": " / ".join(item.tags)})
	var lines: PackedStringArray = [TEXT.get_message(&"intel.partial")]
	if item.has("value"):
		lines.append("调整后基础价格：" + _format_value(int(item.value)))
	if item.has("outline"):
		lines.append(TEXT.get_message(&"intel.outline").format({"width": item.rect[2], "height": item.rect[3]}))
	if item.has("quality"):
		lines.append(TEXT.get_message(&"intel.quality").format({"quality": Catalog.QUALITY_NAMES[int(item.quality)]}))
	if item.has("tags"):
		lines.append(TEXT.get_message(&"intel.tags").format({"tags": " / ".join(item.tags)}))
	return "\n".join(lines)
