extends PanelContainer
## Presentation only: interpolate the host clock; all prices and payouts come from its snapshot.
const Rules: Script = preload("res://games/minigame/godot_party_default_auction_master/rules.gd")
const Catalog: Script = preload("res://games/minigame/godot_party_default_auction_master/item_catalog.gd")
const Scanner: Script = preload("res://games/minigame/godot_party_default_auction_master/search_effect.gd")
const Roller: Script = preload("res://games/minigame/godot_party_default_auction_master/rolling_number.gd")
@onready var winner_label: Label = %Winner
@onready var stage_label: Label = %Stage
@onready var item_box: VBoxContainer = %ItemBox
@onready var item_icon: TextureRect = %ItemIcon
@onready var search_effect: Scanner = %SearchEffect
@onready var search_profit: Roller = %SearchProfit
@onready var search_profit_box: VBoxContainer = %SearchProfitBox
@onready var item_name: Label = %ItemName
@onready var item_value: Roller = %ItemValue
@onready var total_value: Roller = %TotalValue
@onready var total_title: Label = %TotalTitle
@onready var formula: VBoxContainer = %Formula
@onready var formula_caption: Label = %FormulaCaption
@onready var formula_operator: Label = %FormulaOperator
@onready var warehouse_price: Roller = %WarehousePrice
@onready var sale_price: Roller = %SalePrice
@onready var profit_value: Roller = %ProfitValue
@onready var profit_caption: Label = %ProfitCaption
@onready var payouts_box: VBoxContainer = %PayoutsBox
@onready var payout_note: Label = %PayoutNote
@onready var payout_rows: VBoxContainer = %PayoutRows
var snapshot: Dictionary = {}
var _since_snapshot: float = 0.0
var _display_elapsed: float = 0.0
var _item_index: int = -1
var _warehouse: int = -1
var _prefix_totals: Array[int] = []

func _ready() -> void:
	set_process(false)

func set_snapshot(data: Dictionary) -> void:
	snapshot = data
	_since_snapshot = 0.0
	if _warehouse != int(data.warehouse):
		_warehouse = data.warehouse
		_display_elapsed = 0.0
		_item_index = -1
		_prefix_totals.assign([0])
		total_value.reset_value()
		item_value.reset_value()
		search_profit.reset_value(-int(data.price))
		for item: Dictionary in data.items:
			_prefix_totals.append(_prefix_totals.back() + int(item.effective_value))
	winner_label.text = "%s 成交" % data.names[int(data.winner)]
	set_process(true)
	_render(float(data.settlement_elapsed))

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_since_snapshot += delta
	# Extrapolate only one publication interval, then hold if the host stops publishing.
	_render(minf(float(snapshot.settlement_seconds), float(snapshot.settlement_elapsed) + minf(_since_snapshot, 0.1)))

func _render(elapsed: float) -> void:
	elapsed = maxf(_display_elapsed, elapsed)
	_display_elapsed = elapsed
	var duration: float = snapshot.settlement_seconds
	var progress: float = elapsed / duration
	var counting: bool = progress < Rules.ITEMS_END
	var totaling: bool = progress >= Rules.ITEMS_END and progress < Rules.TOTAL_END
	var profiting: bool = progress >= Rules.TOTAL_END and progress < Rules.PROFIT_END
	var distributing: bool = progress >= Rules.PROFIT_END
	item_box.visible = counting
	search_profit_box.visible = counting
	formula.visible = progress >= Rules.ITEMS_END
	payouts_box.visible = distributing
	total_title.text = "累计仓库价格" if counting else "仓库价格（含羁绊）"
	var total: int = snapshot.total_value
	var price: int = snapshot.price
	var profit: int = total - price
	# The running total never restarts for each item or when the formula phase begins.
	var count: int = Rules.revealed_items(snapshot.search_ends, elapsed)
	var known_total: int = _prefix_totals[count]
	total_value.follow_value(known_total, elapsed)
	if counting:
		var searching: bool = count < snapshot.items.size()
		var since_reveal: float = elapsed - float(snapshot.search_ends[count - 1]) if count > 0 else 100.0
		var show_found: bool = count > 0 and (not searching or since_reveal < 0.22)
		search_effect.visible = not show_found
		item_icon.visible = show_found
		search_effect.show_search(elapsed, Rules.search_fraction(snapshot.search_ends, count, elapsed))
		if count > 0:
			var index: int = count - 1
			var item: Dictionary = snapshot.items[index]
			if index != _item_index:
				_item_index = index
				item_icon.texture = load("res://games/minigame/godot_party_default_auction_master/assets/items/realistic/%s.png" % item.kind)
			item_value.follow_value(int(item.effective_value), elapsed)
			item_name.text = item.name if show_found else "正在搜索…"
			item_name.add_theme_color_override("font_color", Catalog.QUALITY_COLORS[int(item.quality)] if show_found else Color("99b5c4"))
		else:
			item_value.follow_value(0, elapsed)
			item_name.text = "正在搜索…"
			item_name.add_theme_color_override("font_color", Color("99b5c4"))
		stage_label.text = "搜索物资  %d / %d" % [mini(count + 1, snapshot.items.size()), snapshot.items.size()] if searching else "搜索完成"
		# This is a provisional appraisal, not a balance mutation.
		var current_profit: int = known_total - price
		search_profit.number_color = Color("#ef7277") if current_profit < 0 else Color("#5fd6a5")
		search_profit.follow_value(current_profit, elapsed)
	elif totaling:
		stage_label.text = "核算仓库总价"
	if progress >= Rules.TOTAL_END:
		formula_caption.text = "仓库价格 − 成交价 = 盈亏"
		formula_operator.text = "−"
		stage_label.text = "计算盈亏" if profiting else "分配亏损价值"
		var fraction: float = _fraction(progress, Rules.TOTAL_END, Rules.PROFIT_END)
		warehouse_price.set_roll(0, total, clampf(fraction * 3.0, 0.0, 1.0))
		sale_price.set_roll(0, price, clampf(fraction * 3.0 - 0.7, 0.0, 1.0))
		profit_value.number_color = Color("#ef7277") if profit < 0 else Color("#5fd6a5")
		profit_value.set_roll(0, profit, clampf(fraction * 2.0 - 0.8, 0.0, 1.0))
		profit_caption.text = "亏损" if profit < 0 else ("盈利" if profit > 0 else "持平")
	elif totaling:
		formula_caption.text = "基础总价 + 羁绊增值 = 仓库价格"
		formula_operator.text = "+"
		var fraction: float = _fraction(progress, Rules.ITEMS_END, Rules.TOTAL_END)
		warehouse_price.set_roll(0, int(snapshot.base_value), fraction)
		sale_price.set_roll(0, int(snapshot.bonus_value), fraction)
		profit_value.number_color = Color("#f0b047")
		profit_value.set_roll(0, total, fraction)
		profit_caption.text = ""
	if distributing:
		var seats: Array = snapshot.payout_seats
		payout_note.text = "按成交轮报价权重分配" if not seats.is_empty() else ("本仓未亏损，无需分配" if profit >= 0 else "其他玩家有效报价为 0，无需分配")
		var fraction: float = _fraction(progress, Rules.PROFIT_END, Rules.PAYOUT_END)
		var weight_total: int = 0
		for seat: int in seats:
			weight_total += int(snapshot.round_bids[seat])
		for index: int in payout_rows.get_child_count():
			var row: HBoxContainer = payout_rows.get_child(index)
			row.visible = index < seats.size()
			if row.visible:
				var seat: int = seats[index]
				row.get_node("Name").text = "%s  %.1f%%" % [snapshot.names[seat], float(snapshot.round_bids[seat]) / weight_total * 100.0]
				row.get_node("Amount").set_roll(0, int(snapshot.payouts[seat]), clampf(fraction * 1.3 - index * 0.04, 0.0, 1.0))
		if progress >= Rules.PAYOUT_END:
			stage_label.text = "结算完成"

func _fraction(progress: float, start: float, end: float) -> float:
	return clampf((progress - start) / (end - start) / 0.85, 0.0, 1.0)
