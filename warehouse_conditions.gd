extends Resource
## Warehouse-local rule selection, valuation and public evidence. Never owns player state.
const Catalog: Script = preload("res://games/minigame/gp_auction_master/item_catalog.gd")
const SPECIAL_IDS: Array[String] = ["reserve", "step", "patient", "fast", "hot", "cold", "small", "large", "common", "quality", "unique", "bulk", "cross", "assist"]
const PUBLIC_IDS: Array[String] = ["outline", "quality", "full", "tags", "region", "count", "cells", "quality_count", "tag_count", "largest", "prices", "value_band", "highest", "cheap", "duplicates", "synergy", "concentration", "absent"]
const ASSISTS: Array[String] = ["full", "outline", "quality", "tags"]
const FIELDS: Dictionary = {
	"briefing_seconds": {"type":"int","default":15,"min":0,"max":120,"title":"仓前展示秒数（0 跳过）"},
	"reserve_price": {"type":"int","default":40000,"min":0,"max":1000000,"title":"起拍底价（允许 0 或不低于底价）"},
	"raise_step": {"type":"int","default":100,"min":1,"max":1000000,"title":"步步加价：比本人上次正报价至少增加"},
	"patient_rounds": {"type":"int","default":2,"min":0,"max":4,"title":"耐心竞拍：禁止提前成交的轮数"},
	"uplift_target": {"type":"int","default":80,"min":1,"max":300,"title":"增值目标：高品质参考价百分比"},
	"discount_percent": {"type":"int","default":30,"min":0,"max":100,"title":"冷门标签贬值百分比"},
	"small_cells": {"type":"int","default":2,"min":1,"max":100,"title":"小件增值：最多格数"},
	"large_cells": {"type":"int","default":12,"min":1,"max":100,"title":"大件增值：最少格数"},
	"common_quality": {"type":"int","default":1,"min":0,"max":6,"title":"普货增值：最高品质序号（0–6）"},
	"quality_min": {"type":"int","default":2,"min":0,"max":6,"title":"品质增值：随机品质最低序号"},
	"quality_max": {"type":"int","default":6,"min":0,"max":6,"title":"品质增值：随机品质最高序号"},
	"bulk_count": {"type":"int","default":3,"min":2,"max":100,"title":"成批增值：同款最低件数"},
	"cross_tags": {"type":"int","default":2,"min":1,"max":10,"title":"跨界增值：最低标签数"},
	"assist_multiplier": {"type":"int","default":2,"min":1,"max":10,"title":"工具加倍：辅助操作数量倍率"},
	"region_cells": {"type":"int","default":4,"min":1,"max":16,"title":"区域扫描：正方形边长（格）"},
	"largest_count": {"type":"int","default":1,"min":1,"max":100,"title":"大件线索：轮廓和品质揭示件数"},
	"price_count": {"type":"int","default":3,"min":0,"max":100,"title":"价格线索：仅价格揭示件数"},
	"price_band": {"type":"int","default":10000,"min":1,"max":1000000,"title":"估价区间宽度"},
	"highest_count": {"type":"int","default":1,"min":1,"max":100,"title":"珍品线索：最高价物品件数"},
	"highest_tags": {"type":"int","default":1,"min":1,"max":10,"title":"珍品线索：每件揭示标签数"},
	"cheap_price": {"type":"int","default":500,"min":0,"max":1000000,"title":"廉价统计：低于此价格"},
	"duplicate_kinds": {"type":"int","default":1,"min":1,"max":100,"title":"重复货物：完整揭示的同款组数"},
	"synergy_groups": {"type":"int","default":1,"min":1,"max":10,"title":"羁绊线索：公开已激活组数"},
	"top_count": {"type":"int","default":3,"min":1,"max":100,"title":"集中度：最高价值物品件数"},
	"share_band": {"type":"int","default":10,"min":1,"max":100,"title":"集中度：占比区间宽度（百分点）"},
	"pending_seconds": {"type":"int","default":3,"min":0,"max":30,"title":"全部确认后的倒计时"},
	"unsold_seconds": {"type":"int","default":15,"min":1,"max":180,"title":"流拍开仓秒数"},
	"special_counts": {"type":"array","default":[0,2],"title":"特殊规则数量范围","control":"numbers","min_items":2,"max_items":2,"labels":["最少","最多"],"items":{"type":"int","min":0,"max":14},"ordered":true},
	"public_counts": {"type":"array","default":[1,3],"title":"公共信息数量范围","control":"numbers","min_items":2,"max_items":2,"labels":["最少","最多"],"items":{"type":"int","min":0,"max":18},"ordered":true},
	"early_percent": {"type":"array","default":[200,160,130,110],"title":"普通提前成交倍率（百分比）","control":"numbers","min_items":4,"max_items":4,"labels":["第 1 轮","第 2 轮","第 3 轮","第 4 轮"],"items":{"type":"int","min":100,"max":1000}},
	"fast_percent": {"type":"array","default":[150,130,110,105],"title":"快速成交倍率（百分比）","control":"numbers","min_items":4,"max_items":4,"labels":["第 1 轮","第 2 轮","第 3 轮","第 4 轮"],"items":{"type":"int","min":100,"max":1000}},
	"assist_counts": {"type":"array","default":[1,3,2,4],"title":"每轮辅助揭示件数","control":"numbers","min_items":4,"max_items":4,"labels":["完整信息","轮廓","品质","标签"],"items":{"type":"int","min":0,"max":100}},
	"public_reveals": {"type":"array","default":[10,5,2,8],"title":"公共揭示件数","control":"numbers","min_items":4,"max_items":4,"labels":["轮廓","品质","完整信息","标签"],"items":{"type":"int","min":0,"max":100}},
	"special_weights": {"type":"array","default":[1,1,1,1,1,1,1,1,1,1,1,1,1,1],"title":"特殊规则抽取权重","control":"numbers","min_items":14,"max_items":14,"labels":["起拍底价","步步加价","耐心竞拍","快速成交","热门标签","冷门标签","小件增值","大件增值","普货增值","品质增值","孤品增值","成批增值","跨界增值","工具加倍"],"items":{"type":"int","min":0,"max":10000}},
	"public_weights": {"type":"array","default":[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],"title":"公共信息抽取权重","control":"numbers","min_items":18,"max_items":18,"labels":["轮廓","品质","完整信息","标签","区域扫描","货物数量","占格统计","品质统计","标签统计","大件线索","价格线索","估价区间","珍品线索","廉价统计","重复货物","羁绊线索","价值集中度","缺席线索"],"items":{"type":"int","min":0,"max":10000}}
}
@export var values: Dictionary = {}

func _init() -> void:
	for key: String in FIELDS:
		values[key] = FIELDS[key].default.duplicate() if FIELDS[key].default is Array else FIELDS[key].default

func configure(settings: Dictionary) -> Error:
	for key: String in FIELDS:
		var spec: Dictionary = FIELDS[key]
		var value: Variant = settings.get(key, values[key])
		if spec.type == "array":
			if not value is Array or value.size() != int(spec.min_items):
				return ERR_INVALID_PARAMETER
			for component: Variant in value:
				if not _valid_number(component, spec.items):
					return ERR_INVALID_PARAMETER
			if spec.get("ordered", false) and value[0] > value[1]:
				return ERR_INVALID_PARAMETER
			values[key] = value.duplicate()
		else:
			if not _valid_number(value, spec):
				return ERR_INVALID_PARAMETER
			values[key] = int(value)
	if values.quality_min > values.quality_max:
		return ERR_INVALID_PARAMETER
	for pair: Array in [["special_counts", "special_weights"], ["public_counts", "public_weights"]]:
		var available: int = 0
		for weight: int in values[pair[1]]:
			available += 1 if weight > 0 else 0
		if pair[0] == "special_counts" and int(values.special_weights[2]) > 0 and int(values.special_weights[3]) > 0:
			available -= 1
		if int(values[pair[0]][0]) > available:
			return ERR_INVALID_PARAMETER
	return OK

static func _valid_number(value: Variant, spec: Dictionary) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= spec.min and value <= spec.max

## Weighted sampling without replacement; patient/fast are mutually exclusive.
func select_ids(ids: Array[String], weights: Array, limits: Array, rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array[int] = []
	for index: int in ids.size():
		if int(weights[index]) > 0:
			pool.append(index)
	var result: Array[String] = []
	for draw: int in rng.randi_range(int(limits[0]), int(limits[1])):
		if pool.is_empty():
			break
		var total: int = 0
		for index: int in pool:
			total += int(weights[index])
		var ticket: int = rng.randi_range(0, total - 1)
		for index: int in pool:
			ticket -= int(weights[index])
			if ticket < 0:
				result.append(ids[index])
				pool.erase(index)
				if ids[index] == "patient":
					pool.erase(ids.find("fast"))
				elif ids[index] == "fast":
					pool.erase(ids.find("patient"))
				break
	return result

func draw(rng: RandomNumberGenerator) -> Dictionary:
	var ids: Array[String] = select_ids(SPECIAL_IDS, values.special_weights, values.special_counts, rng)
	return {"ids": ids,
		"public_ids": select_ids(PUBLIC_IDS, values.public_weights, values.public_counts, rng),
		"hot_tag": Catalog.TAGS[rng.randi_range(0, Catalog.TAGS.size() - 1)],
		"cold_tag": Catalog.TAGS[rng.randi_range(0, Catalog.TAGS.size() - 1)],
		"quality": rng.randi_range(values.quality_min, values.quality_max),
		"assist": ASSISTS[rng.randi_range(0, ASSISTS.size() - 1)]}

static func cells(item: Dictionary) -> int:
	return int(item.size[0]) * int(item.size[1])

## Exact total cell count takes priority over quality distance, then nearest area.
## Median density at the nearest higher quality is compared under equal synergy.
static func reference_density(item: Dictionary, catalog: Array[Dictionary]) -> float:
	var distance: int = 2147483647
	var quality: int = 7
	var densities: Array[float] = []
	for other: Dictionary in catalog:
		if int(other.quality) <= int(item.quality):
			continue
		var gap: int = absi(cells(other) - cells(item))
		if gap < distance or (gap == distance and int(other.quality) < quality):
			distance = gap
			quality = int(other.quality)
			densities.clear()
		if gap == distance and int(other.quality) == quality:
			densities.append(float(other.value) / cells(other))
	if densities.is_empty():
		return 0.0
	densities.sort()
	var middle: int = densities.size() / 2
	return densities[middle] if densities.size() % 2 == 1 else (densities[middle - 1] + densities[middle]) * 0.5

## Apply all matching positive rules once; discount follows. Catalogue stays immutable.
func apply_values(lot: Array, condition: Dictionary, catalog: Array[Dictionary]) -> Dictionary:
	var counts: Dictionary = {}
	for item: Dictionary in lot:
		counts[item.kind] = int(counts.get(item.kind, 0)) + 1
	var stats: Dictionary = {"uplifted": 0, "within": 0, "below": 0, "above": 0, "incomparable": 0}
	var ids: Array = condition.ids
	for item: Dictionary in lot:
		var boost: bool = ("hot" in ids and condition.hot_tag in item.tags) or ("small" in ids and cells(item) <= int(values.small_cells)) or ("large" in ids and cells(item) >= int(values.large_cells)) or ("common" in ids and int(item.quality) <= int(values.common_quality)) or ("quality" in ids and item.quality == condition.quality) or ("unique" in ids and counts[item.kind] == 1) or ("bulk" in ids and counts[item.kind] >= int(values.bulk_count)) or ("cross" in ids and item.tags.size() >= int(values.cross_tags))
		var original: int = int(item.value)
		item["original_value"] = original
		var reference: float = reference_density(item, catalog) if boost else 0.0
		if boost:
			if reference > 0.0:
				item.value = maxi(original, floori(reference * cells(item) * int(values.uplift_target) / 100.0))
			else:
				stats.incomparable += 1
		if "cold" in ids and condition.cold_tag in item.tags:
			item.value = floori(int(item.value) * (100 - int(values.discount_percent)) / 100.0)
		if int(item.value) > original:
			stats.uplifted += 1
			var ratio: float = float(item.value) / cells(item) / reference
			stats.within += 1 if ratio >= 0.7 and ratio <= 0.9 else 0
			stats.below += 1 if ratio < 0.7 else 0
			stats.above += 1 if ratio > 0.9 else 0
	return stats

static func number(value: int) -> String:
	var text: String = str(absi(value))
	var result: String = ""
	for index: int in text.length():
		if index > 0 and (text.length() - index) % 3 == 0:
			result += ","
		result += text[index]
	return ("−" if value < 0 else "") + result

func describe(condition: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var uplift: String = "增值至同格数优先的更高品质参考价 %s%%；原价更高则保留，多条增值只计算一次" % number(values.uplift_target)
	for id: String in condition.ids:
		match id:
			"reserve": result.append("起拍底价｜报价为 0，或不低于 %s" % number(values.reserve_price))
			"step": result.append("步步加价｜正报价须比本人此前最近一次正报价至少增加 %s；仍可报 0" % number(values.raise_step))
			"patient": result.append("耐心竞拍｜前 %s 轮禁止提前成交，末轮照常成交" % number(values.patient_rounds))
			"fast":
				var parts: PackedStringArray = []
				for rate: int in values.fast_percent:
					parts.append(number(rate) + "%")
				result.append("快速成交｜前四轮最高价/第二名：" + " / ".join(parts))
			"hot": result.append("热门标签·%s｜%s" % [condition.hot_tag, uplift])
			"cold": result.append("冷门标签·%s｜增值后再降价 %s%%" % [condition.cold_tag, number(values.discount_percent)])
			"small": result.append("小件增值·最多 %s 格｜%s" % [number(values.small_cells), uplift])
			"large": result.append("大件增值·至少 %s 格｜%s" % [number(values.large_cells), uplift])
			"common": result.append("普货增值·%s及以下｜%s" % [Catalog.QUALITY_NAMES[values.common_quality], uplift])
			"quality": result.append("品质增值·%s｜%s" % [Catalog.QUALITY_NAMES[condition.quality], uplift])
			"unique": result.append("孤品增值·本仓仅一件的款式｜" + uplift)
			"bulk": result.append("成批增值·同款至少 %s 件｜%s" % [number(values.bulk_count), uplift])
			"cross": result.append("跨界增值·至少 %s 个标签｜%s" % [number(values.cross_tags), uplift])
			"assist": result.append("工具加倍·%s｜每次揭示数量 ×%s" % [["完整信息", "轮廓", "品质", "标签"][ASSISTS.find(condition.assist)], number(values.assist_multiplier)])
	return result

## Merge only explicitly revealed fields. Used identically by public and private discovery.
static func reveal(records: Dictionary, lot: Array, layout: Array, index: int, kind: String) -> void:
	var item: Dictionary = lot[index]
	var rect: Rect2i = layout[index]
	var record: Dictionary = records.get(index, {"index": index, "rect": [rect.position.x, rect.position.y, 1, 1]})
	if kind in ["full", "outline"]:
		record.rect = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	match kind:
		"full": record.merge(item.duplicate(true), true)
		"outline": record["outline"] = true
		"quality": record["quality"] = item.quality
		"tags":
			record["tags"] = item.tags.duplicate()
			record.erase("partial_tags")
		"price": record["value"] = item.value
	records[index] = record

static func pick_indices(count: int, size: int, rng: RandomNumberGenerator) -> Array[int]:
	var pool: Array[int] = []
	var result: Array[int] = []
	for index: int in size:
		pool.append(index)
	for draw: int in mini(count, size):
		var selected: int = rng.randi_range(0, pool.size() - 1)
		result.append(pool[selected])
		pool.remove_at(selected)
	return result

## Evidence is generated once on the host and reused for every recipient and review panel.
func public_evidence(lot: Array, layout: Array, appraisal: Dictionary, condition: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var records: Dictionary = {}
	var lines: Array[String] = []
	var quality_counts: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	var tag_counts: Dictionary = {}
	var kind_indices: Dictionary = {}
	var area: int = 0
	var small: int = 0
	var large: int = 0
	var cheap: int = 0
	var rows: int = Catalog.GRID_ROWS
	var size_order: Array[int] = []
	var price_order: Array[int] = []
	for index: int in lot.size():
		var item: Dictionary = lot[index]
		quality_counts[item.quality] += 1
		area += cells(item)
		small += 1 if cells(item) <= int(values.small_cells) else 0
		large += 1 if cells(item) >= int(values.large_cells) else 0
		cheap += 1 if int(item.value) < int(values.cheap_price) else 0
		for tag: String in item.tags:
			tag_counts[tag] = int(tag_counts.get(tag, 0)) + 1
		if not kind_indices.has(item.kind):
			kind_indices[item.kind] = []
		kind_indices[item.kind].append(index)
		rows = maxi(rows, layout[index].end.y)
		size_order.append(index)
		price_order.append(index)
	size_order.sort_custom(func(a: int, b: int) -> bool: return cells(lot[a]) > cells(lot[b]))
	price_order.sort_custom(func(a: int, b: int) -> bool: return int(appraisal.items[a].effective_value) > int(appraisal.items[b].effective_value))
	for id: String in condition.public_ids:
		match id:
			"outline", "quality", "full", "tags":
				var slot: int = ["outline", "quality", "full", "tags"].find(id)
				var selected: Array[int] = pick_indices(values.public_reveals[slot], lot.size(), rng)
				for index: int in selected:
					reveal(records, lot, layout, index, id)
				lines.append("公开%s｜已揭示 %s 件物品" % [["轮廓", "品质", "完整信息", "标签"][slot], number(selected.size())])
			"region":
				var side: int = int(values.region_cells)
				var region: Rect2i = Rect2i(rng.randi_range(0, Catalog.GRID_COLUMNS - side), rng.randi_range(0, rows - side), side, side)
				var count: int = 0
				for index: int in lot.size():
					if region.intersects(layout[index]):
						reveal(records, lot, layout, index, "outline")
						count += 1
				lines.append("区域扫描｜第 %s 列、第 %s 行起 %s × %s 格，揭示相交的 %s 件轮廓" % [number(region.position.x + 1), number(region.position.y + 1), number(side), number(side), number(count)])
			"count": lines.append("货物数量｜共 %s 件" % number(lot.size()))
			"cells": lines.append("占格统计｜共 %s 格；≤%s 格的小件 %s 件，≥%s 格的大件 %s 件" % [number(area), number(values.small_cells), number(small), number(values.large_cells), number(large)])
			"quality_count":
				var quality: int = rng.randi_range(0, quality_counts.size() - 1)
				lines.append("品质统计｜%s：%s 件" % [Catalog.QUALITY_NAMES[quality], number(quality_counts[quality])])
			"tag_count":
				var tag: String = Catalog.TAGS[rng.randi_range(0, Catalog.TAGS.size() - 1)]
				lines.append("标签统计｜%s：%s 件" % [tag, number(int(tag_counts.get(tag, 0)))])
			"largest":
				var count: int = mini(values.largest_count, lot.size())
				for position: int in count:
					reveal(records, lot, layout, size_order[position], "outline")
					reveal(records, lot, layout, size_order[position], "quality")
				lines.append("大件线索｜占格最大的 %s 件已揭示轮廓与品质" % number(count))
			"prices":
				var indices: Array[int] = pick_indices(values.price_count, lot.size(), rng)
				for index: int in indices:
					reveal(records, lot, layout, index, "price")
				lines.append("价格线索｜已揭示 %s 件的调整后基础价格（不含羁绊）" % number(indices.size()))
			"value_band":
				var width: int = values.price_band
				var lower: int = floori(float(appraisal.total_value) / width) * width
				lines.append("估价区间｜含羁绊总价 %s–%s" % [number(lower), number(lower + width - 1)])
			"highest":
				var count: int = mini(values.highest_count, lot.size())
				for position: int in count:
					var index: int = price_order[position]
					reveal(records, lot, layout, index, "quality")
					var tags: Array = []
					for tag_index: int in pick_indices(values.highest_tags, lot[index].tags.size(), rng):
						tags.append(lot[index].tags[tag_index])
					if not records[index].has("tags"):
						records[index]["tags"] = tags
						records[index]["partial_tags"] = true
				lines.append("珍品线索｜总价值最高的 %s 件：品质及最多 %s 个标签已公开" % [number(count), number(values.highest_tags)])
			"cheap": lines.append("廉价统计｜调整后基础价格低于 %s：%s 件" % [number(values.cheap_price), number(cheap)])
			"duplicates":
				var repeated: Array[String] = []
				for kind: String in kind_indices:
					if kind_indices[kind].size() > 1:
						repeated.append(kind)
				var selected: Array[int] = pick_indices(values.duplicate_kinds, repeated.size(), rng)
				for index: int in selected:
					var indices: Array = kind_indices[repeated[index]]
					for item_index: int in indices:
						reveal(records, lot, layout, item_index, "full")
					lines.append("重复货物｜%s ×%s，全部完整揭示" % [lot[indices[0]].name, number(indices.size())])
				if selected.is_empty():
					lines.append("重复货物｜本仓没有同款重复货物")
			"synergy":
				var active: Array[Dictionary] = []
				for group: Dictionary in appraisal.tags:
					if int(group.percent) > 0:
						active.append(group)
				for index: int in pick_indices(values.synergy_groups, active.size(), rng):
					lines.append("羁绊线索｜%s：%s 件，+%s%%" % [active[index].tag, number(active[index].count), number(active[index].percent)])
				if active.is_empty():
					lines.append("羁绊线索｜本仓没有激活的羁绊")
			"concentration":
				var count: int = mini(values.top_count, lot.size())
				var total: int = 0
				for position: int in count:
					total += int(appraisal.items[price_order[position]].effective_value)
				var percent: float = 100.0 * total / maxi(1, int(appraisal.total_value))
				var lower: int = floori(percent / int(values.share_band)) * int(values.share_band)
				lines.append("价值集中度｜最高价值的 %s 件占总价 %s%%–%s%%" % [number(count), number(lower), number(mini(100, lower + int(values.share_band)))])
			"absent":
				var absent: Array[String] = []
				for quality: int in quality_counts.size():
					if quality_counts[quality] == 0:
						absent.append("品质·" + Catalog.QUALITY_NAMES[quality])
				for tag: String in Catalog.TAGS:
					if not tag_counts.has(tag):
						absent.append("标签·" + tag)
				lines.append("缺席线索｜没有缺席的品质或标签" if absent.is_empty() else "缺席线索｜本仓没有" + absent[rng.randi_range(0, absent.size() - 1)])
	return {"intel": records, "lines": lines}

