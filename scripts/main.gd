extends Node
const Session = preload("res://scripts/session.gd")
const WarehouseView = preload("res://scripts/warehouse_view.gd")
const INK = Color("e6e9df")
const MUTED = Color("a3aca4")
const GOLD = Color("d6ed41")
const MINT = Color("b7ccb4")
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
var estimate_label: Label
var skill_heading: Label
var bidder_rounds: Array = []

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
	l.add_theme_color_override("font_shadow_color",Color(0.0,0.0,0.0,0.85))
	l.add_theme_constant_override("shadow_offset_x",0)
	l.add_theme_constant_override("shadow_offset_y",2)
	return l

func button(text: String, callback: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text=text
	b.custom_minimum_size=Vector2(0,48)
	b.add_theme_font_size_override("font_size",19)
	b.add_theme_stylebox_override("normal",style(Color("d6ed41") if primary else Color("273139"),Color("d6ed41") if primary else Color("4a555e"),3))
	b.add_theme_stylebox_override("hover",style(Color("eaff61") if primary else Color("35444e"),GOLD,3))
	b.add_theme_stylebox_override("pressed",style(Color("adca2c") if primary else Color("172d39"),GOLD,3))
	b.add_theme_stylebox_override("disabled",style(Color("23313a"),Color("35434d"),3))
	for state in ["normal","hover","pressed","disabled"]:
		var box := b.get_theme_stylebox(state)
		box.content_margin_top=8
		box.content_margin_bottom=8
	b.add_theme_color_override("font_color",Color("182b35") if primary else INK)
	b.add_theme_color_override("font_hover_color",Color("182b35") if primary else INK)
	b.pressed.connect(callback)
	return b


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

func place(control: Control, pos: Vector2, extent: Vector2) -> void:
	control.position=pos
	control.size=extent
	ui.add_child(control)

func flat_box(bg: Color, margin := 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color=bg
	box.content_margin_left=margin
	box.content_margin_right=margin
	box.content_margin_top=8
	box.content_margin_bottom=8
	return box

func hud_button(text: String, callback: Callable, primary := false) -> Button:
	var b := button(text,callback,primary)
	b.add_theme_stylebox_override("normal",flat_box(Color("d6ed41") if primary else Color(0.06,0.08,0.08,0.62)))
	b.add_theme_stylebox_override("hover",flat_box(Color("eaff61") if primary else Color(0.20,0.25,0.24,0.75)))
	b.add_theme_stylebox_override("pressed",flat_box(Color("adca2c") if primary else Color(0.06,0.09,0.09,0.9)))
	b.add_theme_stylebox_override("disabled",flat_box(Color(0.1,0.13,0.13,0.45)))
	b.add_theme_color_override("font_color",Color("172015") if primary else INK)
	b.add_theme_color_override("font_hover_color",Color("172015") if primary else Color.WHITE)
	b.add_theme_color_override("font_pressed_color",Color("172015") if primary else INK)
	b.add_theme_color_override("font_disabled_color",Color("75807a"))
	b.add_theme_font_size_override("font_size",18)
	return b

func hairline(pos: Vector2, extent: Vector2, color: Color = Color(0.78,0.82,0.76,0.16)) -> void:
	var line := ColorRect.new()
	line.color=color
	line.mouse_filter=Control.MOUSE_FILTER_IGNORE
	place(line,pos,extent)

func build_hud() -> void:
	var bg := ColorRect.new()
	bg.color=Color("141e20")
	bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	place(bg,Vector2.ZERO,Vector2(1440,900))
	var background_path := "res://assets/backgrounds/auction_warehouse_original.png"
	if ResourceLoader.exists(background_path):
		var backdrop := TextureRect.new()
		backdrop.texture=load(background_path)
		backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
		backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
		place(backdrop,Vector2.ZERO,Vector2(1440,900))
	# Transparent gradients preserve the warehouse scene instead of boxing the HUD.
	var gradient := Gradient.new()
	gradient.set_color(0,Color(0.015,0.025,0.027,0.38))
	gradient.set_color(1,Color(0.015,0.025,0.027,0.025))
	var wash := GradientTexture2D.new()
	wash.gradient=gradient
	wash.fill_from=Vector2(0.0,0.0)
	wash.fill_to=Vector2(0.74,0.0)
	var shade := TextureRect.new()
	shade.texture=wash
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	place(shade,Vector2.ZERO,Vector2(1440,900))
	var lower_gradient := Gradient.new()
	lower_gradient.set_color(0,Color(0.01,0.02,0.025,0))
	lower_gradient.set_color(1,Color(0.01,0.02,0.025,0.65))
	var lower_wash := GradientTexture2D.new()
	lower_wash.gradient=lower_gradient
	lower_wash.fill_from=Vector2(0,0)
	lower_wash.fill_to=Vector2(0,1)
	var lower_shade := TextureRect.new()
	lower_shade.texture=lower_wash
	lower_shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	place(lower_shade,Vector2(0,520),Vector2(1440,380))

	title_label=label("秘仓竞拍",21,INK)
	place(title_label,Vector2(28,25),Vector2(200,36))
	phase_label=label("第 1 轮",25,INK)
	phase_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	place(phase_label,Vector2(358,23),Vector2(284,38))
	sub_label=label("秘仓 01 / 03",13,MUTED)
	sub_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	place(sub_label,Vector2(358,65),Vector2(284,22))
	timer_label=label("30 秒",22,MINT)
	place(timer_label,Vector2(714,32),Vector2(92,36))
	hairline(Vector2(254,71),Vector2(98,1))
	hairline(Vector2(648,71),Vector2(136,1))
	var rules_button := hud_button("规则",func(): show_help())
	place(rules_button,Vector2(1232,24),Vector2(72,40))
	var pause_button := hud_button("暂停",func(): show_pause())
	place(pause_button,Vector2(1320,24),Vector2(86,40))

	for i in 4:
		var y := 138.0+i*132.0
		var portrait := TextureRect.new()
		portrait.texture=load("res://assets/portraits/%s.svg" % ["appraiser","chen","lin","zhou"][i])
		portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
		place(portrait,Vector2(28,y),Vector2(52,64))
		if i==0: hairline(Vector2(28,y),Vector2(3,64),GOLD)
		var name_label := label(["你 · 鉴定师","算盘陈","眼力林","胆大周"][i],17,GOLD if i==0 else INK)
		place(name_label,Vector2(92,y-3),Vector2(145,28))
		var cash := label("10,000",21,INK)
		place(cash,Vector2(92,y+25),Vector2(145,34))
		bidder_labels.append(cash)
		var bid := label("报价已密封",13,MUTED)
		place(bid,Vector2(29,y+74),Vector2(199,25))
		bidder_bids.append(bid)
		var rounds: Array[Label] = []
		for r in 5:
			var tick := label(str(r+1),11,Color("6b7875"))
			place(tick,Vector2(31+r*39,y+105),Vector2(25,19))
			rounds.append(tick)
		bidder_rounds.append(rounds)

	# Only two compact pieces of information float over the environment.
	intel_title=label("公开线索",17,INK)
	place(intel_title,Vector2(278,141),Vector2(240,32))
	hairline(Vector2(254,145),Vector2(3,24),Color("a8b59d"))
	clue_label=label("等待仓库资料",19,INK)
	clue_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	place(clue_label,Vector2(278,191),Vector2(484,138))
	clue_label.add_theme_constant_override("line_spacing",9)
	hairline(Vector2(254,343),Vector2(514,1))
	skill_heading=label("鉴定师",17,INK)
	place(skill_heading,Vector2(278,369),Vector2(210,30))
	hairline(Vector2(254,373),Vector2(3,24),MINT)
	skill_button=hud_button("私密鉴定",func(): use_skill())
	place(skill_button,Vector2(635,363),Vector2(135,42))
	private_label=label("每仓一次 · 缩小估价范围",16,MINT)
	private_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	place(private_label,Vector2(278,422),Vector2(486,66))
	history_label=label("",13,MUTED)
	place(history_label,Vector2(278,506),Vector2(482,28))

	stage_caption=label("封存物资",20,INK)
	place(stage_caption,Vector2(832,76),Vector2(320,34))
	storage_label=label("封存中",13,MUTED)
	storage_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	place(storage_label,Vector2(1195,80),Vector2(212,26))
	view=WarehouseView.new()
	view.position=Vector2(832,116)
	view.size=Vector2(576,672)
	ui.add_child(view)
	view.selection_changed.connect(show_item_details)
	view.reveal_progress.connect(update_reveal_progress)
	estimate_label=label("当前估价  2,000—12,000",18,INK)
	estimate_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	place(estimate_label,Vector2(832,798),Vector2(576,32))
	grid_note=label("",12,MUTED)
	grid_note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	place(grid_note,Vector2(832,840),Vector2(576,23))
	skip_button=hud_button("完成搜索",func(): skip_reveal())
	skip_button.add_theme_font_size_override("font_size",13)
	place(skip_button,Vector2(1290,796),Vector2(118,34))
	skip_button.hide()
	detail_title=label("",18,INK)
	place(detail_title,Vector2(832,798),Vector2(340,30))
	detail_text=label("",14,MUTED)
	place(detail_text,Vector2(832,840),Vector2(575,25))
	detail_title.hide()
	detail_text.hide()

	status_label=label("等待开始",15,INK)
	status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	place(status_label,Vector2(274,647),Vector2(494,38))
	var bid_prompt := label("你的报价",13,MUTED)
	bid_prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	place(bid_prompt,Vector2(347,694),Vector2(342,24))
	bid_fields.append(bid_prompt)
	bid_input=LineEdit.new()
	bid_input.text="2000"
	bid_input.placeholder_text="输入金币数额"
	bid_input.max_length=9
	bid_input.alignment=HORIZONTAL_ALIGNMENT_CENTER
	bid_input.add_theme_font_size_override("font_size",32)
	bid_input.add_theme_stylebox_override("normal",flat_box(Color(0.02,0.04,0.04,0.35)))
	var focus_box := flat_box(Color(0.04,0.07,0.065,0.7))
	focus_box.border_color=GOLD
	focus_box.border_width_bottom=1
	bid_input.add_theme_stylebox_override("focus",focus_box)
	bid_input.text_submitted.connect(func(_text): phase_action(submit))
	place(bid_input,Vector2(369,723),Vector2(296,50))
	bid_fields.append(bid_input)
	for i in 2:
		var amount: int = [-500,500][i]
		var adjust := hud_button("−" if amount<0 else "+",func(): adjust_bid(amount))
		adjust.tooltip_text="减少 500 金币" if amount<0 else "增加 500 金币"
		adjust.add_theme_font_size_override("font_size",27)
		place(adjust,Vector2(312 if i==0 else 676,723),Vector2(46,50))
		adjust_buttons.append(adjust)
		bid_fields.append(adjust)
	commit_button=hud_button("锁定报价",func(): phase_action(submit),true)
	commit_button.add_theme_font_size_override("font_size",25)
	place(commit_button,Vector2(348,790),Vector2(338,64))
	pass_button=hud_button("弃权",func(): phase_action(func(): submit(0)))
	place(pass_button,Vector2(700,800),Vector2(68,48))
	next_button=hud_button("下一轮  →",func(): phase_action(advance),true)
	next_button.add_theme_font_size_override("font_size",23)
	place(next_button,Vector2(348,790),Vector2(338,64))
	settlement_summary=HBoxContainer.new()
	settlement_summary.add_theme_constant_override("separation",30)
	place(settlement_summary,Vector2(277,713),Vector2(489,61))
	for heading in ["成交价", "货物总值", "净收益"]:
		var column := VBoxContainer.new()
		column.custom_minimum_size.x=144
		column.add_theme_constant_override("separation",2)
		settlement_summary.add_child(column)
		column.add_child(label(heading,12,MUTED))
		var amount_label := label("0",25,INK)
		column.add_child(amount_label)
		settlement_values.append(amount_label)
	settlement_summary.hide()

func show_item_details(item: Dictionary) -> void:
	if item.is_empty():
		detail_title.text="正在搜索物资…" if started and game.phase=="reveal" else ""
		detail_text.text="选择已发现的物资查看详情" if started and game.phase=="reveal" else ""
	else:
		detail_title.text=item.get("name","")
		detail_text.text="价值  %s 金币    ·    %s    ·    已核验" % [money(int(item.get("value",0))),view.tier_name(int(item.get("value",0)))]

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
	phase_label.text="第 %d 轮" % game.round
	sub_label.text="秘仓 %02d / %02d    ·    五轮暗标" % [game.warehouse+1,game.rules.warehouses]
	if game.warehouse!=last_warehouse:
		last_warehouse=game.warehouse
		view.set_snapshot(snap)
		displayed_items=false
		show_item_details({})
		storage_label.text="封存中"
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
		for r in 5:
			var mark: Label = bidder_rounds[i][r]
			mark.add_theme_color_override("font_color",GOLD if r+1==game.round else (INK if r+1<game.round else Color("62716c")))
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
	stage_caption.text="仓库物资" if phase in ["reveal","finished"] else "封存物资"
	view.set_snapshot(snap)
	var bidding := phase=="bidding"
	var opened := phase in ["reveal","finished"]
	for field in bid_fields: field.visible=not opened
	settlement_summary.visible=opened
	intel_title.text="本仓结果" if opened else "公开线索"
	skill_heading.visible=not opened
	skill_button.visible=not opened
	private_label.visible=not opened
	history_label.visible=not opened
	grid_note.visible=false
	detail_title.visible=opened
	detail_text.visible=opened
	estimate_label.visible=not opened
	var shown_bounds: Array = snap.get("bounds",[2000,12000])
	estimate_label.text="当前估价  %s—%s" % [money(int(shown_bounds[0])),money(int(shown_bounds[1]))]
	if opened:
		var winner_id: int = snap.get("winner",-1)
		var sale: int = snap.get("price",0)
		var total: int = snap.get("total_value",0)
		clue_label.text="本仓流拍\n所有竞拍者保留资金" if winner_id<0 else "%s 拍得本仓\n整仓物资已自动变现" % snap.names[winner_id]
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
