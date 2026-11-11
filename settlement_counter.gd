extends Control
## Presentation-only vertical settlement: item values accumulate, then three static amounts appear.
signal completed(balance: int)

const TweenNumber = preload("res://core/ui/components/tween_number.gd")
const ImpactNumber = preload("res://core/ui/components/impact_number.gd")
@export_range(0.1, 2.0) var item_interval_seconds: float = 0.65
@export_range(0.1, 5.0) var reveal_interval_seconds: float = 1.0
@onready var digits: ImpactNumber = %Digits
@onready var bonus: ImpactNumber = %Bonus
@onready var price: ImpactNumber = %Price
@onready var balance: TweenNumber = %Balance
@onready var base_sign: Label = %BaseSign
@onready var bonus_sign: Label = %BonusSign
@onready var price_sign: Label = %PriceSign
@onready var balance_sign: Label = %BalanceSign
@onready var bonus_row: HBoxContainer = %BonusRow
@onready var price_row: HBoxContainer = %PriceRow
@onready var balance_row: HBoxContainer = %BalanceRow

@export var pitch_reference_value: float = 100000.0
@export var pitch_min: float = 0.85
@export var pitch_max: float = 1.85
@export var tally_interval: float = 0.075
@onready var add_sound: AudioStreamPlayer = %AddSound
@onready var appear_sound: AudioStreamPlayer = %AppearSound
@onready var tally_sound: AudioStreamPlayer = %TallySound
@onready var finish_sound: AudioStreamPlayer = %FinishSound
var _tally_clock: float = 0.0
var _balance_started: bool = false
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
	balance.reset(0)
	_balance_started = false
	_tally_clock = 0.0
	for player: AudioStreamPlayer in [add_sound, appear_sound, tally_sound, finish_sound]:
		player.stop()
	bonus_row.modulate.a = 0.0
	price_row.modulate.a = 0.0
	balance_row.modulate.a = 0.0
	set_process(true)

func _process(delta: float) -> void:
	advance(delta)

## A shared clock keeps the base-number impact and the one-second reveals deterministic.
func advance(delta: float) -> void:
	digits.advance(delta)
	_advance_balance(delta)
	if not _active:
		return
	_elapsed += delta
	while _active and _elapsed >= _next_at:
		if _stage == 0:
			total += _values[_index]
			_update_base(total)
			_index += 1
			if _index < _values.size():
				_next_at += item_interval_seconds
				continue
			_stage = 1
		elif _stage == 1:
			appear_sound.play()
			bonus_row.modulate.a = 1.0
			_stage = 2
		elif _stage == 2:
			appear_sound.play()
			price_row.modulate.a = 1.0
			_stage = 3
		else:
			var final_balance: int = total + _bonus - _price
			_begin_balance(final_balance)
			balance_row.modulate.a = 1.0
			_active = false
			completed.emit(final_balance)
		_next_at += reveal_interval_seconds

func _set_amount(number: ImpactNumber, sign_label: Label, amount: int) -> void:
	var tint: Color = digits.increase_color if amount > 0 else (digits.decrease_color if amount < 0 else digits.number_color)
	sign_label.text = "−" if amount < 0 else "+"
	sign_label.add_theme_color_override("font_color", tint)
	number.number_color = tint
	number.reset(absi(amount))

## Formal game uses the host search timeline, so income changes exactly when items are found.
var _warehouse: int = -1
var _host_elapsed: float = 0.0

func set_snapshot(data: Dictionary) -> void:
	if _warehouse != int(data.warehouse):
		_warehouse = int(data.warehouse)
		_host_elapsed = 0.0
		var values: Array[int] = []
		start(values, int(data.bonus_value), int(data.price))
	set_process(false)
	var delta: float = maxf(0.0, float(data.settlement_elapsed) - _host_elapsed)
	digits.advance(delta)
	_advance_balance(delta)
	_host_elapsed = maxf(_host_elapsed, float(data.settlement_elapsed))
	var revealed: int = 0
	var base: int = 0
	for index: int in data.items.size():
		if float(data.search_ends[index]) > _host_elapsed:
			break
		revealed += 1
		base += int(data.items[index].get("original_value", data.items[index].value))
	total = base
	_update_base(base)
	var finished_at: float = float(data.search_ends.back()) if not data.search_ends.is_empty() else 0.0
	var after_search: float = _host_elapsed - finished_at
	if (bonus_row.modulate.a == 0.0 and after_search >= reveal_interval_seconds) or (price_row.modulate.a == 0.0 and after_search >= reveal_interval_seconds * 2.0):
		appear_sound.play()
	bonus_row.modulate.a = 1.0 if after_search >= reveal_interval_seconds else 0.0
	price_row.modulate.a = 1.0 if after_search >= reveal_interval_seconds * 2.0 else 0.0
	balance_row.modulate.a = 1.0 if after_search >= reveal_interval_seconds * 3.0 else 0.0
	if balance_row.modulate.a > 0.0 and not _balance_started:
		_begin_balance(int(data.total_value) - int(data.price))

func _update_base(amount: int) -> void:
	if amount != digits.value:
		var weight: float = clampf(log(1.0 + absf(amount)) / log(1.0 + pitch_reference_value), 0.0, 1.0)
		add_sound.pitch_scale = lerpf(pitch_min, pitch_max, weight)
		add_sound.play()
		digits.set_value(amount)

func _begin_balance(amount: int) -> void:
	_balance_started = true
	var tint: Color = digits.increase_color if amount >= 0 else digits.decrease_color
	balance_sign.text = "−" if amount < 0 else "+"
	balance_sign.add_theme_color_override("font_color", tint)
	balance.number_color = tint
	balance.set_value(absi(amount))
	appear_sound.play()
	if amount == 0:
		finish_sound.play()

func _advance_balance(delta: float) -> void:
	if not _balance_started or balance.is_settled():
		return
	var previous: int = roundi(balance.display_value)
	balance.advance(delta)
	_tally_clock += delta
	if balance.is_settled():
		tally_sound.stop()
		finish_sound.play()
	elif previous != roundi(balance.display_value) and _tally_clock >= tally_interval:
		_tally_clock = 0.0
		var progress: float = absf(balance.display_value) / maxf(1.0, absf(balance.value))
		tally_sound.pitch_scale = lerpf(0.9, 1.4, progress)
		tally_sound.play()
