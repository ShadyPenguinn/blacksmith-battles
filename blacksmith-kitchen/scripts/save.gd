class_name Save
extends RefCounted
## Progress, kept in the browser (or user://) between visits.

const PATH := "user://blacksmith_kitchen.json"
static var data := {}

static func defaults() -> Dictionary:
	return {"day": 0, "coins": 0, "day_stars": {}, "best": {}, "forged": 0, "upgrades": [], "rush_best": 0}

static func load_game() -> void:
	data = defaults()
	if FileAccess.file_exists(PATH):
		var f = FileAccess.open(PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			for k in parsed:
				data[k] = parsed[k]

static func save_game() -> void:
	var f = FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

static func reset() -> void:
	data = defaults()
	save_game()

## Highest day you can play (0-based).
static func open_day() -> int:
	return int(data.get("day", 0))

static func has_upgrade(id: String) -> bool:
	return id in data.get("upgrades", [])

## Weapons you've met in the shop are unlocked in the recipe book.
static func unlocked_weapons() -> Array:
	var out = []
	for d in mini(open_day() + 1, BK.DAYS.size()):
		for o in BK.DAYS[d]["orders"]:
			if not o[1] in out:
				out.append(o[1])
	var sorted = []
	for w in BK.WEAPON_ORDER:
		if w in out:
			sorted.append(w)
	return sorted

static func max_tier() -> int:
	var t = 0
	for d in mini(open_day() + 1, BK.DAYS.size()):
		for o in BK.DAYS[d]["orders"]:
			t = maxi(t, o[2])
	return t

## Record a finished weapon. Keeps the best medal per weapon and material.
static func record(weapon: String, tier: int, score: float) -> void:
	var key = weapon + ":" + str(tier)
	var best: Dictionary = data.get("best", {})
	if score > float(best.get(key, -1.0)):
		best[key] = score
	data["best"] = best
	data["forged"] = int(data.get("forged", 0)) + 1

static func best_score(weapon: String, tier: int = -1) -> float:
	var best: Dictionary = data.get("best", {})
	if tier >= 0:
		return float(best.get(weapon + ":" + str(tier), -1.0))
	var b = -1.0
	for k in best:
		if String(k).begins_with(weapon + ":"):
			b = maxf(b, float(best[k]))
	return b
