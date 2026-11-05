extends Resource
## Auction-wide rules; solo practice keeps five rounds without early settlement.
const ROUNDS: int = 5
const EARLY_WIN_PERCENT: Array[int] = [200, 160, 130, 110]
@export_range(1, 20) var warehouses: int = 3
@export_range(1, 1000000) var initialcoins: int = 10000
@export_range(5.0, 300.0) var round_seconds: float = 15.0
