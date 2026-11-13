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
		if extra == "--season":
			Season.add_xp(Season.XP_PER * 23 + 300, "test")
			UI.replace("season"); await shot("g30_season")
			UI.replace("home"); await shot("g31_home_season")
			UI.replace("season"); await w(0.3)
			UI.modules[3]._unlock_dialog(); await w(0.5); await shot("g32_unlock")
			UI.close_top(true); await w(0.6)
			print("PREMIUM ", Season.premium(), " claimable ", Season.claim_count())
			print("CLAIMED ", Season.claim_all(), " unopened ", Save.data.unopened)
			UI.replace("season", {"focus": 20}); await shot("g33_season_claimed")
			for pkid in ["pp82x5", "pp83x2", "pp85x1"]:
				var items = Sys.generate_pack(pkid)
				print("PACK ", pkid, " ", items.map(func(x): return "%d %s" % [x.ovr, x.name]))
			UI.modules[1].open_pack("pick86", false); await w(1.6); await shot("g34_pick")
			print("PICK ", Save.data.pick_cur)
			UI.modules[1].open_pack("pickasc", false); await w(1.6); await shot("g35_pick_asc")
			var asc = Data.P("asc_p443"); print("ASC ", asc.ovr, " ", asc.stats, " sm ", asc.sm)
			UI.inspect(asc); await shot("g36_asc_card"); UI.close_top(null)
			print("MARKET has pass: ", Sys.market_search({}).any(func(l): return Data.P(l.pid).type == "pass"))
		if extra == "--gallery":
			print("TOP ", Gallery.top_clubs)
			for pid in ["p256", "p247", "p420", "p443", "p0", "p14"]: print("GEMS ", Data.P(pid).name, " ", Data.P(pid).ovr, " ", Gallery.gems(Data.P(pid)))
			print("GEMS asc ", Gallery.gems(Data.P("asc_p443")), " 70-rated ", Gallery.gems(Data.players.filter(func(x): return x.ovr == 70)[0]))
			var club: String = Gallery.top_clubs["ENG1"][0]
			for pl in Data.by_club[club]:
				if pl.type == "base" and pl.ovr >= 78: Gallery.record(pl.id, "pack")
			var sid = "C:" + club
			print("SET ", sid, " ", Gallery.score(sid).total, " grade ", Gallery.score(sid).grade, " max ", Gallery.max_score(sid))
			UI.go("gallery"); await shot("g40_gallery")
			UI.go("galleryset", {"id": sid}); await shot("g41_set")
			print("GRADE ", Gallery.grade(sid), " tokens ", Gallery.tokens(), " level ", Gallery.level())
			Gallery.st().tokens = 3000
			UI.go("gallerystore"); await shot("g42_store")
			print("BUY ", Gallery.buy(Gallery.STORE[6]), " unopened has icon pick ", Save.data.unopened.has("pickicon"))
			UI.go("galleryset", {"id": "L:ESP1"}); await shot("g43_league")
			UI.replace("home"); await shot("g44_home")
		if extra == "--event":
			print("STARS ", Event.stars.map(func(x): return "%d %s" % [x.ovr, x.name]))
			UI.go("event"); await shot("g60_event")
			Save.data.unopened.append("rspick")
			var it = Sys.club_add("p443", false, "pack")
			var sq = Sys.active_squad(); sq.slots[0] = it.uid
			print("ELIGIBLE ", Event.evo_eligible(it), " start ", Event.start_evo(it.uid))
			UI.replace("event", {"tab": "evo"}); await shot("g61_evo")
			for k in 6:
				Event.after_match({"user_side": "home", "goals": [{"side": "home", "pid": it.pid}]}, "W")
			print("EVO pid ", it.pid, " ovr ", Data.P(it.pid).ovr, " sm ", Data.P(it.pid).sm, " evos ", Event.st().evos.size(), " evolved ", Event.st().evolved)
			Data.by_id.erase(it.pid); print("REGEN ", Data.P(it.pid).ovr)
			for o in Event.objectives(): Save.data.objectives.progress[Sys.obj_key(o)] = o.target
			UI.replace("event", {"tab": "objectives"}); await shot("g62_objectives")
			for o in Event.objectives(): Sys.obj_claim(o)
			print("TOKENS ", Event.tokens(), " final ", Event.claim_final())
			UI.replace("event", {"tab": "store"}); await shot("g63_store")
			print("RSPACK ", Sys.generate_pack("rspack").map(func(x): return "%d %s %s" % [x.ovr, x.name, x.type]))
			UI.replace("sbc", {"cat": "Rising Stars"}); await shot("g64_sbc")
			UI.replace("home"); await shot("g65_home")
			UI.modules[1].open_pack("rspack", true); await w(7.0); await shot("g66_rs_walkout")
		if extra == "--match":
			UI.run_match({"home": Sys.club_team("MCI"), "away": Sys.club_team("RMA"), "user_side": "", "difficulty": "professional", "half_len": 3, "sim": false, "mode": "kickoff", "title": "Kick Off"}, func(res): print("RESULT ", res.hg, "-", res.ag))
			await w(1.0)
			for c in UI.root.get_children(): print("ROOTCHILD ", c.name, " ", c.size, " ", c.get_class())
			await w(2.0); await shot("g10_match")
			await w(4.0); await shot("g11_match")
			print("FPS ", Engine.get_frames_per_second(), " max ", Engine.max_fps)
	for extra in OS.get_cmdline_user_args():
		if extra == "--simtest":
			for g in 4:
				var sim := MatchSim.new({"home": Sys.club_team(["MCI", "ARS", "INT", "PSG"][g]), "away": Sys.club_team(["RMA", "LIV", "FCB2", "BVB"][g]), "user_side": "", "difficulty": "professional", "half_len": 3, "mode": "test"})
				var n := 0
				while not sim.finished and n < 60 * 500: sim.update(1.0 / 60.0); n += 1
				print("SIM ", sim.teams.home.short, " ", sim.score.home, "-", sim.score.away, " ", sim.teams.away.short, " shots ", sim.stats.shots, " sot ", sim.stats.sot, " passes ", sim.stats.passes, " fouls ", sim.stats.fouls, " corners ", sim.stats.corners)
	for extra in OS.get_cmdline_user_args():
		if extra == "--aitest":
			for lvl in [0.45, 0.8, 1.2]:
				var gs = [0, 0]; var sh = [0, 0]
				for g in 3:
					var sim := MatchSim.new({"home": Sys.club_team("ARS"), "away": Sys.club_team("LIV"), "user_side": "home" if g == 2 else "", "difficulty": "professional", "ai": lvl, "half_len": 3, "mode": "test"})
					if g == 2: sim.inp = {"x": 0.0, "y": 0.0, "jockey": true, "contain": true}
					var n := 0
					while not sim.finished and n < 60 * 500: sim.update(1.0 / 60.0); n += 1
					gs[0] += sim.score.home; gs[1] += sim.score.away; sh[0] += sim.stats.shots[0]; sh[1] += sim.stats.shots[1]
				print("AI ", lvl, " goals ", gs, " shots ", sh)
			print("RIVALS ai div10 ", Sys.rivals_ai(10), " div1 ", Sys.rivals_ai(1), " str ", Sys.rivals_strength(10), "/", Sys.rivals_strength(1))
			UI.replace("play"); await w(0.2); UI.go("rivals"); await shot("g50_rivals")
	print("AUTOTEST DONE")
	get_tree().quit()
