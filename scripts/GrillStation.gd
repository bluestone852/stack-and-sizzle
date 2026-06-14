class_name GrillStation
extends Control

signal sandwich_sliced(ticket)

const TOTAL_COOK_TIME   := 20.0   # seconds per side
const FLIP_WINDOW_MIN   := 0.45
const FLIP_WINDOW_MAX   := 0.55
const FLIP_PARTIAL_MIN  := 0.40
const FLIP_PARTIAL_MAX  := 0.60
const DONENESS_RANGES := {
	"Light":     [0.60, 0.75],
	"Medium":    [0.76, 0.90],
	"Well Done": [0.91, 1.00],
}
const BURN_GRACE := 0.10   # 10% past 100% before scoring 0

# Grill slot state
class GrillSlotState:
	var ticket = null
	var progress: float = 0.0      # 0.0 – 1.0 per side
	var flipped: bool = false
	var flip_score: float = -1.0
	var cooking: bool = false
	var burned: bool = false
	var done: bool = false         # ready for slicer

var slots: Array[GrillSlotState] = []

# Slicer state
var _slicer_ticket = null
var _slice_position: float = 0.5   # 0.0 = far left, 1.0 = far right (0.5 = centre)
var _slicer_active: bool = false

# UI refs
var _slot_panels: Array[Control] = []
var _slot_dials: Array[Control] = []
var _slot_labels: Array[Label] = []
var _slot_flip_btns: Array[Button] = []
var _slot_pull_btns: Array[Button] = []
var _slicer_panel: Control
var _slice_slider: HSlider
var _slice_accuracy_label: Label
var _slice_btn: Button

func _ready():
	slots.append(GrillSlotState.new())
	slots.append(GrillSlotState.new())
	_build_ui()

func _build_ui():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS

	var bg = Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s = StyleBoxFlat.new()
	s.bg_color = Color("#1A1A2E")
	bg.add_theme_stylebox_override("panel", s)
	add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 12)
	m.add_child(vbox)
	add_child(m)

	var title = Label.new()
	title.text = "🔥 GRILL STATION"
	title.add_theme_color_override("font_color", Color("#FF6B35"))
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hint = Label.new()
	hint.text = "Flip at 50% • Pull at your customer's doneness zone"
	hint.add_theme_color_override("font_color", Color("#F39C12"))
	hint.add_theme_font_size_override("font_size", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	# Grill slots row
	var slots_hbox = HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 20)
	slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(slots_hbox)

	for i in 2:
		var slot_panel = _build_slot_ui(i)
		slots_hbox.add_child(slot_panel)

	# Slicer section
	_slicer_panel = _build_slicer_ui()
	vbox.add_child(_slicer_panel)

func _build_slot_ui(idx: int) -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(340, 340)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#2D2D44")
	style.border_color = Color("#FF6B35")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	_slot_panels.append(panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 12)
	m.add_child(vbox)
	panel.add_child(m)

	var slot_title = Label.new()
	slot_title.text = "SLOT %d" % (idx + 1)
	slot_title.add_theme_color_override("font_color", Color("#FF6B35"))
	slot_title.add_theme_font_size_override("font_size", 13)
	slot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(slot_title)

	# Cook dial (custom draw node)
	var dial = _CookDial.new()
	dial.name = "Dial%d" % idx
	dial.custom_minimum_size = Vector2(160, 160)
	dial.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_slot_dials.append(dial)
	vbox.add_child(dial)

	# Status label
	var status_lbl = Label.new()
	status_lbl.text = "Empty"
	status_lbl.add_theme_color_override("font_color", Color("#BDC3C7"))
	status_lbl.add_theme_font_size_override("font_size", 13)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_slot_labels.append(status_lbl)
	vbox.add_child(status_lbl)

	# Flip button
	var flip_btn = Button.new()
	flip_btn.text = "FLIP SANDWICH"
	flip_btn.disabled = true
	_style_grill_btn(flip_btn, Color("#F39C12"))
	flip_btn.pressed.connect(_on_flip_pressed.bind(idx))
	_slot_flip_btns.append(flip_btn)
	vbox.add_child(flip_btn)

	# Pull button
	var pull_btn = Button.new()
	pull_btn.text = "PULL OFF GRILL"
	pull_btn.disabled = true
	_style_grill_btn(pull_btn, Color("#27AE60"))
	pull_btn.pressed.connect(_on_pull_pressed.bind(idx))
	_slot_pull_btns.append(pull_btn)
	vbox.add_child(pull_btn)

	return panel

func _build_slicer_ui() -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 180)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#16213E")
	style.border_color = Color("#4ECDC4")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 12)
	m.add_child(vbox)
	panel.add_child(m)

	var title = Label.new()
	title.text = "✂ SLICER — Centre the sandwich then cut"
	title.add_theme_color_override("font_color", Color("#4ECDC4"))
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var inactive_lbl = Label.new()
	inactive_lbl.name = "InactiveLabel"
	inactive_lbl.text = "No sandwich ready for slicing"
	inactive_lbl.add_theme_color_override("font_color", Color("#555577"))
	inactive_lbl.add_theme_font_size_override("font_size", 13)
	inactive_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(inactive_lbl)

	var active_container = VBoxContainer.new()
	active_container.name = "ActiveContainer"
	active_container.visible = false
	active_container.add_theme_constant_override("separation", 8)
	vbox.add_child(active_container)

	var slice_lbl = Label.new()
	slice_lbl.name = "SliceForLabel"
	slice_lbl.text = "Slicing for: —"
	slice_lbl.add_theme_color_override("font_color", Color.WHITE)
	slice_lbl.add_theme_font_size_override("font_size", 13)
	slice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_container.add_child(slice_lbl)

	_slice_slider = HSlider.new()
	_slice_slider.min_value = 0.0
	_slice_slider.max_value = 1.0
	_slice_slider.step = 0.01
	_slice_slider.value = 0.5
	_slice_slider.custom_minimum_size = Vector2(0, 20)
	_slice_slider.value_changed.connect(_on_slice_slider_changed)
	active_container.add_child(_slice_slider)

	_slice_accuracy_label = Label.new()
	_slice_accuracy_label.text = "Accuracy: Perfect"
	_slice_accuracy_label.add_theme_color_override("font_color", Color("#27AE60"))
	_slice_accuracy_label.add_theme_font_size_override("font_size", 13)
	_slice_accuracy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_container.add_child(_slice_accuracy_label)

	_slice_btn = Button.new()
	_slice_btn.text = "✂ CUT!"
	_style_grill_btn(_slice_btn, Color("#4ECDC4"))
	_slice_btn.pressed.connect(_on_slice_pressed)
	active_container.add_child(_slice_btn)

	return panel

# === Public API ===

func add_sandwich(ticket) -> bool:
	for i in slots.size():
		if slots[i].ticket == null:
			slots[i].ticket = ticket
			slots[i].progress = 0.0
			slots[i].flipped = false
			slots[i].flip_score = -1.0
			slots[i].cooking = true
			slots[i].burned = false
			slots[i].done = false
			_update_slot_ui(i)
			return true
	return false

func has_free_slot() -> bool:
	for s in slots:
		if s.ticket == null:
			return true
	return false

# === Processing (always runs) ===

func _process(delta: float):
	for i in slots.size():
		_tick_slot(i, delta)

func _tick_slot(idx: int, delta: float):
	var s = slots[idx]
	if s.ticket == null or not s.cooking or s.done:
		return

	s.progress += delta / TOTAL_COOK_TIME

	# Burn detection
	if s.flipped and s.progress > 1.0 + BURN_GRACE:
		s.burned = true
		s.cooking = false
		_set_slot_status(idx, "🔥 BURNED! Score = 0", Color("#E74C3C"))
		_update_slot_dial(idx)
		_slot_pull_btns[idx].disabled = true
		_slot_flip_btns[idx].disabled = true
		return

	# Update dial
	_update_slot_dial(idx)
	_update_slot_buttons(idx)
	_update_slot_label(idx)

func _update_slot_dial(idx: int):
	var dial = _slot_dials[idx] as _CookDial
	var s = slots[idx]
	if s.ticket == null:
		dial.progress = 0.0
		dial.flipped = false
		dial.doneness = ""
		dial.burned = false
		dial.queue_redraw()
		return

	dial.progress = clampf(s.progress, 0.0, 1.1)
	dial.flipped = s.flipped
	dial.doneness = s.ticket.doneness
	dial.burned = s.burned
	dial.queue_redraw()

func _update_slot_buttons(idx: int):
	var s = slots[idx]
	if s.ticket == null:
		_slot_flip_btns[idx].disabled = true
		_slot_pull_btns[idx].disabled = true
		return

	# Flip button: enabled when NOT flipped and in flip or partial window
	if not s.flipped:
		var in_window = s.progress >= FLIP_PARTIAL_MIN and s.progress <= FLIP_PARTIAL_MAX
		_slot_flip_btns[idx].disabled = not in_window
		_slot_pull_btns[idx].disabled = true
	else:
		_slot_flip_btns[idx].disabled = true
		# Pull button: enabled when in doneness zone
		var d_range = DONENESS_RANGES.get(s.ticket.doneness, [0.76, 0.90])
		var in_zone = s.progress >= d_range[0] - 0.05 and s.progress <= d_range[1] + 0.10
		_slot_pull_btns[idx].disabled = not in_zone

func _update_slot_label(idx: int):
	var s = slots[idx]
	if s.ticket == null:
		_set_slot_status(idx, "Empty — drag a sandwich here", Color("#555577"))
		return

	var pct = s.progress * 100.0
	if not s.flipped:
		if s.progress < FLIP_PARTIAL_MIN:
			_set_slot_status(idx, "Cooking side 1... %.0f%%" % pct, Color("#BDC3C7"))
		elif s.progress >= FLIP_WINDOW_MIN and s.progress <= FLIP_WINDOW_MAX:
			_set_slot_status(idx, "⚡ FLIP NOW! %.0f%%" % pct, Color("#F1C40F"))
		elif s.progress > FLIP_PARTIAL_MAX:
			_set_slot_status(idx, "⚠ Flip overdue! %.0f%%" % pct, Color("#E74C3C"))
		else:
			_set_slot_status(idx, "Almost ready to flip... %.0f%%" % pct, Color("#F39C12"))
	else:
		var target = DONENESS_RANGES.get(s.ticket.doneness, [0.76, 0.90])
		if s.progress < target[0]:
			_set_slot_status(idx, "Cooking side 2... %.0f%%\nTarget: %s" % [pct, s.ticket.doneness], Color("#BDC3C7"))
		elif s.progress <= target[1]:
			_set_slot_status(idx, "🟢 PULL NOW — %s! %.0f%%" % [s.ticket.doneness, pct], Color("#27AE60"))
		else:
			_set_slot_status(idx, "⚠ Over target... %.0f%%" % pct, Color("#E74C3C"))

func _set_slot_status(idx: int, text: String, color: Color):
	_slot_labels[idx].text = text
	_slot_labels[idx].add_theme_color_override("font_color", color)

func _update_slot_ui(idx: int):
	_update_slot_dial(idx)
	_update_slot_buttons(idx)
	_update_slot_label(idx)

# === Interaction ===

func _on_flip_pressed(idx: int):
	var s = slots[idx]
	if s.ticket == null or s.flipped:
		return

	var p = s.progress
	var flip_score: float
	if p >= FLIP_WINDOW_MIN and p <= FLIP_WINDOW_MAX:
		flip_score = 1.0
	elif (p >= FLIP_PARTIAL_MIN and p < FLIP_WINDOW_MIN) or (p > FLIP_WINDOW_MAX and p <= FLIP_PARTIAL_MAX):
		var dist = min(abs(p - FLIP_WINDOW_MIN), abs(p - FLIP_WINDOW_MAX))
		flip_score = 1.0 - (dist / (FLIP_WINDOW_MIN - FLIP_PARTIAL_MIN)) * 0.5
	else:
		flip_score = 0.0

	s.flip_score = clampf(flip_score, 0.0, 1.0)
	s.flipped = true
	s.progress = 0.0
	_update_slot_ui(idx)

func _on_pull_pressed(idx: int):
	var s = slots[idx]
	if s.ticket == null or not s.flipped:
		return

	# Compute doneness score
	var d_range = DONENESS_RANGES.get(s.ticket.doneness, [0.76, 0.90])
	var doneness_score: float
	var p = s.progress
	if s.burned:
		doneness_score = 0.0
	elif p >= d_range[0] and p <= d_range[1]:
		doneness_score = 1.0
	elif p < d_range[0]:
		doneness_score = clampf(p / d_range[0], 0.3, 0.9)
	else:
		var over = p - d_range[1]
		doneness_score = clampf(1.0 - (over / BURN_GRACE), 0.0, 0.8)

	s.cooking = false
	s.done = true

	# Pass to slicer
	_activate_slicer(s.ticket, s.flip_score, doneness_score)

	# Clear the slot
	s.ticket = null
	s.progress = 0.0
	s.flipped = false
	s.flip_score = -1.0
	s.cooking = false
	s.done = false
	s.burned = false
	_update_slot_ui(idx)

# === Slicer ===

func _activate_slicer(ticket, flip_score: float, doneness_score: float):
	_slicer_ticket = ticket
	_slicer_ticket.set_meta("_pending_flip_score", flip_score)
	_slicer_ticket.set_meta("_pending_doneness_score", doneness_score)
	_slicer_active = true
	_slice_slider.value = 0.5
	_update_slice_display()

	var slicer_active = _slicer_panel.find_child("ActiveContainer", true, false)
	if slicer_active:
		slicer_active.visible = true
	var slicer_inactive = _slicer_panel.find_child("InactiveLabel", true, false)
	if slicer_inactive:
		slicer_inactive.visible = false
	var for_label = _slicer_panel.find_child("SliceForLabel", true, false)
	if for_label:
		for_label.text = "Slicing for: " + ticket.customer_name

func _on_slice_slider_changed(value: float):
	_slice_position = value
	_update_slice_display()

func _update_slice_display():
	var deviation = abs(_slice_position - 0.5)
	var accuracy_pct = clampf(1.0 - (deviation / 0.5), 0.0, 1.0) * 100.0

	if accuracy_pct >= 90:
		_slice_accuracy_label.text = "Accuracy: %.0f%% — PERFECT!" % accuracy_pct
		_slice_accuracy_label.add_theme_color_override("font_color", Color("#27AE60"))
	elif accuracy_pct >= 70:
		_slice_accuracy_label.text = "Accuracy: %.0f%% — Good" % accuracy_pct
		_slice_accuracy_label.add_theme_color_override("font_color", Color("#F39C12"))
	else:
		_slice_accuracy_label.text = "Accuracy: %.0f%% — Off-centre" % accuracy_pct
		_slice_accuracy_label.add_theme_color_override("font_color", Color("#E74C3C"))

func _on_slice_pressed():
	if _slicer_ticket == null:
		return

	var deviation = abs(_slice_position - 0.5)
	var slice_score = clampf(1.0 - (deviation * 2.0), 0.0, 1.0)

	var flip_score = _slicer_ticket.get_meta("_pending_flip_score", 0.0)
	var doneness_score = _slicer_ticket.get_meta("_pending_doneness_score", 0.0)

	# Combine grill scores
	_slicer_ticket.grill_score = (flip_score + doneness_score + slice_score) / 3.0 * _slicer_ticket.strictness
	_slicer_ticket.grill_score = clampf(_slicer_ticket.grill_score, 0.0, 1.0)

	var finished_ticket = _slicer_ticket
	_slicer_ticket = null
	_slicer_active = false

	var slicer_active = _slicer_panel.find_child("ActiveContainer", true, false)
	if slicer_active:
		slicer_active.visible = false
	var slicer_inactive = _slicer_panel.find_child("InactiveLabel", true, false)
	if slicer_inactive:
		slicer_inactive.visible = true

	emit_signal("sandwich_sliced", finished_ticket)

# === Style helpers ===

func _style_grill_btn(btn: Button, col: Color):
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s = StyleBoxFlat.new()
		match state:
			"normal":   s.bg_color = col
			"hover":    s.bg_color = col.lightened(0.2)
			"pressed":  s.bg_color = col.darkened(0.2)
			"disabled": s.bg_color = Color(0.3, 0.3, 0.3)
		s.set_corner_radius_all(8)
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 14)
	btn.custom_minimum_size = Vector2(0, 36)

# === Inner class: Cook dial drawn with _draw() ===

class _CookDial extends Control:
	var progress: float = 0.0
	var flipped: bool = false
	var doneness: String = "Medium"
	var burned: bool = false

	func _draw():
		var center = size / 2.0
		var radius = min(size.x, size.y) * 0.44

		# Dark background circle
		draw_circle(center, radius + 2, Color("#111122"))
		draw_arc(center, radius, 0, TAU, 64, Color(0.15, 0.15, 0.15), radius * 0.55, false)

		if burned:
			draw_circle(center, radius * 0.8, Color("#111111"))
			var lbl_text = "BURNED"
			_draw_centered_text(lbl_text, center, Color("#E74C3C"), 14)
			return

		# Doneness zone arcs (drawn on second side only)
		if flipped and doneness != "":
			var zones := {
				"Light":     [0.60, 0.75, Color("#81C784")],
				"Medium":    [0.76, 0.90, Color("#FFB74D")],
				"Well Done": [0.91, 1.00, Color("#E57373")],
			}
			for zone_name in zones:
				var zdata = zones[zone_name]
				var start_angle = -PI * 0.5 + TAU * float(zdata[0])
				var end_angle   = -PI * 0.5 + TAU * float(zdata[1])
				var zone_color = zdata[2] as Color
				if zone_name == doneness:
					zone_color.a = 0.9
				else:
					zone_color.a = 0.3
				draw_arc(center, radius * 0.95, start_angle, end_angle, 32, zone_color, radius * 0.18, false)

		# Progress arc
		var prog_clamped = clampf(progress, 0.0, 1.1)
		var prog_color: Color
		if progress < 0.4:
			prog_color = Color("#4FC3F7")
		elif progress < 0.5:
			prog_color = Color("#F1C40F")
		elif progress < 0.7:
			prog_color = Color("#FF8C42")
		elif progress < 0.9:
			prog_color = Color("#E74C3C")
		else:
			prog_color = Color("#8B0000")

		var arc_start = -PI / 2.0
		var arc_end = arc_start + TAU * prog_clamped
		if prog_clamped > 0.01:
			draw_arc(center, radius * 0.75, arc_start, arc_end, 64, prog_color, radius * 0.28, false)

		# Centre text
		var pct_text = "%.0f%%" % (progress * 100.0)
		var state_text = "Side 1" if not flipped else "Side 2"
		_draw_centered_text(pct_text, center - Vector2(0, 10), Color.WHITE, 16)
		_draw_centered_text(state_text, center + Vector2(0, 12), Color(0.7, 0.7, 0.7), 11)

		# Flip indicator ring
		if not flipped and progress >= 0.40 and progress <= 0.60:
			var ring_color = Color("#F1C40F") if (progress >= 0.45 and progress <= 0.55) else Color("#FF8C42")
			ring_color.a = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.008)
			draw_arc(center, radius + 6, 0, TAU, 64, ring_color, 4.0, false)

	func _draw_centered_text(text: String, pos: Vector2, color: Color, font_size: int):
		var font = ThemeDB.fallback_font
		var str_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, pos - str_size / 2.0 + Vector2(0, str_size.y * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
