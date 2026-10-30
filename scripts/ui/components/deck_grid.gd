class_name UiDeckGrid
extends UiDeckSurface
## Compose action specifications into a bounded command panel.
const COLUMNS := 3
const GAP := 6
var title: Label
var scroll: ScrollContainer
var grid: GridContainer
var tile_width := UiDeckAction.DEFAULT_SIZE.x
var max_rows := 3


func _init() -> void:
	super()
	accented = true
	custom_minimum_size.y = 0
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var heading := UiKit.header("Orders")
	title = heading.get_node("Text") as Label
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(heading)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	scroll.add_child(grid)
	fit_width(348)


func add_action(spec: Dictionary, callback := Callable()) -> UiDeckAction:
	var button := UiDeckAction.new()
	button.configure(spec)
	button.custom_minimum_size.x = tile_width
	if callback.is_valid():
		button.pressed.connect(callback)
	grid.add_child(button)
	refresh_layout()
	return button


func clear_actions() -> void:
	for button in grid.get_children():
		grid.remove_child(button)
		button.queue_free()
	scroll.scroll_vertical = 0
	refresh_layout()


func fit_width(available: float) -> void:
	var next_width := clampf(floorf((available - 48) / COLUMNS), 80, UiDeckAction.DEFAULT_SIZE.x)
	if next_width != tile_width:
		tile_width = next_width
		for button: Control in grid.get_children():
			button.custom_minimum_size.x = tile_width
	scroll.custom_minimum_size.x = tile_width * COLUMNS + 24
	refresh_layout()


func refresh_layout() -> void:
	var rows := clampi(ceili(grid.get_child_count() / float(COLUMNS)), 1, max_rows)
	scroll.custom_minimum_size.y = rows * (UiDeckAction.DEFAULT_SIZE.y + GAP) - GAP
