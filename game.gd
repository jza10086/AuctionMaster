extends "res://games/protocols/godot_party_default_protocol/ranked_round.gd"
## Sealed auction. The random inventory and private appraisals never enter public snapshots.
const Session: Script = preload("res://games/minigame/godot_party_default_auction_master/session.gd")
const Warehouse: Script = preload("res://games/minigame/godot_party_default_auction_master/warehouse_view.gd")
const Catalog: Script = preload("res://games/minigame/godot_party_default_auction_master/item_catalog.gd")
var item_details: Label
var valuation: Label
var encyclopedia: AcceptDialog
var session: RefCounted = Session.new()
var warehouse_view: Control
var private_view: Dictionary = {}
var bid: SpinBox
var submit: Button
var appraisal: Button
var private_label: Label
var clues: Label
var transition: float = 0.0
var previous_phase: String = ""
var public_revision: int = 0
var private_revision: int = -1

func build_game() -> void:
	heading.text = "秘仓竞拍 · 密封报价"
	footer.text = "每仓 5 轮，仅第 5 轮成交 · 同价按公开优先顺序 · 0 金币表示放弃"
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(center)
	warehouse_view = Warehouse.new()
	var inventory: VBoxContainer = VBoxContainer.new()
	center.add_child(inventory)
	valuation = label(inventory, "封仓期间不显示物资、tag 或羁绊", 20)
	valuation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory.add_child(warehouse_view)
	item_details = label(inventory, "开仓后点击物资查看品质、占格和增值", 18)
	item_details.custom_minimum_size = Vector2(576, 64)
	item_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warehouse_view.selection_changed.connect(_show_item)
	clues = label(sidebar, "", 20)
	clues.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clues.custom_minimum_size.x = 330
	private_label = label(sidebar, "鉴定信息仅自己可见", 20)
	private_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bid = SpinBox.new()
	bid.step = 50
	bid.custom_minimum_size.y = 48
	sidebar.add_child(bid)
	submit = button(sidebar, "确认密封报价", func() -> void: _act("bid"))
	appraisal = button(sidebar, "私密鉴定（每仓一次）", func() -> void: _act("appraise"))
	button(sidebar, "物资图鉴 / 羁绊规则", _open_catalog)

func start_game() -> void:
	if not api.is_host():
		return
	session.names = []
	for player: Dictionary in players:
		session.names.append(player.name)
	session.rules.warehouses = int(settings.get("warehouses", 3))
	session.rules.initialcoins = int(settings.get("coins", 10000))
	session.rules.round_seconds = float(settings.get("round_seconds", 15))
	session.start()

func _act(kind: String) -> void:
	if not private_view.is_empty():
		send_action({"kind": kind, "amount": int(bid.value), "warehouse": private_view.warehouse, "round": private_view.round})

func handle_action(id: String, data: Dictionary) -> void:
	if not data.get("warehouse") is int or not data.get("round") is int or data.warehouse != session.warehouse or data.round != session.round:
		return
	var seat: int = seat_of(id)
	if data.get("kind") == "bid" and data.get("amount") is int:
		session.submit_bid(seat, data.amount, data.warehouse, data.round)
	elif data.get("kind") == "appraise":
		session.use_skill(seat)
	publish()

func seat_of(id: String) -> int:
	for index: int in players.size():
		if players[index].player_id == id:
			return index
	return -1

func tick_game(delta: float) -> void:
	if not api.is_host():
		return
	if players.size() - disconnected.size() < 2:
		finish_rows([], [], "cancelled")
		return
	for id: String in disconnected:
		var seat: int = seat_of(id)
		if session.phase == "bidding":
			session._bids[seat] = 0
			if not session._locked[seat]:
				session.submit_bid(seat, 0, session.warehouse, session.round)
	session.tick(delta)
	if previous_phase != session.phase:
		previous_phase = session.phase
		transition = 0.0
	if session.phase in ["round_result", "reveal"]:
		transition += delta
		if transition >= (15.0 if session.phase == "reveal" else 3.0):
			session.advance()
	if session.phase == "finished":
		var scores: Dictionary = {}
		for index: int in players.size():
			scores[players[index].player_id] = session.balances[index]
		finish_scores(scores, {}, [{"key": "score", "title": "最终金币", "format": "integer"}])

func make_snapshot() -> Dictionary:
	public_revision += 1
	for player: Dictionary in api.get_players():
		if player.connected:
			var snap: Dictionary = session.snapshot(seat_of(player.player_id))
			snap["revision"] = public_revision
			api.net.send_to_player(player.player_id, &"private_view", snap)
	var public_view: Dictionary = session.snapshot(-1)
	public_view["reveal_elapsed"] = transition if session.phase == "reveal" else 0.0
	public_view["locked"] = session._locked.duplicate()
	return public_view

func receive_private(data: Dictionary) -> void:
	if int(data.get("revision", -1)) <= private_revision:
		return
	private_revision = data.revision
	private_view = data
	render_game()

func render_game() -> void:
	if view.is_empty():
		return
	warehouse_view.set_snapshot(view)
	warehouse_view.advance_reveal(maxf(0.0, float(view.get("reveal_elapsed", 0.0)) - warehouse_view._animation_time))
	if view.phase in ["reveal", "finished"]:
		valuation.text = "基础 %d  +  羁绊 %d  =  总值 %d" % [view.base_value, view.bonus_value, view.total_value]
	else:
		valuation.text = "封仓期间不显示物资、tag 或羁绊"
	status.text = "仓库 %d / %d · 第 %d / 5 轮 · 剩余 %d 秒 · %s" % [int(view.warehouse) + 1, view.warehouses_total, view.round, ceili(view.time), {"bidding": "密封报价", "round_result": "本轮报价公布", "reveal": "开仓揭晓", "finished": "竞拍结束"}.get(view.phase, "等待")]
	var lines: PackedStringArray = []
	for index: int in players.size():
		var revealed_bid: String = " · 报价 %d" % int(view.round_bids[index]) if view.round_bids.size() == players.size() else (" · 已锁定" if view.locked[index] else " · 思考中")
		lines.append("%s  %d%s" % [players[index].name, view.balances[index], revealed_bid])
	standings.text = "\n".join(lines)
	var priority_names: PackedStringArray = []
	for seat: int in view.priority:
		priority_names.append(players[seat].name)
	clues.text = "\n".join(view.clues) + "\n同价优先：" + " → ".join(priority_names)
	if view.phase in ["reveal", "finished"]:
		clues.text += "\n" + ("流拍" if int(view.winner) < 0 else "成交：%s · 支付 %d\n仓库总值：%d" % [players[int(view.winner)].name, view.price, view.total_value])
		var tag_lines: PackedStringArray = []
		for group: Dictionary in view.get("tag_groups", []):
			tag_lines.append("%s %d 件 · %s" % [group.tag, group.count, "+%d%%" % group.percent if group.percent > 0 else "未激活"])
		clues.text += "\n同仓羁绊（只给对应物资增值）\n" + " / ".join(tag_lines)
	var can_bid: bool = not local_id.is_empty() and not private_view.is_empty() and private_view.phase == "bidding" and not private_view.bidlocked
	submit.disabled = not can_bid
	bid.editable = can_bid
	appraisal.disabled = local_id.is_empty() or not private_view.get("skill_available", false)
	private_label.text = private_view.get("skilltext", "") if not local_id.is_empty() else "观战中（不显示私密鉴定）"
	if not local_id.is_empty() and not private_view.is_empty():
		bid.max_value = private_view.balances[seat_of(local_id)]

func player_left(id: String) -> void:
	if session.phase == "bidding":
		session._bids[seat_of(id)] = 0

func _show_item(item: Dictionary) -> void:
	if item_details == null:
		return
	if item.is_empty():
		item_details.text = "开仓后点击物资查看品质、占格和增值"
		return
	item_details.text = "%s · %s · %d × %d 格\n%s\n基础 %d + 羁绊 %d（+%d%%）= %d 金币" % [
		item.name, Catalog.QUALITY_NAMES[int(item.quality)] + "（" + Catalog.QUALITY_COLOR_NAMES[int(item.quality)] + "）", item.size[0], item.size[1],
		" / ".join(item.tags) + (" · 高密度珍品" if item.get("compact_premium", false) else ""), item.value, item.bonus_value, item.bonus_percent, item.effective_value]

## The catalogue contains public definitions only, never the current sealed inventory.
func _open_catalog() -> void:
	if is_instance_valid(encyclopedia):
		encyclopedia.popup_centered(Vector2i(1120, 800))
		return
	encyclopedia = AcceptDialog.new()
	encyclopedia.title = "秘仓竞拍 · 100 种物资图鉴"
	encyclopedia.ok_button_text = "关闭"
	encyclopedia.min_size = Vector2i(800, 600)
	add_child(encyclopedia)
	var content: VBoxContainer = VBoxContainer.new()
	encyclopedia.add_child(content)
	var rule: Label = label(content, Catalog.RULE_TEXT, 20)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.custom_minimum_size = Vector2(1050, 70)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1050, 580)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 24)
	scroll.add_child(grid)
	for item: Dictionary in Catalog.new().items:
		var card: VBoxContainer = VBoxContainer.new()
		card.custom_minimum_size.x = 242
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var icon: TextureRect = TextureRect.new()
		icon.texture = load("res://games/minigame/godot_party_default_auction_master/assets/items/realistic/%s.png" % item.kind)
		icon.custom_minimum_size = Vector2(120, 120)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(icon)
		var title: Label = label(card, item.name, 22)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_color_override("font_color", Catalog.QUALITY_COLORS[int(item.quality)])
		if int(item.quality) == 6:
			var stripe: HBoxContainer = HBoxContainer.new()
			stripe.add_theme_constant_override("separation", 0)
			card.add_child(stripe)
			for tint: Color in Catalog.RAINBOW_COLORS:
				var band: ColorRect = ColorRect.new()
				band.color = tint
				band.custom_minimum_size.y = 3
				band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				stripe.add_child(band)
		var info: Label = label(card, "%s · %d × %d 格\n%d 金币\n%s" % [
			Catalog.QUALITY_NAMES[int(item.quality)] + "（" + Catalog.QUALITY_COLOR_NAMES[int(item.quality)] + "）", item.size[0], item.size[1], item.value, " / ".join(item.tags) + ("\n高密度珍品" if item.get("compact_premium", false) else "")], 16)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	encyclopedia.popup_centered(Vector2i(1120, 800))

