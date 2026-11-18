extends StaticBody3D
## Fixed things in the area: ore nodes, furnace, anvil, trough, grindstone, door, lightning rod.

var main: Node
var kind = ""
var ore = ""             # node: which ore it gives
var hits = 0             # node: pickaxe hits so far; anvil/grind: good hits
var misses = 0
var heat = 0.0           # furnace
var contents = {}        # furnace: {"copper": 1, "scrap:2": 1}
var smelt = 0.0          # furnace: seconds spent in band
var slot: RigidBody3D = null  # anvil, grindstone: item sitting on it
var hp = 0.0             # door
var max_hp = 0.0
var tier = 0             # door armor tier
var beat_t = 0.0         # anvil/grind beat clock
var perfect = false      # tests: every beat hit lands
var beat_override = -1   # online: the client judged the beat on its own screen (1 hit, 0 miss)
var weak: MeshInstance3D  # door weak spot
var weak_x = 0.0
var label: Label3D
var size = Vector3.ONE
var node_id = 0          # node: id for online sync
var chunks = 0           # node: chunks left before the vein is tapped out
var max_chunks = 0
var jiggling = false
var dead = false         # a station left behind in an earlier area: just scenery now

func setup(p_main: Node, p_kind: String, p_size: Vector3, color: Color, opts: Dictionary = {}) -> void:
	main = p_main
	kind = p_kind
	size = p_size
	ore = opts.get("ore", "")
	node_id = opts.get("node_id", 0)
	chunks = opts.get("chunks", SF.VEIN_CHUNKS)
	max_chunks = maxi(chunks, 1)
	add_to_group("station")
	if kind == "node":
		add_to_group("node")
	collision_layer = 1
	collision_mask = 0
	add_child(Build.box_shape(size))
	var model_key = "ore_node" if kind == "node" else kind
	var visual = SF.fitted_model(model_key, size)
	if visual and kind == "node":
		SF.tint(visual, SF.ORE_COLORS.get(ore, Color.GRAY), 0.55, 0.6 if ore == "starmetal" else 0.0)
	if visual == null:
		visual = Build.box(size, color, 0.5 if ore == "starmetal" else 0.0)
	visual.name = "Visual"
	visual.position.y = 0.0
	add_child(visual)
	label = Build.label("", 30)
	label.position = Vector3(0, size.y * 0.5 + 0.6, 0)
	add_child(label)
	if kind == "door":
		weak = Build.box(Vector3(SF.WEAK_SPOT_WIDTH, 1.0, 0.1), Color(1.0, 0.9, 0.3), 2.0)
		weak.position = Vector3(0, -size.y * 0.5 + 1.2, size.z * 0.5 + 0.06)
		add_child(weak)

func set_ore(o: String) -> void:
	ore = o
	var v = get_node_or_null("Visual")
	if v is MeshInstance3D:
		(v as MeshInstance3D).material_override = Build.mat(SF.ORE_COLORS.get(o, Color.GRAY), 0.6 if o == "starmetal" else 0.0)
	elif v:
		SF.tint(v, SF.ORE_COLORS.get(o, Color.GRAY), 0.55, 0.6 if o == "starmetal" else 0.0)

## Leave this station behind in an old area: it stops working and drops what's on it.
func retire() -> void:
	dead = true
	remove_from_group("station")
	remove_from_group("node")
	label.text = ""
	if slot and is_instance_valid(slot):
		var it = slot
		clear_slot(it)
		it.station = null
		it.release()

## Squash and spring back when something hits it.
func jiggle() -> void:
	var v = get_node_or_null("Visual")
	if v == null:
		return
	if not has_meta("base_scale") or not jiggling:
		set_meta("base_scale", v.scale)
	var base: Vector3 = get_meta("base_scale")
	jiggling = true
	var tw = create_tween()
	tw.tween_property(v, "scale", base * Vector3(1.18, 0.78, 1.18), 0.05)
	tw.tween_property(v, "scale", base, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func(): jiggling = false)

func set_chunks(n: int) -> void:
	chunks = n
	var v = get_node_or_null("Visual")
	if v:
		var k = lerpf(0.45, 1.0, float(chunks) / max_chunks)
		v.scale = Vector3(k, k, k)
		v.position.y = -size.y * 0.5 * (1.0 - k)

func _physics_process(delta: float) -> void:
	if dead:
		return
	beat_t += delta
	match kind:
		"node":
			label.text = "%s  %d left%s" % [ore.capitalize(), chunks, ("  " + "*".repeat(hits) if hits > 0 else "")]
		"furnace":
			_furnace_tick(delta)
		"anvil":
			_follow_slot(Vector3(0, size.y * 0.5 + 0.15, 0))
			if slot == null:
				label.text = "Anvil"
			elif slot.kind == "ingot" and slot.hot > 0.0:
				label.text = "%s  %d/%d\n%s" % [slot.display_name(), hits, SF.ANVIL_HITS, Build.meter(beat_pos(), 0.5 - zone() * 0.5, 0.5 + zone() * 0.5)]
			else:
				label.text = slot.display_name() + "\ntoo cold: reheat in the furnace"
		"grindstone":
			_follow_slot(Vector3(0, size.y * 0.5 + 0.15, 0))
			if slot == null:
				label.text = "Grindstone"
			elif not slot.quenched:
				label.text = slot.display_name() + "\nquench it with a full bucket"
			else:
				label.text = "%s  %d/%d\n%s" % [slot.display_name(), hits, SF.GRIND_HITS, Build.meter(beat_pos(), 0.5 - SF.GRIND_ZONE * 0.5, 0.5 + SF.GRIND_ZONE * 0.5)]
		"trough":
			label.text = "Quench trough"
		"door":
			weak_x = sin(beat_t * 0.6) * (size.x * 0.5 - 1.0)
			weak.position.x = weak_x
			label.text = "%s door  %d/%d HP\nNeeds %s or better" % [SF.DOORS[main.door_index]["area"], int(ceil(hp)), int(max_hp), SF.material_name(tier)]
		"rod":
			label.text = "Lightning rod"

func zone() -> float:
	return SF.ANVIL_ZONE * (0.5 ** main.mod("tiny_anvil"))

## 0..1 back-and-forth marker; the middle is the beat.
func beat_pos() -> float:
	var t = fmod(beat_t, SF.BEAT_TIME) / SF.BEAT_TIME
	return 1.0 - absf(t * 2.0 - 1.0)

func on_beat(window: float) -> bool:
	if perfect:
		return true
	if beat_override >= 0:
		return beat_override == 1
	return absf(beat_pos() - 0.5) <= window * 0.5

func _follow_slot(offset: Vector3) -> void:
	if main.is_client():
		return
	if slot and is_instance_valid(slot):
		slot.global_position = global_position + offset
		slot.global_rotation = Vector3(0, PI * 0.5, 0)

func clear_slot(item: RigidBody3D) -> void:
	if slot == item:
		slot = null
		hits = 0
		misses = 0

# --- Furnace ---

func _furnace_tick(delta: float) -> void:
	if not main.is_client():
		_furnace_logic(delta)
	var line = "Furnace  heat %d" % int(heat)
	if contents.is_empty():
		label.text = line + "\nempty"
		return
	var stuff = []
	for k in contents.keys():
		stuff.append("%s x%d" % [_content_name(k), contents[k]])
	line += "\n" + ", ".join(stuff)
	var target = best_recipe()
	if target < 0:
		label.text = line + "\nno recipe yet"
		return
	var band: Array = SF.MATERIALS[target]["band"]
	line += "\n%s: keep heat %d-%d  %s" % [SF.material_name(target), int(band[0]), int(band[1]), Build.meter(heat / 100.0, band[0] / 100.0, band[1] / 100.0)]
	label.text = line + ("  %d%%" % int(100.0 * smelt / SF.SMELT_TIME))

func _furnace_logic(delta: float) -> void:
	heat = maxf(0.0, heat - SF.HEAT_DECAY * delta)
	var target = best_recipe()
	if contents.is_empty() or target < 0:
		smelt = 0.0
		return
	var band: Array = SF.MATERIALS[target]["band"]
	if heat > band[1] + SF.OVERHEAT_MARGIN:
		contents.clear()
		smelt = 0.0
		main.toast("Too hot! The batch turned to slag.")
		return
	if heat >= band[0] and heat <= band[1]:
		smelt += delta
		if smelt >= SF.SMELT_TIME:
			_consume(target)
			smelt = 0.0
			var ingot = main.spawn_item("ingot", global_position + Vector3(1.4, 1.0, 0.6), {"tier": target})
			ingot.apply_central_impulse(Vector3(1.5, 2.0, 0.5) * ingot.mass)
			main.toast(SF.material_name(target) + " ingot ready! Grab it with tongs.")

func _content_name(k: String) -> String:
	if k.begins_with("scrap:"):
		return SF.material_name(int(k.substr(6))) + " scrap"
	return k

## Highest material the contents can make right now, or -1.
func best_recipe() -> int:
	for i in range(SF.MATERIALS.size() - 1, -1, -1):
		if contents.get("scrap:%d" % i, 0) > 0:
			return i
		var recipe: Dictionary = SF.MATERIALS[i]["recipe"]
		var ok = true
		for k in recipe:
			if contents.get(k, 0) < recipe[k]:
				ok = false
				break
		if ok:
			return i
	return -1

func _consume(i: int) -> void:
	var sk = "scrap:%d" % i
	if contents.get(sk, 0) > 0:
		_take(sk, 1)
		return
	var recipe: Dictionary = SF.MATERIALS[i]["recipe"]
	for k in recipe:
		_take(k, recipe[k])

func _take(k: String, n: int) -> void:
	contents[k] = contents.get(k, 0) - n
	if contents[k] <= 0:
		contents.erase(k)

## Put an item in. Returns true if the station took it.
func accept(item: RigidBody3D) -> bool:
	match kind:
		"furnace":
			if item.kind == "ore":
				contents[item.ore] = contents.get(item.ore, 0) + 1
			elif item.kind in ["scrap", "ingot", "blank"]:
				var k = "scrap:%d" % item.tier
				contents[k] = contents.get(k, 0) + 1
			else:
				return false
			main.despawn(item)
			return true
		"anvil":
			if slot == null and item.kind == "ingot":
				_seat(item)
				return true
		"grindstone":
			if slot == null and item.kind == "blank":
				_seat(item)
				return true
	return false

func _seat(item: RigidBody3D) -> void:
	slot = item
	hits = 0
	misses = 0
	item.holder = null
	item.gripped_by = null
	item.station = self
	item.attach()

# --- Tool use ---

func pump() -> void:
	heat = minf(110.0, heat + SF.HEAT_PER_PUMP * (1.3 ** main.mod("hot_coals")) * (0.7 ** main.mod("wet_coal")))

func hammer() -> String:
	if slot == null:
		return "Nothing on the anvil"
	if slot.hot <= 0.0:
		return "Too cold. Reheat it in the furnace"
	if on_beat(zone()):
		hits += 1
		if hits >= SF.ANVIL_HITS:
			var t: int = slot.tier
			var pos = slot.global_position
			main.despawn(slot)
			slot = null
			hits = 0
			misses = 0
			# The blade pops off the anvil toward the grindstone side.
			var blank = main.spawn_item("blank", pos + Vector3(0, 0.4, 0), {"tier": t})
			blank.apply_central_impulse(Vector3(1.0, 2.5, 1.0) * blank.mass)
			return SF.material_name(t) + " blade shaped!"
		return "Clang! %d/%d" % [hits, SF.ANVIL_HITS]
	misses += 1
	if misses >= SF.ANVIL_MISSES_TO_RUIN:
		var t2: int = slot.tier
		var pos2 = slot.global_position
		main.despawn(slot)
		slot = null
		main.spawn_item("scrap", pos2 + Vector3(0, 0.4, 0), {"tier": t2})
		return "Warped! It's scrap now"
	return "Off beat! (%d/%d misses)" % [misses, SF.ANVIL_MISSES_TO_RUIN]

func grind(bucket: RigidBody3D) -> String:
	if slot == null:
		return "Nothing on the grindstone"
	if not slot.quenched:
		if not bucket.bucket_full:
			return "Bucket is empty. Fill it at the trough"
		bucket.bucket_full = false
		slot.quenched = true
		return "Hissss! Quenched"
	if on_beat(SF.GRIND_ZONE):
		hits += 1
		if hits >= SF.GRIND_HITS:
			var t: int = slot.tier
			var pos = slot.global_position
			main.despawn(slot)
			slot = null
			hits = 0
			var w = main.spawn_item("weapon", pos + Vector3(0, 0.5, 0), {"tier": t})
			w.spare_handle = main.mod("spare_handle") > 0
			w.apply_central_impulse(Vector3(0, 3.0, 1.5) * w.mass)
			return SF.material_name(t) + " sword finished!"
		return "Shhhk! %d/%d" % [hits, SF.GRIND_HITS]
	return "Slipped. Wait for the middle"

func mine() -> String:
	hits += 1
	if hits >= SF.MINE_HITS:
		hits = 0
		var chunk = main.spawn_item("ore", global_position + Vector3(0, size.y * 0.5 + 0.5, 0), {"ore": ore})
		chunk.apply_central_impulse(Vector3(randf_range(-1.5, 1.5), 3.0, randf_range(0.5, 2.0)) * chunk.mass)
		set_chunks(chunks - 1)
		if chunks <= 0:
			var name = ore.capitalize()
			main.remove_node(self)
			return name + " ore! The vein is tapped out."
		return ore.capitalize() + " ore!"
	return "Tink"

## Hit the door. Returns a message.
func door_hit(player: Node3D, item: RigidBody3D) -> String:
	var weak_hit = absf(player.global_position.x - (global_position.x + weak_x)) <= SF.WEAK_SPOT_WIDTH * 0.5 + 0.3
	var mult = SF.WEAK_SPOT_MULT if weak_hit else 1.0
	if item.kind == "tool":
		_damage(SF.TOOL_DOOR_DAMAGE * mult)
		return "Chip"
	var wear = 1.0 * (1.4 ** main.mod("brittle"))
	if item.tier < tier:
		item.durability -= SF.BOUNCE_DURABILITY_COST * wear
		main.check_weapon(item, player)
		return "CLANG! Bounced off. Needs %s or better" % SF.material_name(tier)
	var dmg = SF.WEAPON_DAMAGE * (1.0 + SF.TIER_BONUS * (item.tier - tier)) * mult * (1.25 ** main.mod("sharp"))
	item.durability -= wear
	_damage(dmg)
	main.check_weapon(item, player)
	return ("WEAK SPOT! " if weak_hit else "") + "-%d" % int(dmg)

func _damage(d: float) -> void:
	hp -= d
	var v = get_node_or_null("Visual")
	if v:
		v.position.x = randf_range(-0.08, 0.08)
	if hp <= 0.0:
		main.door_broken()
