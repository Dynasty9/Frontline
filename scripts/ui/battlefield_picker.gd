class_name BattlefieldPicker
extends OptionButton

signal picked(key: String)


func _init() -> void:
	custom_minimum_size.y = 30
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry: Dictionary in Battlefields.MAPS:
		add_item("%s  ·  %d m" % [String(entry.title).to_upper(), int(entry.size)])
		set_item_metadata(item_count - 1, entry.key)
		set_item_tooltip(item_count - 1, entry.description)
	item_selected.connect(func(i: int): picked.emit(String(get_item_metadata(i))))
	tooltip_text = "Choose the ground before deploying. Every commander joins the same battlefield."


func select_key(key: String) -> void:
	for i in item_count:
		if String(get_item_metadata(i)) == key:
			select(i)
			return
	select(-1)
