extends SceneTree
## Independent regression for dense-grid privacy, search, geometry, and UI text bounds.
const Grid = preload("res://scripts/warehouse_view.gd")
const Session = preload("res://scripts/session.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("DENSE QA: " + message)
func reveal(s) -> void:
	for r in range(5):
		s.submit_bid(0, 0, s.warehouse, s.round)
		if r < 4: s.advance()
func inspect_controls(node: Node, mode: String) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is Label or node is Button or node is LineEdit:
		var rect: Rect2 = node.get_global_rect()
		var title: String = node.text.replace("\n", " / ")
		check(Rect2(-1,-1,1442,902).encloses(rect), "%s control out of canvas: %s = %s" % [mode,title,rect])
		var minimum: Vector2 = node.get_minimum_size()
		check(rect.size.x + 1.0 >= minimum.x and rect.size.y + 1.0 >= minimum.y, "%s control smaller than text minimum: %s = %s vs %s" % [mode,title,rect.size,minimum])
		if node is Label and not node.clip_text and node.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var font: Font = node.get_theme_font("font")
			var font_size: int = node.get_theme_font_size("font_size")
			for line in node.text.split("\n"):
				var width: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				check(width <= rect.size.x + 1.0, "%s clipped label: %s = %.1f > %.1f" % [mode,line,width,rect.size.x])
	for child in node.get_children(): inspect_controls(child,mode)
func run() -> void:
	check(Grid.GRID_COLUMNS * Grid.GRID_ROWS >= 168, "At least 168 cells, increased from original 60")
	var grid = Grid.new()
	root.add_child(grid)
	await process_frame
	grid.size=Grid.GRID_SIZE
	var s = Session.new()
	for seed_value in range(1000):
		s.start(seed_value)
		for warehouse in range(3):
			grid.set_snapshot(s.snapshot())
			check(grid.layout.is_empty() and grid.items.is_empty(), "No sealed metadata")
			var malicious: Dictionary = s.snapshot()
			malicious.items = [{"kind":"clock","name":"QA_PRIVATE","value":1234}]
			grid.set_snapshot(malicious)
			check(grid.items.is_empty() and grid.layout.is_empty(), "Renderer rejects injected pre-reveal inventory")
			reveal(s)
			grid.set_snapshot(s.snapshot())
			check(grid.revealed_count == 0, "Search starts empty")
			check(not grid.select_item(0), "Undiscovered item not selectable")
			var finance: Array = s.balances.duplicate()
			grid.advance_reveal(Grid.REVEAL_SECONDS * 0.5)
			check(grid.revealed_count == 0, "Half-step reveals nothing")
			grid.advance_reveal(Grid.REVEAL_SECONDS * 0.6)
			check(grid.revealed_count == 1, "First threshold reveals exactly one")
			check(grid.select_item(0), "Discovered item selectable")
			check(not grid.select_item(1), "Next undiscovered item stays unselectable")
			grid.skip_reveal()
			check(grid.revealed_count == grid.items.size() and s.balances == finance, "Skip reveals all without finance mutation")
			for i in range(grid.layout.size()):
				var rect: Rect2 = grid.get_item_rect(i)
				check(rect.size.x > 0 and rect.size.y > 0 and grid.get_grid_rect().encloses(rect), "Every supported item fits dense grid")
				for j in range(i): check(not rect.intersects(grid.get_item_rect(j)), "No dense item overlap")
			s.advance()
	grid.queue_free()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	inspect_controls(main.ui,"menu")
	main.show_help()
	await process_frame
	await process_frame
	inspect_controls(main.ui,"help")
	main.start_game()
	main.set_process(false)
	for warehouse in range(3):
		for r in range(5):
			main.use_skill()
			await process_frame
			await process_frame
			inspect_controls(main.ui,"w%d-r%d-bidding" % [warehouse,r])
			main.submit(0)
			await process_frame
			await process_frame
			inspect_controls(main.ui,"w%d-r%d-result" % [warehouse,r])
			if r == 4:
				main.view.advance_reveal(Grid.REVEAL_SECONDS * 1.1)
				await process_frame
				inspect_controls(main.ui,"partial-search")
				main.skip_reveal()
				await process_frame
				inspect_controls(main.ui,"completed-search")
			main.advance()
			await process_frame
			await process_frame
	inspect_controls(main.ui,"final-ranking")
	main.start_game()
	main.show_pause()
	await process_frame
	await process_frame
	inspect_controls(main.ui,"pause")
	main.show_restart_confirm()
	await process_frame
	await process_frame
	inspect_controls(main.ui,"restart-confirm")
	main.resume_game()
	main.game.balances = [46000,46000,46000,46000]
	main.refresh()
	await process_frame
	await process_frame
	inspect_controls(main.ui,"large-balances")
	main.queue_free()
	await process_frame
	print("DENSE INDEPENDENT QA: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
