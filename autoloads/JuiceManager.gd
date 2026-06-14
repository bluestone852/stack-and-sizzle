extends Node

signal score_popup_done

var _ui_layer: CanvasLayer = null
var _shake_tween: Tween = null

func register_ui_layer(layer: CanvasLayer):
	_ui_layer = layer

func show_score_popup(anchor_node: Control, ticket):
	if not _ui_layer:
		return
	var popup = _build_score_popup(ticket)
	_ui_layer.add_child(popup)
	var anchor_rect = anchor_node.get_global_rect()
	popup.global_position = anchor_rect.position - Vector2(0, 280)
	popup.global_position.x = clamp(popup.global_position.x, 10, 1180)
	popup.global_position.y = clamp(popup.global_position.y, 10, 600)
	_animate_score_popup(popup)

func _build_score_popup(ticket) -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(300, 260)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#2C3E50")
	style.border_color = Color("#F1C40F")
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.z_index = 100

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	vbox.add_child(margin)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	margin.add_child(inner)

	var title = Label.new()
	title.text = "ORDER COMPLETE!"
	title.add_theme_color_override("font_color", Color("#F1C40F"))
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(title)

	var final_score = ticket.get_final_score() * 100.0
	var score_data = [
		["⏱ Waiting", ticket.waiting_score],
		["🥪 Build",   ticket.build_score],
		["🔥 Grill",   ticket.grill_score],
		["🍟 Fry",     ticket.fry_score],
	]

	for entry in score_data:
		var row = _make_score_row(entry[0], entry[1])
		inner.add_child(row)

	var sep = HSeparator.new()
	inner.add_child(sep)

	var total_row = HBoxContainer.new()
	var total_label = Label.new()
	total_label.text = "Total Score"
	total_label.add_theme_color_override("font_color", Color.WHITE)
	total_label.add_theme_font_size_override("font_size", 15)
	total_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_row.add_child(total_label)

	var total_val = Label.new()
	total_val.text = "%.0f%%" % final_score
	var score_color = Color("#27AE60") if final_score >= 75 else (Color("#F39C12") if final_score >= 50 else Color("#E74C3C"))
	total_val.add_theme_color_override("font_color", score_color)
	total_val.add_theme_font_size_override("font_size", 18)
	total_row.add_child(total_val)
	inner.add_child(total_row)

	var tip = GameState.get_tip_for_score(final_score)
	var tip_label = Label.new()
	tip_label.text = "Tip: $%.2f" % tip
	tip_label.add_theme_color_override("font_color", Color("#F1C40F"))
	tip_label.add_theme_font_size_override("font_size", 16)
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(tip_label)

	return panel

func _make_score_row(label_text: String, score: float) -> Control:
	var row = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.custom_minimum_size.x = 100
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var bar = ProgressBar.new()
	bar.value = score * 100.0
	bar.custom_minimum_size = Vector2(100, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var score_color = Color("#27AE60") if score >= 0.75 else (Color("#F39C12") if score >= 0.5 else Color("#E74C3C"))
	bar.add_theme_color_override("font_color", score_color)
	row.add_child(bar)

	var val = Label.new()
	val.text = "%.0f%%" % (score * 100.0)
	val.add_theme_color_override("font_color", Color.WHITE)
	val.add_theme_font_size_override("font_size", 13)
	val.custom_minimum_size.x = 45
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)

	return row

func _animate_score_popup(popup: Control):
	popup.modulate.a = 0.0
	popup.scale = Vector2(0.7, 0.7)
	popup.pivot_offset = popup.custom_minimum_size / 2.0

	var tween = popup.create_tween()
	tween.tween_property(popup, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(popup, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.5)
	tween.tween_property(popup, "modulate:a", 0.0, 0.3)
	tween.tween_callback(popup.queue_free)
	tween.tween_callback(Callable(self, "_emit_popup_done"))

func _emit_popup_done():
	emit_signal("score_popup_done")

func show_rank_up(new_rank: int, unlock_message: String, parent: Control):
	var overlay = Panel.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	overlay.add_theme_stylebox_override("panel", style)
	overlay.z_index = 200
	parent.add_child(overlay)

	var flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color("#F1C40F", 0.6)
	overlay.add_child(flash)

	var center_panel = Panel.new()
	center_panel.custom_minimum_size = Vector2(420, 200)
	center_panel.set_anchors_preset(Control.PRESET_CENTER)
	center_panel.position = Vector2(640 - 210, 360 - 100)
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color("#2C3E50")
	ps.border_color = Color("#F1C40F")
	ps.set_border_width_all(4)
	ps.set_corner_radius_all(16)
	center_panel.add_theme_stylebox_override("panel", ps)
	overlay.add_child(center_panel)

	var vb = VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	center_panel.add_child(vb)

	var rank_label = Label.new()
	rank_label.text = "⭐ RANK UP! ⭐"
	rank_label.add_theme_color_override("font_color", Color("#F1C40F"))
	rank_label.add_theme_font_size_override("font_size", 28)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(rank_label)

	var name_label = Label.new()
	name_label.text = "Rank %d — %s" % [new_rank, GameState.get_rank_name()]
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(name_label)

	if unlock_message != "":
		var unlock_label = Label.new()
		unlock_label.text = unlock_message
		unlock_label.add_theme_color_override("font_color", Color("#4ECDC4"))
		unlock_label.add_theme_font_size_override("font_size", 16)
		unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unlock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(unlock_label)

	var tween = overlay.create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.5)
	tween.tween_interval(2.0)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.4)
	tween.tween_callback(overlay.queue_free)

func show_notification(text: String, color: Color, parent: Control, duration: float = 2.0):
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 22)
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position = Vector2(640 - 200, 80)
	label.custom_minimum_size = Vector2(400, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 150
	parent.add_child(label)

	var tween = label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40.0, duration)
	tween.parallel().tween_property(label, "modulate:a", 0.0, duration)
	tween.tween_callback(label.queue_free)

func screen_shake(parent: Node2D, intensity: float = 8.0, duration: float = 0.3):
	if _shake_tween and _shake_tween.is_running():
		_shake_tween.kill()
	_shake_tween = parent.create_tween()
	var steps = int(duration / 0.05)
	for i in steps:
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		_shake_tween.tween_property(parent, "position", offset, 0.05)
	_shake_tween.tween_property(parent, "position", Vector2.ZERO, 0.05)
