extends Node

signal rank_up(new_rank: int)
signal xp_changed(current_xp: int, next_threshold: int, rank_start: int)
signal tips_changed(new_total: float)

var rank: int = 1
var xp: int = 0
var total_tips: float = 0.0

const RANK_THRESHOLDS: Array[int] = [0, 3000, 7000, 13000, 20000]
const RANK_NAMES := ["Rookie", "Trainee", "Line Cook", "Chef", "Head Chef"]

var unlocked_ingredients: Dictionary = {
	"breads": ["White Sandwich", "Sourdough", "Wheat"],
	"cheeses": ["American", "Cheddar", "Swiss"],
	"proteins": ["Turkey Slices", "Ham", "Bacon Strips", "Salami"],
	"veggies": ["Lettuce", "Tomato", "Onion", "Pickles", "Jalapeños", "Avocado"],
	"sauces": ["Mustard", "Mayo", "Ranch", "Hot Sauce", "Pesto"],
	"sides": ["Classic Fries"],
	"side_toppings": ["Ketchup", "Cheese Sauce", "Salt & Vinegar"],
}

var unlock_messages: Dictionary = {
	2: "Ciabatta & Rye breads unlocked!",
	3: "Pepper Jack & Provolone unlocked!",
	4: "Waffle Fries unlocked! Tip ×1.1!",
	5: "Sweet Potato Fries unlocked! Full roster!",
}

var tip_multiplier: float = 1.0

func reset():
	rank = 1
	xp = 0
	total_tips = 0.0
	tip_multiplier = 1.0
	unlocked_ingredients["breads"] = ["White Sandwich", "Sourdough", "Wheat"]
	unlocked_ingredients["cheeses"] = ["American", "Cheddar", "Swiss"]
	unlocked_ingredients["sides"] = ["Classic Fries"]

func add_xp(amount: int) -> Array:
	var old_rank = rank
	xp += amount
	_check_rank_up()
	emit_signal("xp_changed", xp, get_next_threshold(), get_current_threshold())
	var unlocks: Array = []
	if rank > old_rank:
		unlocks.append(unlock_messages.get(rank, ""))
	return unlocks

func add_tip(amount: float):
	total_tips += amount * tip_multiplier
	emit_signal("tips_changed", total_tips)

func get_next_threshold() -> int:
	if rank >= RANK_THRESHOLDS.size():
		return RANK_THRESHOLDS[-1]
	return RANK_THRESHOLDS[rank]

func get_current_threshold() -> int:
	if rank <= 1:
		return 0
	return RANK_THRESHOLDS[rank - 1]

func get_xp_in_current_rank() -> int:
	return xp - get_current_threshold()

func get_xp_needed_for_rank() -> int:
	return get_next_threshold() - get_current_threshold()

func get_rank_name() -> String:
	if rank <= RANK_NAMES.size():
		return RANK_NAMES[rank - 1]
	return "Master Chef"

func _check_rank_up():
	while rank < RANK_THRESHOLDS.size() and xp >= RANK_THRESHOLDS[rank]:
		rank += 1
		_apply_rank_unlock(rank)
		emit_signal("rank_up", rank)

func _apply_rank_unlock(new_rank: int):
	match new_rank:
		2:
			if not "Ciabatta" in unlocked_ingredients["breads"]:
				unlocked_ingredients["breads"].append_array(["Ciabatta", "Rye"])
		3:
			if not "Pepper Jack" in unlocked_ingredients["cheeses"]:
				unlocked_ingredients["cheeses"].append_array(["Pepper Jack", "Provolone"])
			tip_multiplier = 1.0
		4:
			if not "Waffle Fries" in unlocked_ingredients["sides"]:
				unlocked_ingredients["sides"].append("Waffle Fries")
			tip_multiplier = 1.1
		5:
			if not "Sweet Potato Fries" in unlocked_ingredients["sides"]:
				unlocked_ingredients["sides"].append("Sweet Potato Fries")

func get_tip_for_score(score_pct: float) -> float:
	var base: float
	if score_pct >= 90.0:
		base = 8.0
	elif score_pct >= 75.0:
		base = 6.0
	elif score_pct >= 60.0:
		base = 4.0
	elif score_pct >= 40.0:
		base = 2.0
	else:
		base = 0.0
	return base * tip_multiplier
