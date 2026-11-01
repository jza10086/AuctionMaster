extends RefCounted
## Host-owned sealed auction. Only recipient-filtered snapshot() may cross the network boundary.
const Rules: Variant = preload("res://games/minigame/godot_party_default_auction_master/rules.gd")
const Catalog: Script = preload("res://games/minigame/godot_party_default_auction_master/item_catalog.gd")
var catalog: Resource = Catalog.new()
var _appraisals: Array[Dictionary] = []
var rules: Variant = Rules.new()
var phase: String = "finished"
var warehouse: int = 0
var round: int = 1
var balances: Array = []
var names: Array = []
var time: float = 0.0
var _lots: Array = []
var _bids: Array = [0, 0, 0, 0]
var _locked: Array = [false, false, false, false]
var _history: Array = []
var _bounds: Array = [Catalog.MIN_LOT_VALUE, Catalog.MAX_LOT_VALUE]
var _clues: Array = []
var _skill_used: Array = [false, false, false, false]
var _skill_bounds: Array = [[], [], [], []]
var _skill_text: Array = ["", "", "", ""]
var _winner: int = -1
var _price: int = 0
var _settled: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _clue_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _skill_seed: int = 0

func start(seed_value: int = -1) -> void:
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	_clue_rng.seed = _rng.seed ^ 0x631B2
	_skill_seed = _rng.seed ^ 0x947F3
	balances = []
	balances.resize(names.size())
	balances.fill(rules.initialcoins)
	_lots.clear()
	_appraisals.clear()
	for _index: Variant in range(rules.warehouses):
		var lot: Array = _generate_lot()
		_lots.append(lot)
		_appraisals.append(Catalog.evaluate(lot))
	warehouse = 0
	_begin_warehouse()

## Theme-biased lots create set decisions, while bounded rejection keeps appraisal ranges truthful.
func _generate_lot() -> Array:
	for attempt: int in 128:
		var theme_tag: String = Catalog.TAGS[_rng.randi_range(0, Catalog.TAGS.size() - 1)]
		var themed: Array[Dictionary] = []
		for item: Dictionary in catalog.items:
			if theme_tag in item.tags:
				themed.append(item)
		var lot: Array = []
		for index: int in _rng.randi_range(6, 9):
			var candidates: Array[Dictionary] = themed if index < 3 or _rng.randf() < 0.35 else catalog.items
			lot.append(_draw_item(candidates))
		var total: int = int(Catalog.evaluate(lot).total_value)
		if total >= Catalog.MIN_LOT_VALUE and total <= Catalog.MAX_LOT_VALUE and not Catalog.pack(lot).is_empty():
			return lot
	# Deterministic, valid six-piece fallback; no unbounded generation loop.
	var fallback: Array = []
	for index: int in 6:
		fallback.append(catalog.items[5 if index < 3 else 17].duplicate(true))
	return fallback

func _draw_item(candidates: Array[Dictionary]) -> Dictionary:
	var weights: Array[int] = Catalog.QUALITY_WEIGHTS
	var total: int = 0
	for item: Dictionary in candidates:
		total += weights[int(item.quality)]
	var ticket: int = _rng.randi_range(0, total - 1)
	for item: Dictionary in candidates:
		ticket -= weights[int(item.quality)]
		if ticket < 0:
			return item.duplicate(true)
	return candidates.back().duplicate(true)

func _hidden_total() -> int:
	return int(_appraisals[warehouse].total_value)

func _begin_warehouse() -> void:
	round = 1
	_history = []
	_bounds = [Catalog.MIN_LOT_VALUE, Catalog.MAX_LOT_VALUE]
	_clues = ["仓库封存完整，含同仓羁绊的估值范围为 2,000—120,000 金币。"]
	_skill_used = []
	for seat: int in names.size():
		_skill_used.append(false)
	_skill_bounds = []
	for seat: int in names.size():
		_skill_bounds.append([])
	_skill_text = []
	for seat: int in names.size():
		_skill_text.append("")
	_winner = -1
	_price = 0
	_settled = false
	_begin_round()

func _begin_round() -> void:
	phase = "bidding"
	time = rules.round_seconds
	_bids = []
	for seat: int in names.size():
		_bids.append(0)
	_locked = []
	for seat: int in names.size():
		_locked.append(false)
	if round > 1:
		var actual: int = _hidden_total()
		var widths: Array = [70000, 32000, 12000, 5000]
		var width: int = int(widths[mini(round - 2, widths.size() - 1)])
		_bounds = _uncertain_interval(actual, _bounds, width, _clue_rng)
		_clues.append("第 %d 轮公开鉴定：总值在 %s—%s 金币之间。" % [round, _bounds[0], _bounds[1]])
func submit_bid(player_id: int, amount: int, expected_warehouse: int, expected_round: int) -> bool:
	if phase != "bidding" or expected_warehouse != warehouse or expected_round != round:
		return false
	if player_id < 0 or player_id >= names.size() or _locked[player_id]:
		return false
	if amount < 0 or amount > int(balances[player_id]):
		return false
	_bids[player_id] = amount
	_locked[player_id] = true
	if not _locked.has(false):
		_history.append({"round": round, "bids": _bids.duplicate()})
		phase = "round_result"
		time = 0.0
		if round == rules.rounds:
			_settle()
			phase = "reveal"
	return true

func tick(delta: float) -> void:
	if phase != "bidding":
		return
	time = maxf(0.0, time - maxf(delta, 0.0))
	if time <= 0.0:
		expire_round()

func expire_round() -> void:
	for seat: int in names.size():
		if phase == "bidding" and not _locked[seat]:
			submit_bid(seat, 0, warehouse, round)

func advance() -> void:
	if phase == "round_result":
		if round < rules.rounds:
			round += 1
			_begin_round()
		else:
			_settle()
			phase = "reveal"
	elif phase == "reveal":
		if warehouse + 1 < rules.warehouses:
			warehouse += 1
			_begin_warehouse()
		else:
			phase = "finished"

func priority_order() -> Array:
	var order: Array = []
	for offset: Variant in range(names.size()):
		order.append((warehouse + offset) % names.size())
	return order

func _settle() -> void:
	if _settled:
		return
	_settled = true
	_winner = -1
	_price = 0
	for player_id: Variant in priority_order():
		if int(_bids[player_id]) > _price:
			_price = int(_bids[player_id])
			_winner = player_id
	if _winner >= 0:
		balances[_winner] = int(balances[_winner]) - _price + _hidden_total()

func use_skill(player_id: int) -> String:
	if player_id < 0 or player_id >= names.size():
		return ""
	if phase != "bidding" or _skill_used[player_id]:
		return _skill_text[player_id]
	_skill_used[player_id] = true
	var actual: int = _hidden_total()
	# A player/warehouse-specific stream: using the skill cannot alter public
	# evidence, opponents' decisions, or another player's private appraisal.
	var private_rng: Variant = RandomNumberGenerator.new()
	private_rng.seed = _skill_seed ^ ((warehouse + 1) * 73856093) ^ ((player_id + 1) * 19349663)
	_skill_bounds[player_id] = _uncertain_interval(actual, _bounds, 900, private_rng)
	_skill_text[player_id] = "私密鉴定：本仓总值在 %d—%d 金币之间。" % [_skill_bounds[player_id][0], _skill_bounds[player_id][1]]
	return _skill_text[player_id]

## Pick a random truthful window inside the preceding window. Its midpoint
## is deliberately not anchored to actual value, so it is only an estimate.
func _uncertain_interval(actual: int, previous: Array, requested_width: int, rng: RandomNumberGenerator) -> Array:
	var width: int = mini(requested_width, int(previous[1]) - int(previous[0]))
	var lowest: int = maxi(int(previous[0]), actual - width)
	var highest: int = mini(actual, int(previous[1]) - width)
	var lower: int = rng.randi_range(lowest, highest)
	return [lower, lower + width]

func snapshot(player_id: int = 0) -> Dictionary:
	var valid: bool = player_id >= 0 and player_id < names.size()
	var visible_bounds: Array = _bounds.duplicate()
	if valid and not _skill_bounds[player_id].is_empty():
		visible_bounds = [maxi(int(_bounds[0]), int(_skill_bounds[player_id][0])), mini(int(_bounds[1]), int(_skill_bounds[player_id][1]))]
	var result: Dictionary = {
		"phase": phase, "warehouse": warehouse, "round": round,
		"warehouses_total": rules.warehouses, "rounds_total": rules.rounds,
		"balances": balances.duplicate(), "names": names.duplicate(),
		"clues": _clues.duplicate(), "bounds": visible_bounds,
		"public_bounds": _bounds.duplicate(), "history": _history.duplicate(true),
		"time": time, "ownbid": _bids[player_id] if valid else 0,
		"bidlocked": _locked[player_id] if valid else true,
		"skilltext": _skill_text[player_id] if valid else "",
		"skill_available": valid and phase == "bidding" and not _skill_used[player_id],
		"priority": priority_order(), "round_bids": [], "winner": -1,
		"price": 0, "rankings": rankings(),
	}
	if phase == "round_result" or phase == "reveal" or phase == "finished":
		result.round_bids = _bids.duplicate()
	if phase == "reveal" or phase == "finished":
		result.winner = _winner
		result.price = _price
		result.items = reveal_items()
		result.total_value = total_value()
		result.base_value = _appraisals[warehouse].base_value
		result.bonus_value = _appraisals[warehouse].bonus_value
		result.tag_groups = _appraisals[warehouse].tags.duplicate(true)
	return result

func reveal_items() -> Array:
	if (phase != "reveal" and phase != "finished") or _lots.is_empty():
		return []
	return _appraisals[warehouse].items.duplicate(true)

func total_value() -> int:
	if (phase != "reveal" and phase != "finished") or _lots.is_empty():
		return 0
	return _hidden_total()

func rankings() -> Array:
	var result: Array = []
	for player_id: Variant in range(balances.size()):
		var rank: int = 1
		for other: Variant in balances:
			if int(other) > int(balances[player_id]):
				rank += 1
		result.append({"player_id": player_id, "name": names[player_id], "balance": balances[player_id], "rank": rank})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.balance == b.balance:
			return a.player_id < b.player_id
		return a.balance > b.balance)
	return result
