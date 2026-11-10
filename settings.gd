extends RefCounted
## Room form and runtime share rule defaults.
const Rules: Script = preload("res://games/minigame/gp_auction_master/rules.gd")

static func schema() -> Dictionary:
	var defaults: Rules = Rules.new()
	var fields: Dictionary = {
		"warehouses": {"type": "int", "default": defaults.warehouses, "title": "仓库数量", "min": 1, "max": 10},
		"rounds": {"type": "int", "default": defaults.rounds, "title": "每仓最多轮数", "min": 1, "max": 5},
		"round_seconds": {"type": "int", "default": int(defaults.round_seconds), "title": "每轮竞价秒数", "min": 5, "max": 300},
		"reveal_seconds": {"type": "int", "default": int(defaults.reveal_seconds), "title": "每轮揭示秒数", "min": 1, "max": 60},
		"settlement_seconds": {"type": "int", "default": int(defaults.settlement_seconds), "title": "成交结算秒数", "min": 10, "max": 180},
		"search_seconds": {"type": "array", "default": defaults.search_seconds, "title": "各品质搜索秒数", "control": "numbers", "min_items": 7, "max_items": 7, "labels": ["普通", "优良", "稀有", "珍贵", "典藏", "传世", "至臻"], "items": {"type": "float", "min": 0.02, "max": 15.0, "step": 0.01}},
		"search_jitter_percent": {"type": "int", "default": defaults.search_jitter_percent, "title": "搜索时间随机扰动（±百分比）", "min": 0, "max": 100},
		"search_fakeout_percent": {"type": "int", "default": defaults.search_fakeout_percent, "title": "低品质长搜索概率（百分比）", "min": 0, "max": 100},
		"search_fakeout_quality": {"type": "int", "default": defaults.search_fakeout_quality, "title": "长搜索扰动最高品质（0普通 / 1优良）", "min": 0, "max": 5},
		"search_fakeout_seconds": {"type": "array", "default": defaults.search_fakeout_seconds, "title": "低品质长搜索秒数范围", "control": "numbers", "min_items": 2, "max_items": 2, "ordered": true, "labels": ["最短", "最长"], "items": {"type": "float", "min": 0.02, "max": 15.0, "step": 0.1}},
		"coins": {"type": "int", "default": defaults.initialcoins, "title": "所有玩家初始金币", "min": 1000, "max": 1000000, "step": 100},
		"item_counts": {"type": "array", "default": defaults.item_counts, "title": "每仓物品数量范围", "control": "numbers", "min_items": 2, "max_items": 2, "ordered": true, "labels": ["最少物品", "最多物品"], "items": {"type": "int", "min": 1, "max": 100}},
		"quality_weights": {"type": "array", "default": defaults.quality_weights, "title": "物品品质相对权重", "description": "先按品质权重抽取，再在该品质物品中等概率抽取；0 表示不出现，至少一档大于 0。", "control": "numbers", "min_items": 7, "max_items": 7, "labels": ["普通", "优良", "稀有", "珍贵", "典藏", "传世", "至臻"], "items": {"type": "int", "min": 0, "max": 10000}},
	}
	fields.merge(Rules.Conditions.FIELDS.duplicate(true))
	var groups: Array[Dictionary] = [
		{"id": "room", "title": "基础规则", "children": []},
		{"id": "selection", "title": "仓前与抽取", "children": []},
		{"id": "special", "title": "特殊规则", "children": []},
		{"id": "public", "title": "公共信息", "children": []}]
	for key: String in fields:
		fields[key]["audience"] = "room"
		fields[key]["apply"] = "next_round"
		var group: int = 0
		if key in ["briefing_seconds", "special_counts", "public_counts", "special_weights", "public_weights"]:
			group = 1
		elif key in ["reserve_price", "raise_step", "patient_rounds", "fast_percent", "uplift_target", "discount_percent", "small_cells", "large_cells", "common_quality", "quality_min", "quality_max", "bulk_count", "cross_tags", "assist_multiplier"]:
			group = 2
		elif key in ["public_reveals", "region_cells", "largest_count", "price_count", "price_band", "highest_count", "highest_tags", "cheap_price", "duplicate_kinds", "synergy_groups", "top_count", "share_band"]:
			group = 3
		groups[group].children.append({"field": key})
	return {"schema_format": 3, "settings_version": 1, "fields": fields, "layout": groups}
