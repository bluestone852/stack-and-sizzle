extends Node2D

# ── Preloads (needed because class_name cache isn't built outside editor) ─────
const _OrderStationScript = preload("res://scripts/OrderStation.gd")
const _BuildStationScript  = preload("res://scripts/BuildStation.gd")
const _GrillStationScript  = preload("res://scripts/GrillStation.gd")
const _FryStationScript    = preload("res://scripts/FryStation.gd")

# ── Layout constants ──────────────────────────────────────────────────────────
const SCREEN_W    := 1280
const SCREEN_H    := 720
const HUD_H       := 58
const QUEUE_W     := 290
const SHIFT_SECS  := 300.0   # 5 minutes

# ── Colours ───────────────────────────────────────────────────────────────────
const C_BG       := Color("#FFF3E0")
const C_HEADER   := Color("#E65100")
const C_TAB_ON   := Color("#FF6B35")
const C_TAB_OFF  := Color("#BDC3C7")
const C_DARK     := Color("#1A1A2E")
const C_GOLD     := Color("#F1C40F")

# ── State ─────────────────────────────────────────────────────────────────────
var _shift_running:  bool  = false
var _shift_elapsed:  float = 0.0
var _spawn_timer:    float = 8.0   # first customer appears after 8s
var _grilled_tickets: Array = []   # done with grill, waiting for fry

# ── Node refs ─────────────────────────────────────────────────────────────────
var _canvas:           CanvasLayer
var _hud:              Control
var _rank_label:       Label
var _xp_bar:           ProgressBar
var _tips_label:       Label
var _timer_label:      Label
var _tab_btns:         Dictionary = {}   # "build" | "grill" | "fry" → Button
var _attention_lbls:   Dictionary = {}

var _order_station     # OrderStation instance
var _build_station     # BuildStation instance
var _grill_station     # GrillStation instance
var _fry_station       # FryStation instance
var _stations:         Dictionary = {}   # name → Control
var _active_station:   String = "build"

var _root_control:     Control   # full-screen UI root

# ─────────────────────────────────────────────────────────────────────────────
func _ready():
	_build_full_ui()
	_connect_signals()
	JuiceManager.register_ui_layer(_canvas)
	_start_shift()

# ── UI construction ───────────────────────────────────────────────────────────

func _build_full_ui():
	_canvas = CanvasLayer.new()
	_canvas.layer = 0
	add_child(_canvas)

	_root_control = Control.new()
	_root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_control.custom_minimum_size = Vector2(SCREEN_W, SCREEN_H)
	_canvas.add_child(_root_control)

	# Background
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = C_BG
	_root_control.add_child(bg)

	# Top HUD bar
	_hud = _build_hud()
	_root_control.add_child(_hud)

	# Content row below HUD
	var content = HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_top = HUD_H
	content.add_theme_constant_override("separation", 0)
	_root_control.add_child(content)

	# ── Left panel: Order station (always visible) ──
	var left_wrapper = Panel.new()
	left_wrapper.custom_minimum_size = Vector2(QUEUE_W, 0)
	var lw_style = StyleBoxFlat.new()
	lw_style.bg_color = Color("#FFF8EF")
	lw_style.border_color = Color("#E67E22")
	lw_style.set_border_width_all(0)
	lw_style.border_width_right = 2
	left_wrapper.add_theme_stylebox_override("panel", lw_style)
	content.add_child(left_wrapper)

	_order_station = _OrderStationScript.new()
	_order_station.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_wrapper.add_child(_order_station)

	# ── Right panel: Station tabs + content ──
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 0)
	content.add_child(right_vbox)

	# Station tab bar
	var tab_bar = _build_tab_bar()
	right_vbox.add_child(tab_bar)

	# Station content area
	var station_container = Control.new()
	station_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	station_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(station_container)

	# Build all three stations (all in the same container, only one visible)
	_build_station  = _BuildStationScript.new()
	_build_station.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	station_container.add_child(_build_station)
	_stations["build"] = _build_station

	_grill_station = _GrillStationScript.new()
	_grill_station.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grill_station.visible = false
	station_container.add_child(_grill_station)
	_stations["grill"] = _grill_station

	_fry_station = _FryStationScript.new()
	_fry_station.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fry_station.visible = false
	station_container.add_child(_fry_station)
	_stations["fry"] = _fry_station

func _build_hud() -> Control:
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.custom_minimum_size = Vector2(0, HUD_H)
	var ps = StyleBoxFlat.new()
	ps.bg_color = C_DARK
	ps.border_color = C_GOLD
	ps.set_border_width_all(0)
	ps.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", ps)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 20)
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	m.add_child(hbox)
	panel.add_child(m)

	# Title
	var title_lbl = Label.new()
	title_lbl.text = "🥪 Stack & Sizzle"
	title_lbl.add_theme_color_override("font_color", C_GOLD)
	title_lbl.add_theme_font_size_override("font_size", 18)
	hbox.add_child(title_lbl)

	# Rank info
	var rank_vbox = VBoxContainer.new()
	rank_vbox.add_theme_constant_override("separation", 2)
	rank_vbox.custom_minimum_size = Vector2(200, 0)
	hbox.add_child(rank_vbox)

	_rank_label = Label.new()
	_rank_label.text = "Rank 1 — Rookie"
	_rank_label.add_theme_color_override("font_color", Color.WHITE)
	_rank_label.add_theme_font_size_override("font_size", 13)
	rank_vbox.add_child(_rank_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(200, 12)
	_xp_bar.value = 0
	_xp_bar.max_value = 100
	_xp_bar.show_percentage = false
	rank_vbox.add_child(_xp_bar)

	# Attention indicators (grill / fry alerts)
	var attn_hbox = HBoxContainer.new()
	attn_hbox.add_theme_constant_override("separation", 8)
	hbox.add_child(attn_hbox)

	for station in ["grill", "fry"]:
		var lbl = Label.new()
		lbl.text = ("🔥" if station == "grill" else "🍟") + " OK"
		lbl.add_theme_color_override("font_color", Color("#27AE60"))
		lbl.add_theme_font_size_override("font_size", 13)
		attn_hbox.add_child(lbl)
		_attention_lbls[station] = lbl

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Tips
	_tips_label = Label.new()
	_tips_label.text = "Tips: $0.00"
	_tips_label.add_theme_color_override("font_color", C_GOLD)
	_tips_label.add_theme_font_size_override("font_size", 15)
	hbox.add_child(_tips_label)

	# Timer
	_timer_label = Label.new()
	_timer_label.text = "5:00"
	_timer_label.add_theme_color_override("font_color", Color.WHITE)
	_timer_label.add_theme_font_size_override("font_size", 18)
	_timer_label.custom_minimum_size = Vector2(55, 0)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(_timer_label)

	return panel

func _build_tab_bar() -> Control:
	var bar = Panel.new()
	bar.custom_minimum_size = Vector2(0, 48)
	var bs = StyleBoxFlat.new()
	bs.bg_color = Color("#1F2940")
	bar.add_theme_stylebox_override("panel", bs)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 4)
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	m.add_child(hbox)
	bar.add_child(m)

	var tabs = [
		["build", "🥪 BUILD"],
		["grill", "🔥 GRILL"],
		["fry",   "🍟 FRY"],
	]
	for tab in tabs:
		var btn = Button.new()
		btn.text = tab[1]
		btn.toggle_mode = false
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(_switch_station.bind(tab[0]))
		_tab_btns[tab[0]] = btn
		hbox.add_child(btn)

	_refresh_tabs()
	return bar

# ── Station switching ─────────────────────────────────────────────────────────

func _switch_station(station_name: String):
	_active_station = station_name
	for sname in _stations:
		_stations[sname].visible = (sname == station_name)
	_refresh_tabs()

func _refresh_tabs():
	for sname in _tab_btns:
		var btn: Button = _tab_btns[sname]
		var is_active = (sname == _active_station)
		var col = C_TAB_ON if is_active else C_TAB_OFF
		for state in ["normal", "hover", "pressed"]:
			var s = StyleBoxFlat.new()
			s.bg_color = col if state == "normal" else (col.lightened(0.15) if state == "hover" else col.darkened(0.15))
			s.set_corner_radius_all(6)
			btn.add_theme_stylebox_override(state, s)
		btn.add_theme_color_override("font_color", Color.WHITE if is_active else C_DARK)

# ── Signal connections ─────────────────────────────────────────────────────────

func _connect_signals():
	_order_station.order_taken.connect(_on_order_taken)
	_order_station.plate_served.connect(_on_plate_served)
	_build_station.sandwich_ready.connect(_on_sandwich_ready)
	_grill_station.sandwich_sliced.connect(_on_sandwich_sliced)
	_fry_station.fries_ready.connect(_on_fries_ready)
	GameState.rank_up.connect(_on_rank_up)
	GameState.xp_changed.connect(_on_xp_changed)
	GameState.tips_changed.connect(_on_tips_changed)

# ── Shift management ─────────────────────────────────────────────────────────

func _start_shift():
	GameState.reset()
	_shift_elapsed = 0.0
	_shift_running = true
	_order_station.setup_spawn_queue(
		GameState.unlocked_ingredients["breads"],
		GameState.unlocked_ingredients["sides"]
	)
	_update_hud()

func _end_shift():
	_shift_running = false
	_show_end_of_shift_screen()

func _show_end_of_shift_screen():
	var overlay = Panel.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var os = StyleBoxFlat.new()
	os.bg_color = Color(0, 0, 0, 0.72)
	overlay.add_theme_stylebox_override("panel", os)
	overlay.z_index = 300
	_root_control.add_child(overlay)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(SCREEN_W / 2.0 - 200, SCREEN_H / 2.0 - 120)
	vbox.custom_minimum_size = Vector2(400, 240)
	vbox.add_theme_constant_override("separation", 12)
	overlay.add_child(vbox)

	var title = Label.new()
	title.text = "⏰ Shift Over!"
	title.add_theme_color_override("font_color", C_GOLD)
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var stats = Label.new()
	stats.text = "Rank: %d — %s\nTotal Tips: $%.2f\nTotal XP: %d" % [
		GameState.rank, GameState.get_rank_name(),
		GameState.total_tips, GameState.xp
	]
	stats.add_theme_color_override("font_color", Color.WHITE)
	stats.add_theme_font_size_override("font_size", 17)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats)

	var restart_btn = Button.new()
	restart_btn.text = "Play Again"
	restart_btn.custom_minimum_size = Vector2(180, 44)
	restart_btn.add_theme_font_size_override("font_size", 16)
	var rs = StyleBoxFlat.new()
	rs.bg_color = Color("#27AE60")
	rs.set_corner_radius_all(8)
	restart_btn.add_theme_stylebox_override("normal", rs)
	restart_btn.add_theme_color_override("font_color", Color.WHITE)
	restart_btn.pressed.connect(_on_restart)
	vbox.add_child(restart_btn)

func _on_restart():
	get_tree().reload_current_scene()

# ── Processing ────────────────────────────────────────────────────────────────

func _process(delta: float):
	if not _shift_running:
		return
	_shift_elapsed += delta
	_spawn_timer -= delta

	if _spawn_timer <= 0.0:
		_order_station.spawn_customer()
		_spawn_timer = randf_range(45.0, 60.0)  # next customer in 45–60s

	_update_hud()
	_update_attention_indicators()

func _update_hud():
	var remaining = SHIFT_SECS - _shift_elapsed
	remaining = maxf(0.0, remaining)
	if remaining <= 0.0 and _shift_running:
		_end_shift()
		return

	var mins: int = int(remaining) / 60  # @warning_ignore:integer_division
	var secs: int = int(remaining) % 60
	_timer_label.text = "%d:%02d" % [mins, secs]
	if remaining < 60:
		_timer_label.add_theme_color_override("font_color", Color("#E74C3C"))
	elif remaining < 120:
		_timer_label.add_theme_color_override("font_color", Color("#F39C12"))

	_rank_label.text = "Rank %d — %s" % [GameState.rank, GameState.get_rank_name()]

func _update_attention_indicators():
	# Grill attention: any slot in flip window or doneness zone
	var grill_needs_attn = false
	for i in _grill_station.slots.size():
		var s = _grill_station.slots[i]
		if s.ticket == null or not s.cooking:
			continue
		var p = s.progress
		if not s.flipped and p >= 0.40 and p <= 0.60:
			grill_needs_attn = true
		elif s.flipped:
			var doneness_range = _GrillStationScript.DONENESS_RANGES.get(s.ticket.doneness, [0.76, 0.90])
			if p >= doneness_range[0] - 0.05:
				grill_needs_attn = true

	var grill_lbl: Label = _attention_lbls["grill"]
	if grill_needs_attn:
		grill_lbl.text = "🔥 GRILL!"
		grill_lbl.add_theme_color_override("font_color", Color("#E74C3C"))
	else:
		grill_lbl.text = "🔥 OK"
		grill_lbl.add_theme_color_override("font_color", Color("#27AE60"))

	# Fry attention
	var fry_needs_attn = _fry_station._fry_running and _fry_station._fry_progress >= _FryStationScript.FRY_ZONE_MIN
	var fry_lbl: Label = _attention_lbls["fry"]
	if fry_needs_attn:
		fry_lbl.text = "🍟 PULL!"
		fry_lbl.add_theme_color_override("font_color", Color("#E74C3C"))
	else:
		fry_lbl.text = "🍟 OK"
		fry_lbl.add_theme_color_override("font_color", Color("#27AE60"))

# ── Station signal handlers ────────────────────────────────────────────────────

func _on_order_taken(ticket):
	_build_station.add_ticket(ticket)
	_fry_station.set_ticket(ticket)
	_switch_station("build")
	JuiceManager.show_notification("Order taken! Build the sandwich.", Color("#27AE60"), _root_control, 1.8)

func _on_sandwich_ready(ticket):
	var placed = _grill_station.add_sandwich(ticket)
	if placed:
		_switch_station("grill")
		JuiceManager.show_notification("Sandwich on the grill! Watch it cook.", Color("#FF6B35"), _root_control, 1.8)
	else:
		# Both grill slots full — notify player
		JuiceManager.show_notification("Both grill slots full! Wait for one to finish.", Color("#E74C3C"), _root_control, 2.0)
		# Re-queue the ticket for building
		_build_station.add_ticket(ticket)

func _on_sandwich_sliced(ticket):
	# Ticket is now grilled+sliced. Hold until fries are done.
	_grilled_tickets.append(ticket)
	_switch_station("fry")
	JuiceManager.show_notification("Sandwich sliced! Now fry the side.", Color("#4ECDC4"), _root_control, 1.8)

func _on_fries_ready(ticket):
	# Match fry ticket to a grilled ticket by customer name
	var matched = null
	for gt in _grilled_tickets:
		if gt.customer_name == ticket.customer_name:
			# Merge fry score into the grilled ticket
			gt.fry_score = ticket.fry_score
			matched = gt
			break

	if matched == null:
		# If somehow no grilled ticket (e.g., order taken while grill was busy),
		# just set fry score on the ticket and use it directly
		ticket.sandwich_grilled = true
		matched = ticket

	_grilled_tickets.erase(matched)
	_order_station.add_completed_plate(matched)
	JuiceManager.show_notification("Plate ready! Serve it to " + matched.customer_name, Color("#F1C40F"), _root_control, 2.0)

func _on_plate_served(ticket):
	# Compute waiting score and final
	ticket.serve_time = _shift_elapsed

	# Show score popup and add rewards
	JuiceManager.show_score_popup(_order_station, ticket)

	var tip = ticket.calculate_tip()
	GameState.add_tip(tip)
	var unlocks = GameState.add_xp(ticket.get_xp())

	# Show any unlock messages after a brief delay
	if unlocks.size() > 0 and unlocks[0] != "":
		await get_tree().create_timer(0.5).timeout
		JuiceManager.show_rank_up(GameState.rank, unlocks[0], _root_control)

func _on_rank_up(new_rank):
	_rank_label.text = "Rank %d — %s" % [new_rank, GameState.get_rank_name()]
	# Rebuild fry selector to show newly unlocked sides
	_fry_station._rebuild_fry_selector()

func _on_xp_changed(current_xp, next_threshold, rank_start):
	var needed = next_threshold - rank_start
	var progress = current_xp - rank_start
	if needed > 0:
		_xp_bar.value = float(progress) / float(needed) * 100.0
	else:
		_xp_bar.value = 100.0

func _on_tips_changed(new_total):
	_tips_label.text = "Tips: $%.2f" % new_total
