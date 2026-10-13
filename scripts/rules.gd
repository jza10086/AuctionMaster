extends Resource
## Adjustable auction rules. Production defaults are three five-round warehouses.
@export_range(1, 20) var rounds: int = 5
@export_range(1, 20) var warehouses: int = 3
@export_range(1, 1000000) var initialcoins: int = 10000
@export_range(5.0, 300.0) var round_seconds: float = 30.0
