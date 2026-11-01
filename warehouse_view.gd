extends Control
## Public-snapshot-only presentation. The host owns the reveal clock and pause.
## Nothing is packed, rendered, selectable, or retained before the warehouse opens.
signal selection_changed(item: Dictionary)
signal reveal_progress(revealed: int, total: int)

const GRID_COLUMNS: int = 12
const GRID_ROWS: int = 14
const GRID_SIZE: Vector2 = Vector2(576.0, 672.0)
const REVEAL_SECONDS: float = 0.68
const Catalog: Script = preload("res://games/minigame/godot_party_default_auction_master/item_catalog.gd")
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
	for item: Dictionary in Catalog.new().items:
		var kind: String = item.kind
		var path: String = "res://games/minigame/godot_party_default_auction_master/assets/items/realistic/%s.png" % kind
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
		for entry: Variant in snap.get("items", []):
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
	layout = Catalog.pack(items)
	_revealed_at.resize(items.size())
	_revealed_at.fill(-100.0)

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
	for index: Variant in range(revealed_count, items.size()):
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

func _draw() -> void:
	var grid: Rect2 = get_grid_rect()
	var cell: float = grid.size.x / GRID_COLUMNS
	if cell <= 0.0:
		return
	# One translucent inventory surface, shared single-pixel grid lines.
	# Sealed geometry is constant and never depends on a hidden lot.
	draw_rect(grid, Color(0.012,0.02,0.025,0.56))
	for column: Variant in range(GRID_COLUMNS + 1):
		var x: float = grid.position.x + column * cell
		draw_line(Vector2(x, grid.position.y), Vector2(x, grid.end.y), Color(0.67,0.72,0.71,0.17), 1.0)
	for row: Variant in range(GRID_ROWS + 1):
		var y: float = grid.position.y + row * cell
		draw_line(Vector2(grid.position.x, y), Vector2(grid.end.x, y), Color(0.67,0.72,0.71,0.17), 1.0)
	if not opened:
		_draw_sealed(grid)
		return
	for index: Variant in range(layout.size()):
		var rect: Rect2 = get_item_rect(index).grow(-1.0)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if index >= revealed_count:
			_draw_unknown(rect, index == revealed_count)
		else:
			_draw_item(rect, index)

func _draw_sealed(grid: Rect2) -> void:
	# This fixed lock is an overall seal, never an inventory silhouette.
	var center: Vector2 = grid.get_center()
	var lock_center: Vector2 = center-Vector2(0.0,26.0)
	var ink: Variant = Color(0.68,0.75,0.70,0.65)
	draw_arc(lock_center-Vector2(0,7),12,PI,TAU,24,ink,1.5,true)
	draw_rect(Rect2(lock_center-Vector2(15,7),Vector2(30,26)),ink,false,1.5)
	draw_circle(lock_center+Vector2(0,3),2,ink)
	draw_line(lock_center+Vector2(0,4),lock_center+Vector2(0,9),ink,1.5)
	var title: Variant = "仓库已封存"
	var title_width: float = get_theme_default_font().get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
	_draw_text(title,center+Vector2(-title_width*0.5,32),17,Color("aab7ab"))

func _draw_unknown(rect: Rect2, scanning: bool) -> void:
	draw_rect(rect,Color(0.10,0.14,0.145,0.72))
	draw_rect(rect,Color("74817d") if scanning else Color("414e50"),false,1.0)
	if scanning:
		var progress: float = clampf(_reveal_elapsed / REVEAL_SECONDS,0.0,1.0)
		var scan_y: float = rect.position.y+rect.size.y*progress
		draw_rect(Rect2(rect.position,Vector2(rect.size.x,rect.size.y*progress)),Color(0.65,0.76,0.54,0.08))
		draw_line(Vector2(rect.position.x,scan_y),Vector2(rect.end.x,scan_y),Color("b8c996"),1.0)
		_draw_text("搜索中",rect.position+Vector2(7,17),11,Color("d8dfcd"))
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
	var name_text: String = str(item.get("name","未知藏品"))
	if not compact:
		_draw_text(_fit_text(name_text,rect.size.x-12,11),rect.position+Vector2(6,16),11,Color("d9dfd4"))
	var flash: float = 1-clampf((_animation_time-_revealed_at[index])/0.32,0,1)
	if flash>0: draw_rect(rect,Color(rarity,flash*0.14))
	if selected or hovered:
		var border: Color = Color("e3ecce") if selected else Color("a2b6aa")
		draw_rect(rect,border,false,1)
		if selected: _draw_selection_corners(rect,border)

func _draw_selection_corners(rect: Rect2, color: Color) -> void:
	var length: float = 9.0
	for corner: Variant in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
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
	for index: Variant in range(text.length()):
		if index > 0 and (text.length() - index) % 3 == 0:
			result += ","
		result += text[index]
	return result

func _index_at(point: Vector2) -> int:
	if not opened:
		return -1
	for index: Variant in range(revealed_count):
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
	var item: Dictionary = items[index]
	return "%s · %s（%s）\n%d × %d 格 · 基础 %d 金币\n%s" % [item.name, Catalog.QUALITY_NAMES[int(item.quality)], Catalog.QUALITY_COLOR_NAMES[int(item.quality)], item.size[0], item.size[1], item.value, " / ".join(item.tags)]
