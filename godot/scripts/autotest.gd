extends Node
## Developer auto-test: run with `-- --autotest=<outdir>`. Walks through screens,
## saves screenshots and quits. Not active in normal play.

var out = ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest="): out = a.substr(11)
	if out == "": queue_free(); return
	DirAccess.make_dir_recursive_absolute(out)
	run()

func shot(name: String) -> void:
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)

func w(t: float) -> void: await get_tree().create_timer(t).timeout

func run() -> void:
	await w(1.0)
	Save.wipe()
	await shot("g01_title")
	UI.reset("onboard"); await shot("g02_onboard")
	Save.create("Tester"); UI.modules[0].grant_starter(); Save.data.coins = 400000; Save.data.points = 8000
	UI.reset("main"); await shot("g03_main")
	for t in ["home", "objectives", "play", "club", "sbc", "transfers", "store"]:
		UI.replace(t); await shot("g04_" + t)
	UI.go("squad"); await shot("g05_squad")
	for extra in OS.get_cmdline_user_args():
		if extra == "--pack":
			for pk in ["premium", "ultimate", "legends"]:
				UI.replace("store")
				UI.modules[1].open_pack(pk, true)
				await w(1.2); await shot("g20_pack_" + pk)
				await w(6.5); await shot("g21_reveal_" + pk)
				var ov = UI.overlay.get_child(UI.overlay.get_child_count() - 1) if UI.overlay.get_child_count() > 0 else null
				if ov and ov.has_method("done"): ov.done()
				await w(1.0); await shot("g22_items_" + pk)
				print("CUR ", UI.cur_name)
				UI.modules[1].s_packresult  # noop
		if extra == "--match":
			UI.run_match({"home": Sys.club_team("MCI"), "away": Sys.club_team("RMA"), "user_side": "", "difficulty": "professional", "half_len": 3, "sim": false, "mode": "kickoff", "title": "Kick Off"}, func(res): print("RESULT ", res.hg, "-", res.ag))
			await w(1.0)
			for c in UI.root.get_children(): print("ROOTCHILD ", c.name, " ", c.size, " ", c.get_class())
			await w(2.0); await shot("g10_match")
			await w(4.0); await shot("g11_match")
	for extra in OS.get_cmdline_user_args():
		if extra == "--simtest":
			for g in 4:
				var sim := MatchSim.new({"home": Sys.club_team(["MCI", "ARS", "INT", "PSG"][g]), "away": Sys.club_team(["RMA", "LIV", "FCB2", "BVB"][g]), "user_side": "", "difficulty": "professional", "half_len": 3, "mode": "test"})
				var n := 0
				while not sim.finished and n < 60 * 500: sim.update(1.0 / 60.0); n += 1
				print("SIM ", sim.teams.home.short, " ", sim.score.home, "-", sim.score.away, " ", sim.teams.away.short, " shots ", sim.stats.shots, " sot ", sim.stats.sot, " passes ", sim.stats.passes, " fouls ", sim.stats.fouls, " corners ", sim.stats.corners)
	print("AUTOTEST DONE")
	get_tree().quit()
