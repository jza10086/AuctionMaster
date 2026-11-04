extends "res://games/protocols/godot_party_default_protocol/ranked_round.gd"
## Sealed auction. The random inventory and private appraisals never enter public snapshots.
const Session: Script = preload("res://games/minigame/godot_party_default_auction_master/session.gd")
const CatalogItem: PackedScene = preload("res://games/minigame/godot_party_default_auction_master/catalog_item.tscn")
const Catalog: Script = preload("res://games/minigame/godot_party_default_auction_master/item_catalog.gd")
@onready var item_details: Label = %ItemDetails
@onready var valuation: Label = %Valuation
@onready var encyclopedia: AcceptDialog = %Encyclopedia
var session: RefCounted = Session.new()
@onready var warehouse_view: Control = %Warehouse
var private_view: Dictionary = {}
@onready var bid: SpinBox = %Bid
@onready var submit: Button = %Submit
@onready var appraisal: Button = %Appraise
@onready var private_label: Label = %PrivateNote
@onready var clues: Label = %Clues
var transition: float = 0.0
var previous_phase: String = ""
var public_revision: int = 0
var private_revision: int = -1

func build_game() -> void:
	warehouse_view.selection_changed.connect(_show_item)
	submit.pressed.connect(func() -> void: _act("bid"))
	appraisal.pressed.connect(func() -> void: _act("appraise"))
	%OpenCatalog.pressed.connect(_open_catalog)
	%CatalogRules.text = Catalog.RULE_TEXT
	clues.text = ""

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
	if not api.input.input_blocked and not private_view.is_empty():
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
		valuation.text = api.i18n.text(&"hud.valuation", {"base": view.base_value, "bonus": view.bonus_value, "total": view.total_value})
	else:
		valuation.text = "封仓期间不显示物资、tag 或羁绊"
	status.text = api.i18n.text(&"hud.clock", {"current": int(view.warehouse) + 1, "total": view.warehouses_total, "round": view.round, "time": ceili(view.time), "phase": {"bidding": "密封报价", "round_result": "本轮报价公布", "reveal": "开仓揭晓", "finished": "竞拍结束"}.get(view.phase, "等待")})
	for index: int in players.size():
		var revealed_bid: String = " · 报价 %d" % int(view.round_bids[index]) if view.round_bids.size() == players.size() else (" · 已锁定" if view.locked[index] else " · 思考中")
		update_standing(players[index].player_id, api.i18n.text(&"hud.player", {"player": players[index].name, "balance": view.balances[index], "bid": revealed_bid}))
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
	var grid: GridContainer = %CatalogGrid
	if grid.get_child_count() > 0:
		encyclopedia.popup_centered(Vector2i(1120, 800))
		return
	for item: Dictionary in Catalog.new().items:
		var card: VBoxContainer = CatalogItem.instantiate()
		grid.add_child(card)
		card.get_node("Icon").texture = load("res://games/minigame/godot_party_default_auction_master/assets/items/realistic/%s.png" % item.kind)
		var title: Label = card.get_node("Title")
		title.text = item.name
		title.add_theme_color_override("font_color", Catalog.QUALITY_COLORS[int(item.quality)])
		if int(item.quality) == 6:
			var stripe: HBoxContainer = card.get_node("Stripe")
			stripe.show()
			for tint: Color in Catalog.RAINBOW_COLORS:
				var band: ColorRect = ColorRect.new()
				band.color = tint
				band.custom_minimum_size.y = 3
				band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				stripe.add_child(band)
		var info: Label = card.get_node("Info")
		info.text = api.i18n.text(&"hud.item", {"quality": Catalog.QUALITY_NAMES[int(item.quality)] + "（" + Catalog.QUALITY_COLOR_NAMES[int(item.quality)] + "）", "width": item.size[0], "height": item.size[1], "value": item.value, "tags": " / ".join(item.tags) + ("\n高密度珍品" if item.get("compact_premium", false) else "")})
	encyclopedia.popup_centered(Vector2i(1120, 800))

