extends "res://games/protocols/godot_party_default_protocol/ranked_round.gd"
## Auction entry owns transport and panels; session owns secrets, rules and settlement.
const WarehouseView: Script = preload("res://games/minigame/gp_auction_master/warehouse_view.gd")
const Session: Script = preload("res://games/minigame/gp_auction_master/session.gd")
const PlayerCard: PackedScene = preload("res://games/minigame/gp_auction_master/player_card.tscn")
const SettlementPanel: Script = preload("res://games/minigame/gp_auction_master/settlement_panel.gd")
const ConditionsPanel: Script = preload("res://games/minigame/gp_auction_master/conditions_panel.gd")
const Catalog: Script = preload("res://games/minigame/gp_auction_master/item_catalog.gd")
const DiscoveryFlash: Script = preload("res://games/minigame/gp_auction_master/discovery_flash.gd")
@export var search_sound: PartyAudioCue
@export var reveal_sounds: Array[PartyAudioCue] = []
const MusicPlaylist: Script = preload("res://games/minigame/gp_auction_master/music_playlist.gd")
const CatalogPanel: Script = preload("res://games/minigame/gp_auction_master/catalog_panel.gd")
@onready var music_playlist: MusicPlaylist = %MusicPlaylist
@onready var catalog_panel: CatalogPanel = %CatalogPanel
@onready var game_audio: PartyGameAudio = %GameAudio
@onready var discovery_flash: DiscoveryFlash = %DiscoveryFlash
var _search_handle: PartyAudioHandle
var _audio_warehouse: int = -1
var _heard_count: int = 0
@onready var warehouse_view: WarehouseView = %Warehouse
@onready var item_details: Label = %ItemDetails
@onready var submit: Button = %Submit
@onready var settlement_panel: SettlementPanel = %SettlementPanel
@onready var operations: PanelContainer = %Operations
@onready var conditions_panel: ConditionsPanel = %ConditionsPanel
@onready var bid_minimum: Label = %BidMinimum
var reviewing_conditions: bool = false
var review_warehouse: int = -1
@onready var warehouse_scroll: ScrollContainer = %WarehouseScroll
@onready var quote: LineEdit = %Quote
@onready var balance_label: Label = %Balance
@onready var player_cards: VBoxContainer = %PlayerCards
@onready var assist_description: Label = %AssistDescription
@onready var countdown: Label = %Countdown
@onready var phase_label: Label = %PhaseLabel
@onready var round_indicator: Label = %RoundIndicator
var assist_colors: Dictionary[String, Color] = {}
@onready var bid_buttons: GridContainer = %BidButtons
@onready var assist_buttons: HBoxContainer = %AssistButtons
var session: Session = Session.new()
var private_view: Dictionary = {}
var public_revision: int = 0
var _published_public: Dictionary = {}
var _published_private: Dictionary = {}
var _private_sequences: Dictionary = {}
var _received_private_sequence: int = 0
var _phase_key: String = ""
var _phase_end_msec: int = 0
var _phase_start_msec: int = 0
var draft_bid: int = 0
var draft_round: String = ""
var sent_draft_key: String = ""
var sent_draft_amount: int = -1
var quote_valid: bool = true
var settlement_item: int = -1

func party_setup(value: PartyAPI, config: Dictionary) -> void:
	super.party_setup(value, config)
	%GameAudio.prepare_scope()

func godot_party_audio_target() -> PartyGameAudio:
	return %GameAudio

func party_stop(reason: StringName) -> void:
	super.party_stop(reason)
	warehouse_view.set_process(false)
	settlement_panel.set_process(false)
	music_playlist.stop()
	game_audio.close_scope()
	discovery_flash.clear()

func build_game() -> void:
	assert(search_sound != null and search_sound.validate() == OK)
	assert(reveal_sounds.size() == 7)
	for cue: PartyAudioCue in reveal_sounds:
		assert(cue != null and cue.validate() == OK)
	warehouse_view.assist_search_changed.connect(_on_assist_search_changed)
	warehouse_view.assist_found.connect(_on_assist_found)
	warehouse_view.reveal_progress.connect(_on_reveal_progress)
	warehouse_view.selection_changed.connect(_show_item)
	%ShowCatalog.pressed.connect(func() -> void:
		if not api.input.input_blocked:
			reviewing_conditions = false
			render_game()
			catalog_panel.open_catalog())
	%ReviewConditions.pressed.connect(func() -> void:
		if not api.input.input_blocked:
			catalog_panel.hide()
			reviewing_conditions = true
			render_game())
	conditions_panel.close_requested.connect(func() -> void:
		if not api.input.input_blocked:
			reviewing_conditions = false
			render_game())
	quote.text_changed.connect(_on_quote_changed)
	quote.focus_exited.connect(_format_quote)
	quote.text_submitted.connect(func(_text: String) -> void: _act("bid"))
	quote.tooltip_text = api.i18n.text(&"bid.input_hint")
	submit.pressed.connect(func() -> void: _act("bid"))
	for button: Button in bid_buttons.get_children():
		var delta: int = int(button.get_meta("delta"))
		button.text = ("+" if delta > 0 else "−") + _format_coins(absi(delta))
		button.pressed.connect(_adjust_bid.bind(delta))
	%Zero.pressed.connect(_reset_bid)
	for button: Button in assist_buttons.get_children():
		var kind: String = button.get_meta("assist")
		assist_colors[kind] = button.get_node("Swatch").self_modulate
		button.mouse_entered.connect(_show_assist_description.bind(kind))
		button.mouse_exited.connect(_clear_assist_description)
		button.focus_entered.connect(_show_assist_description.bind(kind))
		button.focus_exited.connect(_clear_assist_description)
		button.pressed.connect(_act.bind("assist", kind))
	%Zero.tooltip_text = api.i18n.text(&"bid.zero")
	submit.tooltip_text = api.i18n.text(&"hud.submit")
	for player: Dictionary in players:
		player_cards.add_child(PlayerCard.instantiate())
	_show_item({})

## Reveal signals follow the displayed host timeline, including rapid consecutive items.
## Repeated events cannot replay a discovery; no rarity cue plays before it is visible.
func _on_reveal_progress(count: int, total: int) -> void:
	if warehouse_view.warehouse != _audio_warehouse:
		_audio_warehouse = warehouse_view.warehouse
		_heard_count = 0
		game_audio.stop_category(PartyGameAudio.Category.SFX)
		game_audio.stop_category(PartyGameAudio.Category.AMBIENCE)
		_search_handle = null
		discovery_flash.clear()
	if warehouse_view.phase not in ["settlement", "reveal"]:
		return
	for index: int in range(_heard_count, count):
		var quality: int = int(warehouse_view.items[index].quality)
		var handle: PartyAudioHandle = game_audio.play_sfx(reveal_sounds[quality])
		if handle.error != OK:
			_fail_publication("discovery_audio", handle.error)
			return
		var flash_center: Vector2 = settlement_panel.item_box.get_global_rect().position + Vector2(settlement_panel.item_box.size.x * 0.5, settlement_panel.item_icon.custom_minimum_size.y * 0.5)
		discovery_flash.reveal(quality, flash_center)
	_heard_count = count
	if count < total:
		if _search_handle == null:
			_search_handle = game_audio.play_ambience(search_sound, 0.06)
			if _search_handle.error != OK:
				_fail_publication("search_audio", _search_handle.error)
				return
	else:
		_stop_search_sound()

func _on_assist_search_changed(active: bool) -> void:
	if not active:
		_stop_search_sound()
	elif _search_handle == null:
		_search_handle = game_audio.play_ambience(search_sound, 0.06)
		if _search_handle.error != OK:
			_fail_publication("assist_search_audio", _search_handle.error)

func _on_assist_found(item: Dictionary) -> void:
	# Outline/tag discoveries do not carry rarity, so they use a neutral click.
	var quality: int = int(item.get("quality", 0))
	var handle: PartyAudioHandle = game_audio.play_sfx(reveal_sounds[quality])
	if handle.error != OK:
		_fail_publication("assist_found_audio", handle.error)
		return
	if item.has("quality"):
		discovery_flash.reveal(quality, warehouse_scroll.get_global_rect().get_center())

func _stop_search_sound() -> void:
	if _search_handle != null:
		_search_handle.stop(0.12)
		_search_handle = null

func start_game() -> void:
	music_playlist.start()
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
	var maximum: int = int(view.balances[seat_of(local_id)])
	draft_bid = clampi(draft_bid + amount, 0, maximum)
	_show_quote()

func _reset_bid() -> void:
	if api.input.input_blocked or not _can_bid():
		return
	draft_bid = 0
	_show_quote()

## Keep incomplete input editable; only whole-number bids within the balance can be confirmed.
func _on_quote_changed(text: String) -> void:
	if api.input.input_blocked or not _can_bid():
		return
	var digits: String = text.replace(",", "").strip_edges()
	quote_valid = digits.is_valid_int()
	if quote_valid:
		var amount: int = digits.to_int()
		quote_valid = amount >= 0 and amount <= int(view.balances[seat_of(local_id)]) and (amount == 0 or amount >= int(private_view.minimum_bid))
		if quote_valid:
			draft_bid = amount
	if quote_valid:
		quote.remove_theme_color_override("font_color")
	else:
		quote.add_theme_color_override("font_color", Color("f06b72"))
	submit.disabled = not quote_valid
	_sync_draft()

## Send edits before the deadline so the host can commit the last valid current input.
func _sync_draft() -> void:
	var amount: int = draft_bid if quote_valid else 0
	if sent_draft_key == draft_round and sent_draft_amount == amount:
		return
	sent_draft_key = draft_round
	sent_draft_amount = amount
	send_action({"kind": "draft", "amount": amount, "warehouse": private_view.warehouse, "round": private_view.round})

func _format_quote() -> void:
	if _can_bid():
		_on_quote_changed(quote.text)
	if quote_valid:
		quote.text = _format_coins(draft_bid)

func _show_quote() -> void:
	quote_valid = true
	quote.remove_theme_color_override("font_color")
	quote.text = _format_coins(draft_bid)
	if _can_bid():
		_on_quote_changed(quote.text)
	submit.disabled = not _can_bid() or not quote_valid

func _can_bid() -> bool:
	return running and not local_id.is_empty() and not private_view.is_empty() and private_view.phase == "bidding" and _private_matches_phase() and not private_view.bidlocked

func _act(kind: String, assist: String = "") -> void:
	if api.input.input_blocked or private_view.is_empty():
		return
	if kind == "assist" and (private_view.phase != "bidding" or not _private_matches_phase()):
		return
	if kind == "bid":
		if not _can_bid():
			return
		_on_quote_changed(quote.text)
		if not quote_valid:
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
	if data.get("kind") == "draft" and data.get("amount") is int:
		session.update_draft(seat, data.amount, data.warehouse, data.round)
		return
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
	var previous_phase: String = "%d/%d/%s" % [session.warehouse, session.round, session.phase]
	var previous_balances: Array = session.balances.duplicate()
	session.tick(delta)
	if previous_phase != "%d/%d/%s" % [session.warehouse, session.round, session.phase] or previous_balances != session.balances:
		publish()
	if not running:
		return
	if session.phase == "finished":
		var scores: Dictionary = {}
		for index: int in players.size():
			scores[players[index].player_id] = session.balances[index]
		finish_scores(scores, {}, [{"key": "score", "title": api.i18n.text(&"result.coins"), "format": "integer"}])

## Publish only changed public facts and owner-only discoveries. Timelines travel once per phase.
func publish() -> void:
	if not running or not api.is_host():
		return
	var phase_key: String = "%d/%d/%s" % [session.warehouse, session.round, session.phase]
	if phase_key != _phase_key:
		_phase_key = phase_key
		_phase_start_msec = api.net.host_time_msec()
		_phase_end_msec = _phase_start_msec + roundi(session.time * 1000.0)
	var public_data: Dictionary = session.snapshot(-1)
	for key: String in ["time", "reveal_elapsed", "settlement_elapsed", "ownbid", "bidlocked", "assist_available", "intel", "minimum_bid"]:
		public_data.erase(key)
	public_data["phase_end_msec"] = _phase_end_msec
	public_data["phase_start_msec"] = _phase_start_msec
	var changes: Dictionary = _changed_fields(public_data, _published_public)
	if not changes.is_empty():
		public_revision += 1
		changes["revision"] = public_revision
		var error: Error = api.net.broadcast(&"auction/facts", changes)
		if error != OK:
			_fail_publication("facts", error)
			return
		_published_public = public_data.duplicate(true)
	for player: Dictionary in api.get_players():
		if not player.connected:
			continue
		var source: Dictionary = session.snapshot(seat_of(player.player_id))
		var personal: Dictionary = {}
		for key: String in ["warehouse", "round", "phase", "ownbid", "bidlocked", "assist_available", "intel", "minimum_bid"]:
			personal[key] = source[key]
		var private_changes: Dictionary = _changed_fields(personal, _published_private.get(player.player_id, {}))
		if private_changes.is_empty():
			continue
		var private_sequence: int = int(_private_sequences.get(player.player_id, 0)) + 1
		private_changes["revision"] = private_sequence
		var error: Error = api.net.send_to_player(player.player_id, &"auction/private", private_changes)
		if error != OK:
			_fail_publication("private/" + player.player_id, error)
			return
		_private_sequences[player.player_id] = private_sequence
		_published_private[player.player_id] = personal.duplicate(true)

func _changed_fields(current: Dictionary, previous: Dictionary) -> Dictionary:
	var changes: Dictionary = {}
	var removed: Array[String] = []
	var additions: Array = []
	var intel: Dictionary = {}
	for key: String in previous:
		if not current.has(key):
			removed.append(key)
	for key: String in current:
		if previous.has(key) and previous[key] == current[key]:
			continue
		if key == "history" and previous.has(key) and current.history.slice(0, previous.history.size()) == previous.history:
			additions = current.history.slice(previous.history.size())
		elif key in ["intel", "public_intel"] and previous.has(key) and current.warehouse == previous.warehouse:
			var updates: Array = []
			for entry: Dictionary in current[key]:
				var old: Dictionary = {}
				for candidate: Dictionary in previous[key]:
					if candidate.index == entry.index:
						old = candidate
						break
				if entry != old:
					updates.append(entry)
			if not updates.is_empty():
				intel[key] = updates
		else:
			changes[key] = current[key]
	if changes.is_empty() and removed.is_empty() and additions.is_empty() and intel.is_empty():
		return {}
	return {"changes": changes, "removed": removed, "history_added": additions, "intel_updates": intel}

func _apply_changes(target: Dictionary, payload: Dictionary) -> bool:
	if not payload.get("changes") is Dictionary or not payload.get("removed") is Array or not payload.get("history_added") is Array or not payload.get("intel_updates") is Dictionary:
		return false
	for key: Variant in payload.removed:
		if not key is String:
			return false
		target.erase(key)
	for key: String in payload.changes:
		var value: Variant = payload.changes[key]
		if key == "phase":
			if value not in ["briefing", "bidding", "pending", "round_result", "settlement", "reveal", "finished"]:
				return false
		elif key in ["warehouse", "round", "phase_start_msec", "phase_end_msec", "warehouses_total", "rounds_total", "ownbid", "minimum_bid", "early_percent", "winner", "price", "total_value", "base_value", "bonus_value"]:
			if not value is int:
				return false
		elif key in ["bidlocked", "assist_available"]:
			if not value is bool:
				return false
		elif key in ["names", "balances", "clues", "history", "locked", "withdrawn", "intel", "public_intel", "special_rules", "assist_counts", "round_bids", "payouts", "rankings", "payout_seats", "items", "search_ends", "tag_groups"]:
			if not value is Array:
				return false
		elif key == "settlement_seconds":
			if not (value is int or value is float) or not is_finite(float(value)):
				return false
		elif key == "outcome":
			if not value is String:
				return false
		else:
			return false
	target.merge(payload.changes, true)
	if not payload.history_added.is_empty():
		if not target.get("history") is Array:
			return false
		target.history.append_array(payload.history_added)
	for key: String in payload.intel_updates:
		if key not in ["intel", "public_intel"] or not payload.intel_updates[key] is Array or not target.get(key) is Array:
			return false
		for entry: Variant in payload.intel_updates[key]:
			if not entry is Dictionary or not entry.get("index") is int or entry.index < 0:
				return false
			var replaced: bool = false
			for index: int in target[key].size():
				if target[key][index].index == entry.index:
					target[key][index] = entry
					replaced = true
					break
			if not replaced:
				target[key].append(entry)
	return true

func _message(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	if topic not in [&"auction/facts", &"auction/private"]:
		super._message(sender, topic, payload)
		return
	if not running or sender.peer_id != 1 or not payload is Dictionary or not payload.get("changes") is Dictionary:
		return
	if topic == &"auction/facts":
		if not payload.get("revision") is int or payload.revision <= received_sequence:
			return
		if not _apply_changes(view, payload):
			_fail_publication("invalid_facts", ERR_INVALID_DATA)
			return
		received_sequence = payload.revision
		view["_sequence"] = received_sequence
	else:
		if not payload.get("revision") is int or payload.revision <= _received_private_sequence:
			return
		if not _apply_changes(private_view, payload):
			_fail_publication("invalid_private", ERR_INVALID_DATA)
			return
		_received_private_sequence = payload.revision
	render_game()

func _private_matches_phase() -> bool:
	return not view.is_empty() and not private_view.is_empty() and private_view.warehouse == view.warehouse and private_view.round == view.round and private_view.phase == view.phase

func _fail_publication(stream: String, error: Error) -> void:
	party_stop(&"publication_failed")
	var message: String = "Auction publication %s: %s" % [stream, error_string(error)]
	var failure_error: Error = api.fail("publication_failed", message)
	if failure_error != OK:
		push_error("%s; failure report: %s" % [message, error_string(failure_error)])

func render_game() -> void:
	var snap: Dictionary = view.duplicate(true)
	if snap.is_empty():
		return
	if _private_matches_phase():
		snap.merge(private_view, true)
	else:
		snap["minimum_bid"] = 0
	var now: int = api.net.host_time_msec()
	snap["time"] = maxf(0.0, float(snap.phase_end_msec - now) / 1000.0)
	var phase_elapsed: float = maxf(0.0, float(now - snap.phase_start_msec) / 1000.0)
	snap["reveal_elapsed"] = phase_elapsed if snap.phase in ["settlement", "reveal"] else 0.0
	snap["settlement_elapsed"] = minf(phase_elapsed, float(snap.settlement_seconds)) if snap.phase == "settlement" else 0.0
	var intel: Array = private_view.intel if not local_id.is_empty() and not private_view.is_empty() and private_view.warehouse == snap.warehouse else snap.public_intel
	warehouse_view.set_snapshot(snap, intel, not local_id.is_empty())
	warehouse_view.set_reveal_elapsed(float(snap.reveal_elapsed))
	if warehouse_view.is_assist_searching():
		warehouse_scroll.scroll_vertical = int(maxf(0.0, warehouse_view.get_assist_rect().get_center().y - warehouse_scroll.size.y * 0.5))
	var settling: bool = snap.phase == "settlement"
	if snap.phase not in ["settlement", "reveal"] and not warehouse_view.is_assist_searching():
		_stop_search_sound()
	if review_warehouse != int(snap.warehouse):
		review_warehouse = int(snap.warehouse)
		catalog_panel.hide()
		reviewing_conditions = true
	conditions_panel.visible = reviewing_conditions
	if conditions_panel.visible:
		conditions_panel.set_snapshot(snap)
	operations.visible = not settling
	settlement_panel.visible = settling
	bid_minimum.text = "本轮可报 0，或至少 " + _format_coins(int(snap.minimum_bid)) if int(snap.minimum_bid) > 1 else ""
	if settling:
		settlement_panel.set_snapshot(snap)
		var index: int = mini(warehouse_view.revealed_count, warehouse_view.items.size() - 1)
		if index >= 0 and warehouse_view.revealed_count != settlement_item:
			settlement_item = warehouse_view.revealed_count
			warehouse_view.select_item(warehouse_view.revealed_count - 1)
			var rect: Rect2 = warehouse_view.get_item_rect(index)
			warehouse_scroll.scroll_vertical = int(maxf(0.0, rect.get_center().y - warehouse_scroll.size.y * 0.5))
	else:
		settlement_item = -1
	var round_key: String = "%d/%d" % [snap.warehouse, snap.round]
	if round_key != draft_round:
		draft_round = round_key
		draft_bid = 0
		_show_quote()
	if not private_view.is_empty() and private_view.bidlocked:
		draft_bid = private_view.ownbid
		_show_quote()
	balance_label.text = api.i18n.text(&"bid.balance", {"amount": _format_coins(int(snap.balances[seat_of(local_id)]))}) if not local_id.is_empty() else api.i18n.text(&"hud.spectating")
	var can_bid: bool = _can_bid()
	var editable: bool = can_bid and not api.input.input_blocked
	if quote.editable != editable:
		quote.editable = editable
	for button: Button in bid_buttons.get_children():
		button.disabled = not can_bid
	%Zero.disabled = not can_bid
	submit.disabled = not can_bid or not quote_valid
	for button: Button in assist_buttons.get_children():
		button.disabled = not running or local_id.is_empty() or private_view.is_empty() or snap.phase != "bidding" or not _private_matches_phase() or not private_view.assist_available
	var phase_names: Dictionary[String, StringName] = {
		"briefing": &"hud.phase_rules",
		"bidding": &"hud.phase_bid",
		"pending": &"hud.phase_bid",
		"round_result": &"hud.phase_result",
		"settlement": &"hud.phase_reveal",
		"reveal": &"hud.phase_reveal",
		"finished": &"hud.phase_result",
	}
	phase_label.text = api.i18n.text(phase_names[snap.phase])
	countdown.text = _format_coins(ceili(snap.time))
	countdown.add_theme_color_override("font_color", Color("f06b72") if float(snap.time) <= 10.0 else Color("f4f1e8"))
	round_indicator.text = api.i18n.text(&"hud.round_indicator", {"current": _format_coins(int(snap.round)), "total": _format_coins(int(snap.rounds_total))})
	_render_player_cards(snap)

func _render_player_cards(snap: Dictionary) -> void:
	for seat: int in players.size():
		var amount: int = -1
		var result_key: String = ""
		var kinds: Array[String] = []
		kinds.resize(int(snap.rounds_total))
		kinds.fill("")
		for record: Dictionary in snap.history:
			if record.warehouse == snap.warehouse:
				amount = int(record.bids[seat])
				result_key = "%s:%s" % [record.warehouse, record.round]
				kinds[int(record.round) - 1] = record.assists[seat]
		var colors: Array[Color] = []
		for kind: String in kinds:
			colors.append(Color.TRANSPARENT if kind.is_empty() else assist_colors[kind])
		player_cards.get_child(seat).set_view(players[seat].name, amount, colors, snap.withdrawn[seat], result_key, snap.phase == "round_result" and snap.outcome.is_empty())

func _format_coins(value: int) -> String:
	var digits: String = str(absi(value))
	var result: String = ""
	for index: int in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits[index]
	return ("−" if value < 0 else "") + result

func _show_assist_description(kind: String) -> void:
	if private_view.is_empty():
		return
	var index: int = Session.ASSISTS.find(kind)
	assist_description.text = "揭示 %s 件物品的%s" % [_format_coins(int(view.assist_counts[index])), ["完整信息", "轮廓", "品质", "羁绊标签"][index]]

func _clear_assist_description() -> void:
	assist_description.text = ""

func player_left(id: String) -> void:
	session.withdraw_player(seat_of(id))
	publish()

func _show_item(item: Dictionary) -> void:
	if item_details == null:
		return
	item_details.visible = not item.is_empty()
	if item.is_empty():
		item_details.text = ""
	elif item.has("effective_value"):
		item_details.text = api.i18n.text(&"hud.item_details", {"name": item.name, "quality": _quality_caption(int(item.quality)), "width": item.size[0], "height": item.size[1], "tags": _tag_caption(item, &"hud.premium_tags"), "base": _format_coins(int(item.value)), "bonus": _format_coins(int(item.bonus_value)), "percent": _format_coins(int(item.bonus_percent)), "total": _format_coins(int(item.effective_value))})
	else:
		item_details.text = warehouse_view.describe_item(item)

func _quality_caption(quality: int) -> String:
	return api.i18n.text(&"hud.quality", {"name": Catalog.QUALITY_NAMES[quality], "color": Catalog.QUALITY_COLOR_NAMES[quality]})

func _tag_caption(item: Dictionary, premium_key: StringName) -> String:
	var tags: String = " / ".join(item.tags)
	return api.i18n.text(premium_key, {"tags": tags}) if item.get("compact_premium", false) else tags
