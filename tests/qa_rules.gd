extends SceneTree
## Independent adversarial QA. Run with --headless --path . --script tests/qa_rules.gd.
const Session = preload("res://scripts/session.gd")
var checks: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error("QA: " + message)
		quit(1)
		assert(ok, message)
func _initialize() -> void:
	var s = Session.new()
	s.start(42)
	check(s.reveal_items().is_empty() and s.total_value() == 0, "no hidden values before reveal")
	check(not s.submit_bid(-1, 0, 0, 1), "invalid player")
	check(not s.submit_bid(4, 0, 0, 1), "invalid player upper")
	check(not s.submit_bid(0, -1, 0, 1), "negative bid")
	check(not s.submit_bid(0, 10001, 0, 1), "over budget")
	check(not s.submit_bid(0, 10, 1, 1), "stale warehouse")
	check(not s.submit_bid(0, 10, 0, 2), "stale round")
	check(not s.submit_bid(1, 1, 0, 1), "AI already committed")
	var obs = s._ai_observation(2)
	for key in ["ownbid", "bidlocked", "round_bids", "items", "total", "total_value", "_lots"]:
		check(not obs.has(key), "AI sanitized " + key)
	obs.balances[0] = 1
	obs.public_bounds[0] = -100
	check(s.balances[0] == 10000 and s.snapshot().public_bounds[0] == 2000, "snapshot does not expose aliases")
	var skill: String = s.use_skill(0)
	check(not skill.is_empty() and not s.snapshot().skill_available, "skill one use")
	check(s.use_skill(0) == skill and s.snapshot(1).skilltext == "", "skill private and idempotent")
	s.tick(-10)
	check(s.time == s.rules.round_seconds, "negative tick no increase")
	s.tick(10000)
	check(s.phase == "round_result" and s.snapshot().ownbid == 0, "timeout passes")
	check(not s.submit_bid(0, 100, 0, 1), "duplicate refused")
	s.advance()
	check(s.round == 2 and not s.submit_bid(0, 100, 0, 1), "stale token across advance")
	# Forced fixture establishes deterministic zero and tie settlement edge cases.
	for w in range(3):
		s.start(56)
		s.warehouse = w
		s.round = 5
		s._bids = [500,500,500,500]
		s._locked = [false,true,true,true]
		check(s.submit_bid(0,500,w,5), "tie accepted")
		check(s.snapshot().winner == w, "rotating tie priority")
		var before: Array = s.balances.duplicate()
		s._settle()
		check(s.balances == before, "settlement idempotent")
	s.start(45)
	s.round = 5
	s._bids = [0,0,0,0]
	s._locked = [false,true,true,true]
	s.submit_bid(0,0,0,5)
	check(s.snapshot().winner == -1 and s.snapshot().price == 0 and s.balances == [10000,10000,10000,10000], "all zero unsold")
	for seed_value in range(500):
		var a = Session.new()
		var b = Session.new()
		a.start(seed_value)
		b.start(seed_value)
		check(a._bids == b._bids, "deterministic AI setup")
		var ai_before: Array = a._bids.slice(1)
		a.submit_bid(0,0,0,1)
		b.submit_bid(0,10000,0,1)
		check(a.snapshot().round_bids.slice(1) == b.snapshot().round_bids.slice(1) and a.snapshot().round_bids.slice(1) == ai_before, "AI ignores current human bid")
		a.start(seed_value)
		for w in range(3):
			var before: Array = a.balances.duplicate()
			for r in range(1,6):
				var bounds: Array = a.snapshot().bounds
				var actual: int = a._hidden_total()
				check(actual >= bounds[0] and actual <= bounds[1], "public clue truthful")
				if r == 2:
					a.use_skill(0)
					bounds = a.snapshot().bounds
					check(actual >= bounds[0] and actual <= bounds[1], "skill truthful")
				check(a.submit_bid(0, min(10000, int(a.balances[0])) if r == 1 else 0,w,r), "valid round submit")
				check(not a.submit_bid(0, 1,w,r), "repeat does not mutate")
				if r < 5:
					check(a.balances == before, "no money deducted in preliminary rounds")
					a.advance()
			var snap: Dictionary = a.snapshot()
			check(a.phase == "reveal" and snap.history.size() == 5, "fifth round reveal")
			check(snap.ownbid == 0, "latest bid replaces first bid")
			var items: Array = a.reveal_items()
			var total: int = 0
			for item in items: total += item.value
			check(total == a.total_value(), "revealed line values match total")
			for p in range(4):
				var expected: int = before[p] - snap.price + total if p == snap.winner else before[p]
				check(a.balances[p] == expected and a.balances[p] >= 0, "winner paid exactly once, losers unchanged")
			check(not a.submit_bid(0, 0,w,5), "cannot submit after reveal")
			a.advance()
		check(a.phase == "finished", "three warehouses finish")
		var final_balances: Array = a.balances.duplicate()
		a.advance()
		a.tick(100)
		check(a.balances == final_balances and a.phase == "finished", "finished stable")
		a.start(seed_value)
		check(a.phase == "bidding" and a.warehouse == 0 and a.round == 1 and a.balances == [10000,10000,10000,10000] and a.snapshot().history.is_empty() and a.snapshot().skill_available, "restart clean")
	print("INDEPENDENT QA PASS: %d checks / 500 seeded complete games" % checks)
	quit(0)
