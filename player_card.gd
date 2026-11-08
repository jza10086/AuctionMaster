extends PanelContainer
## Reusable public player summary; all values are supplied by the auction entry.
@onready var player_label: Label = %PlayerName
@onready var amount_label: Label = %Amount
@onready var operations: HBoxContainer = %Operations

func set_view(player_name: String, amount: String, colors: Array[Color], withdrawn: bool) -> void:
	player_label.text = player_name
	player_label.tooltip_text = player_name
	amount_label.text = amount
	self_modulate.a = 0.45 if withdrawn else 1.0
	for index: int in operations.get_child_count():
		var slot: PanelContainer = operations.get_child(index)
		slot.visible = index < colors.size()
		if slot.visible:
			var swatch: Panel = slot.get_node("Swatch")
			swatch.self_modulate = colors[index]
