extends Node3D
const Session = preload("res://scripts/session.gd")
const WarehouseView = preload("res://scripts/warehouse_view.gd")
const INK = Color("eef1e8")
const MUTED = Color("9bafb9")
const GOLD = Color("edc775")
const MINT = Color("8bddc6")
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
var lot_cards: HBoxContainer
var paused := false
var started := false
var last_phase := ""
var last_warehouse := -1
var overlay_mode := "menu"
var timer_seconds := 30
var displayed_items := false
var stage_caption: Label

func style(bg: Color, border := Color("344a56"), radius := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=bg
	s.border_color=border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left=20
	s.content_margin_right=20
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
	b.add_theme_stylebox_override("normal",style(Color("d6b56d") if primary else Color("253c49"),Color("e8c883") if primary else Color("506775"),9))
	b.add_theme_stylebox_override("hover",style(Color("ecd398") if primary else Color("3b5765"),GOLD,9))
	b.add_theme_stylebox_override("pressed",style(Color("ad9054") if primary else Color("172d39"),GOLD,9))
	b.add_theme_stylebox_override("disabled",style(Color("23313a"),Color("35434d"),9))
	b.add_theme_color_override("font_color",Color("182b35") if primary else INK)
	b.add_theme_color_override("font_hover_color",Color("182b35") if primary else INK)
	b.pressed.connect(callback)
	return b

func panel(pos: Vector2, size: Vector2, parent: Node = null) -> VBoxContainer:
	var p := PanelContainer.new()
	p.position=pos
	p.size=size
	p.add_theme_stylebox_override("panel",style(Color(0.06,0.12,0.16,0.94)))
	(parent if parent else ui).add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",10)
	p.add_child(v)
	return v

func _ready() -> void:
	view=WarehouseView.new()
	add_child(view)
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
	var top := panel(Vector2(28,24),Vector2(1384,96))
	var row := HBoxContainer.new()
	top.add_child(row)
	var title := VBoxContainer.new()
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(title)
	title_label=label("秘仓竞拍",29,GOLD)
	title.add_child(title_label)
	sub_label=label("AUCTION MASTER   /   先判断，再落槌。",15,MUTED)
	title.add_child(sub_label)
	phase_label=label("3 座秘仓  ·  4 位买家",22)
	phase_label.custom_minimum_size.x=420
	row.add_child(phase_label)
	timer_label=label("30 秒",27,MINT)
	timer_label.custom_minimum_size.x=120
	row.add_child(timer_label)
	row.add_child(button("玩法",func(): show_help()))
	row.add_child(button("暂停",func(): show_pause()))
	var left := panel(Vector2(28,140),Vector2(276,462))
	left.add_child(label("竞拍席位",20,GOLD))
	left.add_child(label("仅第 5 轮报价决定成交",14,MUTED))
	for i in 4:
		var card := PanelContainer.new()
		var card_style := style(Color("203541") if i==0 else Color("172b36"),Color("729582") if i==0 else Color("354c58"),9)
		card_style.content_margin_top=7
		card_style.content_margin_bottom=7
		card_style.content_margin_left=12
		card_style.content_margin_right=12
		card.add_theme_stylebox_override("panel",card_style)
		left.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation",2)
		card.add_child(v)
		var l := label(["你 · 鉴定师","算盘陈 · 稳健派","眼力林 · 价值派","胆大周 · 冒险派"][i],17,MINT if i==0 else INK)
		v.add_child(l)
		var cash := label("¥ 10,000",24,GOLD)
		v.add_child(cash)
		bidder_labels.append(cash)
		var bid := label("本轮报价保密",13,MUTED)
		v.add_child(bid)
		bidder_bids.append(bid)
	var right := panel(Vector2(1110,140),Vector2(302,464))
	right.add_child(label("仓库情报",20,GOLD))
	clue_label=label("封存资料等待开启",17)
	clue_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	clue_label.custom_minimum_size=Vector2(252,177)
	right.add_child(clue_label)
	skill_button=button("鉴定 · 每仓一次",func(): use_skill())
	right.add_child(skill_button)
	private_label=label("私有技能：缩小货值估价区间。",14,MINT)
	private_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	private_label.custom_minimum_size.y=50
	right.add_child(private_label)
	history_label=label("平价优先权将在开局公开",13,MUTED)
	history_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	right.add_child(history_label)
	var center := panel(Vector2(390,140),Vector2(660,67))
	var center_title := label("SEALED STORAGE    /    封存中",17,MINT)
	center_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(center_title)
	stage_caption=center_title
	center.name="StageCaption"
	var bottom := panel(Vector2(28,675),Vector2(1384,197))
	status_label=label("从有限线索中找到真正的价值。",20)
	bottom.add_child(status_label)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation",12)
	bottom.add_child(row2)
	row2.add_child(label("本轮报价",19,GOLD))
	bid_input=LineEdit.new()
	bid_input.custom_minimum_size=Vector2(255,55)
	bid_input.placeholder_text="输入金额"
	bid_input.text="2000"
	bid_input.max_length=9
	bid_input.add_theme_font_size_override("font_size",26)
	bid_input.add_theme_stylebox_override("normal",style(Color("0b1821"),Color("667b81"),8))
	bid_input.text_submitted.connect(func(_text): submit())
	row2.add_child(bid_input)
	row2.add_child(button("− 500",func(): adjust_bid(-500)))
	row2.add_child(button("+ 500",func(): adjust_bid(500)))
	commit_button=button("锁定报价  ↵",func(): submit(),true)
	commit_button.custom_minimum_size.x=210
	row2.add_child(commit_button)
	pass_button=button("本轮弃权",func(): submit(0))
	row2.add_child(pass_button)
	next_button=button("下一轮  →",func(): advance(),true)
	next_button.custom_minimum_size.x=200
	row2.add_child(next_button)
	bottom.add_child(label("每轮新报价替换旧报价 · 锁定不可改 · 超时视为 0 元 · 仅最终赢家支付一次 · 全部为虚拟金币",14,MUTED))
	lot_cards=HBoxContainer.new()
	lot_cards.position=Vector2(328,570)
	lot_cards.size=Vector2(755,88)
	lot_cards.add_theme_constant_override("separation",8)
	ui.add_child(lot_cards)

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
	overlay_panel.add_theme_stylebox_override("panel",style(Color("102631"),Color("ad945c"),20))
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
	body.add_child(label("AUCTION MASTER",16,MINT))
	body.add_child(label("秘仓竞拍",48,GOLD))
	body.add_child(label("看见的是线索，押上的是判断。",24))
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

func adjust_bid(amount: int) -> void:
	if not started or game.phase!="bidding": return
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
		view.show_closed()
		displayed_items=false
		for child in lot_cards.get_children(): child.queue_free()
		bid_input.text="2000" if game.balances[0]>=2000 else str(game.balances[0])
	for i in 4:
		bidder_labels[i].text="¥ "+money(game.balances[i])
		bidder_bids[i].text="报价已密封" if i>0 else "等待你的报价"
		if phase=="bidding" and not snap.get("history",[]).is_empty():
			var previous_bid: int = snap.history.back().bids[i]
			bidder_bids[i].text="上轮 %s · %s" % [money(previous_bid),"已密封" if i>0 else "待报价"]
		if phase!="bidding" and snap.get("round_bids",[]).size()==4:
			var b: int = snap.round_bids[i]
			bidder_bids[i].text="本轮弃权" if b==0 else "公开报价  ¥ "+money(b)
	var clues: Array = snap.get("clues",[])
	clue_label.text="\n\n".join(clues.slice(maxi(0,clues.size()-2)))
	private_label.text=snap.get("skilltext","")
	if private_label.text.is_empty(): private_label.text="私有技能：缩小货值估价区间。"
	skill_button.disabled=not snap.get("skill_available",false) or phase!="bidding"
	var priority: Array = snap.get("priority",[0,1,2,3])
	var pnames: Array[String]=[]
	for i in priority: pnames.append(["你","陈","林","周"][i])
	history_label.text="同价优先："+" → ".join(pnames)+"\n（每仓轮换；全 0 则流拍）"
	timer_label.text="%02d 秒" % ceili(snap.get("time",0.0)) if phase=="bidding" else "已揭晓"
	stage_caption.text="OPEN STORAGE    /    藏品已揭晓" if phase in ["reveal","finished"] else "SEALED STORAGE    /    封存中"
	var bidding := phase=="bidding"
	bid_input.editable=bidding
	commit_button.visible=bidding
	pass_button.visible=bidding
	next_button.visible=not bidding and phase!="finished"
	if phase!=last_phase or bidding:
		if bidding:
			status_label.text="第 %d 轮 · 阅读新线索，独立判断本轮报价。" % game.round
		elif phase=="round_result":
			status_label.text="报价已公开 · 本轮不扣款。下一轮可重新报价，直到第 5 轮成交。"
			next_button.text="下一轮  →"
		elif phase=="reveal":
			var winner: int = snap.get("winner",-1)
			var total: int = game.total_value()
			if winner<0: status_label.text="全员弃权，仓库流拍 · 真实货值 ¥ %s" % money(total)
			else:
				var price: int = snap.round_bids[winner]
				status_label.text="%s 成交 ¥ %s  ·  货值 ¥ %s  ·  净收益 %s%s" % [game.names[winner],money(price),money(total),"+" if total>=price else "",money(total-price)]
			next_button.text="最终排名  →" if game.warehouse+1>=game.rules.warehouses else "下一座秘仓  →"
			if not displayed_items:
				displayed_items=true
				show_reveal(game.reveal_items())
		elif phase=="finished": show_finish()
	last_phase=phase

func show_reveal(items: Array) -> void:
	view.show_items(items)
	for child in lot_cards.get_children(): child.queue_free()
	for item in items:
		var p := PanelContainer.new()
		p.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		p.add_theme_stylebox_override("panel",style(Color("112a34"),Color("6a8574"),10))
		lot_cards.add_child(p)
		var v := VBoxContainer.new()
		p.add_child(v)
		v.add_child(label(item.name,14,INK))
		var value_label := label("¥ 0",21,GOLD)
		v.add_child(value_label)
		var tween := value_label.create_tween()
		tween.tween_method(func(value: float): value_label.text="¥ "+money(int(value)),0.0,float(item.value),0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

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
	var before: String = game.phase
	game.tick(delta)
	var snap: Dictionary=game.snapshot(0)
	timer_label.text="%02d 秒" % ceili(snap.get("time",0.0)) if game.phase=="bidding" else "已揭晓"
	timer_label.add_theme_color_override("font_color",Color("f39a85") if snap.get("time",30.0)<=5 and game.phase=="bidding" else MINT)
	if before!=game.phase: refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not started: return
		if overlay.visible and overlay_mode!="finished": resume_game()
		elif not overlay.visible: show_pause()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and started and not paused and is_instance_valid(overlay): show_pause()
