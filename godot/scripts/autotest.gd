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
		if extra == "--evo":
			UI.replace("evolutions"); await shot("g70_evos")
			for k in 4: UI._send_nav(Vector2i(1, 0)); await w(0.15)
			UI._send_nav(Vector2i(0, 1)); await w(0.3)
			print("FOCUS after nav: ", UI.get_viewport().gui_get_focus_owner())
			await shot("g71_evos_nav")
			var cand: Array = Data.players.filter(func(x): return x.type == "base" and x.pos == "ST" and x.ovr == 80)
			var it = Sys.club_add(cand[0].id, false, "pack")
			var ev = Evo.spec("finisher")
			print("ELIG ", Evo.eligible(ev, it), " start ", Evo.start(ev, it.uid))
			var sq = Sys.active_squad(); sq.slots[10] = it.uid
			Evo.after_match({"user_side": "home", "goals": [{"side": "home", "pid": it.pid, "assist": ""}]}, "W", 0)
			print("EVO lvl ", Evo.st().active[0].lvl if not Evo.st().active.is_empty() else -1, " pid ", it.pid, " ovr ", Data.P(it.pid).ovr)
			UI.replace("evolutions", {"tab": "active"}); await shot("g72_active")
			for k in 6: Evo.after_match({"user_side": "home", "goals": []}, "W", 1)
			print("DONE ", Evo.st().done, " final ", Data.P(it.pid).ovr, " ", Data.P(it.pid).stats, " wf ", Data.P(it.pid).wf, " base wf ", cand[0].wf)
			Data.by_id.erase(it.pid); print("REGEN ", Data.P(it.pid).ovr, " ", Data.P(it.pid).evo_name)
			UI.replace("evolutions", {"tab": "done"}); await shot("g73_done")
			var gr = Evo.spec("goldrush"); var sil: Array = Data.players.filter(func(x): return x.type == "base" and x.ovr == 72)
			print("GOLDRUSH final ", Evo.preview(gr, sil[0].id, 3).ovr, " tier ", Data.rarity_name(Evo.preview(gr, sil[0].id, 3)))
			UI.replace("objectives"); await w(0.4)
			for k in 3: UI._send_nav(Vector2i(0, 1)); await w(0.12)
			var before = UI._focus_path(); UI.replace("objectives"); await w(0.5)
			print("RESTORE same: ", before == UI._focus_path(), " ", before, " -> ", UI._focus_path())
			var nn = UI._resolve_path(before); print("RESOLVED ", nn, " vis ", nn.is_visible_in_tree() if nn else null, " fm ", nn.focus_mode if nn else null)
		if extra == "--market":
			UI.replace("transfers"); await shot("g80_tr_hub")
			UI.replace("transfers", {"tab": "search", "filter": {"lg": "ENG1", "min": 80}, "run": true}); await w(0.3); await shot("g81_search")
			var ls: Array = Sys.M().listings
			print("RESULTS ", ls.size(), " pool ", Sys.M().pool.size())
			Sys.toggle_watch(ls[0]); Sys.place_bid(ls[1], Sys.min_bid(ls[1]))
			UI.compare_price(Data.P(ls[2].pid)); await w(0.4); await shot("g82_compare"); UI.close_top(null); await w(0.3)
			for k in 5: Sys.market_tick(); await w(0.05)
			print("POOL after ticks ", Sys.M().pool.size())
			# pack -> new items screen
			Save.data.pending = []
			UI.replace("store"); UI.modules[1].open_pack("jumbo", true)
			await w(1.0)
			var ov = UI.overlay.get_child(UI.overlay.get_child_count() - 1) if UI.overlay.get_child_count() > 0 else null
			if ov and ov.has_method("done"): ov.done()
			await w(1.2); await shot("g83_newitems")
			for k in 2: UI._send_nav(Vector2i(0, -1)); await w(0.15)
			UI._send_nav(Vector2i(1, 0)); await w(0.1)
			for k in 2: UI._send_nav(Vector2i(0, 1)); await w(0.15)
			await w(0.3); await shot("g84_newitems_moved")
			print("DESTS ", Save.data.pending.map(func(x): return x.dest))
			var r = Sys.apply_pending(); print("APPLY ", r, " tl ", Sys.M().tl.size())
			UI.replace("transfers", {"tab": "list"}); await shot("g85_tlist")
			UI.replace("transfers", {"tab": "targets"}); await shot("g86_targets")
		if extra == "--champs":
			UI.go("champions"); await shot("g95_champs_unqualified")
			for k in 4: print("QP +", Champs.add_qp("W"))
			Champs.add_qp("D"); Champs.add_qp("L"); Champs.add_qp("W")
			print("QUALIFIED ", Champs.qualified(), " qp ", Champs.st().qp)
			UI.replace("champions"); await shot("g96_champs_qualified")
			print("START ", Champs.start())
			for k in 7: Champs.record(k % 3 != 2, "2-1", "Opp")
			print("RUN ", Champs.run().pts, " rank ", Champs.rank_name(Champs.rank_for(int(Champs.run().pts))), " cooldown ", int(Champs.cooldown_left()))
			UI.replace("champions"); await w(0.4)
			for k in 3: UI._send_nav(Vector2i(0, -1)); await w(0.15)
			await shot("g97_champs_run")
			UI.modules[8]._preview_all(int(Champs.run().pts)); await w(0.4); await shot("g98_preview"); UI.close_top(null); await w(0.2)
			var res = Champs.claim(); print("CLAIM ", res, " tokens ", Champs.tokens())
			UI.go("champsstore"); await shot("g99_champs_store")
		if extra == "--gemsbc":
			for pid in ["p256", "p14", "p0"]: print("GEM ", Data.P(pid).name, " ", Data.P(pid).ovr, " = ", Gallery.gems(Data.P(pid)))
			var sil = Data.players.filter(func(x): return x.type == "base" and x.ovr == 73)[0]; print("GEM silver 73 = ", Gallery.gems(sil), "  special t0 = ", Gallery.gems(Data.P("t0")))
			Save.data.sbc.erase("intro_seen")
			UI.replace("sbc"); await w(0.8); await shot("g100_sbc_intro")
			UI.replace("sbc", {"cat": "Exchanges"}); await w(0.5)
			UI._send_nav(Vector2i(1, 0)); await w(0.3); await shot("g101_sbc_carousel")
			var gs: Dictionary = {}
			for x in Data.sbcs: if x.id == "ex_gold": gs = x
			var golds = Data.players.filter(func(x): return x.type == "base" and x.ovr >= 76 and x.ovr <= 82)
			for k in 12: Sys.club_add(golds[k * 7].id, true, "pack")
			var fill = GemSBC.autofill(gs)
			print("AUTOFILL ", fill.size(), " score ", GemSBC.score(fill), " / ", gs.target)
			UI.go("gemsbc", {"id": "ex_gold", "cat": "Exchanges", "sel": fill}); await shot("g102_gemsbc")
			var before = Save.data.club.size(); var ok = GemSBC.submit(gs, fill)
			print("SUBMIT ", ok, " club ", before, " -> ", Save.data.club.size(), " unopened has premium ", Save.data.unopened.has("premium"))
		if extra == "--rivals":
			var R = Rivals.st()
			print("START div ", R.div, " step ", R.step)
			for k in 5: var o = Rivals.record("W"); print("W -> div ", R.div, " step ", R.step, " cp ", R.cp, " ", o.msg)
			Rivals.record("L"); print("L -> step ", R.step, " cp ", R.cp)
			for k in 6: Rivals.record("W")
			print("after wins div ", R.div, " step ", R.step, " best ", R.best)
			R.div = 9; R.step = 0; R.cp = 0
			var o2 = Rivals.record("L"); print("RELEGATION: div ", R.div, " step ", R.step, " msg ", o2.msg)
			R.div = 8; R.step = 3; R.cp = 0
			Rivals.record("W"); Rivals.record("D")
			print("CYCLE pts ", R.cycle.pts, " left ", int(Rivals.cycle_left()))
			UI.go("rivals"); await w(0.5); await shot("g110_rivals")
			R.cycle.id = Rivals.cycle_id() - 1; Rivals.tick()
			print("UNCLAIMED ", R.unclaimed)
			UI.replace("rivals"); await w(0.5); await shot("g111_rivals_claim")
			var coins0 = Save.data.coins; print("CLAIM n ", Rivals.claim_all(), " coins +", Save.data.coins - coins0)
			print("AI div10 ", Sys.rivals_ai(10), " div1 ", Sys.rivals_ai(1), " diff pro ", Data.difficulties.professional.ai)
		if extra == "--subs":
			UI.run_match({"home": Sys.user_team(), "away": Sys.club_team("RMA"), "user_side": "home", "difficulty": "professional", "half_len": 3, "sim": false, "mode": "kickoff", "title": "Kick Off"}, func(res): pass)
			await w(2.0)
			var ms = null
			for ch in UI.root.get_children(): if ch.get("sim") != null: ms = ch
			print("BENCH ", ms.sim.teams.home.bench.size())
			ms.sim.paused = true; ms._subs(); await w(0.6); await shot("g120_subs")
			var acc = func():
				var e = InputEventAction.new(); e.action = "ui_accept"; e.pressed = true; Input.parse_input_event(e)
				var e2 = InputEventAction.new(); e2.action = "ui_accept"; e2.pressed = false; Input.parse_input_event(e2)
			UI._send_nav(Vector2i(0, 1)); await w(0.15)
			acc.call(); await w(0.4)
			print("AFTER PICK focus ", UI.get_viewport().gui_get_focus_owner().text if UI.get_viewport().gui_get_focus_owner() else null)
			await shot("g121_subs_picked")
			acc.call(); await w(0.4)
			print("SUBS USED ", ms.sim.subs_used.home, " slot1 now ", ms.sim.teams.home.players[1].p.name)
			await shot("g122_subs_done")
		if extra == "--quick":
			print("QUICK active ", Sys.quick_active(), " left ", int(Sys.quick_left()))
			var c0 = Save.data.coins
			for ev in ["pack", "pack", "buy", "list", "quicksell", "quicksell", "quicksell", "sbc", "sell", "goal", "goal", "goal", "match", "win", "assist", "evo_lvl"]: Sys.track(ev)
			var done = Data.objectives.filter(func(o): return o.cat == "quick" and Sys.obj_live(o) and Sys.obj_claimed(o)).map(func(o): return o.id)
			print("QUICK auto-completed ", done, " coins +", Save.data.coins - c0)
			UI.replace("objectives"); await w(0.5); await shot("g130_quick")
			UI.replace("sbc", {"cat": "POTM"}); await w(0.5); await shot("g131_potm")
			var golds = Data.players.filter(func(x): return x.type == "base" and x.ovr >= 78 and x.ovr <= 84)
			for k in 40: Sys.club_add(golds[k * 3].id, true, "pack")
			var ps: Dictionary = {}
			for x in Data.sbcs: if x.id == "potm_p230": ps = x
			var fill = GemSBC.autofill(ps)
			print("POTM autofill items ", fill.size(), " score ", GemSBC.score(fill), " / ", ps.target)
			UI.go("gemsbc", {"id": "potm_p230", "cat": "POTM", "sel": fill}); await w(0.4); await shot("g132_potm_build")
			print("POTM submit ", GemSBC.submit(ps, fill), " owns ", Sys.owns_pid("potm_p230"), " card ", Data.P("potm_p230").ovr)
			UI.inspect(Data.P("potm_p230")); await w(0.4); await shot("g133_potm_card"); UI.close_top(null)
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
	for extra in OS.get_cmdline_user_args():
		if extra == "--gameplay":
			var sim := MatchSim.new({"home": Sys.club_team("FCB"), "away": Sys.club_team("RSO"), "user_side": "home", "difficulty": "professional", "half_len": 3, "mode": "test"})
			var st = func(n: int, inp: Dictionary, edge := {}, rel := {}):
				for i in n:
					sim.inp = inp; sim.edge = edge if i == 0 else {}; sim.rel = rel if i == 0 else {}; sim.update(1.0 / 60.0)
			sim.state = "play"; sim.state_t = 0.0
			var cands = sim.teams.home.players.filter(func(x): return int(x.p.sm) >= 4)
			if cands.is_empty(): cands = [sim.teams.home.players[9]]
			sim.give_ball(cands[0])
			var c = sim.ball.owner; sim.switch_to(c)
			print("CARRIER ", c.p.name, " dri ", c.dri, " sm ", c.p.sm)
			var leads = []
			for i in 90:
				st.call(1, {"x": 1.0, "y": 0.0, "sprint": true}); leads.append(snapped(c.lead, 0.01))
			print("SPRINT LEADS ", leads.slice(0, 40), " still has ball: ", sim.ball.owner == c)
			sim.give_ball(c); sim.switch_to(c)
			st.call(30, {"x": 1.0, "y": 0.0, "close": true})
			print("CLOSE lead ", snapped(c.lead, 0.01))
			c.skill_t = 0; st.call(1, {"x": 0.0, "y": 0.0}, {"gesture": {"kind": "flick", "ang": c.face + PI / 2}}); print("MOVE1 ", c.label)
			st.call(10, {}); st.call(1, {}, {"gesture": {"kind": "flick", "ang": c.face + PI / 2}}); print("MOVE2 (combo) ", c.label)
			st.call(50, {}); sim.give_ball(c); c.skill_t = 0; st.call(1, {}, {"gesture": {"kind": "rot", "deg": 200.0, "ang": 0.0}}); print("MOVE3 ", c.label)
			st.call(60, {}); sim.give_ball(c); c.skill_t = 0
			st.call(1, {"pass": true}, {"pass": true}); st.call(40, {"pass": true})
			print("PCHARGE ", snapped(sim.pcharge, 0.01), " aim ", sim.aim_tgt.p.name if sim.aim_tgt else "none")
			st.call(1, {}, {}, {"pass": true})
			print("PASSED owner ", sim.ball.owner, " speed ", snapped(Vector2(sim.ball.vx, sim.ball.vy).length(), 0.1), " kind ", sim.ball.kind)
			st.call(90, {})
			sim.give_ball(c); c.x = 90; c.y = 34; sim.switch_to(c)
			st.call(1, {"chip": true}, {"chip": true}); st.call(20, {"chip": true}); st.call(1, {}, {}, {"chip": true})
			print("PENDING ", sim.pending_shot != null); st.call(5, {}); st.call(1, {}, {"shoot": true})
			print("CHIP fired ", sim.ball.shot != null, " vz ", snapped(sim.ball.vz, 0.1), " label ", c.label)
			# full AI match sanity with new dribbling
			for g in 2:
				var s2 := MatchSim.new({"home": Sys.club_team(["MCI", "INT"][g]), "away": Sys.club_team(["RMA", "PSG"][g]), "user_side": "", "difficulty": "professional", "half_len": 3, "mode": "test"})
				var n := 0
				while not s2.finished and n < 60 * 500: s2.update(1.0 / 60.0); n += 1
				print("SIM ", s2.score.home, "-", s2.score.away, " shots ", s2.stats.shots, " passes ", s2.stats.passes, " tackles ", s2.stats.tackles)
			# replay render
			UI.run_match({"home": Sys.club_team("MCI"), "away": Sys.club_team("RMA"), "user_side": "home", "difficulty": "professional", "half_len": 3, "sim": false, "mode": "kickoff", "title": "Kick Off"}, func(res): pass)
			await w(5.0)
			var ms = null
			for ch in UI.root.get_children(): if ch.get("sim") != null: ms = ch
			if ms == null:
				for ch in UI.root.get_parent().get_children(): if ch.get("sim") != null: ms = ch
			print("MATCH SCENE ", ms != null, " replay_len ", ms.sim.replay_len if ms else -1)
			if ms:
				var S = ms.sim
				S.state = "play"; S.state_t = 0.0
				var gxh = S.goal_x(S.teams.home)
				await w(1.5)
				S.ball.owner = null; S.ball.x = gxh + 0.2 * S.teams.home.dir; S.ball.vx = 20.0 * S.teams.home.dir; S.ball.y = 34.0; S.ball.z = 0.5; S.ball.vy = 0.0; S.ball.vz = 0.0; S.ball.last = S.teams.home.players[9]; S.ball.shot = null
				for gk in S.teams.away.players: if gk.gk: gk.x = 80.0 if gxh > 50 else 25.0
				print("SET ball ", S.ball.x, " vx ", S.ball.vx, " gx ", gxh, " paused ", S.paused, " owner ", S.ball.owner)
				await w(0.1)
				print("AFTER SHOT state ", S.state, " ball ", S.ball.x, " ", S.ball.y, " score ", S.score)
				pass
				await w(4.0); await shot("g90_replay")
				print("STATE ", S.state, " t ", snapped(S.state_t, 0.1), " frames ", ms.replay_frames.size(), " replay_on ", ms._replay_on)
	print("AUTOTEST DONE")
	get_tree().quit()
