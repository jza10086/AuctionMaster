extends SceneTree
## Render the real game scene at 1800x1125 (16:10), without upscaling an image.
## Requires a graphical display. Output path may be passed after --.
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var output: String = ProjectSettings.globalize_path("user://screenshots")
	var args = OS.get_cmdline_user_args()
	if not args.is_empty(): output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1800,1125)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(main)
	main.ui.scale = Vector2(1.25,1.25)
	main.start_game()
	main.game.start(8)
	main.last_warehouse = -1
	main.last_phase = ""
	main.refresh()
	for r in range(2):
		main.bid_input.text = "4500"
		main.submit()
		main.advance()
	main.use_skill()
	main.bid_input.text = "5500"
	main.paused = true
	main.overlay.hide()
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var img = viewport.get_texture().get_image()
	assert(img.get_size() == Vector2i(1800,1125))
	assert(img.save_png(output.path_join("auction-bidding.png")) == OK)
	main.paused = false
	while main.game.phase != "reveal":
		if main.game.phase == "bidding":
			main.bid_input.text = "7000"
			main.submit()
		else: main.advance()
	main.set_process(false)
	main.view.advance_reveal(0.85)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(output.path_join("auction-searching.png")) == OK)
	main.skip_reveal()
	main.view.select_item(0)
	main.paused = true
	main.overlay.hide()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(output.path_join("auction-reveal.png")) == OK)
	print("Captured real game renders at ", output)
	quit()
