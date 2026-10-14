extends Node
const Session = preload("res://scripts/session.gd")
const WarehouseView = preload("res://scripts/warehouse_view.gd")
const INK = Color("e5e9ea")
const MUTED = Color("83939e")
const GOLD = Color("d5be8d")
const MINT = Color("a5c8be")
var game
var view
var ui: Control
var overlay: Control
var overlay_panel: PanelContainer
var body: VBoxContainer
var title_label: Label
var sub_label: Label
var phase_label: Label
var timer_label: Label
var clue_label: Label
var private_label: Label
var history_label: Label
var status_label: Label
var bid_input: LineEdit
var commit_button: Button
var pass_button: Button
var skill_button: Button
var next_button: Button
var bidder_labels: Array[Label] = []
var bidder_bids: Array[Label] = []
var intel_title: Label
var grid_note: Label
var bid_fields: Array[Control] = []
var settlement_summary: HBoxContainer
var settlement_values: Array[Label] = []
var detail_title: Label
var detail_text: Label
var storage_label: Label
var skip_button: Button
var adjust_buttons: Array[Button] = []
var phase_action_unlock_msec: int = 0
var double_click_frame: int = -1
var paused := false
var started := false
var last_phase := ""
var last_warehouse := -1
var overlay_mode := "menu"
var timer_seconds := 30
var displayed_items := false
var stage_caption: Label

func style(bg: Color, border := Color("354049"), radius := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=bg
	s.border_color=border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left=16
	s.content_margin_right=16
	s.content_margin_top=14
	s.content_margin_bottom=14
	return s

func label(text: String, size := 20, color := INK) -> Label:
	var l := Label.new()
	l.text=text
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	return l

func button(text: String, callback: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text=text
	b.custom_minimum_size=Vector2(0,48)
	b.add_theme_font_size_override("font_size",19)
	b.add_theme_stylebox_override("normal",style(Color("d6b56d") if primary else Color("273139"),Color("e8c883") if primary else Color("4a555e"),3))
	b.add_theme_stylebox_override("hover",style(Color("ecd398") if primary else Color("35444e"),GOLD,3))
	b.add_theme_stylebox_override("pressed",style(Color("ad9054") if primary else Color("172d39"),GOLD,3))
	b.add_theme_stylebox_override("disabled",style(Color("23313a"),Color("35434d"),3))
	for state in ["normal","hover","pressed","disabled"]:
		var box := b.get_theme_stylebox(state)
		box.content_margin_top=8
		box.content_margin_bottom=8
	b.add_theme_color_override("font_color",Color("182b35") if primary else INK)
	b.add_theme_color_override("font_hover_color",Color("182b35") if primary else INK)
	b.pressed.connect(callback)
	return b

func panel(pos: Vector2, size: Vector2, parent: Node = null) -> VBoxContainer:
	var p := PanelContainer.new()
	p.position=pos
	p.size=size
	p.add_theme_stylebox_override("panel",style(Color("151c22")))
	(parent if parent else ui).add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",10)
	p.add_child(v)
	return v

func _ready() -> void:
	DisplayServer.window_set_title.call_deferred("秘仓竞拍")
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui=Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(ui)
	var theme := Theme.new()
	theme.default_font=load("res://assets/fonts/NotoSansCJK.ttc")
	theme.default_font_size=18
	ui.theme=theme
	build_hud()
	build_overlay()
	show_menu()

func build_hud() -> void:
	var bg := ColorRect.new()
	bg.color=Color("0c1116")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)
	var top := panel(Vector2(24,20),Vector2(1392,76))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	top.add_child(row)
	title_label=label("秘仓竞拍",26,INK)
	title_label.custom_minimum_size.x=208
	row.add_child(title_label)
	phase_label=label("仓库拍卖",20,GOLD)
	phase_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(phase_label)
	timer_label=label("30 秒",25,MINT)
	timer_label.custom_minimum_size.x=105
	row.add_child(timer_label)
	row.add_child(button("规则",func(): show_help()))
	row.add_child(button("暂停",func(): show_pause()))
	var left := panel(Vector2(24,116),Vector2(214,600))
	left.add_theme_constant_override("separation",4)
	left.add_child(label("竞拍者  /  4",17,MUTED))
	for i in 4:
		var spacer := Control.new()
		spacer.custom_minimum_size.y=5
		left.add_child(spacer)
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation",10)
		left.add_child(title_row)
		var avatar := PanelContainer.new()
		avatar.custom_minimum_size=Vector2(36,36)
		var avatar_style := style(Color("35453f") if i==0 else Color("28333c"),Color("53665c") if i==0 else Color("46535c"),2)
		avatar_style.content_margin_left=0
		avatar_style.content_margin_right=0
		avatar_style.content_margin_top=0
		avatar_style.content_margin_bottom=0
		avatar.add_theme_stylebox_override("panel",avatar_style)
		var monogram := label(["鉴","陈","林","周"][i],15,MINT if i==0 else MUTED)
		monogram.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		avatar.add_child(monogram)
		title_row.add_child(avatar)
		title_row.add_child(label(["你 · 鉴定师","算盘陈","眼力林","胆大周"][i],17,INK))
		var cash := label("10,000",26,GOLD if i==0 else INK)
		left.add_child(cash)
		bidder_labels.append(cash)
		var bid := label("等待报价",13,MUTED)
		left.add_child(bid)
		bidder_bids.append(bid)
		left.add_child(HSeparator.new())
	left.add_child(label("资金单位：金币",12,MUTED))
	var head := panel(Vector2(258,116),Vector2(812,66))
	var head_row := HBoxContainer.new()
	head.add_child(head_row)
	stage_caption=label("封存仓库",20,INK)
	stage_caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	head_row.add_child(stage_caption)
	storage_label=label("容量  10 × 6  /  内容未知",13,MUTED)
	head_row.add_child(storage_label)
	view=WarehouseView.new()
	view.position=Vector2(264,194)
	view.size=Vector2(800,480)
	ui.add_child(view)
	view.selection_changed.connect(show_item_details)
	view.reveal_progress.connect(update_reveal_progress)
	var grid_footer := HBoxContainer.new()
	grid_footer.position=Vector2(266,686)
	grid_footer.size=Vector2(798,40)
	ui.add_child(grid_footer)
	grid_note=label("封存货物仅在第五轮成交后开启",14,MUTED)
	grid_note.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid_footer.add_child(grid_note)
	skip_button=button("完成搜索",func(): skip_reveal())
	skip_button.custom_minimum_size=Vector2(126,36)
	skip_button.add_theme_font_size_override("font_size",14)
	grid_footer.add_child(skip_button)
	skip_button.hide()
	var right := panel(Vector2(1090,116),Vector2(326,352))
	intel_title=label("情报档案",18,INK)
	right.add_child(intel_title)
	right.add_child(HSeparator.new())
	clue_label=label("等待仓库资料",16)
	clue_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	clue_label.custom_minimum_size=Vector2(294,112)
	right.add_child(clue_label)
	skill_button=button("私密鉴定",func(): use_skill())
	skill_button.custom_minimum_size.y=42
	right.add_child(skill_button)
	private_label=label("每仓一次 · 仅你可见",14,MINT)
	private_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	private_label.custom_minimum_size.y=42
	right.add_child(private_label)
	history_label=label("",13,MUTED)
	history_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	right.add_child(history_label)
	var detail := panel(Vector2(1090,492),Vector2(326,224))
	detail.add_child(label("物资详情",14,MUTED))
	detail.add_child(HSeparator.new())
	detail_title=label("尚未开仓",23,INK)
	detail.add_child(detail_title)
	detail_text=label("开仓后查看物资",15,MUTED)
	detail_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(detail_text)
	var bottom := panel(Vector2(24,748),Vector2(1392,128))
	status_label=label("等待开始",17,INK)
	bottom.add_child(status_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",12)
	bottom.add_child(actions)
	var bid_prompt := label("你的报价",16,MUTED)
	actions.add_child(bid_prompt)
	bid_fields.append(bid_prompt)
	bid_input=LineEdit.new()
	bid_input.custom_minimum_size=Vector2(232,52)
	bid_input.placeholder_text="输入金币数额"
	bid_input.text="2000"
	bid_input.max_length=9
	bid_input.add_theme_font_size_override("font_size",26)
	bid_input.add_theme_stylebox_override("normal",style(Color("0a1015"),Color("61717a"),2))
	bid_input.text_submitted.connect(func(_text): phase_action(submit))
	actions.add_child(bid_input)
	bid_fields.append(bid_input)
	for amount in [-500,500]:
		var adjust := button("− 500" if amount<0 else "+ 500",func(): adjust_bid(amount))
		adjust_buttons.append(adjust)
		actions.add_child(adjust)
		bid_fields.append(adjust)
	settlement_summary=HBoxContainer.new()
	settlement_summary.add_theme_constant_override("separation",40)
	actions.add_child(settlement_summary)
	for heading in ["成交价", "货物总值", "净收益"]:
		var column := VBoxContainer.new()
		column.custom_minimum_size.x=194
		column.add_theme_constant_override("separation",0)
		settlement_summary.add_child(column)
		column.add_child(label(heading,12,MUTED))
		var amount_label := label("0",25,INK)
		column.add_child(amount_label)
		settlement_values.append(amount_label)
	settlement_summary.hide()
	var gap := Control.new()
	gap.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	actions.add_child(gap)
	pass_button=button("本轮弃权",func(): phase_action(func(): submit(0)))
	actions.add_child(pass_button)
	commit_button=button("锁定报价  ↵",func(): phase_action(submit),true)
	commit_button.custom_minimum_size.x=246
	actions.add_child(commit_button)
	next_button=button("下一轮  →",func(): phase_action(advance),true)
	next_button.custom_minimum_size.x=246
	actions.add_child(next_button)

func show_item_details(item: Dictionary) -> void:
	if item.is_empty():
		detail_title.text="尚未发现物资" if started and game.phase=="reveal" else "尚未开仓"
		detail_text.text="选择已发现的物资，查看详情。" if started and game.phase=="reveal" else "开仓后查看物资"
	else:
		detail_title.text=item.get("name","")
		detail_text.text="估定价值   %s 金币\n\n已核验 · 随整仓结算变现" % money(int(item.get("value",0)))

func update_reveal_progress(revealed: int, total: int) -> void:
	storage_label.text="已搜索  %d / %d" % [revealed,total]
	skip_button.visible=revealed<total

func skip_reveal() -> void:
	if not started or paused or game.phase!="reveal": return
	view.skip_reveal()

func build_overlay() -> void:
	overlay=Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	var dim := ColorRect.new()
	dim.color=Color(0.02,0.05,0.09,0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	overlay_panel=PanelContainer.new()
	overlay_panel.position=Vector2(380,185)
	overlay_panel.size=Vector2(680,530)
	overlay_panel.add_theme_stylebox_override("panel",style(Color("171f26"),Color("5a605b"),4))
	overlay.add_child(overlay_panel)
	body=VBoxContainer.new()
	body.add_theme_constant_override("separation",15)
	overlay_panel.add_child(body)

func clear_overlay(mode: String) -> void:
	overlay_mode=mode
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	overlay.show()
	paused=true
	overlay_panel.size=Vector2(680,530)

func show_menu() -> void:
	clear_overlay("menu")
	body.add_child(label("仓储拍卖 · 本地单人",16,MUTED))
	body.add_child(label("秘仓竞拍",48,GOLD))
	body.add_child(label("三个仓库，五轮判断。",24))
	var intro := label("一位玩家，三位独立 AI。\n探索 3 座神秘仓库，经历 5 轮暗标。\n猜对价值、控制出价，成为最终的拍卖赢家。",19,MUTED)
	intro.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)
	var settings := HBoxContainer.new()
	settings.add_child(label("每轮思考时间",18))
	var choice := OptionButton.new()
	for value in [15,30,60]: choice.add_item("%d 秒" % value)
	choice.select([15,30,60].find(timer_seconds))
	choice.item_selected.connect(func(index): timer_seconds=[15,30,60][index])
	settings.add_child(choice)
	body.add_child(settings)
	body.add_child(button("进入第一座秘仓",func(): start_game(),true))
	body.add_child(button("了解竞拍规则",func(): show_help()))
	body.add_child(label("原创轻量玩法 · 本地单人 · 无真实交易",14,MUTED))

func show_pause() -> void:
	if not started: return
	clear_overlay("pause")
	body.add_child(label("拍卖已暂停",36,GOLD))
	body.add_child(label("计时已停止，所有报价保持原样。",19,MUTED))
	body.add_child(button("继续竞拍",func(): resume_game(),true))
	body.add_child(button("查看规则",func(): show_help()))
	body.add_child(button("重新开始",func(): show_restart_confirm()))
	body.add_child(label("Esc 继续 · 窗口失焦自动暂停",15,MUTED))

func show_restart_confirm() -> void:
	clear_overlay("restart")
	body.add_child(label("重新开始这场拍卖？",32,GOLD))
	body.add_child(label("当前场次与资金将清零，重新分配 10,000 金币。",17,MUTED))
	body.add_child(button("重新开局",func(): start_game(),true))
	body.add_child(button("返回竞拍",func(): resume_game()))

func show_help() -> void:
	clear_overlay("help")
	body.add_child(label("竞拍指南",32,GOLD))
	var text := label("1. 一场 3 仓，每仓 5 轮。每轮追加一条公开线索。\n2. 输入整数报价或弃权；新报价替换上一轮，并非加价。\n3. 你锁定前，三位 AI 已独立报价；提交后公开该轮报价。\n4. 前 4 轮只供参考。第 5 轮最高价获得整仓，只支付一次。\n5. 藏品立即变现：资金变化 = 货值 − 成交价。\n6. 最高同价按公开的轮换优先权；全员 0 元则流拍。\n7. 鉴定技能每仓一次，仅自己看见更窄的估价区间。\n8. 3 仓后按资金排名，资金相同共享名次。",17,INK)
	text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_child(text)
	body.add_child(label("所有金额为虚拟金币。AI 不知道真实货值。\n超时自动弃权；失焦与暂停时不计时；Enter 锁定，Esc 暂停。",15,MINT))
	body.add_child(button("明白了",func(): resume_game() if started else show_menu(),true))

func resume_game() -> void:
	paused=false
	overlay.hide()

func start_game() -> void:
	game=Session.new()
	game.rules.round_seconds=timer_seconds
	game.start()
	started=true
	last_phase=""
	last_warehouse=-1
	displayed_items=false
	resume_game()
	refresh()

func phase_action(action: Callable) -> void:
	# New phase buttons share the action position. Absorb the trailing click of
	# a double-click instead of advancing and accidentally bidding the next round.
	var now: int = Time.get_ticks_msec()
	if now < phase_action_unlock_msec or double_click_frame==Engine.get_process_frames(): return
	phase_action_unlock_msec=now+250
	action.call()

func adjust_bid(amount: int) -> void:
	if not started or paused or game.phase!="bidding": return
	bid_input.text=str(clampi(bid_input.text.to_int()+amount,0,game.balances[0]))

func submit(override := -1) -> void:
	if not started or paused or game.phase!="bidding": return
	var text := bid_input.text.strip_edges()
	if override<0 and (not text.is_valid_int() or text.begins_with("-") or text.begins_with("+")):
		status_label.text="请输入 0 到 %d 之间的整数金额。" % game.balances[0]
		return
	var amount: int = override if override>=0 else text.to_int()
	if not game.submit_bid(0,amount,game.warehouse,game.round):
		status_label.text="报价未接受：请检查余额，或等待下一轮。"
		return
	refresh()

func use_skill() -> void:
	if started and not paused:
		game.use_skill(0)
		refresh()

func advance() -> void:
	if not started or paused: return
	game.advance()
	refresh()

func money(value: int) -> String:
	var s := str(absi(value))
	var result := ""
	for i in s.length():
		if i>0 and (s.length()-i)%3==0: result+=","
		result+=s[i]
	return ("−" if value<0 else "")+result

func refresh() -> void:
	if not started: return
	var snap: Dictionary = game.snapshot(0)
	var phase: String = snap.phase
	phase_label.text="秘仓 %02d / %02d    ·    暗标 %d / %d" % [game.warehouse+1,game.rules.warehouses,game.round,game.rules.rounds]
	if game.warehouse!=last_warehouse:
		last_warehouse=game.warehouse
		view.set_snapshot(snap)
		displayed_items=false
		show_item_details({})
		storage_label.text="容量  10 × 6  /  内容未知"
		skip_button.hide()
		bid_input.text="2000" if game.balances[0]>=2000 else str(game.balances[0])
	for i in 4:
		bidder_labels[i].text=money(snap.balances[i])
		bidder_bids[i].text="报价已密封" if i>0 else "等待你的报价"
		if phase=="bidding" and not snap.get("history",[]).is_empty():
			var previous_bid: int = snap.history.back().bids[i]
			bidder_bids[i].text="上轮 %s · %s" % [money(previous_bid),"已密封" if i>0 else "待报价"]
		if phase!="bidding" and snap.get("round_bids",[]).size()==4:
			var b: int = snap.round_bids[i]
			bidder_bids[i].text="本轮弃权" if b==0 else "公开报价  ¥ "+money(b)
	var clues: Array = snap.get("clues",[])
	clue_label.text="\n".join(clues.slice(maxi(0,clues.size()-2)))
	private_label.text=snap.get("skilltext","")
	if private_label.text.is_empty(): private_label.text="每仓一次 · 缩小估价范围"
	skill_button.disabled=not snap.get("skill_available",false) or phase!="bidding"
	var priority: Array = snap.get("priority",[0,1,2,3])
	var pnames: Array[String]=[]
	for i in priority: pnames.append(["你","陈","林","周"][i])
	history_label.text="同价优先："+" → ".join(pnames)
	timer_label.text="%02d 秒" % ceili(snap.get("time",0.0)) if phase=="bidding" else "已揭晓"
	stage_caption.text="仓库 %02d    /    物资搜索" % (snap.warehouse+1) if phase in ["reveal","finished"] else "仓库 %02d    /    封存中" % (snap.warehouse+1)
	view.set_snapshot(snap)
	var bidding := phase=="bidding"
	var opened := phase in ["reveal","finished"]
	for field in bid_fields: field.visible=not opened
	settlement_summary.visible=opened
	intel_title.text="仓库结算" if opened else "情报档案"
	skill_button.visible=not opened
	private_label.visible=not opened
	history_label.visible=not opened
	grid_note.text="点击物资查看详情" if opened else "封存货物仅在第五轮成交后开启"
	if opened:
		var winner_id: int = snap.get("winner",-1)
		var sale: int = snap.get("price",0)
		var total: int = snap.get("total_value",0)
		clue_label.text="本仓流拍\n\n所有竞拍者保留资金" if winner_id<0 else "本仓赢家\n%s\n\n整仓物资已自动变现" % snap.names[winner_id]
		settlement_values[0].text=money(sale) if winner_id>=0 else "流拍"
		settlement_values[1].text=money(total)
		settlement_values[2].text=("+" if total>=sale else "")+money(total-sale) if winner_id>=0 else "—"
		settlement_values[2].add_theme_color_override("font_color",MINT if total>=sale else Color("de9786"))
	for adjust in adjust_buttons: adjust.disabled=not bidding
	bid_input.editable=bidding
	commit_button.visible=bidding
	pass_button.visible=bidding
	next_button.visible=not bidding and phase!="finished"
	if phase!=last_phase or bidding:
		if bidding:
			status_label.text="第 %d 轮 · 等待你的报价" % game.round
		elif phase=="round_result":
			status_label.text="本轮报价已公开 · 进入下一轮"
			next_button.text="下一轮  →"
		elif phase=="reveal":
			var winner: int = snap.get("winner",-1)
			if winner<0: status_label.text="本仓流拍 · 无人支付"
			else:
				status_label.text="%s 拍得本仓 · 已结算" % snap.names[winner]
			next_button.text="最终排名  →" if game.warehouse+1>=game.rules.warehouses else "下一座秘仓  →"
			if not displayed_items:
				displayed_items=true
				show_reveal(snap)
		elif phase=="finished": show_finish()
	last_phase=phase

func show_reveal(snap: Dictionary) -> void:
	view.set_snapshot(snap)

func show_finish() -> void:
	clear_overlay("finished")
	body.add_child(label("拍卖落幕",38,GOLD))
	body.add_child(label("三座秘仓已结算 · 最终资金排名",18,MUTED))
	for entry in game.rankings():
		body.add_child(label("#%d   %s     ¥ %s" % [entry.rank,entry.name,money(entry.balance)],23,MINT if entry.player_id==0 else INK))
	body.add_child(button("再开一场",func(): start_game(),true))
	body.add_child(button("返回主菜单",func(): started=false; show_menu()))

func _process(delta: float) -> void:
	if not started or paused: return
	view.advance_reveal(delta)
	var before: String = game.phase
	game.tick(delta)
	var snap: Dictionary=game.snapshot(0)
	timer_label.text="%02d 秒" % ceili(snap.get("time",0.0)) if game.phase=="bidding" else "已揭晓"
	timer_label.add_theme_color_override("font_color",Color("f39a85") if snap.get("time",30.0)<=5 and game.phase=="bidding" else MINT)
	if before!=game.phase: refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and event.double_click:
		double_click_frame=Engine.get_process_frames()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not started: return
		if overlay.visible and overlay_mode!="finished": resume_game()
		elif not overlay.visible: show_pause()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and started and not paused and is_instance_valid(overlay): show_pause()
