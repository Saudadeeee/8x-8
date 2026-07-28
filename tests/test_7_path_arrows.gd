extends SceneTree
# BATCH 7 — mui ten vang chi huong dich di tren duong.
var fail := 0
func _init() -> void: _run()
func ok(c: bool, l: String, e: String = "") -> void:
	if c: print("  OK   ", l, ("  " + e) if e != "" else "")
	else: print("  FAIL ", l, "  ", e); fail += 1

func _run() -> void:
	await process_frame
	var gm = root.get_node("/root/GameManagerSingleton")
	gm.start_run(load("res://res/kings/king_iron.tres"))
	change_scene_to_file("res://scenes/map/game_map.tscn")
	await process_frame; await process_frame
	var map = root.get_node_or_null("/root/GameMap")
	var gc = map.grid_controller
	var pa = map.path_arrows
	ok(pa != null, "co node PathArrows")
	if pa == null: quit(); return
	var mm = pa._multi.multimesh
	var path: Array = gc.current_path_grid
	print("     duong dai %d o | so mui ten %d" % [path.size(), mm.instance_count])
	ok(mm.instance_count == path.size() - 2, "so mui ten = so o - 2 (bo o Vua)")

	# Huong tung mui ten phai tro sang o KE TIEP
	var wrong := 0
	for i in range(mm.instance_count):
		var t: Transform3D = mm.get_instance_transform(i)
		var here: Vector3 = GridUtil.cell_to_world(path[i])
		var nxt: Vector3 = GridUtil.cell_to_world(path[i + 1])
		if t.origin.distance_to(Vector3(here.x, t.origin.y, here.z)) > 0.01: wrong += 1
		# Mesh tro +Z; sau khi xoay, truc Z cua basis phai cung huong voi buoc di
		var want := (nxt - here).normalized()
		var got: Vector3 = t.basis.z.normalized()
		if got.dot(want) < 0.99: wrong += 1
	ok(wrong == 0, "moi mui ten dat dung o va tro dung huong", "%d sai" % wrong)

	# Cao do phai tren overlay quad (0.06) va duoi model thap
	var y: float = mm.get_instance_transform(0).origin.y
	ok(y > 0.06 and y < 0.3, "cao do hop le", "y=%.3f" % y)

	# Mo rong ban do -> phai rai lai
	var n0: int = mm.instance_count
	gc.expand()
	await process_frame
	await process_frame
	var n1: int = pa._multi.multimesh.instance_count
	print("     sau mo rong: duong %d o | mui ten %d" % [gc.current_path_grid.size(), n1])
	ok(n1 > n0, "mo rong xong co them mui ten", "%d -> %d" % [n0, n1])
	ok(n1 == gc.current_path_grid.size() - 2, "van khop do dai duong moi")
	var wrong2 := 0
	var p2: Array = gc.current_path_grid
	for i in range(n1):
		var t: Transform3D = pa._multi.multimesh.get_instance_transform(i)
		var want := (GridUtil.cell_to_world(p2[i + 1]) - GridUtil.cell_to_world(p2[i])).normalized()
		if t.basis.z.normalized().dot(want) < 0.99: wrong2 += 1
	ok(wrong2 == 0, "sau rebase huong van dung", "%d sai" % wrong2)

	print("\n== BATCH 7 FAIL=%d ==" % fail)
	quit()
