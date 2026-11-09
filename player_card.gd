extends PanelContainer
## Reusable public player summary; all values are supplied by the auction entry.
@onready var player_label: Label = %PlayerName
@onready var amount_label: Label = %Amount
@onready var operations: HBoxContainer = %Operations
@onready var amount_reel: Control = %AmountReel
@export var reveal_seconds: float = 0.85
var _result_key: String = ""
var _amount: int = 0
var _previous: int = 0
var _elapsed: float = 0.0

func _process(delta: float) -> void:
	_elapsed = minf(_elapsed + delta, reveal_seconds)
	amount_reel.set_roll(_previous, _amount, _elapsed / reveal_seconds)
	if _elapsed >= reveal_seconds:
		amount_reel.hide()
		amount_label.show()
		set_process(false)

func set_view(player_name: String, amount: int, colors: Array[Color], withdrawn: bool, result_key: String, animate: bool) -> void:
	player_label.text = player_name
	player_label.tooltip_text = player_name
	amount_label.text = "—"
	if amount >= 0:
		var digits: String = str(amount)
		var formatted: String = ""
		for index: int in digits.length():
			if index > 0 and (digits.length() - index) % 3 == 0:
				formatted += ","
			formatted += digits[index]
		amount_label.text = formatted
	if result_key != _result_key:
		_result_key = result_key
		_previous = _amount
		_amount = maxi(0, amount)
		_elapsed = 0.0
		amount_reel.visible = animate and amount >= 0
		amount_label.visible = not amount_reel.visible
		set_process(amount_reel.visible)
		amount_reel.set_roll(_previous, _amount, 0.0)
	elif not animate:
		amount_reel.hide()
		amount_label.show()
		set_process(false)
	self_modulate.a = 0.45 if withdrawn else 1.0
	for index: int in operations.get_child_count():
		var slot: PanelContainer = operations.get_child(index)
		slot.visible = index < colors.size()
		if slot.visible:
			var swatch: Panel = slot.get_node("Swatch")
			swatch.self_modulate = colors[index]
