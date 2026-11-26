extends SceneTree
func _init():
	for p in ["res://assets/models/anims/Rig_Medium_General.glb","res://assets/models/anims/Rig_Medium_Tools.glb","res://assets/models/anims/Rig_Medium_MovementBasic.glb","res://assets/models/anims/Rig_Medium_MovementAdvanced.glb"]:
		var s = load(p).instantiate()
		for ap in s.find_children("*","AnimationPlayer",true,false):
			print(p.get_file(), ": ", ap.get_animation_list())
		s.free()
	for p in ["res://assets/models/stations/furnace_forge.glb","res://assets/models/stations/bellows_giant.glb","res://assets/models/stations/trip_hammer_parts.glb","res://assets/models/stations/dunk_tank_parts.glb","res://assets/models/tools/grindstone.gltf","res://assets/models/tools/anvil.gltf","res://assets/models/dungeon/bar_straight_A.gltf"]:
		var s = load(p).instantiate()
		var out = []
		for n in s.find_children("*","Node3D",true,false):
			var info = String(n.name)
			if n is MeshInstance3D: info += "[" + str(n.get_aabb().size.snapped(Vector3.ONE*0.01)) + "]"
			out.append(info)
		print(p.get_file(), " AABB ", _aabb(s), ": ", out)
		for ap in s.find_children("*","AnimationPlayer",true,false): print("  anims ", ap.get_animation_list())
		s.free()
	quit()
func _aabb(n):
	var b = AABB(); var first=true
	for mi in n.find_children("*","MeshInstance3D",true,false):
		var t = mi.transform
		var p = mi.get_parent()
		while p and p != n: 
			if p is Node3D: t = p.transform * t
			p = p.get_parent()
		var bb = t * mi.get_aabb()
		b = bb if first else b.merge(bb); first=false
	return b
