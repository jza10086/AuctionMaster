extends RefCounted
## Room form and runtime share rule defaults.
const Rules: Script = preload("res://games/minigame/godot_party_default_auction_master/rules.gd")

static func schema() -> Dictionary:
	var defaults: Rules = Rules.new()
	var fields: Dictionary = {
		"warehouses": {"type": "int", "default": defaults.warehouses, "title": "仓库数量", "min": 1, "max": 10},
		"rounds": {"type": "int", "default": defaults.rounds, "title": "每仓最多轮数", "min": 1, "max": 5},
		"round_seconds": {"type": "int", "default": int(defaults.round_seconds), "title": "每轮竞价秒数", "min": 5, "max": 300},
		"reveal_seconds": {"type": "int", "default": int(defaults.reveal_seconds), "title": "每轮揭示秒数", "min": 1, "max": 60},
		"coins": {"type": "int", "default": defaults.initialcoins, "title": "所有玩家初始金币", "min": 1000, "max": 1000000, "step": 100},
		"item_counts": {"type": "array", "default": defaults.item_counts, "title": "每仓物品数量范围", "control": "numbers", "min_items": 2, "max_items": 2, "ordered": true, "labels": ["最少物品", "最多物品"], "items": {"type": "int", "min": 1, "max": 100}},
		"quality_weights": {"type": "array", "default": defaults.quality_weights, "title": "物品品质相对权重", "description": "先按品质权重抽取，再在该品质物品中等概率抽取；0 表示不出现，至少一档大于 0。", "control": "numbers", "min_items": 7, "max_items": 7, "labels": ["普通", "优良", "稀有", "珍贵", "典藏", "传世", "至臻"], "items": {"type": "int", "min": 0, "max": 10000}},
	}
	var children: Array[Dictionary] = []
	for key: String in fields:
		fields[key]["audience"] = "room"
		fields[key]["apply"] = "next_round"
		children.append({"field": key})
	return {"schema_format": 3, "settings_version": 1, "fields": fields, "layout": [{"id": "room", "title": "游戏规则", "expanded": true, "children": children}]}
