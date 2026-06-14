class_name OrderStation
extends Control

const _OrderTicket = preload("res://scripts/OrderTicket.gd")

signal order_taken(ticket)
signal plate_served(ticket)

const PATIENCE_DRAIN_IDLE   := 1.0    # % per second before order taken
const PATIENCE_DRAIN_ACTIVE := 0.5    # % per second while food being made

const CUSTOMER_DATA := [
	{
		"name": "Marco", "patience": 90.0, "color": Color("#3498DB"),
		"fav_bread": "Sourdough", "fav_cheese": "American",
		"fav_toppings": ["Turkey Slices", "Mustard", "Tomato"],
		"strictness": 0.8, "fav_side": "Classic Fries", "fav_side_toppings": ["Ketchup"],
	},
	{
		"name": "Leila", "patience": 60.0, "color": Color("#9B59B6"),
		"fav_bread": "Wheat", "fav_cheese": "Swiss",
		"fav_toppings": ["Avocado", "Bacon Strips", "Ranch"],
		"strictness": 1.0, "fav_side": "Classic Fries", "fav_side_toppings": ["Cheese Sauce"],
	},
	{
		"name": "Dev", "patience": 40.0, "color": Color("#27AE60"),
		"fav_bread": "Ciabatta", "fav_cheese": "Pepper Jack",
		"fav_toppings": ["Salami", "Jalapeños", "Pesto"],
		"strictness": 1.2, "fav_side": "Classic Fries", "fav_side_toppings": [],
	},
	{
		"name": "Rosa", "patience": 90.0, "color": Color("#E91E8C"),
		"fav_bread": "White Sandwich", "fav_cheese": "Swiss",
		"fav_toppings": ["Ham", "Mayo", "Pickles"],
		"strictness": 1.0, "fav_side": "Classic Fries", "fav_side_toppings": ["Ketchup"],
	},
	{
		"name": "Theo", "patience": 60.0, "color": Color("#E67E22"),
		"fav_bread": "Rye", "fav_cheese": "Cheddar",
		"fav_toppings": ["Turkey Slices", "Onion", "Hot Sauce"],
		"strictness": 1.5, "fav_side": "Classic Fries", "fav_side_toppings": ["Salt & Vinegar"],
	},
]

# Active customers: each entry = { "data": {...}, "patience": float, "ticket": OrderTicket|null, "node": Control }
var active_customers: Array = []
var completed_plates: Array = []   # { "ticket": OrderTicket, "node": Control }
var _shift_elapsed: float = 0.0

# Layout refs
var _queue_vbox: VBoxContainer
var _plates_vbox: VBoxContainer

var _next_customer_data_idx: int = 0
var _customer_spawn_queue: Array = []

func _ready():
	_build_ui()

func _build_ui():
	custom_minimum_size = Vector2(280, 660)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var bg = Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style = _panel_style(Color("#FFF3E0"), Color("#E67E22"), 2, 0)
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	# Header
	var header = _make_section_header("CUSTOMERS", Color("#E67E22"))
	vbox.add_child(header)

	# Scroll for customer queue
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_queue_vbox = VBoxContainer.new()
	_queue_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_queue_vbox.add_theme_constant_override("separation", 8)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.add_child(_queue_vbox)
	scroll.add_child(margin)

	# Ready to serve header
	var serve_header = _make_section_header("READY TO SERVE", Color("#27AE60"))
	vbox.add_child(serve_header)

	var serve_scroll = ScrollContainer.new()
	serve_scroll.custom_minimum_size = Vector2(0, 200)
	serve_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(serve_scroll)

	_plates_vbox = VBoxContainer.new()
	_plates_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plates_vbox.add_theme_constant_override("separation", 6)
	var plates_margin = MarginContainer.new()
	plates_margin.add_theme_constant_override("margin_left", 8)
	plates_margin.add_theme_constant_override("margin_right", 8)
	plates_margin.add_theme_constant_override("margin_top", 6)
	plates_margin.add_theme_constant_override("margin_bottom", 6)
	plates_margin.add_child(_plates_vbox)
	serve_scroll.add_child(plates_margin)

func _make_section_header(title: String, color: Color) -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 32)
	var style = StyleBoxFlat.new()
	style.bg_color = color
	panel.add_theme_stylebox_override("panel", style)
	var lbl = Label.new()
	lbl.text = title
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(lbl)
	return panel

func _panel_style(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	return s

# === Spawning ===

func setup_spawn_queue(unlocked_breads: Array, _unlocked_sides: Array):
	_customer_spawn_queue.clear()
	_next_customer_data_idx = 0
	# Filter customers whose fav_bread is unlocked
	var valid: Array = []
	for cd in CUSTOMER_DATA:
		if cd["fav_bread"] in unlocked_breads or unlocked_breads.size() >= 3:
			valid.append(cd)
	if valid.is_empty():
		valid = [CUSTOMER_DATA[0]]
	_customer_spawn_queue = valid.duplicate()
	_customer_spawn_queue.shuffle()

func spawn_customer():
	if active_customers.size() >= 2:
		return
	if _customer_spawn_queue.is_empty():
		return

	var cd = _customer_spawn_queue[_next_customer_data_idx % _customer_spawn_queue.size()]
	_next_customer_data_idx += 1

	var ticket = _generate_ticket(cd)
	var node = _make_customer_widget(cd, ticket)
	_queue_vbox.add_child(node)

	active_customers.append({
		"data": cd,
		"patience": cd["patience"],
		"max_patience": cd["patience"],
		"ticket": ticket,
		"node": node,
		"order_taken": false,
	})

func _generate_ticket(cd: Dictionary):
	var t = _OrderTicket.new()
	t.customer_name = cd["name"]
	t.customer_color = cd["color"]
	t.strictness = cd["strictness"]

	var breads = GameState.unlocked_ingredients["breads"]
	t.bread = cd["fav_bread"] if cd["fav_bread"] in breads else breads[0]

	var cheeses = GameState.unlocked_ingredients["cheeses"]
	t.cheese = cd["fav_cheese"] if cd["fav_cheese"] in cheeses else cheeses[0]

	# Pick 1-3 toppings from fav + available
	var all_tops: Array = GameState.unlocked_ingredients["proteins"].duplicate()
	all_tops.append_array(GameState.unlocked_ingredients["veggies"])
	all_tops.append_array(GameState.unlocked_ingredients["sauces"])

	t.toppings.clear()
	for fav in cd["fav_toppings"]:
		if fav in all_tops and t.toppings.size() < 3:
			t.toppings.append(fav)

	var doneness_choices = ["Light", "Medium", "Well Done"]
	t.doneness = doneness_choices[randi() % 3]

	var sides = GameState.unlocked_ingredients["sides"]
	t.side = cd["fav_side"] if cd["fav_side"] in sides else sides[0]

	t.side_toppings.clear()
	for st in cd["fav_side_toppings"]:
		if st in GameState.unlocked_ingredients["side_toppings"]:
			t.side_toppings.append(st)

	return t

func _make_customer_widget(cd: Dictionary, ticket) -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(260, 110)
	var style = _panel_style(Color.WHITE, cd["color"], 3, 8)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_meta("customer_color", cd["color"])
	panel.set_meta("ticket", ticket)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 8)
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	m.add_child(hbox)
	panel.add_child(m)

	# Avatar
	var avatar = _make_avatar(cd["color"], cd["name"][0])
	hbox.add_child(avatar)

	# Info column
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = cd["name"]
	name_label.add_theme_color_override("font_color", cd["color"])
	name_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(name_label)

	var patience_bar = ProgressBar.new()
	patience_bar.name = "PatienceBar"
	patience_bar.custom_minimum_size = Vector2(0, 14)
	patience_bar.max_value = 100
	patience_bar.value = 100
	patience_bar.show_percentage = false
	info_vbox.add_child(patience_bar)

	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Tap to take order"
	status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	status_label.add_theme_font_size_override("font_size", 11)
	info_vbox.add_child(status_label)

	var take_btn = Button.new()
	take_btn.name = "TakeOrderBtn"
	take_btn.text = "Take Order"
	take_btn.custom_minimum_size = Vector2(0, 26)
	_style_button(take_btn, cd["color"], Color.WHITE)
	info_vbox.add_child(take_btn)
	take_btn.pressed.connect(_on_take_order_pressed.bind(panel, ticket))

	return panel

func _make_avatar(color: Color, initial: String) -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(60, 60)

	var circle = ColorRect.new()
	circle.color = color
	circle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_child(circle)

	var lbl = Label.new()
	lbl.text = initial
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_child(lbl)

	return container

func _style_button(btn: Button, bg: Color, fg: Color):
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = bg
	style_normal.set_corner_radius_all(6)
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = bg.lightened(0.2)
	style_hover.set_corner_radius_all(6)
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = bg.darkened(0.2)
	style_pressed.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_font_size_override("font_size", 13)

func _on_take_order_pressed(panel: Control, ticket):
	# Mark order taken in active_customers
	for entry in active_customers:
		if entry["node"] == panel:
			if entry["order_taken"]:
				return
			entry["order_taken"] = true
			ticket.mark_order_taken(_shift_elapsed)

			var btn = panel.get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/TakeOrderBtn")
			if btn:
				btn.disabled = true
				btn.text = "In Progress"

			var status = panel.get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/StatusLabel")
			if status:
				status.text = "Preparing..."

			emit_signal("order_taken", ticket)
			break

func _process(delta: float):
	_shift_elapsed += delta
	_update_patience(delta)

func _update_patience(delta: float):
	var to_remove: Array = []
	for i in active_customers.size():
		var entry = active_customers[i]
		var drain = PATIENCE_DRAIN_IDLE if not entry["order_taken"] else PATIENCE_DRAIN_ACTIVE
		entry["patience"] -= drain * delta
		entry["patience"] = maxf(0.0, entry["patience"])

		# Update patience bar
		var pct = entry["patience"] / entry["max_patience"] * 100.0
		var bar: ProgressBar = entry["node"].get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/PatienceBar")
		if bar:
			bar.value = pct
			# Color based on zone
			if pct > 60:
				bar.modulate = Color("#27AE60")
			elif pct > 30:
				bar.modulate = Color("#F39C12")
			else:
				bar.modulate = Color("#E74C3C")

		if entry["patience"] <= 0.0:
			to_remove.append(i)

	# Remove impatient customers (in reverse)
	for i in range(to_remove.size() - 1, -1, -1):
		var idx = to_remove[i]
		var entry = active_customers[idx]
		entry["node"].queue_free()
		active_customers.remove_at(idx)

# === Serve system ===

func add_completed_plate(ticket):
	completed_plates.append(ticket)
	_build_plate_widget(ticket)

func _build_plate_widget(ticket):
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(260, 80)
	var style = _panel_style(Color("#E8F8F5"), ticket.customer_color, 2, 6)
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	m.add_child(hbox)
	panel.add_child(m)

	# Plate icon
	var icon = Label.new()
	icon.text = "🍽"
	icon.add_theme_font_size_override("font_size", 32)
	hbox.add_child(icon)

	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	hbox.add_child(info)

	var name_lbl = Label.new()
	name_lbl.text = "Order for " + ticket.customer_name
	name_lbl.add_theme_color_override("font_color", ticket.customer_color)
	name_lbl.add_theme_font_size_override("font_size", 14)
	info.add_child(name_lbl)

	var serve_btn = Button.new()
	serve_btn.text = "Serve to " + ticket.customer_name
	_style_button(serve_btn, Color("#27AE60"), Color.WHITE)
	serve_btn.add_theme_font_size_override("font_size", 13)
	info.add_child(serve_btn)
	serve_btn.pressed.connect(_on_serve_pressed.bind(ticket, panel))

	_plates_vbox.add_child(panel)

func _on_serve_pressed(ticket, plate_node: Control):
	ticket.serve_time = _shift_elapsed
	ticket.compute_waiting_score(0.0)

	# Find and remove customer from active_customers
	var to_remove_idx = -1
	for i in active_customers.size():
		if active_customers[i]["ticket"] == ticket:
			to_remove_idx = i
			break
	if to_remove_idx >= 0:
		active_customers[to_remove_idx]["node"].queue_free()
		active_customers.remove_at(to_remove_idx)

	plate_node.queue_free()
	completed_plates.erase(ticket)

	emit_signal("plate_served", ticket)
