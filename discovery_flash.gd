extends Control
## A single soft flare on real high-quality discoveries, never on search duration.
const Catalog: Script = preload("res://games/minigame/gp_auction_master/item_catalog.gd")
@export_range(0, 6) var minimum_quality: int = 3
@export_range(0.1, 2.0) var duration: float = 0.85
@export_range(0.0, 1.0) var intensity: float = 0.65
var age: float = 10.0
var quality: int = 0
var center: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func reveal(value: int, screen_center: Vector2) -> void:
	if value < minimum_quality:
		return
	quality = value
	center = get_global_transform_with_canvas().affine_inverse() * screen_center
	age = 0.0
	set_process(true)
	queue_redraw()

func clear() -> void:
	age = duration
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= duration:
		set_process(false)

func _draw() -> void:
	if age >= duration:
		return
	var progress: float = age / duration
	var strength: float = intensity * sin(minf(1.0, progress / 0.08) * PI * 0.5) * pow(1.0 - progress, 2.0)
	var tint: Color = Catalog.QUALITY_COLORS[quality]
	if quality == 6:
		tint = Color.from_hsv(fposmod(progress * 0.5 + 0.08, 1.0), 0.4, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(tint, strength * 0.05))
	# Smooth edge glow and an expanding bloom; no hard frame or repeated strobing.
	var edge: Color = Color(tint, strength * 0.28)
	var clear_color: Color = Color(tint, 0.0)
	var corners: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	for side: int in 4:
		var first: Vector2 = corners[side]
		var last: Vector2 = corners[(side + 1) % 4]
		var inward: Vector2 = (last - first).normalized().orthogonal() * -60.0
		draw_polygon(PackedVector2Array([first, last, last + inward, first + inward]), PackedColorArray([edge, edge, clear_color, clear_color]))
	for band: int in 32:
		var radius: float = (12.0 + band * 5.0) * (1.0 + progress * 1.4)
		draw_circle(center, radius, Color(tint, strength * 0.012))
	var light: Color = tint.lerp(Color.WHITE, 0.7)
	for ray: int in 8:
		var direction: Vector2 = Vector2.from_angle(ray * TAU / 8.0)
		var length: float = (350.0 if ray % 4 == 0 else 150.0) * (0.7 + progress)
		var width: float = 7.0 if ray % 4 == 0 else 3.0
		var normal: Vector2 = direction.orthogonal() * width
		draw_polygon(PackedVector2Array([center + normal, center + direction * length, center - normal]), PackedColorArray([Color(light, strength * 0.8), Color(light, 0.0), Color(light, strength * 0.8)]))
