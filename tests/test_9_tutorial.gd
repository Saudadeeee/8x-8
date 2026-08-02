extends SceneTree
# BATCH 9 — huong dan nhap mon.
#
# Bat bien thiet ke cot loi ("nguyen to den tu O, khong tu loai thap") khong ai
# tu doan ra duoc. Khong co huong dan thi nguoi choi moi bo qua toan bo he thong
# lam nen ban sac cua game.
var fail := 0
func _init() -> void: _run()
func ok(c: bool, l: String, e: String = "") -> void:
	if c: print("  OK   ", l, ("  " + e) if e != "" else "")
	else: print("  FAIL ", l, "  ", e); fail += 1

func _run() -> void:
	await process_frame
	var gm = root.get_node("/root/GameManagerSingleton")
	ok(gm.meta_progress != null, "co meta_progress")
	if gm.meta_progress == null:
		print("
== BATCH 9 FAIL=%d ==" % fail); quit(); return

	ok("seen_tutorial" in gm.meta_progress, "MetaProgress co co seen_tutorial")
	gm.meta_progress.seen_tutorial = false
	ok(not TutorialOverlay.already_seen(), "chua xem -> already_seen() = false")

	gm.start_run(load("res://res/kings/king_iron.tres"))
	change_scene_to_file("res://scenes/map/game_map.tscn")
	await process_frame; await process_frame
	await create_timer(0.8).timeout
	var map = root.get_node_or_null("/root/GameMap")
	ok(map != null, "vao duoc man choi")
	if map == null:
		print("
== BATCH 9 FAIL=%d ==" % fail); quit(); return

	var tut = map.get_node_or_null("TutorialOverlay")
	ok(tut != null, "van dau TU DONG hien huong dan")
	ok(paused, "game tam dung trong luc doc")
	if tut:
		ok(tut.PAGES.size() >= 4, "co it nhat 4 the", "%d the" % tut.PAGES.size())
		# Moi the phai co tieu de + than
		var bad := ""
		for pg in tut.PAGES:
			if str(pg.get("title", "")).is_empty() or str(pg.get("body", "")).is_empty():
				bad += str(pg.get("title", "?")) + " "
		ok(bad == "", "moi the co tieu de va noi dung", bad)
		# Tutorial phai day DU BON bat bien cua thiet ke hien tai. Thieu mot cai
		# la nguoi choi mo game ra khong hieu minh dang toi uu cai gi.
		var all_text := ""
		for pg in tut.PAGES:
			all_text += str(pg.get("title", "")) + str(pg.get("body", "")) 				+ str(pg.get("accent", ""))
		var low := all_text.to_lower()
		var missing := ""
		if not (low.contains("sát thương") and low.contains("tổng máu")):
			missing += "nguong-bang-so "
		if not (low.contains("xe") and low.contains("tượng") and low.contains("mã")):
			missing += "nuoc-di-quan-co "
		if not low.contains("thế"):
			missing += "the-co "
		if not low.contains("bộ"):
			missing += "bo-quan "
		if not (low.contains("ô") and low.contains("nguyên tố")):
			missing += "o-nguyen-to "
		ok(missing == "", "tutorial day du moi bat bien cot loi", missing)

		for i in range(tut.PAGES.size()):
			tut._next()
		await process_frame
		ok(not paused, "doc xong thi bo tam dung")
		ok(gm.meta_progress.seen_tutorial, "ghi co da xem")
		ok(TutorialOverlay.already_seen(), "lan sau khong hien lai")

	# Nut trong Cai Dat bat lai duoc
	TutorialOverlay.reset_seen()
	ok(not TutorialOverlay.already_seen(), "reset_seen() bat lai duoc huong dan")
	gm.meta_progress.seen_tutorial = true
	gm.meta_progress.save()

	print("
== BATCH 9 FAIL=%d ==" % fail)
	quit()
