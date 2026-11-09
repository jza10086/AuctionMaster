extends Resource
## Host room rules. Schema reads these defaults; runtime receives the host snapshot.
const Conditions: Script = preload("res://games/minigame/godot_party_default_auction_master/warehouse_conditions.gd")
const BID_UNIT: int = 1
@export var conditions: Conditions = Conditions.new()
const ITEMS_END: float = 0.5
const TOTAL_END: float = 0.6
const PROFIT_END: float = 0.75
const PAYOUT_END: float = 0.95
@export_range(1, 10) var warehouses: int = 3
@export_range(1, 5) var rounds: int = 5
@export_range(1000, 1000000, 100) var initialcoins: int = 80000
@export_range(5.0, 300.0) var round_seconds: float = 60.0
@export_range(1.0, 60.0) var reveal_seconds: float = 10.0
@export_range(10.0, 180.0) var settlement_seconds: float = 90.0
@export var search_seconds: Array[float] = [0.08, 0.14, 0.35, 0.85, 1.7, 2.8, 4.2]
@export_range(0, 100) var search_jitter_percent: int = 15
@export_range(0, 100) var search_fakeout_percent: int = 5
@export_range(0, 5) var search_fakeout_quality: int = 1
@export var search_fakeout_seconds: Array[float] = [1.8, 4.2]
@export var item_counts: Array[int] = [20, 40]
@export var quality_weights: Array[int] = [120, 90, 60, 40, 20, 6, 2]

func configure(settings: Dictionary) -> Error:
	warehouses = int(settings.get("warehouses", warehouses))
	rounds = int(settings.get("rounds", rounds))
	initialcoins = int(settings.get("coins", initialcoins))
	round_seconds = float(settings.get("round_seconds", round_seconds))
	reveal_seconds = float(settings.get("reveal_seconds", reveal_seconds))
	settlement_seconds = float(settings.get("settlement_seconds", settlement_seconds))
	search_seconds.assign(settings.get("search_seconds", search_seconds))
	search_jitter_percent = int(settings.get("search_jitter_percent", search_jitter_percent))
	search_fakeout_percent = int(settings.get("search_fakeout_percent", search_fakeout_percent))
	search_fakeout_quality = int(settings.get("search_fakeout_quality", search_fakeout_quality))
	search_fakeout_seconds.assign(settings.get("search_fakeout_seconds", search_fakeout_seconds))
	if search_seconds.size() != 7 or search_fakeout_seconds.size() != 2:
		return ERR_INVALID_PARAMETER
	for seconds: float in search_seconds + search_fakeout_seconds:
		if not is_finite(seconds) or seconds < 0.02 or seconds > 15.0:
			return ERR_INVALID_PARAMETER
	if search_fakeout_seconds[0] > search_fakeout_seconds[1] or search_jitter_percent < 0 or search_jitter_percent > 100 or search_fakeout_percent < 0 or search_fakeout_percent > 100 or search_fakeout_quality < 0 or search_fakeout_quality > 5:
		return ERR_INVALID_PARAMETER
	item_counts.assign(settings.get("item_counts", item_counts))
	quality_weights.assign(settings.get("quality_weights", quality_weights))
	if item_counts.size() != 2 or item_counts[0] < 1 or item_counts[1] < item_counts[0] or item_counts[1] > 100:
		return ERR_INVALID_PARAMETER
	if warehouses < 1 or warehouses > 10 or rounds < 1 or rounds > 5 or initialcoins < 1000 or initialcoins > 1000000 or round_seconds < 5 or round_seconds > 300 or reveal_seconds < 1 or reveal_seconds > 60 or settlement_seconds < 10 or settlement_seconds > 180:
		return ERR_INVALID_PARAMETER
	if quality_weights.size() != 7:
		return ERR_INVALID_PARAMETER
	var total: int = 0
	for weight: int in quality_weights:
		if weight < 0 or weight > 10000:
			return ERR_INVALID_PARAMETER
		total += weight
	return conditions.configure(settings) if total > 0 else ERR_INVALID_PARAMETER

## The host rolls uncertainty once. Only completion times are sent, never a fakeout flag.
## Compress long inventories into the search window; never stretch cheap-only lots.
func make_search_ends(items: Array, rng: RandomNumberGenerator) -> Array[float]:
	var lengths: Array[float] = []
	var total: float = 0.0
	for item: Dictionary in items:
		var quality: int = int(item.quality)
		var seconds: float = search_seconds[quality]
		if quality <= search_fakeout_quality and rng.randf() * 100.0 < search_fakeout_percent:
			seconds = maxf(seconds, rng.randf_range(search_fakeout_seconds[0], search_fakeout_seconds[1]))
		seconds *= rng.randf_range(1.0 - search_jitter_percent / 100.0, 1.0 + search_jitter_percent / 100.0)
		seconds = maxf(0.02, seconds)
		lengths.append(seconds)
		total += seconds
	var scale: float = minf(1.0, (settlement_seconds * ITEMS_END - 0.8) / total)
	var ends: Array[float] = []
	var elapsed: float = 0.0
	for seconds: float in lengths:
		elapsed += seconds * scale
		ends.append(elapsed)
	return ends

static func revealed_items(ends: Array, elapsed: float) -> int:
	var count: int = 0
	for end: float in ends:
		if elapsed < end:
			break
		count += 1
	return count
