extends SceneTree
func _init():
	for f in ["dungeon/floor_wood_large.gltf","dungeon/wall.gltf","dungeon/table_medium.gltf","dungeon/rocks.gltf","dungeon/shelves_decorated.gltf","dungeon/barrel_large.gltf","dungeon/torch_mounted.gltf","dungeon/banner_patternA_red.gltf","dungeon/bar_straight_A.gltf","tools/grindstone.gltf","tools/hammer.gltf","tools/tongs.gltf","tools/pickaxe.gltf","tools/bucket_metal.gltf","weapons/sword_A.gltf","weapons/dagger_A.gltf","weapons/axe_A.gltf","weapons/shield_A.gltf","weapons/staff_A.gltf","weapons/halberd.gltf","weapons/spear_A.gltf","weapons/hammer_A.gltf","weapons/sword_E.gltf","resources/Iron_Bar.gltf","resources/Copper_Nugget_Large.gltf","dungeon/chest.gltf","dungeon/keg.gltf","dungeon/crate_large.gltf","dungeon/stool.gltf","dungeon/candle_triple.gltf","dungeon/coin_stack_large.gltf"]:
		var s = load("res://assets/models/"+f).instantiate()
		var bb = BK.mesh_aabb(s, Transform3D())
		var names = []
		for mi in s.find_children("*","MeshInstance3D",true,false): names.append(str(mi.name)+"@"+str(mi.position.snapped(Vector3.ONE*0.01))+" "+str(mi.get_aabb().size.snapped(Vector3.ONE*0.01)))
		print(f, " pos ", bb.position.snapped(Vector3.ONE*0.01), " size ", bb.size.snapped(Vector3.ONE*0.01), " ", names if names.size() < 4 else names.size())
		s.free()
	quit()
