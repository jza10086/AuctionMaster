extends Control
## Static catalogue only: never consumes the current warehouse or private discoveries.
const Catalog: Script = preload("res://games/minigame/godot_party_default_auction_master/item_catalog.gd")
const ItemCard: PackedScene = preload("res://games/minigame/godot_party_default_auction_master/catalog_item.tscn")
@onready var grid: GridContainer = %CatalogGrid
@onready var search: LineEdit = %CatalogSearch

func _ready() -> void:
	%CloseCatalog.pressed.connect(hide)
	search.text_changed.connect(_filter)
	%Synergy.text = Catalog.RULE_TEXT

func open_catalog() -> void:
	if grid.get_child_count() == 0:
		var items: Array[Dictionary] = Catalog.new().items.duplicate(true)
		items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.quality) < int(b.quality) if a.quality != b.quality else int(a.value) < int(b.value))
		for item: Dictionary in items:
			var card: VBoxContainer = ItemCard.instantiate()
			grid.add_child(card)
			card.get_node("Icon").texture = load("res://games/minigame/godot_party_default_auction_master/assets/items/realistic/%s.png" % item.kind)
			card.get_node("Title").text = item.name
			card.get_node("Title").add_theme_color_override("font_color", Catalog.QUALITY_COLORS[int(item.quality)])
			card.get_node("Stripe").visible = int(item.quality) == 6
			card.get_node("Info").text = "%s · %d × %d 格\n基础价格 %s\n%s" % [Catalog.QUALITY_NAMES[int(item.quality)], item.size[0], item.size[1], _number(int(item.value)), " / ".join(item.tags)]
			card.set_meta("search", (str(item.name) + " " + " ".join(item.tags) + " " + Catalog.QUALITY_NAMES[int(item.quality)]).to_lower())
	_filter(search.text)
	show()

func _filter(query: String) -> void:
	var term: String = query.strip_edges().to_lower()
	for card: Control in grid.get_children():
		card.visible = term.is_empty() or term in str(card.get_meta("search"))

func _number(value: int) -> String:
	var digits: String = str(value)
	var result: String = ""
	for index: int in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits[index]
	return result
