extends RefCounted
## Host-owned auction. Recipient snapshots contain only that player's discovered fields.
const Rules: Script = preload("res://games/minigame/godot_party_default_auction_master/rules.gd")
const Catalog: Script = preload("res://games/minigame/godot_party_default_auction_master/item_catalog.gd")
const TEXT: Translation = preload("res://games/minigame/godot_party_default_auction_master/i18n/zh_Hans.po")
const ASSISTS: Array[String] = ["full", "outline", "quality", "tags"]
const ASSIST_COUNTS: Array[int] = [1, 3, 2, 4]
var rules: Rules = Rules.new()
var catalog: Catalog = Catalog.new()
var names: Array[String] = []
var balances: Array[int] = []
var phase: String = "finished"
var warehouse: int = 0
var round: int = 1
var time: float = 0.0
var _lots: Array[Array] = []
var _appraisals: Array[Dictionary] = []
var _layouts: Array[Array] = []
var _bids: Array[int] = []
var _locked: Array[bool] = []
var _bid_order: Array[int] = []
var _submission_count: int = 0
var _withdrawn: Array[bool] = []
var _assists: Array[String] = []
var _intel: Array[Dictionary] = []
var _history: Array[Dictionary] = []
var _clues: Array[String] = []
var _payouts: Array[int] = []
var _winner: int = -1
var _price: int = 0
var _outcome: String = ""
var _settled: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _assist_seed: int = 0

func start(seed_value: int = -1) -> void:
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	_assist_seed = _rng.seed ^ 0x947F3
	balances.resize(names.size())
	balances.fill(rules.initialcoins)
	_withdrawn.resize(names.size())
	_withdrawn.fill(false)
	_lots.clear()
	_appraisals.clear()
	_layouts.clear()
	_history.clear()
	for index: int in rules.warehouses:
		var lot: Array = _generate_lot()
		_lots.append(lot)
		_appraisals.append(Catalog.evaluate(lot))
		_layouts.append(Catalog.pack(lot))
	warehouse = 0
	_begin_warehouse()

## Select quality first, so a weight is independent of how many catalogue entries share it.
func _generate_lot() -> Array:
	var groups: Array[Array] = []
	var total_weight: int = 0
	for quality: int in rules.quality_weights.size():
		groups.append([])
		total_weight += rules.quality_weights[quality]
	for item: Dictionary in catalog.items:
		groups[int(item.quality)].append(item)
	var lot: Array = []
	for index: int in _rng.randi_range(rules.item_counts[0], rules.item_counts[1]):
		var ticket: int = _rng.randi_range(0, total_weight - 1)
		for quality: int in rules.quality_weights.size():
			ticket -= rules.quality_weights[quality]
			if ticket < 0:
				var choices: Array = groups[quality]
				lot.append(choices[_rng.randi_range(0, choices.size() - 1)].duplicate(true))
				break
	return lot

func _hidden_total() -> int:
	return int(_appraisals[warehouse].total_value)

func _begin_warehouse() -> void:
	round = 1
	_clues.clear()
	_intel.clear()
	for seat: int in names.size():
		_intel.append({})
	_payouts.resize(names.size())
	_payouts.fill(0)
	_winner = -1
	_price = 0
	_outcome = ""
	_settled = false
	_begin_round()

func _begin_round() -> void:
	phase = "bidding"
	time = rules.round_seconds
	_submission_count = 0
	_bids.resize(names.size())
	_bids.fill(0)
	_bid_order.resize(names.size())
	_bid_order.fill(-1)
	_locked = _withdrawn.duplicate()
	_assists.resize(names.size())
	_assists.fill("")
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


func submit_bid(seat: int, amount: int, expected_warehouse: int, expected_round: int) -> bool:
	if phase != "bidding" or expected_warehouse != warehouse or expected_round != round:
		return false
	if seat < 0 or seat >= names.size() or _locked[seat] or _withdrawn[seat]:
		return false
	if amount < 0 or amount > balances[seat] or amount % Rules.BID_UNIT != 0:
		return false
	_bids[seat] = amount
	_locked[seat] = true
	_bid_order[seat] = _submission_count
	_submission_count += 1
	if not _locked.has(false):
		_begin_pending()
	return true

func _begin_pending() -> void:
	phase = "pending"
	time = Rules.REVEAL_DELAY

## Publish one completed round only after bidding or the three-second lock window ends.
func _resolve_round() -> void:
	_history.append({"warehouse": warehouse, "round": round, "bids": _bids.duplicate(), "assists": _assists.duplicate()})
	phase = "round_result"
	time = rules.reveal_seconds
	var highest: int = 0
	var second: int = 0
	var leaders: Array[int] = []
	for seat: int in names.size():
		if _withdrawn[seat]:
			continue
		var amount: int = _bids[seat]
		if amount > highest:
			second = highest
			highest = amount
			leaders.assign([seat])
		elif amount == highest and amount > 0:
			second = highest
			leaders.append(seat)
		elif amount > second:
			second = amount
	if round < rules.rounds:
		if names.size() > 1 and leaders.size() == 1 and highest * 100 >= second * Rules.EARLY_WIN_PERCENT[round - 1]:
			_winner = leaders[0]
			_price = highest
			_outcome = "early"
		return
	if leaders.is_empty():
		_outcome = "unsold"
	else:
		var winner: int = leaders[0]
		for seat: int in leaders:
			if _bid_order[seat] < _bid_order[winner]:
				winner = seat
		_winner = winner
		_price = highest
		_outcome = "first" if leaders.size() > 1 else "final"

func tick(delta: float) -> void:
	if phase == "finished":
		return
	if phase == "bidding" and not _locked.has(false):
		_begin_pending()
		return
	time = maxf(0.0, time - maxf(delta, 0.0))
	if time > 0.0:
		return
	match phase:
		"bidding": expire_round()
		"pending": _resolve_round()
		"round_result", "reveal": advance()

func expire_round() -> void:
	if phase != "bidding":
		return
	for seat: int in names.size():
		if not _locked[seat]:
			submit_bid(seat, 0, warehouse, round)
	_resolve_round()

func withdraw_player(seat: int) -> void:
	_withdrawn[seat] = true
	if phase in ["bidding", "pending"]:
		_bids[seat] = 0
		_locked[seat] = true

func advance() -> void:
	if phase == "round_result":
		if not _outcome.is_empty():
			_settle()
			phase = "reveal"
			time = 15.0
		else:
			round += 1
			_begin_round()
	elif phase == "reveal":
		if warehouse + 1 < rules.warehouses:
			warehouse += 1
			_begin_warehouse()
		else:
			phase = "finished"
			time = 0.0

## Delay balance changes until opening so review snapshots cannot expose the sealed value.
func _settle() -> void:
	if _settled:
		return
	_settled = true
	if _winner >= 0:
		var profit: int = _hidden_total() - _price
		balances[_winner] += profit
		if profit < 0:
			_distribute_loss(-profit)

## Largest remainders conserve the entire loss pool in whole coins; zero bids receive nothing.
func _distribute_loss(loss: int) -> void:
	var total_weight: int = 0
	var recipients: Array[int] = []
	for seat: int in names.size():
		if seat != _winner and not _withdrawn[seat] and _bids[seat] > 0:
			recipients.append(seat)
			total_weight += _bids[seat]
	if total_weight == 0:
		return
	var remaining: int = loss
	for seat: int in recipients:
		_payouts[seat] = int(float(loss * _bids[seat]) / total_weight)
		remaining -= _payouts[seat]
	recipients.sort_custom(func(a: int, b: int) -> bool:
		var left: int = loss * _bids[a] % total_weight
		var right: int = loss * _bids[b] % total_weight
		return a < b if left == right else left > right)
	for index: int in remaining:
		_payouts[recipients[index]] += 1
	for seat: int in recipients:
		balances[seat] += _payouts[seat]

## One operation per round. Previously discovered information persists only in this warehouse.
func use_assist(seat: int, kind: String) -> bool:
	if phase != "bidding" or seat < 0 or seat >= names.size() or _withdrawn[seat] or not _assists[seat].is_empty() or not kind in ASSISTS:
		return false
	_assists[seat] = kind
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = _assist_seed ^ ((warehouse + 1) * 73856093) ^ ((seat + 1) * 19349663) ^ (round * 83492791)
	var candidates: Array[int] = []
	for index: int in _lots[warehouse].size():
		var known: Dictionary = _intel[seat].get(index, {})
		if not known.has("name") and not known.has(kind):
			candidates.append(index)
	var count: int = mini(ASSIST_COUNTS[ASSISTS.find(kind)], candidates.size())
	for draw: int in count:
		var selected: int = random.randi_range(0, candidates.size() - 1)
		var index: int = candidates[selected]
		candidates.remove_at(selected)
		var item: Dictionary = _lots[warehouse][index]
		var rect: Rect2i = _layouts[warehouse][index]
		var record: Dictionary = _intel[seat].get(index, {"index": index, "rect": [rect.position.x, rect.position.y, 1, 1]})
		record[kind] = true
		if kind in ["full", "outline"]:
			record.rect = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		match kind:
			"full":
				# Base item data only; undiscovered warehouse synergies stay private.
				record.merge(item.duplicate(true), true)
			"quality": record["quality"] = item.quality
			"tags": record["tags"] = item.tags.duplicate()
		_intel[seat][index] = record
	return true

func get_locked_bids() -> Array[bool]:
	return _locked.duplicate()

func snapshot(seat: int = -1) -> Dictionary:
	var valid: bool = seat >= 0 and seat < names.size()
	var result: Dictionary = {
		"phase": phase, "warehouse": warehouse, "round": round, "time": time,
		"warehouses_total": rules.warehouses, "rounds_total": rules.rounds,
		"balances": balances.duplicate(), "names": names.duplicate(),
		"clues": _clues.duplicate(), "history": _history.duplicate(true),
		"locked": get_locked_bids(), "withdrawn": _withdrawn.duplicate(),
		"ownbid": _bids[seat] if valid else 0,
		"bidlocked": _locked[seat] if valid else true,
		"assist_available": valid and phase == "bidding" and not _withdrawn[seat] and _assists[seat].is_empty(),
		"intel": _intel[seat].values().duplicate(true) if valid else [],
		"early_percent": Rules.EARLY_WIN_PERCENT[round - 1] if round < rules.rounds and names.size() > 1 else 0,
		"outcome": _outcome, "round_bids": [], "winner": -1, "price": 0,
		"payouts": _payouts.duplicate(), "rankings": rankings(),
		"reveal_elapsed": 15.0 - time if phase == "reveal" else 0.0,
	}
	if phase in ["round_result", "reveal", "finished"]:
		result.round_bids = _bids.duplicate()
	if phase in ["reveal", "finished"]:
		result.winner = _winner
		result.price = _price
		result.items = _appraisals[warehouse].items.duplicate(true)
		result.total_value = _hidden_total()
		result.base_value = _appraisals[warehouse].base_value
		result.bonus_value = _appraisals[warehouse].bonus_value
		result.tag_groups = _appraisals[warehouse].tags.duplicate(true)
	return result

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
