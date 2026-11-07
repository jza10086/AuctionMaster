extends RefCounted
## Host-owned sealed auction. Only recipient-filtered snapshot() may cross the network boundary.
const Rules: Script = preload("res://games/minigame/godot_party_default_auction_master/rules.gd")
const Catalog: Script = preload("res://games/minigame/godot_party_default_auction_master/item_catalog.gd")
var catalog: Catalog = Catalog.new()
var _appraisals: Array[Dictionary] = []
var rules: Rules = Rules.new()
## Existing wire fields carry Chinese text; use the package default without changing their format.
const TEXT: Translation = preload("res://games/minigame/godot_party_default_auction_master/i18n/zh_Hans.po")
var phase: String = "finished"
var warehouse: int = 0
var round: int = 1
var balances: Array = []
var names: Array = []
var time: float = 0.0
var _lots: Array = []
var _bids: Array = [0, 0, 0, 0]
var _locked: Array[bool] = [false, false, false, false]
var _history: Array = []
var _eligible: Array[bool] = []
var _withdrawn: Array[bool] = []
var _minimum_bid: int = 1
var _outcome: String = ""
var _clues: Array = []
var _skill_used: Array = [false, false, false, false]
var _skill_bounds: Array = [[], [], [], []]
var _skill_text: Array = ["", "", "", ""]
var _winner: int = -1
var _price: int = 0
var _settled: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _skill_seed: int = 0

func start(seed_value: int = -1) -> void:
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	_skill_seed = _rng.seed ^ 0x947F3
	balances = []
	balances.resize(names.size())
	balances.fill(rules.initialcoins)
	_withdrawn.resize(names.size())
	_withdrawn.fill(false)
	_lots.clear()
	_appraisals.clear()
	for _index: int in range(rules.warehouses):
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
	_eligible.resize(names.size())
	for seat: int in names.size():
		_eligible[seat] = not _withdrawn[seat]
	_minimum_bid = 1
	_outcome = ""
	_clues = []
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
	_locked = []
	for seat: int in names.size():
		_bids.append(0)
		_locked.append(not _eligible[seat] or _withdrawn[seat])
	if round <= Rules.ROUNDS:
		_add_public_clue()

## Public evidence describes the sealed lot without exposing exact prices or inventory.
func _add_public_clue() -> void:
	var lot: Array = _lots[warehouse]
	match round:
		1:
			_clues.append(TEXT.get_message(&"clue.count").format({"count": lot.size()}))
		2:
			var cells: int = 0
			for item: Dictionary in lot:
				cells += int(item.size[0]) * int(item.size[1])
			_clues.append(TEXT.get_message(&"clue.cells").format({"cells": cells}))
		3:
			var rare_count: int = 0
			for item: Dictionary in lot:
				if int(item.quality) >= 4:
					rare_count += 1
			_clues.append(TEXT.get_message(&"clue.rare").format({"count": rare_count}))
		4:
			var strongest: Dictionary = _appraisals[warehouse].tags[0]
			for group: Dictionary in _appraisals[warehouse].tags:
				if int(group.count) > int(strongest.count):
					strongest = group
			_clues.append(TEXT.get_message(&"clue.synergy").format({"tag": strongest.tag, "count": strongest.count, "percent": strongest.percent}))
		5:
			var quality_counts: Array[int] = []
			quality_counts.resize(Catalog.QUALITY_NAMES.size())
			quality_counts.fill(0)
			for item: Dictionary in lot:
				quality_counts[int(item.quality)] += 1
			var parts: PackedStringArray = []
			for quality: int in quality_counts.size():
				if quality_counts[quality] > 0:
					parts.append(TEXT.get_message(&"clue.quality_count").format({"quality": Catalog.QUALITY_NAMES[quality], "count": quality_counts[quality]}))
			_clues.append(TEXT.get_message(&"clue.qualities").format({"qualities": " / ".join(parts)}))

func submit_bid(player_id: int, amount: int, expected_warehouse: int, expected_round: int) -> bool:
	if phase != "bidding" or expected_warehouse != warehouse or expected_round != round:
		return false
	if player_id < 0 or player_id >= names.size() or _locked[player_id]:
		return false
	if not _eligible[player_id] or _withdrawn[player_id]:
		return false
	if amount < 0 or amount > int(balances[player_id]) or (amount > 0 and amount < _minimum_bid):
		return false
	_bids[player_id] = amount
	_locked[player_id] = true
	if not _locked.has(false):
		_resolve_round()
	return true

## Compare sealed bids once everyone is locked. No money moves before a sale.
func _resolve_round() -> void:
	_history.append({"round": round, "bids": _bids.duplicate()})
	phase = "round_result"
	time = 0.0
	var highest: int = 0
	var second: int = 0
	var leaders: Array[int] = []
	for seat: int in names.size():
		if not _eligible[seat] or _withdrawn[seat]:
			continue
		var amount: int = int(_bids[seat])
		if amount > highest:
			second = highest
			highest = amount
			leaders.assign([seat])
		elif amount == highest and amount > 0:
			second = highest
			leaders.append(seat)
		elif amount > second:
			second = amount
	if round < Rules.ROUNDS:
		# A solo practice run has no second bidder and deliberately shows all five clues.
		if names.size() > 1 and leaders.size() == 1 and highest * 100 >= second * Rules.EARLY_WIN_PERCENT[round - 1]:
			_settle(leaders[0], highest, "early")
		return
	if leaders.is_empty():
		_settle(-1, 0, "unsold")
	elif leaders.size() == 1:
		_settle(leaders[0], highest, "overtime" if round > Rules.ROUNDS else "final")
	else:
		_eligible.fill(false)
		for seat: int in leaders:
			_eligible[seat] = true
		_minimum_bid = highest + 1
		_outcome = "tie"

func tick(delta: float) -> void:
	if phase != "bidding":
		return
	if not _locked.has(false):
		_resolve_round()
		return
	time = maxf(0.0, time - maxf(delta, 0.0))
	if time <= 0.0:
		expire_round()

func expire_round() -> void:
	for seat: int in names.size():
		if phase == "bidding" and not _locked[seat]:
			submit_bid(seat, 0, warehouse, round)

## Disconnected seats cannot bid, win or return in later warehouses.
func withdraw_player(seat: int) -> void:
	_withdrawn[seat] = true
	_eligible[seat] = false
	if phase == "bidding":
		_bids[seat] = 0
		_locked[seat] = true

func advance() -> void:
	if phase == "round_result":
		round += 1
		_begin_round()
	elif phase == "reveal":
		if warehouse + 1 < rules.warehouses:
			warehouse += 1
			_begin_warehouse()
		else:
			phase = "finished"

func _settle(winner: int, price: int, outcome: String) -> void:
	if _settled:
		return
	_settled = true
	_winner = winner
	_price = price
	_outcome = outcome
	if _winner >= 0:
		balances[_winner] = int(balances[_winner]) - _price + _hidden_total()
	phase = "reveal"

func use_skill(player_id: int) -> String:
	if player_id < 0 or player_id >= names.size():
		return ""
	if phase != "bidding" or _skill_used[player_id] or not _eligible[player_id] or _withdrawn[player_id]:
		return _skill_text[player_id]
	_skill_used[player_id] = true
	var actual: int = _hidden_total()
	# A player/warehouse-specific stream: using the skill cannot alter public
	# evidence, opponents' decisions, or another player's private appraisal.
	var private_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	private_rng.seed = _skill_seed ^ ((warehouse + 1) * 73856093) ^ ((player_id + 1) * 19349663)
	_skill_bounds[player_id] = _uncertain_interval(actual, [Catalog.MIN_LOT_VALUE, Catalog.MAX_LOT_VALUE], 900, private_rng)
	_skill_text[player_id] = TEXT.get_message(&"skill.appraisal").format({"lower": _skill_bounds[player_id][0], "upper": _skill_bounds[player_id][1]})
	return _skill_text[player_id]

## Pick a random truthful window inside the preceding window. Its midpoint
## is deliberately not anchored to actual value, so it is only an estimate.
func _uncertain_interval(actual: int, previous: Array, requested_width: int, rng: RandomNumberGenerator) -> Array:
	var width: int = mini(requested_width, int(previous[1]) - int(previous[0]))
	var lowest: int = maxi(int(previous[0]), actual - width)
	var highest: int = mini(actual, int(previous[1]) - width)
	var lower: int = rng.randi_range(lowest, highest)
	return [lower, lower + width]

## Public bid readiness, copied so presentation cannot alter the host round.
func get_locked_bids() -> Array[bool]:
	return _locked.duplicate()

func snapshot(player_id: int = 0) -> Dictionary:
	var valid: bool = player_id >= 0 and player_id < names.size()
	var result: Dictionary = {
		"phase": phase, "warehouse": warehouse, "round": round,
		"warehouses_total": rules.warehouses, "rounds_total": Rules.ROUNDS,
		"balances": balances.duplicate(), "names": names.duplicate(),
		"clues": _clues.duplicate(), "history": _history.duplicate(true),
		"time": time, "ownbid": _bids[player_id] if valid else 0,
		"bidlocked": _locked[player_id] if valid else true,
		"skilltext": _skill_text[player_id] if valid else "",
		"skill_available": valid and phase == "bidding" and _eligible[player_id] and not _withdrawn[player_id] and not _skill_used[player_id],
		"eligible": _eligible.duplicate(), "withdrawn": _withdrawn.duplicate(),
		"minimum_bid": _minimum_bid, "outcome": _outcome,
		"early_percent": Rules.EARLY_WIN_PERCENT[round - 1] if round < Rules.ROUNDS and names.size() > 1 else 0,
		"round_bids": [], "winner": -1,
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
	for player_id: int in range(balances.size()):
		var rank: int = 1
		for other: int in balances:
			if int(other) > int(balances[player_id]):
				rank += 1
		result.append({"player_id": player_id, "name": names[player_id], "balance": balances[player_id], "rank": rank})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.balance == b.balance:
			return a.player_id < b.player_id
		return a.balance > b.balance)
	return result
