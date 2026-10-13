extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures+=1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(main.overlay.visible,"Menu opens")
	main.start_game()
	check(main.game.phase=="bidding","Game starts")
	await process_frame
	check(main.bidder_bids[3].get_global_rect().end.y < 675.0,"Fourth bidder stays above controls")
	check(main.history_label.get_global_rect().end.y < 675.0,"Intel panel stays above controls")
	main.bid_input.text="-9"
	main.submit()
	check(main.game.phase=="bidding","Negative blocked")
	main.bid_input.text="1.5"
	main.submit()
	check(main.game.phase=="bidding","Fractions blocked")
	main.bid_input.text="100000"
	main.submit()
	check(main.game.phase=="bidding","Overbudget blocked")
	main.show_pause()
	main.submit(1000)
	check(main.game.phase=="bidding","Paused submission blocked")
	main.resume_game()
	main.use_skill()
	check(main.skill_button.disabled,"Skill disables")
	for warehouse in 3:
		for round_index in 5:
			main.submit(1000)
			check(main.game.phase==("round_result" if round_index<4 else "reveal"),"Correct phase after bid")
			await process_frame
			main.advance()
			await process_frame
			check(main.history_label.get_global_rect().end.y < 675.0,"Intel panel remains clear through all rounds")
	check(main.game.phase=="finished","Match finishes")
	check(main.overlay.visible,"Ranking opens")
	main.start_game()
	check(main.game.balances==[10000,10000,10000,10000],"Restart resets balances")
	main.game.tick(31)
	main.refresh()
	check(main.game.phase=="round_result","Timer resolves UI")
	print("UI FLOW: ",failures," failures")
	main.queue_free()
	await process_frame
	quit(failures)
