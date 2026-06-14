class_name BuildStation
extends Control

signal sandwich_ready(ticket)

# Ingredient color palettes
const INGREDIENT_COLORS := {
	# Breads
	"White Sandwich": Color("#D4A574"),
	"Sourdough":      Color("#B8864E"),
	"Wheat":          Color("#9B7A45"),
	"Ciabatta":       Color("#C9A97A"),
	"Rye":            Color("#7A5C35"),
	# Cheeses
	"American":       Color("#F4D03F"),
	"Cheddar":        Color("#E67E22"),
	"Swiss":          Color("#F9E79F"),
	"Pepper Jack":    Color("#F0B27A"),
	"Provolone":      Color("#FAD7A0"),
	# Proteins
	"Turkey Slices":  Color("#F0A896"),
	"Ham":            Color("#FFB6C1"),
	"Bacon Strips":   Color("#C0392B"),
	"Salami":         Color("#A04040"),
	# Veggies
	"Lettuce":        Color("#82E0AA"),
	"Tomato":         Color("#E74C3C"),
	"Onion":          Color("#D7BDE2"),
	"Pickles":        Color("#A9DFBF"),
	"Jalapeños":      Color("#229954"),
	"Avocado":        Color("#52BE80"),
	# Sauces
	"Mustard":        Color("#F4D03F"),
	"Mayo":           Color("#FDFEFE"),
	"Ranch":          Color("#FDFEFE"),
	"Hot Sauce":      Color("#E74C3C"),
	"Pesto":          Color("#27AE60"),
}

const INGREDIENT_EMOJI := {
	"White Sandwich": "🍞", "Sourdough": "🥖", "Wheat": "🌾",
	"Ciabatta": "🫓", "Rye": "🍞",
	"American": "🧀", "Cheddar": "🧀", "Swiss": "🧀",
	"Pepper Jack": "🧀", "Provolone": "🧀",
	"Turkey Slices": "🦃", "Ham": "🍖", "Bacon Strips": "🥓", "Salami": "🍕",
	"Lettuce": "🥬", "Tomato": "🍅", "Onion": "🧅", "Pickles": "🥒",
	"Jalapeños": "🌶", "Avocado": "🥑",
	"Mustard": "🟡", "Mayo": "⚪", "Ranch": "⚪", "Hot Sauce": "🔴", "Pesto": "🟢",
}

var current_ticket = null
var tickets_queue: Array = []
var sandwich_layers: Array = []   # current stack contents
var bread_chosen: String = ""
var _phase: String = "idle"   # idle | choose_bread | add_cheese | add_toppings | done

# UI refs
var _ticket_panel: Control
var _tray_vbox: VBoxContainer
var _stack_vbox: VBoxContainer
var _status_label: Label
var _send_btn: Button
var _tab_bar: HBoxContainer
var _ticket_tabs: Array = []

func _ready():
	_build_ui()

func _build_ui():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg = Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s = StyleBoxFlat.new()
	s.bg_color = Color("#FFF8EF")
	bg.add_theme_stylebox_override("panel", s)
	add_child(bg)

	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 0)
	add_child(main_hbox)

	# === LEFT: Ticket + tray ===
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(300, 0)
	left_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_panel.add_theme_constant_override("separation", 0)
	main_hbox.add_child(left_panel)

	# Ticket tabs
	_tab_bar = HBoxContainer.new()
	_tab_bar.custom_minimum_size = Vector2(0, 36)
	_tab_bar.add_theme_constant_override("separation", 2)
	left_panel.add_child(_tab_bar)

	# Ticket display panel — expand horizontally, fixed min height
	_ticket_panel = Panel.new()
	_ticket_panel.custom_minimum_size = Vector2(0, 210)
	_ticket_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ticket_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var tp_style = StyleBoxFlat.new()
	tp_style.bg_color = Color("#FFFDE7")
	tp_style.border_color = Color("#F39C12")
	tp_style.set_border_width_all(2)
	tp_style.set_corner_radius_all(8)
	_ticket_panel.add_theme_stylebox_override("panel", tp_style)
	left_panel.add_child(_ticket_panel)
	_build_ticket_display()

	# Tray labels
	var tray_header = _make_label("INGREDIENTS", 14, Color("#E74C3C"), true)
	var th_margin = _wrap_margin(tray_header, 4, 4, 6, 4)
	left_panel.add_child(th_margin)

	# Ingredient tray scrolls
	var tray_scroll = ScrollContainer.new()
	tray_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(tray_scroll)

	_tray_vbox = VBoxContainer.new()
	_tray_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tray_vbox.add_theme_constant_override("separation", 6)
	var tray_m = MarginContainer.new()
	tray_m.add_theme_constant_override("margin_left", 6)
	tray_m.add_theme_constant_override("margin_right", 6)
	tray_m.add_theme_constant_override("margin_top", 6)
	tray_m.add_theme_constant_override("margin_bottom", 6)
	tray_m.add_child(_tray_vbox)
	tray_scroll.add_child(tray_m)

	# === RIGHT: Sandwich stack + controls ===
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_constant_override("separation", 8)
	main_hbox.add_child(right_panel)

	var right_m = MarginContainer.new()
	right_m.add_theme_constant_override("margin_left", 12)
	right_m.add_theme_constant_override("margin_right", 12)
	right_m.add_theme_constant_override("margin_top", 12)
	right_m.add_theme_constant_override("margin_bottom", 12)
	right_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(right_m)

	var right_inner = VBoxContainer.new()
	right_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_inner.add_theme_constant_override("separation", 10)
	right_m.add_child(right_inner)

	var stack_title = _make_label("🥪 SANDWICH BUILDER", 16, Color("#2C3E50"), true)
	stack_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_inner.add_child(stack_title)

	_status_label = _make_label("Take an order to begin", 14, Color("#95A5A6"), false)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_inner.add_child(_status_label)

	# Stack scroll area
	var stack_scroll = ScrollContainer.new()
	stack_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_inner.add_child(stack_scroll)

	_stack_vbox = VBoxContainer.new()
	_stack_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stack_vbox.alignment = BoxContainer.ALIGNMENT_END  # stack grows upward from bottom
	_stack_vbox.add_theme_constant_override("separation", 3)
	stack_scroll.add_child(_stack_vbox)

	# Plate/cutting board area at bottom of stack
	var board = Panel.new()
	board.custom_minimum_size = Vector2(0, 20)
	var bs = StyleBoxFlat.new()
	bs.bg_color = Color("#D4A56A")
	bs.set_corner_radius_all(4)
	board.add_theme_stylebox_override("panel", bs)
	_stack_vbox.add_child(board)

	# Clear + Send buttons
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	right_inner.add_child(btn_row)

	var clear_btn = Button.new()
	clear_btn.text = "Clear Stack"
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_btn(clear_btn, Color("#E74C3C"), Color.WHITE)
	clear_btn.pressed.connect(_on_clear_pressed)
	btn_row.add_child(clear_btn)

	_send_btn = Button.new()
	_send_btn.text = "Send to Grill →"
	_send_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_btn(_send_btn, Color("#27AE60"), Color.WHITE)
	_send_btn.disabled = true
	_send_btn.pressed.connect(_on_send_to_grill)
	btn_row.add_child(_send_btn)

func _build_ticket_display():
	for child in _ticket_panel.get_children():
		child.queue_free()

	# Panel is NOT a Container, so the MarginContainer must anchor itself to fill it.
	var m = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	_ticket_panel.add_child(m)

	# MarginContainer manages its child's size automatically — no preset needed.
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	m.add_child(vbox)

	if current_ticket == null:
		var lbl = _make_label("No active order", 13, Color("#BDC3C7"), false)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lbl)
		return

	var t = current_ticket
	var title = _make_label("Order: " + t.customer_name, 15, t.customer_color, true)
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	_add_ticket_row(vbox, "🍞 Bread", t.bread)
	_add_ticket_row(vbox, "🧀 Cheese", t.cheese)
	if t.toppings.size() > 0:
		_add_ticket_row(vbox, "🥗 Toppings", ", ".join(t.toppings))
	_add_ticket_row(vbox, "🔥 Grill", t.doneness)
	_add_ticket_row(vbox, "🍟 Side", t.side)
	if t.side_toppings.size() > 0:
		_add_ticket_row(vbox, "🧂 Side Tops", ", ".join(t.side_toppings))

func _add_ticket_row(parent: VBoxContainer, key: String, value: String):
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var k = _make_label(key, 12, Color("#7F8C8D"), false)
	k.custom_minimum_size.x = 90
	k.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(k)

	var v = _make_label(value, 12, Color("#2C3E50"), true)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Use horizontal word-wrap only — this works correctly once the parent has real width
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(v)

# === Ticket management ===

func add_ticket(ticket):
	tickets_queue.append(ticket)
	_refresh_tabs()
	if current_ticket == null:
		_activate_ticket(ticket)

func _refresh_tabs():
	for child in _tab_bar.get_children():
		child.queue_free()
	_ticket_tabs.clear()

	for t in tickets_queue:
		var btn = Button.new()
		btn.text = t.customer_name
		btn.toggle_mode = true
		btn.button_pressed = (t == current_ticket)
		btn.custom_minimum_size = Vector2(90, 32)
		btn.add_theme_font_size_override("font_size", 12)
		_style_btn(btn, t.customer_color if t == current_ticket else Color("#BDC3C7"), Color.WHITE)
		btn.pressed.connect(_activate_ticket.bind(t))
		_tab_bar.add_child(btn)
		_ticket_tabs.append(btn)

func _activate_ticket(ticket):
	current_ticket = ticket
	bread_chosen = ""
	sandwich_layers.clear()
	_phase = "choose_bread"
	_refresh_tabs()
	_build_ticket_display()
	_rebuild_tray()
	_refresh_stack()
	_update_status()

# === Tray building ===

func _rebuild_tray():
	for child in _tray_vbox.get_children():
		child.queue_free()

	if current_ticket == null:
		return

	_add_tray_section("BREADS", GameState.unlocked_ingredients["breads"])
	_add_tray_section("CHEESES", GameState.unlocked_ingredients["cheeses"])
	_add_tray_section("PROTEINS", GameState.unlocked_ingredients["proteins"])
	_add_tray_section("VEGGIES", GameState.unlocked_ingredients["veggies"])
	_add_tray_section("SAUCES", GameState.unlocked_ingredients["sauces"])

func _add_tray_section(title: String, items: Array):
	var header = _make_label(title, 11, Color("#95A5A6"), true)
	_tray_vbox.add_child(header)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_tray_vbox.add_child(grid)

	for item in items:
		var btn = _make_ingredient_btn(item)
		grid.add_child(btn)

func _make_ingredient_btn(ingredient: String) -> Button:
	var btn = Button.new()
	var emoji = INGREDIENT_EMOJI.get(ingredient, "•")
	btn.text = "%s %s" % [emoji, ingredient]
	btn.custom_minimum_size = Vector2(114, 36)
	btn.add_theme_font_size_override("font_size", 11)
	btn.clip_text = true
	var col = INGREDIENT_COLORS.get(ingredient, Color("#BDC3C7"))
	_style_btn(btn, col, _contrast_color(col))
	btn.pressed.connect(_on_ingredient_pressed.bind(ingredient))
	return btn

func _contrast_color(bg: Color) -> Color:
	return Color.BLACK if bg.get_luminance() > 0.5 else Color.WHITE

# === Game logic ===

func _on_ingredient_pressed(ingredient: String):
	if current_ticket == null:
		return

	match _phase:
		"choose_bread":
			if _is_bread(ingredient):
				bread_chosen = ingredient
				sandwich_layers.clear()
				sandwich_layers.append("BOTTOM_BREAD:" + ingredient)
				_phase = "add_cheese"
				_update_status()
				_refresh_stack()
		"add_cheese":
			if _is_cheese(ingredient):
				sandwich_layers.append("CHEESE:" + ingredient)
				_phase = "add_toppings"
				_update_status()
				_refresh_stack()
		"add_toppings":
			if not _is_bread(ingredient) and not _is_cheese(ingredient):
				sandwich_layers.append("TOPPING:" + ingredient)
				_refresh_stack()
				_check_send_ready()

func _is_bread(ingredient: String) -> bool:
	return ingredient in GameState.unlocked_ingredients["breads"]

func _is_cheese(ingredient: String) -> bool:
	return ingredient in GameState.unlocked_ingredients["cheeses"]

func _on_clear_pressed():
	sandwich_layers.clear()
	bread_chosen = ""
	_phase = "choose_bread" if current_ticket else "idle"
	_send_btn.disabled = true
	_refresh_stack()
	_update_status()

func _check_send_ready():
	if current_ticket == null:
		_send_btn.disabled = true
		return
	# Need at least bread + cheese
	var has_bread = false
	var has_cheese = false
	for layer in sandwich_layers:
		if layer.begins_with("BOTTOM_BREAD:"): has_bread = true
		if layer.begins_with("CHEESE:"): has_cheese = true
	_send_btn.disabled = not (has_bread and has_cheese)

func _on_send_to_grill():
	if current_ticket == null or not _can_send():
		return

	# Calculate build score
	_compute_build_score()

	var ticket = current_ticket
	tickets_queue.erase(ticket)
	current_ticket = null
	sandwich_layers.clear()
	bread_chosen = ""
	_phase = "idle"
	_send_btn.disabled = true

	_refresh_tabs()
	if tickets_queue.size() > 0:
		_activate_ticket(tickets_queue[0])
	else:
		_build_ticket_display()
		_rebuild_tray()
		_refresh_stack()
		_update_status()

	emit_signal("sandwich_ready", ticket)

func _can_send() -> bool:
	var has_bread = false
	var has_cheese = false
	for layer in sandwich_layers:
		if layer.begins_with("BOTTOM_BREAD:"): has_bread = true
		if layer.begins_with("CHEESE:"): has_cheese = true
	return has_bread and has_cheese

func _compute_build_score():
	if current_ticket == null:
		return

	var t = current_ticket
	var scores: Array = []

	# Bread score
	var placed_bread = ""
	for layer in sandwich_layers:
		if layer.begins_with("BOTTOM_BREAD:"):
			placed_bread = layer.substr("BOTTOM_BREAD:".length())
	scores.append(1.0 if placed_bread == t.bread else 0.0)

	# Cheese score
	var placed_cheese = ""
	for layer in sandwich_layers:
		if layer.begins_with("CHEESE:"):
			placed_cheese = layer.substr("CHEESE:".length())
	scores.append(1.0 if placed_cheese == t.cheese else 0.0)

	# Toppings: each required topping scored, extra toppings penalise
	var placed_tops: Array[String] = []
	for layer in sandwich_layers:
		if layer.begins_with("TOPPING:"):
			placed_tops.append(layer.substr("TOPPING:".length()))

	for req in t.toppings:
		scores.append(1.0 if req in placed_tops else 0.0)

	# Extra topping penalty: -20% per extra
	var extra = 0
	for pt in placed_tops:
		if not pt in t.toppings:
			extra += 1
	var penalty = extra * 0.20

	var raw = 0.0
	for s in scores:
		raw += s
	if scores.size() > 0:
		raw = raw / float(scores.size())

	t.build_score = clampf(raw - penalty, 0.0, 1.0) * t.strictness
	t.build_score = clampf(t.build_score, 0.0, 1.0)

# === Stack visual ===

func _refresh_stack():
	# Keep only the cutting board (last child)
	var children = _stack_vbox.get_children()
	for i in range(children.size() - 1):
		children[i].queue_free()
	await get_tree().process_frame

	var display_layers = sandwich_layers.duplicate()
	# Add top bread placeholder
	if bread_chosen != "":
		display_layers.append("TOP_BREAD:" + bread_chosen)

	for layer_str in display_layers:
		var parts = layer_str.split(":")
		var kind = parts[0]
		var name_str = parts[1] if parts.size() > 1 else ""
		var layer_node = _make_layer_visual(kind, name_str)
		_stack_vbox.add_child(layer_node)
		_stack_vbox.move_child(layer_node, _stack_vbox.get_child_count() - 2)  # above board

func _make_layer_visual(kind: String, ingredient: String) -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 24)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var col: Color
	var display_text: String
	match kind:
		"BOTTOM_BREAD", "TOP_BREAD":
			col = INGREDIENT_COLORS.get(ingredient, Color("#D4A574"))
			display_text = "🍞 " + ingredient + (" (bottom)" if kind == "BOTTOM_BREAD" else " (top)")
		"CHEESE":
			col = INGREDIENT_COLORS.get(ingredient, Color("#F4D03F"))
			display_text = "🧀 " + ingredient
		"TOPPING":
			col = INGREDIENT_COLORS.get(ingredient, Color("#BDC3C7"))
			var emoji = INGREDIENT_EMOJI.get(ingredient, "•")
			display_text = emoji + " " + ingredient
		_:
			col = Color("#BDC3C7")
			display_text = ingredient

	var style = StyleBoxFlat.new()
	style.bg_color = col
	style.border_color = col.darkened(0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)

	var lbl = Label.new()
	lbl.text = display_text
	lbl.add_theme_color_override("font_color", _contrast_color(col))
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(lbl)

	return panel

func _update_status():
	if current_ticket == null:
		_status_label.text = "No active order. Take an order first."
		_status_label.add_theme_color_override("font_color", Color("#95A5A6"))
		return

	match _phase:
		"choose_bread":
			_status_label.text = "Step 1: Choose a bread type"
			_status_label.add_theme_color_override("font_color", Color("#E67E22"))
		"add_cheese":
			_status_label.text = "Step 2: Add cheese"
			_status_label.add_theme_color_override("font_color", Color("#F39C12"))
		"add_toppings":
			_status_label.text = "Step 3: Add toppings, then Send to Grill"
			_status_label.add_theme_color_override("font_color", Color("#27AE60"))
		"idle":
			_status_label.text = "Take an order to begin"
			_status_label.add_theme_color_override("font_color", Color("#95A5A6"))

# === Helpers ===

func _make_label(text: String, font_size: int, color: Color, _bold: bool) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	return lbl

func _wrap_margin(child: Control, l: int, r: int, t: int, b: int) -> MarginContainer:
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(child)
	return m

func _style_btn(btn: Button, bg: Color, fg: Color):
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s = StyleBoxFlat.new()
		match state:
			"normal":   s.bg_color = bg
			"hover":    s.bg_color = bg.lightened(0.15)
			"pressed":  s.bg_color = bg.darkened(0.15)
			"disabled": s.bg_color = Color(0.6, 0.6, 0.6)
		s.set_corner_radius_all(6)
		s.set_border_width_all(1)
		s.border_color = bg.darkened(0.2)
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_disabled_color", Color(0.8, 0.8, 0.8))
