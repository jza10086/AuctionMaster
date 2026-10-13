extends SceneTree
const Session = preload("res://scripts/session.gd")
const AI = preload("res://scripts/bid_ai.gd")
var failures: int = 0
var checks: int = 0

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func fixture(seed_value: int = 123):
	var session = Session.new()
	session.start(seed_value)
	return session

func bid_round(session, human: int, opponents: Array = [0, 0, 0]) -> void:
	# Test-only fixture injection. Production AI never sees hidden session internals.
	for id in range(1, 4):
		session._bids[id] = opponents[id - 1]
	expect(session.submit_bid(0, human, session.warehouse, session.round), "valid round bid")

func _initialize() -> void:
	var s = fixture()
	expect(s.balances == [10000, 10000, 10000, 10000], "initial funds")
	expect(s.rules.rounds == 5 and s.rules.warehouses == 3, "production length")
	expect(s._locked == [false, true, true, true], "AI precommitted")
	expect(not s.submit_bid(-1, 100, 0, 1), "invalid player")
	expect(not s.submit_bid(4, 100, 0, 1), "invalid high player")
	expect(not s.submit_bid(0, -1, 0, 1), "negative bid rejected")
	expect(not s.submit_bid(0, 10001, 0, 1), "overbudget rejected")
	expect(not s.submit_bid(0, 100, 1, 1), "stale warehouse rejected")
	expect(not s.submit_bid(0, 100, 0, 2), "stale round rejected")
	expect(not s.submit_bid(1, 100, 0, 1), "sealed AI cannot be overwritten")
	expect(s.reveal_items().is_empty() and s.total_value() == 0, "hidden before reveal")
	var snap: Dictionary = s.snapshot(0)
	expect(snap.round_bids.is_empty() and snap.history.is_empty(), "sealed bids hidden")
	for forbidden in ["items", "value", "total_value", "true_value", "lots", "ai_bids"]:
		expect(not snap.has(forbidden), "no secret key " + forbidden)
	snap.balances[0] = 1
	snap.bounds[0] = 0
	expect(s.balances[0] == 10000 and s.snapshot(0).bounds[0] == 2000, "snapshot detached")
	var ai_before: Array = s._bids.duplicate()
	bid_round(s, 10000, [ai_before[1], ai_before[2], ai_before[3]])
	expect(s.phase == "round_result", "intermediate result")
	expect(s._bids.slice(1) == ai_before.slice(1), "AI cannot react to human bid")
	expect(s.balances[0] == 10000, "no preliminary charge")
	expect(not s.submit_bid(0, 1, 0, 1), "duplicate rejected")
	s.advance()
	expect(not s.submit_bid(0, 1, 0, 1), "prior round stale rejected")
	for index in range(2, 6):
		bid_round(s, 100 if index == 5 else 10000)
		if index < 5:
			s.advance()
	expect(s.phase == "reveal", "final bid directly reveals")
	expect(s.snapshot().winner == 0 and s.snapshot().price == 100, "only final bid wins and pays")
	expect(s.balances[0] == 10000 - 100 + s.total_value(), "resale accounting")
	var settled: Array = s.balances.duplicate()
	s._settle()
	expect(s.balances == settled, "idempotent settlement")
	expect(s.reveal_items().size() >= 3 and s.reveal_items().size() <= 5, "item count")
	var items: Array = s.reveal_items()
	items[0].value = 0
	expect(s.reveal_items()[0].value >= 500, "revealed items detached")
	# Zero means abstain; tie order rotates per warehouse.
	s = fixture(42)
	for wh in range(3):
		for rnd in range(1, 6):
			bid_round(s, 100, [100, 100, 100])
			if rnd < 5:
				s.advance()
		expect(s.snapshot().winner == wh, "rotating tie warehouse %d" % wh)
		s.advance()
	expect(s.phase == "finished", "three warehouses then finish")
	var finished_funds: Array = s.balances.duplicate()
	s.advance()
	s.tick(999.0)
	expect(s.balances == finished_funds and s.phase == "finished", "finished stable")
	s = fixture()
	for rnd in range(1, 6):
		bid_round(s, 0)
		if rnd < 5:
			s.advance()
	expect(s.snapshot().winner == -1 and s.snapshot().price == 0, "all zero unsold")
	expect(s.balances == [10000, 10000, 10000, 10000], "unsold has no monetary effect")
	# Private appraiser is truthful, once-only, and cannot leak across observers.
	s = fixture()
	var text: String = s.use_skill(0)
	var private: Dictionary = s.snapshot(0)
	expect(not text.is_empty() and not private.skill_available, "skill consumed")
	expect(s.use_skill(0) == text, "skill repeat no reroll")
	expect(private.bounds[0] <= s._hidden_total() and private.bounds[1] >= s._hidden_total(), "private clue truthful")
	expect(s.snapshot(1).skilltext.is_empty() and s.snapshot(1).bounds == [2000, 12000], "private clue not shared")
	s.tick(s.rules.round_seconds + 1)
	expect(s.phase == "round_result" and s.snapshot().round_bids[0] == 0, "timeout abstains")
	s.balances = [12000, 12000, 10000, 9000]
	var ranks: Array = s.rankings()
	expect(ranks[0].rank == 1 and ranks[1].rank == 1 and ranks[2].rank == 3, "rank ties")
	# AI sees only the permitted copy; hidden mutation doesn't alter decision.
	var a = fixture(99)
	var b = fixture(99)
	b._lots[0][0].value += 100
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 55
	rng_b.seed = 55
	expect(AI.choose_bid(a._ai_observation(1), 1, rng_a) == AI.choose_bid(b._ai_observation(1), 1, rng_b), "AI independent of hidden truth")
	# Randomly offset windows do not encode truth in their midpoint.
	var mids: Dictionary = {}
	var private_mids: Dictionary = {}
	for interval_seed in range(100):
		var interval_rng := RandomNumberGenerator.new()
		interval_rng.seed = interval_seed
		var window: Array = a._uncertain_interval(6500, [2000, 12000], 4800, interval_rng)
		mids[int(window[0]) + int(window[1])] = true
		expect(window[0] <= 6500 and window[1] >= 6500, "offset public window truthful")
		expect(window[0] >= 2000 and window[1] <= 12000, "offset window contained")
		var skill_window: Array = a._uncertain_interval(6500, [4000, 9000], 900, interval_rng)
		private_mids[int(skill_window[0]) + int(skill_window[1])] = true
		expect(skill_window[0] <= 6500 and skill_window[1] >= 6500, "offset private window truthful")
	expect(mids.size() > 50, "same true value has many public midpoints")
	expect(private_mids.size() > 50, "same true value has many private midpoints")
	expect(mids.size() > 1 or not mids.has(13000), "midpoint does not directly encode truth")
	# Skill calls cannot perturb AI or public-clue randomness in later rounds.
	a = fixture(221)
	b = fixture(221)
	for wh in range(3):
		a.use_skill(0)
		for rnd in range(1, 6):
			expect(a.snapshot().public_bounds == b.snapshot().public_bounds, "skill independent public clues")
			expect(a._bids == b._bids, "skill independent AI commitments")
			a.submit_bid(0, 0, wh, rnd)
			b.submit_bid(0, 0, wh, rnd)
			if rnd < 5:
				a.advance()
				b.advance()
		a.advance()
		b.advance()
	# Replays, truthful narrowing, item ranges, and all balances stay nonnegative.
	for seed_value in range(40):
		s = fixture(seed_value)
		for wh in range(3):
			var previous: Array = [2000, 12000]
			for rnd in range(1, 6):
				var public: Array = s.snapshot().public_bounds
				expect(public[0] <= s._hidden_total() and public[1] >= s._hidden_total(), "public bound truthful")
				expect(public[0] >= previous[0] and public[1] <= previous[1], "bound narrows")
				previous = public
				expect(s.submit_bid(0, 0, wh, rnd), "full session round accepted")
				if rnd < 5:
					s.advance()
			for item in s.reveal_items():
				expect(item.value >= 500 and item.value <= 3000, "item value range")
			for balance in s.balances:
				expect(balance >= 0, "no negative balances")
			s.advance()
		expect(s.phase == "finished", "repeat run finished")
		s.start(seed_value)
		expect(s.phase == "bidding" and s.round == 1 and s.warehouse == 0 and s.balances == [10000, 10000, 10000, 10000], "restart clean")
	print("MODEL TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
