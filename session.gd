extends RefCounted
## Host-owned auction. Recipient snapshots contain only that player's discovered fields.
const Rules: Script = preload("res://games/minigame/gp_auction_master/rules.gd")
const Catalog: Script = preload("res://games/minigame/gp_auction_master/item_catalog.gd")
const ASSISTS: Array[String] = ["full", "outline", "quality", "tags"]
const Conditions: Script = Rules.Conditions
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
var _drafts: Array[int] = []
var _locked: Array[bool] = []
var _bid_order: Array[int] = []
var _submission_count: int = 0
var _withdrawn: Array[bool] = []
var _assists: Array[String] = []
var _intel: Array[Dictionary] = []
var _history: Array[Dictionary] = []
var _clues: Array[String] = []
var _condition: Dictionary = {}
var _public_intel: Dictionary = {}
var _rule_lines: Array[String] = []
var _previous_positive: Array[int] = []
var _payouts: Array[int] = []
var _winner: int = -1
var _price: int = 0
var _outcome: String = ""
var _settled: bool = false
var _profit_applied: bool = false
var _payout_seats: Array[int] = []
var _search_ends: Array[float] = []
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
	_condition = rules.conditions.draw(_rng)
	rules.conditions.apply_values(_lots[warehouse], _condition, catalog.items)
	_appraisals[warehouse] = Catalog.evaluate(_lots[warehouse])
	_search_ends.clear()
	_rule_lines = rules.conditions.describe(_condition)
	var evidence: Dictionary = rules.conditions.public_evidence(_lots[warehouse], _layouts[warehouse], _appraisals[warehouse], _condition, _rng)
	_clues.assign(evidence.lines)
	_public_intel = evidence.intel
	_previous_positive.resize(names.size())
	_previous_positive.fill(0)
	_intel.clear()
	for seat: int in names.size():
		_intel.append(_public_intel.duplicate(true))
	_payouts.resize(names.size())
	_payouts.fill(0)
	_winner = -1
	_price = 0
	_outcome = ""
	_settled = false
	_profit_applied = false
	_payout_seats.clear()
	_begin_round()
	if int(rules.conditions.values.briefing_seconds) > 0:
		phase = "briefing"
		time = float(rules.conditions.values.briefing_seconds)

func _begin_round() -> void:
	phase = "bidding"
	time = rules.round_seconds
	_submission_count = 0
	_bids.resize(names.size())
	_bids.fill(0)
	_drafts.resize(names.size())
	_drafts.fill(0)
	_bid_order.resize(names.size())
	_bid_order.fill(-1)
	_locked = _withdrawn.duplicate()
	_assists.resize(names.size())
	_assists.fill("")

## A positive quote must satisfy the active warehouse floor and personal raise rule.
func minimum_bid(seat: int) -> int:
	var minimum: int = 1
	if "reserve" in _condition.ids:
		minimum = maxi(minimum, int(rules.conditions.values.reserve_price))
	if "step" in _condition.ids and _previous_positive[seat] > 0:
		minimum = maxi(minimum, _previous_positive[seat] + int(rules.conditions.values.raise_step))
	return minimum

func early_percent() -> int:
	if round >= rules.rounds or names.size() <= 1:
		return 0
	if "patient" in _condition.ids and round <= int(rules.conditions.values.patient_rounds):
		return 0
	var rates: Array = rules.conditions.values.fast_percent if "fast" in _condition.ids else rules.conditions.values.early_percent
	return int(rates[round - 1])

func assist_count(kind: String) -> int:
	var count: int = int(rules.conditions.values.assist_counts[ASSISTS.find(kind)])
	if "assist" in _condition.ids and kind == _condition.assist:
		count *= int(rules.conditions.values.assist_multiplier)
	return count

## Host-private drafts are validated without locking or publishing a player's quote.
func update_draft(seat: int, amount: int, expected_warehouse: int, expected_round: int) -> bool:
	if phase != "bidding" or expected_warehouse != warehouse or expected_round != round:
		return false
	if seat < 0 or seat >= names.size() or _locked[seat] or _withdrawn[seat]:
		return false
	if amount < 0 or amount > balances[seat] or amount % Rules.BID_UNIT != 0:
		return false
	if amount > 0 and amount < minimum_bid(seat):
		return false
	_drafts[seat] = amount
	return true

func submit_bid(seat: int, amount: int, expected_warehouse: int, expected_round: int) -> bool:
	if not update_draft(seat, amount, expected_warehouse, expected_round):
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
	time = float(rules.conditions.values.pending_seconds)

## Publish one completed round only after bidding or the three-second lock window ends.
func _resolve_round() -> void:
	for seat: int in names.size():
		if _bids[seat] > 0:
			_previous_positive[seat] = _bids[seat]
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
		if early_percent() > 0 and leaders.size() == 1 and highest * 100 >= second * early_percent():
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
	if phase == "settlement":
		_update_settlement()
	if time > 0.0:
		return
	match phase:
		"briefing": _begin_round()
		"bidding": expire_round()
		"pending": _resolve_round()
		"round_result", "settlement", "reveal": advance()

func expire_round() -> void:
	if phase != "bidding":
		return
	for seat: int in names.size():
		if not _locked[seat]:
			submit_bid(seat, _drafts[seat], warehouse, round)
	_resolve_round()

func withdraw_player(seat: int) -> void:
	_withdrawn[seat] = true
	if phase in ["bidding", "pending"]:
		_bids[seat] = 0
		_drafts[seat] = 0
		_locked[seat] = true

func advance() -> void:
	if phase == "round_result":
		if not _outcome.is_empty():
			if _winner >= 0:
				_search_ends = rules.make_search_ends(_appraisals[warehouse].items, _rng)
			phase = "settlement" if _winner >= 0 else "reveal"
			time = rules.settlement_seconds if _winner >= 0 else float(rules.conditions.values.unsold_seconds)
			# Publish the complete payout plan once, before the local settlement animation starts.
			if _winner >= 0 and _hidden_total() < _price:
				_calculate_loss(_price - _hidden_total())
		else:
			round += 1
			_begin_round()
	elif phase in ["settlement", "reveal"]:
		if phase == "settlement":
			_settle()
		if warehouse + 1 < rules.warehouses:
			warehouse += 1
			_begin_warehouse()
		else:
			phase = "finished"
			time = 0.0

## Financial commits follow the host timeline, independently of client animation frames.
func _update_settlement() -> void:
	var progress: float = 1.0 - time / rules.settlement_seconds
	if progress >= Rules.PROFIT_END:
		_apply_profit()
	if progress >= Rules.PAYOUT_END:
		_settle()

func _apply_profit() -> void:
	if _profit_applied:
		return
	_profit_applied = true
	var profit: int = _hidden_total() - _price
	balances[_winner] += profit
	# Payouts were fixed when settlement began; presentation and financial commit share that plan.

func _settle() -> void:
	if _settled:
		return
	_apply_profit()
	_settled = true
	for seat: int in _payout_seats:
		balances[seat] += _payouts[seat]

## Largest remainders conserve the entire loss pool in whole coins; zero bids receive nothing.
func _calculate_loss(loss: int) -> void:
	var total_weight: int = 0
	_payout_seats.clear()
	for seat: int in names.size():
		if seat != _winner and not _withdrawn[seat] and _bids[seat] > 0:
			_payout_seats.append(seat)
			total_weight += _bids[seat]
	if total_weight == 0:
		return
	var remaining: int = loss
	for seat: int in _payout_seats:
		_payouts[seat] = int(float(loss * _bids[seat]) / total_weight)
		remaining -= _payouts[seat]
	_payout_seats.sort_custom(func(a: int, b: int) -> bool:
		var left: int = loss * _bids[a] % total_weight
		var right: int = loss * _bids[b] % total_weight
		return a < b if left == right else left > right)
	for index: int in remaining:
		_payouts[_payout_seats[index]] += 1
	_payout_seats.sort()

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
		if not known.has("name") and (not known.has(kind) or (kind == "tags" and known.get("partial_tags", false))):
			candidates.append(index)
	var count: int = mini(assist_count(kind), candidates.size())
	for draw: int in count:
		var selected: int = random.randi_range(0, candidates.size() - 1)
		var index: int = candidates[selected]
		candidates.remove_at(selected)
		Conditions.reveal(_intel[seat], _lots[warehouse], _layouts[warehouse], index, kind)
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
		"intel": _intel[seat].values().duplicate(true) if valid else _public_intel.values().duplicate(true),
		"public_intel": _public_intel.values().duplicate(true),
		"special_rules": _rule_lines.duplicate(),
		"minimum_bid": minimum_bid(seat) if valid else 0,
		"assist_counts": [assist_count("full"), assist_count("outline"), assist_count("quality"), assist_count("tags")],
		"early_percent": early_percent(),
		"outcome": _outcome, "round_bids": [], "winner": -1, "price": 0,
		"payouts": _payouts.duplicate(), "rankings": rankings(),
		"reveal_elapsed": float(rules.conditions.values.unsold_seconds) - time if phase == "reveal" else 0.0,
		"settlement_elapsed": rules.settlement_seconds - time if phase == "settlement" else 0.0,
		"settlement_seconds": rules.settlement_seconds,
		"payout_seats": _payout_seats.duplicate(),
	}
	if phase == "settlement":
		result.reveal_elapsed = result.settlement_elapsed
	if phase in ["round_result", "settlement", "reveal", "finished"]:
		result.round_bids = _bids.duplicate()
	if phase in ["settlement", "reveal", "finished"]:
		result.winner = _winner
		result.price = _price
		result.items = _appraisals[warehouse].items.duplicate(true)
		result.search_ends = _search_ends.duplicate()
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
