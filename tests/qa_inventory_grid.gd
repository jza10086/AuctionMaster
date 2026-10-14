extends SceneTree
## Independent tests for grid geometry, progressive identification and reset races.
const Session = preload("res://scripts/session.gd")
const Grid = preload("res://scripts/warehouse_view.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("GRID QA: " + message)
func _initialize() -> void:
	call_deferred("run")
func reach_reveal(s) -> void:
	for r in range(5):
		s.submit_bid(0, 0, s.warehouse, s.round)
		if r < 4: s.advance()
func run() -> void:
	var grid = Grid.new()
	root.add_child(grid)
	await process_frame
	var s = Session.new()
	for seed_value in range(100):
		s.start(seed_value)
		grid.set_snapshot(s.snapshot())
		check(grid.items.is_empty() and grid.layout.is_empty(), "Sealed grid contains no hidden metadata")
		check(grid.get_selected_item().is_empty(), "Sealed grid exposes no selection")
		grid.select_item(0)
		check(grid.get_selected_item().is_empty(), "Cannot select sealed inventory")
		reach_reveal(s)
		grid.set_snapshot(s.snapshot())
		check(grid.items.size() == s.reveal_items().size(), "Revealed lot carries all items")
		var starting_count: int = grid.revealed_count
		for i in range(starting_count, grid.items.size()):
			grid.select_item(i)
			check(grid.get_selected_item().is_empty() or grid.selected_index < grid.revealed_count, "Unidentified item selection exposes no hidden detail")
		grid.advance_reveal(0.01)
		check(grid.revealed_count < grid.items.size(), "Search does not reveal everything instantly")
		var before_repeat: int = grid.revealed_count
		grid.set_snapshot(s.snapshot())
		check(grid.revealed_count == before_repeat, "Refreshing same snapshot does not restart search")
		grid.skip_reveal()
		check(grid.is_reveal_complete(), "Skip completes current search")
		var count_after: int = grid.revealed_count
		grid.skip_reveal()
		grid.advance_reveal(100.0)
		check(grid.revealed_count == count_after, "Skip and extra tick are idempotent")
		for i in range(grid.items.size()):
			grid.select_item(i)
			check(grid.get_selected_item() == grid.items[i], "Identified item selection matches item")
			var rect: Rect2 = grid.get_item_rect(i)
			check(rect.size.x > 0 and rect.size.y > 0, "Grid item has positive footprint")
			check(grid.get_grid_rect().encloses(rect), "Item footprint is fully inside grid bounds")
			for j in range(i):
				check(not rect.intersects(grid.get_item_rect(j)), "Inventory footprints never overlap")
		s.advance()
		grid.set_snapshot(s.snapshot())
		check(grid.items.is_empty() and grid.layout.is_empty(), "Next warehouse clears previous lot")
		grid.advance_reveal(100.0)
		grid.skip_reveal()
		check(grid.items.is_empty() and grid.get_selected_item().is_empty(), "Old reveal cannot populate sealed next warehouse")
	# Integrated pause and mid-search restart must preserve finance and clear display.
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game()
	main.set_process(false)
	reach_reveal(main.game)
	main.refresh()
	main.view.advance_reveal(0.01)
	var count_before: int = main.view.revealed_count
	main.show_pause()
	main._process(100.0)
	main.skip_reveal()
	check(main.view.revealed_count == count_before, "Pause freezes search and skip")
	main.resume_game()
	var settled_balance: Array = main.game.balances.duplicate()
	for i in range(20): main.skip_reveal()
	check(main.game.balances == settled_balance, "Repeated skip cannot settle twice")
	main.advance()
	var next_balances: Array = main.game.balances.duplicate()
	for i in range(20): main.advance()
	check(main.game.warehouse == 1 and main.game.round == 1 and main.game.phase == "bidding", "Repeated next-warehouse calls cannot skip new bidding")
	check(main.game.balances == next_balances, "Repeated next warehouse cannot resettle")
	check(main.view.items.is_empty(), "Repeated next clears all previous inventory")
	main.start_game()
	reach_reveal(main.game)
	main.refresh()
	main.view.advance_reveal(0.85)
	check(main.view.revealed_count > 0 and not main.view.is_reveal_complete(), "Restart fixture is genuinely mid-search")
	main._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var focus_count: int = main.view.revealed_count
	main._process(100.0)
	check(main.paused and main.view.revealed_count == focus_count, "Focus loss freezes partial search")
	main.start_game()
	main._process(0.01)
	check(main.view.items.is_empty() and main.view.get_selected_item().is_empty(), "Restart discards search and selection")
	main.phase_action_unlock_msec = 0
	var double_event := InputEventMouseButton.new()
	double_event.button_index = MOUSE_BUTTON_LEFT
	double_event.pressed = true
	double_event.double_click = true
	main._input(double_event)
	main.commit_button.pressed.emit()
	check(main.game.phase == "bidding", "Trailing native double click cannot submit new phase")
	await process_frame
	main.commit_button.pressed.emit()
	check(main.game.phase == "round_result", "Ordinary phase action works after double-click frame")
	main.next_button.pressed.emit()
	check(main.game.round == 1 and main.game.phase == "round_result", "Rapid next action is throttled")
	main.queue_free()
	grid.queue_free()
	await process_frame
	print("INVENTORY GRID: ", checks, " checks, ", failures, " failures")
	quit(failures)
