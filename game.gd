extends "res://games/protocols/godot_party_default_protocol/ranked_round.gd"
## Auction entry owns transport and panels; session owns secrets, rules and settlement.
const WarehouseView: Script = preload("res://games/minigame/godot_party_default_auction_master/warehouse_view.gd")
const Session: Script = preload("res://games/minigame/godot_party_default_auction_master/session.gd")
const CatalogItem: PackedScene = preload("res://games/minigame/godot_party_default_auction_master/catalog_item.tscn")
const PlayerCard: PackedScene = preload("res://games/minigame/godot_party_default_auction_master/player_card.tscn")
const Catalog: Script = preload("res://games/minigame/godot_party_default_auction_master/item_catalog.gd")
@onready var warehouse_view: WarehouseView = %Warehouse
@onready var item_details: Label = %ItemDetails
@onready var valuation: Label = %Valuation
@onready var encyclopedia: AcceptDialog = %Encyclopedia
@onready var submit: Button = %Submit
@onready var quote: Label = %Quote
@onready var balance_label: Label = %Balance
@onready var player_cards: VBoxContainer = %PlayerCards
@onready var assist_description: Label = %AssistDescription
@onready var countdown: Label = %Countdown
@onready var round_indicator: Label = %RoundIndicator
var assist_colors: Dictionary[String, Color] = {}
@onready var bid_buttons: GridContainer = %BidButtons
@onready var assist_buttons: HBoxContainer = %AssistButtons
var session: Session = Session.new()
var private_view: Dictionary = {}
var public_revision: int = 0
var private_revision: int = -1
var draft_bid: int = 0
var draft_round: String = ""

func build_game() -> void:
	warehouse_view.selection_changed.connect(_show_item)
	submit.pressed.connect(func() -> void: _act("bid"))
	for button: Button in bid_buttons.get_children():
		button.pressed.connect(_adjust_bid.bind(int(button.get_meta("delta"))))
	%Zero.pressed.connect(_reset_bid)
	for button: Button in assist_buttons.get_children():
		var kind: String = button.get_meta("assist")
		assist_colors[kind] = button.get_node("Swatch").self_modulate
		button.mouse_entered.connect(_show_assist_description.bind(kind))
		button.mouse_exited.connect(_clear_assist_description)
		button.focus_entered.connect(_show_assist_description.bind(kind))
		button.focus_exited.connect(_clear_assist_description)
		button.pressed.connect(_act.bind("assist", kind))
	%OpenCatalog.pressed.connect(_open_catalog)
	%CatalogRules.text = api.i18n.text(&"rules.auction") + "\n" + Catalog.RULE_TEXT
	%OpenCatalog.text = api.i18n.text(&"hud.catalog_button")
	%Zero.text = api.i18n.text(&"bid.zero")
	%AssistTitle.text = api.i18n.text(&"assist.title")
	%BidTitle.text = api.i18n.text(&"bid.title")
	submit.text = api.i18n.text(&"hud.submit")
	encyclopedia.title = api.i18n.text(&"catalog.title")
	encyclopedia.ok_button_text = api.i18n.text(&"catalog.close")
	for player: Dictionary in players:
		player_cards.add_child(PlayerCard.instantiate())
	_show_item({})

func start_game() -> void:
	if not api.is_host():
		return
	session.names.clear()
	for player: Dictionary in players:
		session.names.append(player.name)
	var error: Error = session.rules.configure(settings)
	if error != OK:
		_fail_publication("room_rules", error)
		return
	session.start()

func _adjust_bid(amount: int) -> void:
	if api.input.input_blocked or not _can_bid():
		return
	var maximum: int = int(private_view.balances[seat_of(local_id)]) / 100 * 100
	draft_bid = clampi(draft_bid + amount, 0, maximum)
	quote.text = api.i18n.text(&"bid.amount", {"amount": draft_bid})

func _reset_bid() -> void:
	if api.input.input_blocked or not _can_bid():
		return
	draft_bid = 0
	quote.text = api.i18n.text(&"bid.amount", {"amount": draft_bid})

func _can_bid() -> bool:
	return running and not local_id.is_empty() and not private_view.is_empty() and private_view.phase == "bidding" and not private_view.bidlocked

func _act(kind: String, assist: String = "") -> void:
	if api.input.input_blocked or private_view.is_empty():
		return
	send_action({"kind": kind, "amount": draft_bid, "assist": assist, "warehouse": private_view.warehouse, "round": private_view.round})

func send_action(data: Dictionary) -> void:
	if not running or local_id.is_empty():
		return
	sequence += 1
	data["seq"] = sequence
	var error: Error = api.net.send_to_host(&"action", data)
	if error != OK:
		_fail_publication("action", error)

func handle_action(id: String, data: Dictionary) -> void:
	if not data.get("warehouse") is int or not data.get("round") is int or data.warehouse != session.warehouse or data.round != session.round:
		return
	var seat: int = seat_of(id)
	if data.get("kind") == "bid" and data.get("amount") is int:
		session.submit_bid(seat, data.amount, data.warehouse, data.round)
	elif data.get("kind") == "assist" and data.get("assist") is String:
		session.use_assist(seat, data.assist)
	publish()

func seat_of(id: String) -> int:
	for index: int in players.size():
		if players[index].player_id == id:
			return index
	return -1

func tick_game(delta: float) -> void:
	if not api.is_host():
		return
	var minimum_players: int = 1 if players.size() == 1 else 2
	if players.size() - disconnected.size() < minimum_players:
		finish_rows([], [], "cancelled")
		return
	session.tick(delta)
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
	public_view["_sequence"] = public_revision
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
	return public_view


func receive_private(data: Dictionary) -> void:
	if int(data.get("revision", -1)) <= private_revision:
		return
	private_revision = data.revision
	private_view = data
	render_game()

func render_game() -> void:
	var snap: Dictionary = private_view if not local_id.is_empty() and private_revision >= int(view.get("_sequence", 0)) else view
	if snap.is_empty():
		return
	var intel: Array = private_view.intel if not local_id.is_empty() and not private_view.is_empty() and private_view.warehouse == snap.warehouse else []
	warehouse_view.set_snapshot(snap, intel)
	warehouse_view.set_reveal_elapsed(float(snap.reveal_elapsed))
	var round_key: String = "%d/%d" % [snap.warehouse, snap.round]
	if round_key != draft_round:
		draft_round = round_key
		draft_bid = 0
	if not private_view.is_empty() and private_view.bidlocked:
		draft_bid = private_view.ownbid
	quote.text = api.i18n.text(&"bid.amount", {"amount": draft_bid})
	balance_label.text = api.i18n.text(&"bid.balance", {"amount": snap.balances[seat_of(local_id)]}) if not local_id.is_empty() else api.i18n.text(&"hud.spectating")
	var can_bid: bool = _can_bid()
	for button: Button in bid_buttons.get_children():
		button.disabled = not can_bid
	%Zero.disabled = not can_bid
	submit.disabled = not can_bid
	for button: Button in assist_buttons.get_children():
		button.disabled = not running or local_id.is_empty() or private_view.is_empty() or not private_view.assist_available
	valuation.text = api.i18n.text(&"hud.valuation", {"base": snap.base_value, "bonus": snap.bonus_value, "total": snap.total_value}) if snap.phase in ["reveal", "finished"] else api.i18n.text(&"hud.sealed")
	countdown.text = str(ceili(snap.time))
	countdown.add_theme_color_override("font_color", Color("f06b72") if float(snap.time) <= 10.0 else Color("f4f1e8"))
	round_indicator.text = api.i18n.text(&"hud.round_indicator", {"current": snap.round, "total": snap.rounds_total})
	_render_player_cards(snap)

func _render_player_cards(snap: Dictionary) -> void:
	for seat: int in players.size():
		var amount: String = "—"
		var kinds: Array[String] = []
		kinds.resize(int(snap.rounds_total))
		kinds.fill("")
		for record: Dictionary in snap.history:
			if record.warehouse == snap.warehouse:
				amount = _format_coins(int(record.bids[seat]))
				kinds[int(record.round) - 1] = record.assists[seat]
		kinds[int(snap.round) - 1] = snap.assists[seat]
		var colors: Array[Color] = []
		for kind: String in kinds:
			colors.append(Color.TRANSPARENT if kind.is_empty() else assist_colors[kind])
		player_cards.get_child(seat).set_view(players[seat].name, amount, colors, snap.withdrawn[seat])

func _format_coins(value: int) -> String:
	var digits: String = str(value)
	var result: String = ""
	for index: int in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits[index]
	return result

func _show_assist_description(kind: String) -> void:
	assist_description.text = api.i18n.text(StringName("assist.description." + kind))

func _clear_assist_description() -> void:
	assist_description.text = ""

func player_left(id: String) -> void:
	session.withdraw_player(seat_of(id))

func _show_item(item: Dictionary) -> void:
	if item_details == null:
		return
	item_details.visible = not item.is_empty()
	if item.is_empty():
		item_details.text = ""
	elif item.has("effective_value"):
		item_details.text = api.i18n.text(&"hud.item_details", {"name": item.name, "quality": _quality_caption(int(item.quality)), "width": item.size[0], "height": item.size[1], "tags": _tag_caption(item, &"hud.premium_tags"), "base": item.value, "bonus": item.bonus_value, "percent": item.bonus_percent, "total": item.effective_value})
	else:
		item_details.text = warehouse_view.describe_item(item)

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
