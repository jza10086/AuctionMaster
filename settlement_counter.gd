extends Control
## Presentation-only vertical settlement: item values accumulate, then three static amounts appear.
signal completed(balance: int)

const ImpactNumber = preload("res://core/ui/components/impact_number.gd")
@export_range(0.1, 2.0) var item_interval_seconds: float = 0.65
@export_range(0.1, 5.0) var reveal_interval_seconds: float = 1.0
@onready var digits: ImpactNumber = %Digits
@onready var bonus: ImpactNumber = %Bonus
@onready var price: ImpactNumber = %Price
@onready var balance: ImpactNumber = %Balance
@onready var base_sign: Label = %BaseSign
@onready var bonus_sign: Label = %BonusSign
@onready var price_sign: Label = %PriceSign
@onready var balance_sign: Label = %BalanceSign
@onready var bonus_row: HBoxContainer = %BonusRow
@onready var price_row: HBoxContainer = %PriceRow
@onready var balance_row: HBoxContainer = %BalanceRow

var total: int = 0
var _values: Array[int] = []
var _bonus: int = 0
var _price: int = 0
var _index: int = 0
var _stage: int = 0
var _elapsed: float = 0.0
var _next_at: float = 0.0
var _active: bool = false

func _ready() -> void:
	set_process(false)

## item_values are base values, excluding bonus; bonus_value may be signed.
## No item metadata or textures are required. Restarts clear all later rows.
func start(item_values: Array[int], bonus_value: int = 0, sale_price: int = 0) -> void:
	_values = item_values.duplicate()
	_bonus = bonus_value
	_price = sale_price
	total = 0
	_index = 0
	_stage = 0 if not _values.is_empty() else 1
	_elapsed = 0.0
	_next_at = item_interval_seconds if _stage == 0 else reveal_interval_seconds
	_active = true
	_set_amount(digits, base_sign, 0)
	_set_amount(bonus, bonus_sign, bonus_value)
	_set_amount(price, price_sign, -sale_price)
	_set_amount(balance, balance_sign, 0)
	bonus_row.modulate.a = 0.0
	price_row.modulate.a = 0.0
	balance_row.modulate.a = 0.0
	set_process(true)

func _process(delta: float) -> void:
	advance(delta)

## A shared clock keeps the base-number impact and the one-second reveals deterministic.
func advance(delta: float) -> void:
	digits.advance(delta)
	if not _active:
		return
	_elapsed += delta
	while _active and _elapsed >= _next_at:
		if _stage == 0:
			total += _values[_index]
			digits.set_value(total)
			_index += 1
			if _index < _values.size():
				_next_at += item_interval_seconds
				continue
			_stage = 1
		elif _stage == 1:
			bonus_row.modulate.a = 1.0
			_stage = 2
		elif _stage == 2:
			price_row.modulate.a = 1.0
			_stage = 3
		else:
			var final_balance: int = total + _bonus - _price
			_set_amount(balance, balance_sign, final_balance)
			balance_row.modulate.a = 1.0
			_active = false
			set_process(false)
			completed.emit(final_balance)
		_next_at += reveal_interval_seconds

func _set_amount(number: ImpactNumber, sign_label: Label, amount: int) -> void:
	var tint: Color = digits.increase_color if amount > 0 else (digits.decrease_color if amount < 0 else digits.number_color)
	sign_label.text = "−" if amount < 0 else "+"
	sign_label.add_theme_color_override("font_color", tint)
	number.number_color = tint
	number.reset(absi(amount))
