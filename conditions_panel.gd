extends Control
## Public warehouse briefing; the same frozen information can be reviewed while bidding.
signal close_requested
@onready var heading: Label = %Heading
@onready var rules_text: Label = %RulesText
@onready var clues_text: Label = %CluesText
@onready var close_button: Button = %CloseBriefing

func _ready() -> void:
	close_button.pressed.connect(func() -> void: close_requested.emit())

func set_snapshot(snap: Dictionary) -> void:
	heading.text = "仓库 %s / %s" % [str(snap.warehouse + 1), str(snap.warehouses_total)]
	rules_text.text = "无特殊规则" if snap.special_rules.is_empty() else "\n\n".join(snap.special_rules)
	clues_text.text = "无公共情报" if snap.clues.is_empty() else "\n\n".join(snap.clues)
	close_button.text = "×"
