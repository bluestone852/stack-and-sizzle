class_name FryStation
extends Control

signal fries_ready(ticket)

const TOTAL_FRY_TIME := 15.0
const FRY_ZONE_MIN   := 0.60
const FRY_ZONE_MAX   := 0.85
const BURN_GRACE     := 0.12

const FRY_COLORS := {
	"Classic Fries":      Color("#F4D03F"),
	"Waffle Fries":       Color("#E67E22"),
	"Sweet Potato Fries": Color("#E74C3C"),
}

const TOPPING_COLORS := {
	"Ketchup":              Color("#C0392B"),
	"Cheese Sauce":         Color("#F39C12"),
	"Salt & Vinegar":       Color("#E8DAEF"),
}

# State
var _current_ticket = null
var _fry_progress: float = 0.0
var _fry_running: bool = false
var _fry_burned: bool = false
var _fry_done: bool = false
var _fry_plated: bool = false
var _placed_toppings: Array = []

# UI refs
var _fry_select_vbox: VBoxContainer
var _fryer_panel: Control
var _cook_bar: ProgressBar
var _cook_label: Label
var _pull_btn: Button
var _plate_panel: Control
var _topping_vbox: VBoxContainer
var _plate_vbox: VBoxContainer
var _send_serve_btn: Button
var _ticket_label: Label

func _ready():
	_build_ui()

func _build_ui():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS

	var bg = Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s = StyleBoxFlat.new()
	s.bg_color = Color("#16213E")
	bg.add_theme_stylebox_override("panel", s)
	add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 14)
	m.add_child(vbox)
	add_child(m)

	var title = Label.new()
	title.text = "🍟 FRY STATION"
	title.add_theme_color_override("font_color", Color("#F1C40F"))
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_ticket_label = Label.new()
	_ticket_label.text = "No active order"
	_ticket_label.add_theme_color_override("font_color", Color("#BDC3C7"))
	_ticket_label.add_theme_font_size_override("font_size", 13)
	_ticket_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_ticket_label)

	# Main row: Fryer on left, plate on right
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	# === LEFT: Fryer ===
	var fryer_vbox = VBoxContainer.new()
	fryer_vbox.custom_minimum_size = Vector2(260, 0)
	fryer_vbox.add_theme_constant_override("separation", 10)
	hbox.add_child(fryer_vbox)

	var fryer_title = Label.new()
	fryer_title.text = "FRY SELECTOR"
	fryer_title.add_theme_color_override("font_color", Color("#F1C40F"))
	fryer_title.add_theme_font_size_override("font_size", 14)
	fryer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fryer_vbox.add_child(fryer_title)

	_fry_select_vbox = VBoxContainer.new()
	_fry_select_vbox.add_theme_constant_override("separation", 6)
	fryer_vbox.add_child(_fry_select_vbox)

	# Cook meter panel
	_fryer_panel = Panel.new()
	_fryer_panel.custom_minimum_size = Vector2(260, 180)
	var fp_style = StyleBoxFlat.new()
	fp_style.bg_color = Color("#0D1117")
	fp_style.border_color = Color("#F1C40F")
	fp_style.set_border_width_all(2)
	fp_style.set_corner_radius_all(10)
	_fryer_panel.add_theme_stylebox_override("panel", fp_style)
	fryer_vbox.add_child(_fryer_panel)

	var fryer_inner = VBoxContainer.new()
	fryer_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fryer_inner.add_theme_constant_override("separation", 8)
	var fi_m = MarginContainer.new()
	fi_m.add_theme_constant_override("margin_left", 12)
	fi_m.add_theme_constant_override("margin_right", 12)
	fi_m.add_theme_constant_override("margin_top", 12)
	fi_m.add_theme_constant_override("margin_bottom", 12)
	fi_m.add_child(fryer_inner)
	_fryer_panel.add_child(fi_m)

	var meter_label = Label.new()
	meter_label.text = "🫧 Cook Meter"
	meter_label.add_theme_color_override("font_color", Color("#F1C40F"))
	meter_label.add_theme_font_size_override("font_size", 13)
	meter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fryer_inner.add_child(meter_label)

	_cook_bar = ProgressBar.new()
	_cook_bar.min_value = 0.0
	_cook_bar.max_value = 100.0
	_cook_bar.value = 0.0
	_cook_bar.show_percentage = true
	_cook_bar.custom_minimum_size = Vector2(0, 30)
	fryer_inner.add_child(_cook_bar)

	_cook_label = Label.new()
	_cook_label.text = "Drop fries to start"
	_cook_label.add_theme_color_override("font_color", Color("#BDC3C7"))
	_cook_label.add_theme_font_size_override("font_size", 12)
	_cook_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cook_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fryer_inner.add_child(_cook_label)

	# Zone indicator
	var zone_label = Label.new()
	zone_label.text = "🟢 Pull at 60–85%"
	zone_label.add_theme_color_override("font_color", Color("#27AE60"))
	zone_label.add_theme_font_size_override("font_size", 12)
	zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fryer_inner.add_child(zone_label)

	_pull_btn = Button.new()
	_pull_btn.text = "PULL BASKET"
	_pull_btn.disabled = true
	_style_fry_btn(_pull_btn, Color("#27AE60"))
	_pull_btn.pressed.connect(_on_pull_basket)
	fryer_inner.add_child(_pull_btn)

	# === RIGHT: Plate area ===
	var plate_vbox = VBoxContainer.new()
	plate_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate_vbox.add_theme_constant_override("separation", 10)
	hbox.add_child(plate_vbox)

	var plate_title = Label.new()
	plate_title.text = "PLATE"
	plate_title.add_theme_color_override("font_color", Color("#4ECDC4"))
	plate_title.add_theme_font_size_override("font_size", 14)
	plate_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate_vbox.add_child(plate_title)

	_plate_panel = Panel.new()
	_plate_panel.custom_minimum_size = Vector2(0, 200)
	_plate_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pp_style = StyleBoxFlat.new()
	pp_style.bg_color = Color("#FAFAFA")
	pp_style.border_color = Color("#4ECDC4")
	pp_style.set_border_width_all(2)
	pp_style.set_corner_radius_all(10)
	_plate_panel.add_theme_stylebox_override("panel", pp_style)
	plate_vbox.add_child(_plate_panel)

	var plate_inner = VBoxContainer.new()
	plate_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate_inner.add_theme_constant_override("separation", 6)
	var pi_m = MarginContainer.new()
	pi_m.add_theme_constant_override("margin_left", 10)
	pi_m.add_theme_constant_override("margin_right", 10)
	pi_m.add_theme_constant_override("margin_top", 10)
	pi_m.add_theme_constant_override("margin_bottom", 10)
	pi_m.add_child(plate_inner)
	_plate_panel.add_child(pi_m)

	var fries_icon = Label.new()
	fries_icon.text = "🍟"
	fries_icon.add_theme_font_size_override("font_size", 40)
	fries_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate_inner.add_child(fries_icon)

	_plate_vbox = VBoxContainer.new()
	_plate_vbox.add_theme_constant_override("separation", 4)
	plate_inner.add_child(_plate_vbox)

	var top_title = Label.new()
	top_title.text = "Side Toppings:"
	top_title.add_theme_color_override("font_color", Color("#2C3E50"))
	top_title.add_theme_font_size_override("font_size", 13)
	plate_inner.add_child(top_title)

	_topping_vbox = VBoxContainer.new()
	_topping_vbox.add_theme_constant_override("separation", 4)
	plate_inner.add_child(_topping_vbox)

	_send_serve_btn = Button.new()
	_send_serve_btn.text = "Mark Plate Ready"
	_send_serve_btn.disabled = true
	_style_fry_btn(_send_serve_btn, Color("#4ECDC4"))
	_send_serve_btn.pressed.connect(_on_send_to_serve)
	plate_vbox.add_child(_send_serve_btn)

func _rebuild_fry_selector():
	for child in _fry_select_vbox.get_children():
		child.queue_free()

	var sides = GameState.unlocked_ingredients["sides"]
	for side in sides:
		var btn = Button.new()
		var col = FRY_COLORS.get(side, Color("#F4D03F"))
		btn.text = "🍟 " + side
		btn.custom_minimum_size = Vector2(0, 38)
		_style_fry_btn_color(btn, col, Color("#2C3E50"))
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_fry_selected.bind(side))
		_fry_select_vbox.add_child(btn)

func _rebuild_topping_selector():
	for child in _topping_vbox.get_children():
		child.queue_free()

	if _current_ticket == null:
		return

	var available = GameState.unlocked_ingredients["side_toppings"]
	for topping in available:
		var btn = Button.new()
		var col = TOPPING_COLORS.get(topping, Color("#BDC3C7"))
		btn.text = topping
		btn.custom_minimum_size = Vector2(0, 30)
		btn.disabled = (topping in _placed_toppings) or (_placed_toppings.size() >= 2)
		_style_fry_btn_color(btn, col, Color("#2C3E50") if col.get_luminance() > 0.5 else Color.WHITE)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_topping_applied.bind(topping))
		_topping_vbox.add_child(btn)

# === Public API ===

func set_ticket(ticket):
	_current_ticket = ticket
	_fry_progress = 0.0
	_fry_running = false
	_fry_burned = false
	_fry_done = false
	_fry_plated = false
	_placed_toppings.clear()
	_ticket_label.text = "Order for: " + ticket.customer_name + " | Side: " + ticket.side
	_ticket_label.add_theme_color_override("font_color", ticket.customer_color)
	_rebuild_fry_selector()
	_refresh_plate_vbox()
	_rebuild_topping_selector()
	_pull_btn.disabled = true
	_send_serve_btn.disabled = true

# === Game logic ===

func _on_fry_selected(side: String):
	if _current_ticket == null or _fry_running or _fry_done:
		return
	_fry_running = true
	_fry_burned = false
	_fry_done = false
	_fry_progress = 0.0
	_cook_label.text = "Frying " + side + "..."
	# Disable fry selector during cook
	for btn in _fry_select_vbox.get_children():
		btn.disabled = true

func _process(delta: float):
	if not _fry_running or _fry_done or _fry_burned:
		return

	_fry_progress += delta / TOTAL_FRY_TIME
	_fry_progress = clampf(_fry_progress, 0.0, 1.0 + BURN_GRACE)

	_cook_bar.value = _fry_progress * 100.0

	# Update cook bar color
	if _fry_progress < FRY_ZONE_MIN:
		_cook_bar.modulate = Color("#4FC3F7")
		_cook_label.text = "Cooking... %.0f%%" % (_fry_progress * 100.0)
		_pull_btn.disabled = true
	elif _fry_progress <= FRY_ZONE_MAX:
		_cook_bar.modulate = Color("#27AE60")
		_cook_label.text = "🟢 PULL NOW! %.0f%%" % (_fry_progress * 100.0)
		_pull_btn.disabled = false
	elif _fry_progress <= 1.0:
		_cook_bar.modulate = Color("#E74C3C")
		_cook_label.text = "⚠ Getting overcooked! %.0f%%" % (_fry_progress * 100.0)
		_pull_btn.disabled = false
	else:
		_cook_bar.modulate = Color("#8B0000")
		_cook_label.text = "🔥 BURNED!"
		_fry_burned = true
		_fry_running = false
		_pull_btn.disabled = true

func _on_pull_basket():
	if not _fry_running:
		return
	_fry_running = false
	_fry_done = true
	_pull_btn.disabled = true

	# Compute cook score
	var cook_score: float
	if _fry_burned or _fry_progress > 1.0 + BURN_GRACE:
		cook_score = 0.0
	elif _fry_progress >= FRY_ZONE_MIN and _fry_progress <= FRY_ZONE_MAX:
		cook_score = 1.0
	elif _fry_progress < FRY_ZONE_MIN:
		cook_score = clampf(_fry_progress / FRY_ZONE_MIN, 0.3, 0.9)
	else:
		var over = _fry_progress - FRY_ZONE_MAX
		cook_score = clampf(1.0 - (over / BURN_GRACE), 0.0, 0.8)

	_current_ticket.set_meta("_fry_cook_score", cook_score)
	_cook_label.text = "Fries ready! Add toppings and mark plate."
	_refresh_plate_vbox()
	_rebuild_topping_selector()
	_send_serve_btn.disabled = false

func _refresh_plate_vbox():
	for child in _plate_vbox.get_children():
		child.queue_free()
	if not _fry_done:
		var waiting_lbl = Label.new()
		waiting_lbl.text = "(fries not yet cooked)"
		waiting_lbl.add_theme_color_override("font_color", Color("#BDC3C7"))
		waiting_lbl.add_theme_font_size_override("font_size", 12)
		_plate_vbox.add_child(waiting_lbl)
	else:
		var fries_lbl = Label.new()
		fries_lbl.text = "✅ Fries plated!"
		fries_lbl.add_theme_color_override("font_color", Color("#27AE60"))
		fries_lbl.add_theme_font_size_override("font_size", 13)
		_plate_vbox.add_child(fries_lbl)
		for t in _placed_toppings:
			var tl = Label.new()
			tl.text = "  + " + t
			tl.add_theme_color_override("font_color", Color("#2C3E50"))
			tl.add_theme_font_size_override("font_size", 12)
			_plate_vbox.add_child(tl)

func _on_topping_applied(topping: String):
	if _placed_toppings.size() >= 2 or topping in _placed_toppings:
		return
	_placed_toppings.append(topping)
	_refresh_plate_vbox()
	_rebuild_topping_selector()

func _on_send_to_serve():
	if _current_ticket == null or not _fry_done:
		return

	# Compute topping coverage score
	var required_tops = _current_ticket.side_toppings
	var coverage_scores: Array = []
	for rt in required_tops:
		coverage_scores.append(1.0 if rt in _placed_toppings else 0.0)
	for pt in _placed_toppings:
		if not pt in required_tops:
			coverage_scores.append(0.0)  # extra topping penalty

	var cook_score = _current_ticket.get_meta("_fry_cook_score", 0.0)
	var topping_score = 0.0
	if coverage_scores.size() > 0:
		for cs in coverage_scores:
			topping_score += cs
		topping_score /= float(coverage_scores.size())
	else:
		topping_score = 1.0  # No toppings required = perfect

	_current_ticket.fry_score = clampf((cook_score + topping_score) / 2.0 * _current_ticket.strictness, 0.0, 1.0)

	var finished = _current_ticket
	_current_ticket = null
	_fry_done = false
	_fry_running = false
	_fry_progress = 0.0
	_placed_toppings.clear()
	_cook_bar.value = 0.0
	_cook_label.text = "Drop fries to start"
	_ticket_label.text = "No active order"
	_ticket_label.add_theme_color_override("font_color", Color("#BDC3C7"))
	_send_serve_btn.disabled = true
	_pull_btn.disabled = true
	for btn in _fry_select_vbox.get_children():
		btn.disabled = false
	_refresh_plate_vbox()
	for child in _topping_vbox.get_children():
		child.queue_free()

	emit_signal("fries_ready", finished)

# === Style helpers ===

func _style_fry_btn(btn: Button, col: Color):
	_style_fry_btn_color(btn, col, Color.WHITE)

func _style_fry_btn_color(btn: Button, col: Color, fg: Color):
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s = StyleBoxFlat.new()
		match state:
			"normal":   s.bg_color = col
			"hover":    s.bg_color = col.lightened(0.15)
			"pressed":  s.bg_color = col.darkened(0.15)
			"disabled": s.bg_color = Color(0.35, 0.35, 0.35)
		s.set_corner_radius_all(8)
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_font_size_override("font_size", 13)
	btn.custom_minimum_size = Vector2(0, 34)
