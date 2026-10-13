extends RefCounted
## Pure decision boundary: no session, hidden inventory, or current human bid.
static func choose_bid(observation: Dictionary, player_id: int, rng: RandomNumberGenerator) -> int:
	var budgets: Array = observation.get("balances", [])
	if player_id < 0 or player_id >= budgets.size():
		return 0
	var budget: int = int(budgets[player_id])
	if budget <= 0:
		return 0
	var bounds: Array = observation.get("bounds", [2000, 12000])
	var estimate: float = (float(bounds[0]) + float(bounds[1])) * 0.5
	var styles: Array = [0.72, 0.72, 0.84, 0.92]
	var fraction: float = float(styles[player_id % styles.size()])
	var round_number: int = int(observation.get("round", 1))
	var rounds_total: int = int(observation.get("rounds_total", 5))
	var jitter: float = rng.randf_range(-0.12, 0.10)
	var desired: float = estimate * (fraction + jitter) * (0.86 + 0.14 * float(round_number) / float(maxi(1, rounds_total)))
	# Previous public bids can influence price discovery, never current sealed bids.
	var history: Array = observation.get("history", [])
	if not history.is_empty():
		var last: Dictionary = history.back()
		var previous: Array = last.get("bids", [])
		var previous_high: int = 0
		for value in previous:
			previous_high = maxi(previous_high, int(value))
		desired = minf(estimate * 0.98, maxf(desired, previous_high * 0.93))
	if rng.randf() < 0.06:
		return 0
	return clampi(int(round(desired / 50.0)) * 50, 0, budget)
