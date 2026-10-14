extends RefCounted
## Authoritative hot-seat-free model. Only snapshot() may cross the AI boundary.
const Rules = preload("res://scripts/rules.gd")
const BidAI = preload("res://scripts/bid_ai.gd")
var rules = Rules.new()
var phase: String = "finished"
var warehouse: int = 0
var round: int = 1
var balances: Array = []
var names: Array = ["你", "算盘陈", "眼力林", "胆大周"]
var time: float = 0.0
var _lots: Array = []
var _bids: Array = [0, 0, 0, 0]
var _locked: Array = [false, false, false, false]
var _history: Array = []
var _bounds: Array = [2000, 12000]
var _clues: Array = []
var _skill_used: Array = [false, false, false, false]
var _skill_bounds: Array = [[], [], [], []]
var _skill_text: Array = ["", "", "", ""]
var _winner: int = -1
var _price: int = 0
var _settled: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _ai_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _clue_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _skill_seed: int = 0

func start(seed_value: int = -1) -> void:
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	_ai_rng.seed = _rng.seed ^ 0x4A1C7
	_clue_rng.seed = _rng.seed ^ 0x631B2
	_skill_seed = _rng.seed ^ 0x947F3
	balances = [rules.initialcoins, rules.initialcoins, rules.initialcoins, rules.initialcoins]
	_lots.clear()
	for _index in range(rules.warehouses):
		_lots.append(_generate_lot())
	warehouse = 0
	_begin_warehouse()

func _generate_lot() -> Array:
	var kinds: Array = ["vase", "clock", "gold", "radio", "gem"]
	var labels: Array = ["青玉瓷瓶", "古董座钟", "典藏金条", "老式收音机", "彩色宝石"]
	while true:
		var items: Array = []
		var value: int = 0
		for index in range(_rng.randi_range(3, 5)):
			var kind: int = _rng.randi_range(0, 4)
			var item_value: int = _rng.randi_range(10, 60) * 50
			items.append({"name": labels[kind], "kind": kinds[kind], "value": item_value})
			value += item_value
		if value >= 2000 and value <= 12000:
			return items
	return []

func _hidden_total() -> int:
	var value: int = 0
	for item in _lots[warehouse]:
		value += int(item.value)
	return value

func _begin_warehouse() -> void:
	round = 1
	_history = []
	_bounds = [2000, 12000]
	_clues = ["仓库封存完整，估值范围为 2,000—12,000 金币。"]
	_skill_used = [false, false, false, false]
	_skill_bounds = [[], [], [], []]
	_skill_text = ["", "", "", ""]
	_winner = -1
	_price = 0
	_settled = false
	_begin_round()

func _begin_round() -> void:
	phase = "bidding"
	time = rules.round_seconds
	_bids = [0, 0, 0, 0]
	_locked = [false, false, false, false]
	if round > 1:
		var actual: int = _hidden_total()
		var widths: Array = [7000, 4800, 3200, 2100]
		var width: int = int(widths[mini(round - 2, widths.size() - 1)])
		_bounds = _uncertain_interval(actual, _bounds, width, _clue_rng)
		_clues.append("第 %d 轮公开鉴定：总值在 %s—%s 金币之间。" % [round, _bounds[0], _bounds[1]])
	# Commit every AI bid before the human gets control. Observation is a copy.
	for player_id in range(1, 4):
		_bids[player_id] = BidAI.choose_bid(_ai_observation(player_id), player_id, _ai_rng)
		_locked[player_id] = true

func _ai_observation(player_id: int) -> Dictionary:
	var observation: Dictionary = snapshot(player_id)
	# Do not provide even the AI's own current sealed bid to the decision function.
	observation.erase("ownbid")
	observation.erase("bidlocked")
	observation.erase("round_bids")
	return observation

func submit_bid(player_id: int, amount: int, expected_warehouse: int, expected_round: int) -> bool:
	if phase != "bidding" or expected_warehouse != warehouse or expected_round != round:
		return false
	if player_id < 0 or player_id >= 4 or _locked[player_id]:
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
	if phase == "bidding" and not _locked[0]:
		submit_bid(0, 0, warehouse, round)

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
	for offset in range(4):
		order.append((warehouse + offset) % 4)
	return order

func _settle() -> void:
	if _settled:
		return
	_settled = true
	_winner = -1
	_price = 0
	for player_id in priority_order():
		if int(_bids[player_id]) > _price:
			_price = int(_bids[player_id])
			_winner = player_id
	if _winner >= 0:
		balances[_winner] = int(balances[_winner]) - _price + _hidden_total()

func use_skill(player_id: int) -> String:
	if player_id < 0 or player_id >= 4:
		return ""
	if phase != "bidding" or _skill_used[player_id]:
		return _skill_text[player_id]
	_skill_used[player_id] = true
	var actual: int = _hidden_total()
	# A player/warehouse-specific stream: using the skill cannot alter public
	# evidence, opponents' decisions, or another player's private appraisal.
	var private_rng := RandomNumberGenerator.new()
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
	var valid: bool = player_id >= 0 and player_id < 4
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
	return result

func reveal_items() -> Array:
	if (phase != "reveal" and phase != "finished") or _lots.is_empty():
		return []
	return _lots[warehouse].duplicate(true)

func total_value() -> int:
	if (phase != "reveal" and phase != "finished") or _lots.is_empty():
		return 0
	return _hidden_total()

func rankings() -> Array:
	var result: Array = []
	for player_id in range(balances.size()):
		var rank: int = 1
		for other in balances:
			if int(other) > int(balances[player_id]):
				rank += 1
		result.append({"player_id": player_id, "name": names[player_id], "balance": balances[player_id], "rank": rank})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.balance == b.balance:
			return a.player_id < b.player_id
		return a.balance > b.balance)
	return result
