class_name OrderTicket
extends RefCounted

# Order contents
var customer_name: String = ""
var customer_color: Color = Color.WHITE
var bread: String = ""
var cheese: String = ""
var toppings: Array = []
var doneness: String = "Medium"   # Light | Medium | Well Done
var side: String = ""
var side_toppings: Array = []
var strictness: float = 1.0       # multiplier: 0.8 lenient, 1.0 avg, 1.2 strict, 1.5 very strict

# Tracking
var order_taken_time: float = -1.0
var serve_time: float = -1.0
var is_active: bool = false

# Scores (0.0 – 1.0 each, -1 = not yet computed)
var waiting_score: float = -1.0
var build_score: float = -1.0
var grill_score: float = -1.0
var fry_score: float = -1.0

# Used to ferry the sandwich between stations
var sandwich_placed: bool = false
var sandwich_in_grill: bool = false
var sandwich_grilled: bool = false
var fries_ready: bool = false

func mark_order_taken(time_now: float):
	order_taken_time = time_now
	is_active = true

func compute_waiting_score(_total_shift_time: float = 0.0):
	if order_taken_time < 0 or serve_time < 0:
		waiting_score = 0.0
		return
	var elapsed = serve_time - order_taken_time
	# Best: < 60s → 100%; 120s → 75%; 180s → 50%; > 240s → 0
	if elapsed <= 60.0:
		waiting_score = 1.0
	elif elapsed <= 120.0:
		waiting_score = 0.75 + (120.0 - elapsed) / 240.0
	elif elapsed <= 180.0:
		waiting_score = 0.5 + (180.0 - elapsed) / 240.0
	elif elapsed <= 240.0:
		waiting_score = 0.25 + (240.0 - elapsed) / 240.0
	else:
		waiting_score = 0.0
	waiting_score = clampf(waiting_score, 0.0, 1.0)

func get_final_score() -> float:
	var scores := [waiting_score, build_score, grill_score, fry_score]
	var total := 0.0
	var count := 0
	for s in scores:
		if s >= 0.0:
			total += s
			count += 1
	if count == 0:
		return 0.0
	return total / float(count)

func get_final_score_pct() -> float:
	return get_final_score() * 100.0

func calculate_tip() -> float:
	return GameState.get_tip_for_score(get_final_score_pct())

func get_xp() -> int:
	return int(get_final_score() * 1000.0)

func get_doneness_display() -> String:
	match doneness:
		"Light":     return "Light (60–75%)"
		"Medium":    return "Medium (76–90%)"
		"Well Done": return "Well Done (91–100%)"
	return doneness

func get_summary() -> String:
	var parts := PackedStringArray()
	parts.append("Bread: " + bread)
	parts.append("Cheese: " + cheese)
	if toppings.size() > 0:
		parts.append("Toppings: " + ", ".join(toppings))
	parts.append("Grill: " + doneness)
	parts.append("Side: " + side)
	if side_toppings.size() > 0:
		parts.append("Side Toppings: " + ", ".join(side_toppings))
	return "\n".join(parts)
