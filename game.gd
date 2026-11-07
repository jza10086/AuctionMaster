extends "res://games/protocols/godot_party_default_protocol/ranked_round.gd"
## Sealed auction. The random inventory and private appraisals never enter public snapshots.
const WarehouseView: Script = preload("res://games/minigame/godot_party_default_auction_master/warehouse_view.gd")
const Session: Script = preload("res://games/minigame/godot_party_default_auction_master/session.gd")
const CatalogItem: PackedScene = preload("res://games/minigame/godot_party_default_auction_master/catalog_item.tscn")
const Catalog: Script = preload("res://games/minigame/godot_party_default_auction_master/item_catalog.gd")
@onready var item_details: Label = %ItemDetails
@onready var valuation: Label = %Valuation
@onready var encyclopedia: AcceptDialog = %Encyclopedia
var session: Session = Session.new()
@onready var warehouse_view: WarehouseView = %Warehouse
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
	%CatalogRules.text = api.i18n.text(&"rules.auction") + "\n" + Catalog.RULE_TEXT
	clues.text = ""
	%OpenCatalog.text = api.i18n.text(&"hud.catalog_button")
	submit.text = api.i18n.text(&"hud.submit")
	appraisal.text = api.i18n.text(&"hud.appraise")
	encyclopedia.title = api.i18n.text(&"catalog.title")
	encyclopedia.ok_button_text = api.i18n.text(&"catalog.close")
	_show_item({})

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
	# Only a round that started solo uses the single-player testing threshold.
	var minimum_players: int = 1 if players.size() == 1 else 2
	if players.size() - disconnected.size() < minimum_players:
		finish_rows([], [], "cancelled")
		return
	for id: String in disconnected:
		session.withdraw_player(seat_of(id))
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
		finish_scores(scores, {}, [{"key": "score", "title": api.i18n.text(&"result.coins"), "format": "integer"}])

## Private deliveries must succeed before the corresponding public state is broadcast.
## A failed send cancels this round; no partial publication is retried.
func publish() -> void:
	if not running or not api.is_host():
		return
	public_revision += 1
	for player: Dictionary in api.get_players():
		if player.connected:
			var snap: Dictionary = session.snapshot(seat_of(player.player_id))
			snap["revision"] = public_revision
			var error: Error = api.net.send_to_player(player.player_id, &"private_view", snap)
			if error != OK:
				_fail_publication("private_view/" + player.player_id, error)
				return
	var public_view: Dictionary = make_snapshot()
	public_view["_sequence"] = int(elapsed * 1000000)
	var error: Error = api.net.broadcast_stream(&"state", public_view)
	if error != OK:
		_fail_publication("state", error)

func _fail_publication(stream: String, error: Error) -> void:
	party_stop(&"snapshot_failed")
	var message: String = "Auction snapshot %s: %s" % [stream, error_string(error)]
	var failure_error: Error = api.fail("snapshot_failed", message)
	if failure_error != OK:
		push_error("%s; failure report: %s" % [message, error_string(failure_error)])

func make_snapshot() -> Dictionary:
	var public_view: Dictionary = session.snapshot(-1)
	public_view["reveal_elapsed"] = transition if session.phase == "reveal" else 0.0
	public_view["locked"] = session.get_locked_bids()
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
	warehouse_view.set_reveal_elapsed(float(view.reveal_elapsed))
	if view.phase in ["reveal", "finished"]:
		valuation.text = api.i18n.text(&"hud.valuation", {"base": view.base_value, "bonus": view.bonus_value, "total": view.total_value})
	else:
		valuation.text = api.i18n.text(&"hud.sealed")
	var round_caption: String = api.i18n.text(&"hud.overtime", {"number": int(view.round) - int(view.rounds_total)}) if int(view.round) > int(view.rounds_total) else api.i18n.text(&"hud.regular_round", {"number": view.round, "total": view.rounds_total})
	status.text = api.i18n.text(&"hud.clock", {"current": int(view.warehouse) + 1, "total": view.warehouses_total, "round": round_caption, "time": ceili(view.time), "phase": api.i18n.text(StringName("phase." + str(view.phase)))})
	if players.size() == 1:
		status.text = api.i18n.text(&"hud.solo_status", {"mode": api.i18n.text(&"hud.solo"), "status": status.text})
	for index: int in players.size():
		var revealed_bid: String = api.i18n.text(&"hud.bid_revealed", {"amount": view.round_bids[index]}) if view.round_bids.size() == players.size() else api.i18n.text(&"hud.bid_locked" if view.locked[index] else &"hud.bid_thinking")
		if view.withdrawn[index]:
			revealed_bid += api.i18n.text(&"hud.withdrawn")
		elif int(view.round) > int(view.rounds_total) and not view.eligible[index]:
			revealed_bid = api.i18n.text(&"hud.watching")
		update_standing(players[index].player_id, api.i18n.text(&"hud.player", {"player": players[index].name, "balance": view.balances[index], "bid": revealed_bid}))
	clues.text = "\n".join(view.clues)
	if view.phase in ["bidding", "round_result"] and (int(view.round) > int(view.rounds_total) or view.outcome == "tie"):
		var contender_names: PackedStringArray = []
		for seat: int in players.size():
			if view.eligible[seat]:
				contender_names.append(players[seat].name)
		clues.text += "\n" + api.i18n.text(&"hud.contenders", {"players": "、".join(contender_names), "minimum": view.minimum_bid})
	if view.phase in ["reveal", "finished"]:
		footer.text = api.i18n.text(&"hud.reveal_rule")
	elif int(view.early_percent) > 0:
		footer.text = api.i18n.text(&"hud.early_rule", {"percent": view.early_percent})
	elif int(view.round) > int(view.rounds_total):
		footer.text = api.i18n.text(&"hud.overtime_rule", {"minimum": view.minimum_bid})
	else:
		footer.text = api.i18n.text(&"hud.final_rule")
	if view.phase in ["reveal", "finished"]:
		clues.text += "\n" + (api.i18n.text(&"hud.unsold") if int(view.winner) < 0 else api.i18n.text(&"hud.sale", {"player": players[int(view.winner)].name, "price": view.price, "total": view.total_value}))
		if int(view.winner) >= 0:
			clues.text += "\n" + api.i18n.text(&"hud.sale_profit", {"reason": api.i18n.text(StringName("outcome." + str(view.outcome))), "profit": int(view.total_value) - int(view.price)})
		var tag_lines: PackedStringArray = []
		for group: Dictionary in view.tag_groups:
			var bonus: String = api.i18n.text(&"hud.synergy_bonus", {"percent": group.percent}) if group.percent > 0 else api.i18n.text(&"hud.synergy_inactive")
			tag_lines.append(api.i18n.text(&"hud.synergy_group", {"tag": group.tag, "count": group.count, "bonus": bonus}))
		clues.text += "\n" + api.i18n.text(&"hud.synergies", {"groups": " / ".join(tag_lines)})
	var can_bid: bool = not local_id.is_empty() and not private_view.is_empty() and private_view.phase == "bidding" and not private_view.bidlocked
	if not local_id.is_empty() and not private_view.is_empty():
		bid.max_value = private_view.balances[seat_of(local_id)]
	var valid_amount: bool = int(bid.value) == 0 or int(bid.value) >= int(private_view.get("minimum_bid", 1))
	submit.disabled = not can_bid or not valid_amount
	bid.editable = can_bid
	appraisal.disabled = local_id.is_empty() or not private_view.get("skill_available", false)
	private_label.text = private_view.get("skilltext", "") if not local_id.is_empty() else api.i18n.text(&"hud.spectating")

func player_left(id: String) -> void:
	session.withdraw_player(seat_of(id))

func _show_item(item: Dictionary) -> void:
	if item_details == null:
		return
	if item.is_empty():
		item_details.text = api.i18n.text(&"hud.item_hint")
		return
	item_details.text = api.i18n.text(&"hud.item_details", {
		"name": item.name, "quality": _quality_caption(int(item.quality)),
		"width": item.size[0], "height": item.size[1],
		"tags": _tag_caption(item, &"hud.premium_tags"),
		"base": item.value, "bonus": item.bonus_value, "percent": item.bonus_percent, "total": item.effective_value,
	})

func _quality_caption(quality: int) -> String:
	return api.i18n.text(&"hud.quality", {"name": Catalog.QUALITY_NAMES[quality], "color": Catalog.QUALITY_COLOR_NAMES[quality]})

func _tag_caption(item: Dictionary, premium_key: StringName) -> String:
	var tags: String = " / ".join(item.tags)
	return api.i18n.text(premium_key, {"tags": tags}) if item.get("compact_premium", false) else tags

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
		card.get_node("Stripe").visible = int(item.quality) == 6
		var info: Label = card.get_node("Info")
		info.text = api.i18n.text(&"hud.item", {"quality": _quality_caption(int(item.quality)), "width": item.size[0], "height": item.size[1], "value": item.value, "tags": _tag_caption(item, &"hud.catalog_premium_tags")})
	encyclopedia.popup_centered(Vector2i(1120, 800))
