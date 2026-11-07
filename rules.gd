extends Resource
## Host room rules. Schema reads these defaults; runtime receives the host snapshot.
const EARLY_WIN_PERCENT: Array[int] = [200, 160, 130, 110]
const BID_UNIT: int = 100
const REVEAL_DELAY: float = 2.0
@export_range(1, 10) var warehouses: int = 3
@export_range(1, 5) var rounds: int = 5
@export_range(1000, 1000000, 100) var initialcoins: int = 10000
@export_range(5.0, 300.0) var round_seconds: float = 15.0
@export var item_counts: Array[int] = [15, 30]
@export var quality_weights: Array[int] = [120, 90, 60, 40, 20, 6, 2]

func configure(settings: Dictionary) -> Error:
	warehouses = int(settings.get("warehouses", warehouses))
	rounds = int(settings.get("rounds", rounds))
	initialcoins = int(settings.get("coins", initialcoins))
	round_seconds = float(settings.get("round_seconds", round_seconds))
	item_counts.assign(settings.get("item_counts", item_counts))
	quality_weights.assign(settings.get("quality_weights", quality_weights))
	if item_counts.size() != 2 or item_counts[0] < 1 or item_counts[1] < item_counts[0] or item_counts[1] > 100:
		return ERR_INVALID_PARAMETER
	if warehouses < 1 or warehouses > 10 or rounds < 1 or rounds > 5 or initialcoins < 1000 or initialcoins > 1000000 or round_seconds < 5 or round_seconds > 300:
		return ERR_INVALID_PARAMETER
	if quality_weights.size() != 7:
		return ERR_INVALID_PARAMETER
	var total: int = 0
	for weight: int in quality_weights:
		if weight < 0 or weight > 10000:
			return ERR_INVALID_PARAMETER
		total += weight
	return OK if total > 0 else ERR_INVALID_PARAMETER
