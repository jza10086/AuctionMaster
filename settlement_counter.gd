extends PanelContainer
## Standalone presentation prefab. Supplied values are already appraised; no economy or network writes.
signal completed(total: int)
@export_range(0.1, 2.0) var item_hold_seconds: float = 0.7
@export_range(0.1, 1.0) var transfer_seconds: float = 0.24
@export_range(0.1, 2.0) var result_hold_seconds: float = 0.65
@onready var digits: Control = %Digits
@onready var item_card: PanelContainer = %ItemCard
@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name: Label = %ItemName
@onready var item_value: Label = %ItemValue
@onready var operand: Label = %Operand
@onready var equation: Label = %Equation
@onready var step_label: Label = %Step
@onready var counter: Label = %Counter
@onready var ledger: HBoxContainer = %Ledger
@onready var result: Label = %Result
var total: int = 0
var _items: Array[Dictionary] = []
var _index: int = -1
var _elapsed: float = 0.0
var _before: int = 0
var _price: int = 0
var _active: bool = false

var _receipts: Array[Label] = []

func _ready() -> void:
	set_process(false)

## Each entry supplies name, value, icon (Texture2D), and color (Color). Timing is Inspector-editable.
func start(items: Array[Dictionary], initial_total: int = 0, sale_price: int = 0) -> void:
	_items = items
	total = initial_total
	_price = sale_price
	_index = -1
	_receipts.clear()
	for child: Node in ledger.get_children():
		child.queue_free()
	for item: Dictionary in items:
		var label: Label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		label.text = item.name + "\n待计入"
		ledger.add_child(label)
		_receipts.append(label)
	result.text = ""
	_next_item()
	set_process(true)

func _process(delta: float) -> void:
	advance(delta)

## Shared deterministic animation clock for live playback and frame-by-frame capture.
func advance(delta: float) -> void:
	digits.advance(delta)
	if not _active:
		if digits.is_settled():
			set_process(false)
		return
	_elapsed += delta
	var duration: float = item_hold_seconds + transfer_seconds + result_hold_seconds
	_render()
	if _elapsed >= duration:
		total = _before + int(_items[_index].value)
		_receipts[_index].text = _items[_index].name + "\n+" + format_number(int(_items[_index].value))
		_next_item()

func _next_item() -> void:
	_index += 1
	if _index == _items.size():
		_active = false
		counter.text = "全部物品已计入"
		equation.text = "仓库价格  " + format_number(total) + "  −  成交价  " + format_number(_price)
		var profit: int = total - _price
		result.text = ("盈利  +" if profit >= 0 else "亏损  −") + format_number(absi(profit))
		result.add_theme_color_override("font_color", Color("#79e5ad") if profit >= 0 else Color("#ff787c"))
		step_label.text = "结算完成"
		operand.text = "=  " + format_number(total)
		completed.emit(total)
		return
	_active = true
	_elapsed = 0.0
	_before = total
	item_name.text = _items[_index].name
	item_icon.texture = _items[_index].icon
	item_value.text = "+" + format_number(int(_items[_index].value))
	item_value.add_theme_color_override("font_color", _items[_index].color)
	counter.text = "物品  %02d / %02d" % [_index + 1, _items.size()]
	_render()

func _render() -> void:
	var item: Dictionary = _items[_index]
	var hit_time: float = _elapsed - item_hold_seconds
	var applied: bool = hit_time >= transfer_seconds
	var shown: int = _before + (int(item.value) if applied else 0)
	digits.set_value(shown)
	operand.text = "+  " + format_number(int(item.value)) if not applied else "=  " + format_number(shown)
	equation.text = format_number(_before) + "  +  " + format_number(int(item.value)) + ("  =  " + format_number(shown) if applied else "")
	step_label.text = "物品价值" if hit_time < 0.0 else ("计入总价" if not applied else "已计入")
	# Source first, accumulator second: the addition remains legible through the impact.
	item_value.pivot_offset = item_value.size * 0.5
	var source_age: float = maxf(0.0, hit_time)
	var source_hit: float = sin(clampf(source_age / 0.3, 0.0, 1.0) * PI)
	item_value.scale = Vector2.ONE * (1.0 + source_hit * 0.28)
	item_value.rotation = source_hit * -0.045
	item_value.modulate.a = 1.0 - clampf((hit_time - transfer_seconds) / result_hold_seconds, 0.0, 0.5)
	for index: int in _receipts.size():
		_receipts[index].modulate = Color("#f4cf78") if index == _index else (Color("#a5bfc1") if index < _index else Color("#566e78"))
	item_card.pivot_offset = item_card.size * 0.5
	var pop: float = sin(clampf(maxf(0.0, hit_time) / 0.24, 0.0, 1.0) * PI)
	item_card.scale = Vector2.ONE * (1.0 + pop * 0.065)
	item_card.rotation = pop * 0.018
	operand.pivot_offset = Vector2(operand.size.x, operand.size.y * 0.5)
	var impact: float = sin(clampf((hit_time - transfer_seconds) / 0.28, 0.0, 1.0) * PI)
	operand.scale = Vector2.ONE * (1.0 + maxf(0.0, impact) * 0.12)

func format_number(value: int) -> String:
	var raw: String = str(value)
	var formatted: String = ""
	for index: int in raw.length():
		if index > 0 and (raw.length() - index) % 3 == 0:
			formatted += ","
		formatted += raw[index]
	return formatted

