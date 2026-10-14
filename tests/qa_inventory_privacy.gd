extends SceneTree
## Independent presentation-privacy regression tests. No production state changes.
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("INVENTORY QA: " + message)
func _initialize() -> void:
	call_deferred("run")
func visible_signature(node: Node) -> Array:
	var result: Array = []
	if node is Control and not node.visible:
		return result
	var text_value := ""
	if node is Label or node is Button or node is LineEdit:
		text_value = node.text
	result.append([node.get_class(), text_value, node.position if node is Control else Vector2.ZERO, node.size if node is Control else Vector2.ZERO])
	for child in node.get_children():
		result.append(visible_signature(child))
	return result
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game()
	main.set_process(false)
	await process_frame
	var baseline := visible_signature(main.ui)
	# Keep public evidence fixed while adversarially replacing every hidden item.
	# Nothing in the sealed inventory UI may depend on hidden count, kind or worth.
	for count in range(1, 9):
		var hidden: Array = []
		for i in count:
			hidden.append({"name":"QA_SECRET_%d_%d" % [count,i], "kind":["vase","clock","gold","radio","gem"][i%5], "value":777+i})
		main.game._lots[0] = hidden
		main.refresh()
		await process_frame
		check(visible_signature(main.ui) == baseline, "Sealed UI independent of hidden inventory count/kind/value: %d" % count)
		check(main.game.reveal_items().is_empty(), "Pre-reveal public item API is empty")
		check(main.game.total_value() == 0, "Pre-reveal public total API is zero")
	for observer in range(-1, 5):
		var snap: Dictionary = main.game.snapshot(observer)
		for key in ["items", "inventory", "item_count", "total_value", "_lots"]:
			check(not snap.has(key), "Snapshot never exposes hidden property %s" % key)
	main.start_game()
	main.set_process(false)
	main.use_skill()
	check(not main.game.snapshot(0).skilltext.is_empty(), "Owner can see private appraisal")
	for observer in range(1, 4):
		check(main.game.snapshot(observer).skilltext.is_empty(), "Other seats cannot see private appraisal")
	main.show_pause()
	var time_before: float = main.game.time
	var phase_before: String = main.game.phase
	main._process(100.0)
	main.submit(1000)
	check(main.game.time == time_before and main.game.phase == phase_before, "Pause blocks clock and bids")
	main.resume_game()
	main.submit(1000)
	var balances_before: Array = main.game.balances.duplicate()
	for i in range(10): main.submit(1000)
	check(main.game.round == 1 and main.game.phase == "round_result", "Repeated bid does not advance phase")
	check(main.game.balances == balances_before, "Repeated bid does not settle")
	for i in range(10): main.advance()
	check(main.game.round == 2 and main.game.phase == "bidding", "Repeated next-round click cannot skip bidding")
	main.start_game()
	check(main.game.warehouse == 0 and main.game.round == 1 and main.game.balances == [10000,10000,10000,10000], "Restart restores clean match")
	await process_frame
	print("INVENTORY PRIVACY: ",checks," checks, ",failures," failures")
	main.queue_free()
	await process_frame
	quit(failures)
