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

func extreme_flag(x: String) -> bool: return x == "--extreme"

func _sim_check() -> int:
	var x0 = int(Season.st().xp)
	var res = {"home": {"name": "A"}, "away": {"name": "B"}, "hg": 2, "ag": 0, "goals": [], "user_side": "home", "mode": "rivals", "stats": {}, "winner": "home"}
	Sys.record_ut_match(res)
	return int(Season.st().xp) - x0

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
		if extra == "--trade":
			print("TRADE starter untr count ", Save.data.club.filter(func(x): return x.untr).size(), " / ", Save.data.club.size())
			UI.modules[1].open_pack("rare", false); await w(1.5)
			print("TRADE reward pack pending untr ", Save.data.pending.map(func(x): return x.untr))
			Sys.apply_pending()
			var a1 = Sys.club_add("asc_p13", false, "reward"); var a2 = Sys.club_add("gal_carrick", false, "reward"); var a3 = Sys.club_add("p13", false, "reward")
			print("TRADE asc ", a1.untr, " gallery ", a2.untr, " base reward ", a3.untr)
		if extra == "--skip":
			Save.data.pending = []; Save.data.unopened = ["gold", "gold", "premium", "rare"]
			UI.go("store", {"tab": "mine"}); await w(0.8)
			var fo = UI.get_viewport().gui_get_focus_owner(); print("SKIP focus ", fo)
			var ev0 = InputEventJoypadButton.new(); ev0.button_index = JOY_BUTTON_DPAD_DOWN; ev0.pressed = true; Input.parse_input_event(ev0); await w(0.05)
			ev0 = InputEventJoypadButton.new(); ev0.button_index = JOY_BUTTON_DPAD_DOWN; ev0.pressed = false; Input.parse_input_event(ev0); await w(0.3)
			fo = UI.get_viewport().gui_get_focus_owner()
			fo.emit_signal("pressed"); await w(0.4)
			print("SKIP opened, unopened left ", Save.data.unopened.size())
			for k in 6:
				for pr in [true, false]:
					var jb = InputEventJoypadButton.new(); jb.button_index = JOY_BUTTON_A; jb.pressed = pr; Input.parse_input_event(jb); await w(0.05)
				await w(0.3)
			await w(0.5)
			print("SKIP after 6 presses: unopened left ", Save.data.unopened.size(), " cur ", UI.cur_name)
		if extra == "--slots":
			print("SLOT cur ", Save.slot, " info ", Save.slot_info(Save.slot).get("club"))
			UI.go("slots"); await w(0.6); await shot("g07_slots")
			var had = Save.use_slot(2); print("SLOT2 has ", had); UI.reset("onboard"); await w(0.5)
			Save.create("Second"); UI.modules[0].grant_starter(); Save.data.profile.club_name = "Slot Two FC"; Save.write_now()
			Save.use_slot(1); print("BACK slot1 ", Save.data.profile.club_name)
			UI.reset("slots"); await w(0.6); await shot("g07b_slots_two")
			Save.delete_slot(2); print("SLOT2 after delete ", Save.slot_info(2))
		if extreme_flag(extra):
			Save.data.settings.extreme = true
			var xp0 = Season.st().xp; Season.add_xp(450, "test"); print("EXT season xp +", Season.st().xp - xp0, " carry ", Save.data.get("xp_carry"))
			var hi = 0; var n = 0
			for k in 300:
				for pl in Sys.generate_pack("rare"): n += 1; if pl.ovr >= 84 or pl.type != "base": hi += 1
			print("EXT rare packs: ", hi, " of ", n, " cards were 84+/special")
			print("EXT pp83x2 ", Sys.generate_pack("pp83x2").map(func(x): return x.ovr), " ai team ", Sys.squad_rating(Sys.ai_team("X", 70).players))
			Save.data.settings.extreme = false
			var hi2 = 0
			for k in 300:
				for pl in Sys.generate_pack("rare"): if pl.ovr >= 84 or pl.type != "base": hi2 += 1
			print("NORMAL rare packs: ", hi2, " of ", n)
			UI.go("settings"); await w(0.5); await shot("g08_settings")
		if extra == "--halloween":
			print("HW fright ", Fright.fright.map(func(x): return "%d %s" % [x.ovr, x.name]))
			print("HW totw2 ", Fright.totw_latest.size(), " phantom finale ", Fright.phantom_finale.map(func(x): return x.ovr))
			print("HW season ", Season.NAME, " lvl10 free ", Season.reward(10, "free"), " prem50 ", Season.reward(50, "prem"))
			print("HW fright pack ", Sys.generate_pack("frightpack").map(func(x): return "%d %s %s" % [x.ovr, x.type, x.name]))
			print("HW objectives ", Data.objectives.filter(func(o): return o.cat == "halloween").size(), " sbcs ", Data.sbcs.filter(func(x): return x.cat == "Halloween").map(func(x): return [x.name, x.target]))
			UI.replace("objectives", {"cat": "halloween"}); await w(0.5); await shot("g200_hw_objectives")
			UI.replace("sbc"); await w(0.6); await shot("g201_hw_sbc")
			UI.replace("season"); await w(0.6); await shot("g202_hw_season")
			UI.replace("store", {"tab": "browse"}); await w(0.6); await shot("g203_hw_store")
			UI.inspect(Data.P("fr_p233")); await w(0.4); await shot("g204_hw_card"); UI.close_top(null)
			UI.inspect(Data.P("ph_p19")); await w(0.4); await shot("g205_hw_phantom"); UI.close_top(null)
			UI.reset("main"); await w(0.6); await shot("g206_hw_main")
		if extra == "--faces":
			var g = GridContainer.new(); g.columns = 12; g.add_theme_constant_override("h_separation", 6); g.add_theme_constant_override("v_separation", 6)
			var ids = ["p416", "p125", "p876", "p853", "p929", "p1533", "p60", "p169", "p5"]
			var rest = Data.players.filter(func(x): return x.type == "base" and int(x.ovr) < 76)
			for k in 27: ids.append(rest[(k * 61) % rest.size()].id)
			for pid in ids:
				var c = UI.card(Data.P(pid), 7.0); c.focus_mode = Control.FOCUS_NONE; g.add_child(c)
			UI.modal("Faces", g, [["OK", true, "Primary"]], true); await w(0.8); await shot("g210_faces"); UI.close_top(null)
		if extra == "--cloudui":
			print("CLOUD configured ", Cloud.configured(), " companion ", Cloud.companion())
			UI.go("cloud"); await w(0.6); await shot("g220_cloud_setup")
			Cloud.set_server("https://example.invalid", "testkey_testkey_testkey_123"); UI.replace("cloud"); await w(0.5); await shot("g221_cloud_signin")
			var r = await Cloud.sign_in("tester", "1234"); print("CLOUD offline sign in -> ", r)
			UI.reset("main"); await w(0.8); print("COMPANION main -> ", UI.cur_name); await shot("g222_companion_home")
			var mm = await _sim_check(); print("SP after rivals win: ", mm)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(Cloud.CONFIG_USER))
		if extra == "--mobile":
			print("MOBILE ", UI.mobile, " root ", UI.root.size)
			for scr in ["home", "more", "season", "store", "sbc", "transfers", "objectives", "play", "squad", "club"]:
				UI.reset(scr); await w(1.0); await shot("m_" + scr)
			UI.go("rivals"); await w(1.0); await shot("m_rivals")
			var fl = UI.cur.find_children("*", "HFlowContainer", true, false).size(); var wide = UI.cur.find_children("*", "HBoxContainer", true, false).filter(func(x): return x.get_combined_minimum_size().x > 420).map(func(x): return [x.get_child_count(), x.get_combined_minimum_size().x, x.has_meta("flowed"), UI._h_scroll_ancestor(x)])
			print("RIVALS flows ", fl, " wide hboxes ", wide)
			UI.modules[1].item_actions(Save.data.club[0].uid, func(): pass); await w(0.8); await shot("m_inspect"); UI.close_top(null)
		if extra == "--msquad":
			Sys.auto_build(Sys.active_squad()); UI.reset("squad"); await w(1.0); await shot("ms_squad")
			var ed = UI.cur.find_children("*", "VBoxContainer", true, false).filter(func(n): return n.has_meta("editor"))[0].get_meta("editor")
			ed.tap(9); await w(0.8); await shot("ms_sheet")
			UI.close_top("swap"); await w(0.6); await shot("ms_swapping")
			ed.formation_sheet(); await w(0.7); await shot("ms_formation"); UI.close_top(null); await w(0.4)
			UI.cur.get_child(0); var sc = UI.cur.find_children("*", "ScrollContainer", true, false).filter(func(x): return x.has_meta("page_scroll"))
			if not sc.is_empty(): sc[0].scroll_vertical = 2000; await w(0.4); await shot("ms_squad_bottom")
		if extra == "--mstore":
			UI.reset("store", {"tab": "browse", "cat": "classic"}); await w(1.0); await shot("mst_browse")
			var ps = UI.cur.find_children("*", "ScrollContainer", true, false).filter(func(x): return x.has_meta("page_scroll"))[0]
			var p0 = Vector2(200, 420)
			var send = func(ev): Input.parse_input_event(ev); await w(0.03)
			var dn = InputEventMouseButton.new(); dn.button_index = MOUSE_BUTTON_LEFT; dn.pressed = true; dn.position = p0; dn.global_position = p0
			await send.call(dn)
			for k in 8:
				var mv = InputEventMouseMotion.new(); mv.position = p0 - Vector2(0, 30 * (k + 1)); mv.global_position = mv.position; mv.button_mask = MOUSE_BUTTON_MASK_LEFT
				await send.call(mv)
			var up = InputEventMouseButton.new(); up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false; up.position = p0 - Vector2(0, 240); up.global_position = up.position
			await send.call(up); await w(0.8)
			print("SWIPE page scroll ", ps.scroll_vertical, " modals after swipe ", UI.modals.size())
			await shot("mst_after_swipe")
			var dn2 = dn.duplicate(); dn2.position = Vector2(200, 300); dn2.global_position = dn2.position; await send.call(dn2)
			var up2 = up.duplicate(); up2.position = Vector2(200, 300); up2.global_position = up2.position; await send.call(up2); await w(0.6)
			print("TAP modals after tap ", UI.modals.size()); await shot("mst_tap"); UI.close_top(null); await w(0.3)
			UI.reset("store", {"tab": "mine"}); await w(0.8); await shot("mst_mine")
			UI.reset("store", {"tab": "browse", "cat": "preview"}); await w(0.8); await shot("mst_preview")
		if extra == "--mmodes":
			UI.reset("rivals"); await w(1.0); await shot("mm_rivals")
			UI.reset("champions"); await w(1.0); await shot("mm_champs_qualify")
			Champs.st().next_at = 0; Champs.st().qp = 1000; Champs.start()
			for k in 6: Champs.record(k % 3 != 0, "2-1", "x")
			UI.reset("champions"); await w(1.0); await shot("mm_champs_run")
			UI.reset("play"); await w(1.0); await shot("mm_play")
			UI.go("squadbattles"); await w(1.0); await shot("mm_sb")
		if extra == "--mtransfers":
			for it in Save.data.club.slice(0, 3): Sys.tl_add(it.pid, false, "test")
			UI.reset("transfers"); await w(1.0); await shot("mt_overview")
			UI.replace("transfers", {"tab": "search", "filter": {"min": 82}, "run": true}); await w(1.0); await shot("mt_search")
			UI.replace("transfers", {"tab": "search", "filter": {}, "filters": true}); await w(1.0); await shot("mt_filters")
			UI.replace("transfers", {"tab": "list"}); await w(1.0); await shot("mt_list")
			UI.replace("transfers", {"tab": "targets"}); await w(1.0); await shot("mt_targets")
		if extra == "--munassigned":
			UI.modules[1].open_pack("rare", true); await w(0.9); await shot("mu_opening")
			var tap = InputEventMouseButton.new(); tap.button_index = MOUSE_BUTTON_LEFT; tap.pressed = true; tap.position = Vector2(200, 400); tap.global_position = tap.position
			var fx = UI.overlay.get_children().filter(func(n): return n.has_method("skip"))
			print("BEFORE TAP fx ", fx.size(), " revealed ", fx[0].revealed if not fx.is_empty() else "-")
			Input.parse_input_event(tap); await w(0.1)
			print("AFTER 1 TAP revealed ", fx[0].revealed if is_instance_valid(fx[0]) else "freed", " finished ", fx[0].finished_called if is_instance_valid(fx[0]) else "-")
			await shot("mu_reveal_a")
			await w(0.3)
			print("FX valid ", is_instance_valid(fx[0]))
			if is_instance_valid(fx[0]): print("FX vis ", fx[0].is_visible_in_tree(), " size ", fx[0].size, " pos ", fx[0].position, " mod ", fx[0].modulate, " parent ", fx[0].get_parent(), " idx ", fx[0].get_index(), " overlay kids ", UI.overlay.get_child_count())
			await shot("mu_reveal")
			var t2 = tap.duplicate(); Input.parse_input_event(t2); await w(1.0); print("AFTER TAPS cur ", UI.cur_name, " pending ", Save.data.pending.size())
			await shot("mu_list")
			UI.modules[1]._unassigned_item(0); await w(0.7); await shot("mu_item_sheet"); UI.close_top("keep"); await w(0.6)
			print("AFTER KEEP pending ", Save.data.pending.size())
			UI.modules[1]._unassigned_menu(); await w(0.7); await shot("mu_menu"); UI.close_top("keep"); await w(0.8)
			print("AFTER STORE ALL pending ", Save.data.pending.size(), " cur ", UI.cur_name)
		if extra == "--consum":
			var sq = Sys.active_squad(); Sys.auto_build(sq)
			var u: String = sq.slots[9]; var before = Sys.item_player(u)
			print("CONS start ", Cons.st())
			var inf0 = Sys.squad_info(sq); print("BEFORE ", before.name, " ", before.pos, " stats ", inf0.players[9].stats, " chem ", inf0.chem.per[9])
			print("APPLY Shadow ", Cons.apply_style(u, "Shadow"))
			var inf1 = Sys.squad_info(sq); print("AFTER  stats ", inf1.players[9].stats, " style ", inf1.players[9].get("style"))
			var cb_u: String = sq.slots[2]
			print("POS ", Sys.item_player(cb_u).pos, " -> RB ", Cons.change_pos(cb_u, "RB"), " now ", Sys.item_player(cb_u).pos, " alt ", Sys.item_player(cb_u).alt)
			print("POS card left ", Cons.pos_owned(), " coins ", Save.data.coins)
			UI.go("squad"); await w(0.6); await shot("g06_squad_cons")
			UI.modules[1].item_actions(u, func(): pass); await w(0.6); await shot("g06b_inspect_style"); UI.close_top(null); await w(0.4)
			UI.modules[1].style_dialog(u); await w(0.6); await shot("g06c_style_dialog"); UI.close_top(null); await w(0.4)
			UI.modules[1].pos_dialog(sq.slots[6]); await w(0.6); await shot("g06d_pos_dialog"); UI.close_top(null); await w(0.4)
			var gk: String = sq.slots[0]; print("GK Wall ", Cons.apply_style(gk, "Wall"), " ", Sys.squad_info(sq).players[0].stats)
		if extra == "--squad":
			Sys.auto_build(Sys.active_squad()); UI.replace("squad"); await w(0.6); await shot("g05b_squad_built")
			var hh = UI.cur.find_children("*", "VBoxContainer", true, false).filter(func(n): return n.has_meta("editor"))
			var S = hh[0].get_meta("editor")
			S.pitch.cards[6].grab_focus(); await w(0.3); await shot("g05c_squad_hover")
			S.details(); await w(0.6); await shot("g05d_squad_details"); UI.close_top(null); await w(0.3)
			S.click(6); await w(0.3); await shot("g05e_squad_selected")
			S.team_mgmt(); await w(0.5); await shot("g05f_team_mgmt"); UI.close_top(null)
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
			var asc = Data.P("asc_p13"); print("ASC ", asc.ovr, " ", asc.stats, " sm ", asc.sm)
			UI.inspect(asc); await shot("g36_asc_card"); UI.close_top(null)
			print("MARKET has pass: ", Sys.market_search({}).any(func(l): return Data.P(l.pid).type == "pass"))
		if extra == "--gallery":
			print("TOP ", Gallery.top_clubs)
			for pid in ["p256", "p247", "p420", "p443", "p0", "p14"]: print("GEMS ", Data.P(pid).name, " ", Data.P(pid).ovr, " ", Gallery.gems(Data.P(pid)))
			print("GEMS asc ", Gallery.gems(Data.P("asc_p13")), " 70-rated ", Gallery.gems(Data.players.filter(func(x): return x.ovr == 70)[0]))
			var club: String = Gallery.top_clubs["ENG1"][0]
			for pl in Data.by_club[club]:
				if pl.type == "base" and pl.ovr >= 78: Gallery.record(pl.id, "pack")
			var sid = "C:" + club
			print("SET ", sid, " ", Gallery.score(sid).total, " grade ", Gallery.score(sid).grade, " max ", Gallery.max_score(sid))
			UI.go("gallery"); await shot("g40_gallery")
			UI.go("galleryset", {"id": sid}); await shot("g41_set")
			print("BEFORE UPGRADE grade ", Gallery.score(sid).grade, " gain ", Gallery.upgrade_gain(sid))
			print("UPGRADE +", Gallery.upgrade(sid), " grade now ", Gallery.score(sid).grade)
			UI.replace("galleryset", {"id": sid}); await shot("g41b_set_upgraded")
			UI.modules[4]._slot_pick(sid, 0); await w(0.6); await shot("g41c_slot_pick"); UI.close_top(null); await w(0.3)
			print("GRADE ", Gallery.grade(sid), " tokens ", Gallery.tokens(), " level ", Gallery.level())
			Gallery.st().tokens = 3000
			UI.go("gallerystore"); await shot("g42_store")
			print("BUY ", Gallery.buy(Gallery.STORE[6]), " unopened has icon pick ", Save.data.unopened.has("pickicon"))
			Gallery.st().tokens = 3000; var gi = Gallery.store_items()[0]; print("BUY GALLERY CARD ", Gallery.buy(gi), " in club untr: ", Sys.club_items().filter(func(x): return x.pid == gi.reward.player).map(func(x): return x.untr))
			print("MARKET has gallery: ", Sys.market_search({}).any(func(l): return Data.P(l.pid).type == "gallery"))
			UI.inspect(Data.P(gi.reward.player)); await shot("g42b_gallery_card"); UI.close_top(null)
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
			for k in 30: Sys.club_add(golds[k * 3].id, true, "pack")
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
		if extra == "--store":
			Save.data.unopened = []; Save.data.pending = []
			UI.replace("store", {"tab": "browse", "cat": "promo"}); await w(0.6); await shot("g140_store_promo")
			UI.replace("store", {"tab": "browse", "cat": "classic"}); await w(0.4)
			for k in 3: UI._send_nav(Vector2i(1, 0)); await w(0.15)
			await shot("g141_store_classic")
			UI.replace("store", {"tab": "browse", "cat": "preview"}); await w(0.5); await shot("g142_preview")
			var pv = UI.modules[11].preview(); print("PREVIEW ", pv.items.map(func(x): return "%d %s" % [Data.P(x).ovr, Data.P(x).name]), " left ", int(UI.modules[11].preview_left()))
			UI.modules[1].open_pack("preview", true, pv.items.map(func(x): return Data.P(x))); pv.bought = true
			await w(1.0)
			var ov2 = UI.overlay.get_child(UI.overlay.get_child_count() - 1) if UI.overlay.get_child_count() > 0 else null
			if ov2 and ov2.has_method("done"): ov2.done()
			await w(0.8)
			print("PENDING matches preview ", Save.data.pending.map(func(x): return x.pid) == pv.items)
			# champs: cooldown after run, coin/token rewards
			Champs.st().qp = 1000; Champs.start(); for k in 3: Champs.record(true, "1-0", "x")
			print("CD during run ", int(Champs.cooldown_left()))
			var res = Champs.claim(); print("CLAIM ", res.reward, " CD after run ", int(Champs.cooldown_left()), " can start ", Champs.start())
			UI.go("champions"); await w(0.6); await shot("g143_champs_cd")
			UI.go("champsstore"); await w(0.4); await shot("g144_token_store")
		if extra == "--champsreward":
			Champs.st().next_at = 0; Champs.st().qp = 1000; Champs.start()
			for k in 15: Champs.record(true, "2-0", "x")
			var res = Champs.claim(); print("REWARD ", res)
			UI.go("champsreward", {"res": res}); await w(1.2); await shot("g150_reward_anim")
			await w(3.2); await shot("g151_reward_final")
			print("QP after ", Champs.st().qp, " tokens ", Champs.tokens())
			print("CUR ", UI.cur_name, " modals ", UI.modals.size(), " in_match ", UI.in_match, " focus ", UI.get_viewport().gui_get_focus_owner())
			var ev = InputEventAction.new(); ev.action = "ui_cancel"; ev.pressed = true; Input.parse_input_event(ev)
			await w(0.6); print("AFTER ESC ", UI.cur_name)
			UI.go("champsreward", {"res": res}); await w(4.5)
			var fo = UI.get_viewport().gui_get_focus_owner(); print("FOCUS ", fo, " ", fo.text if fo is Button else "")
			for pr in [true, false]:
				var ev2 = InputEventKey.new(); ev2.physical_keycode = KEY_ENTER; ev2.keycode = KEY_ENTER; ev2.pressed = pr; Input.parse_input_event(ev2); await w(0.1)
			await w(0.6); print("AFTER ENTER ", UI.cur_name)
			UI.go("champsreward", {"res": res}); await w(4.5)
			var fo2 = UI.get_viewport().gui_get_focus_owner(); print("FOCUS2 ", fo2, " ", fo2.text if fo2 is Button else "", " stack ", UI.stack.map(func(x): return x[0]))
			for pr in [true, false]:
				var jb = InputEventJoypadButton.new(); jb.button_index = JOY_BUTTON_A; jb.pressed = pr; Input.parse_input_event(jb); await w(0.1)
			await w(0.6); print("AFTER PAD A ", UI.cur_name)
			UI.go("champsreward", {"res": res}); await w(4.5)
			for pr in [true, false]:
				var jb2 = InputEventJoypadButton.new(); jb2.button_index = JOY_BUTTON_B; jb2.pressed = pr; Input.parse_input_event(jb2); await w(0.1)
			await w(0.6); print("AFTER PAD B ", UI.cur_name)
			# realistic flow: finish a run, press Play on the Champions screen, wait for the animation, press A
			Champs.st().next_at = 0; Champs.st().qp = 1000; Champs.start()
			for k in 15: Champs.record(k % 3 != 0, "2-0", "x")
			UI.reset("champions"); await w(0.8)
			UI.modules[8]._play_pressed(); await w(5.0); await shot("g152_real_flow")
			var fo4 = UI.get_viewport().gui_get_focus_owner(); print("REAL FOCUS ", fo4, " ", fo4.text if fo4 is Button else "", " cur ", UI.cur_name, " modals ", UI.modals.size())
			for pr in [true, false]:
				var jb4 = InputEventJoypadButton.new(); jb4.button_index = JOY_BUTTON_A; jb4.pressed = pr; Input.parse_input_event(jb4); await w(0.1)
			await w(0.6); print("REAL AFTER PAD A ", UI.cur_name)
			for pr in [true, false]:
				var jb5 = InputEventJoypadButton.new(); jb5.button_index = JOY_BUTTON_B; jb5.pressed = pr; Input.parse_input_event(jb5); await w(0.1)
			await w(0.6); print("THEN PAD B ", UI.cur_name)
			UI.reset("main"); await w(0.6); var fo3 = UI.get_viewport().gui_get_focus_owner(); print("MAIN FOCUS ", fo3)
			for pr in [true, false]:
				var jb3 = InputEventJoypadButton.new(); jb3.button_index = JOY_BUTTON_A; jb3.pressed = pr; Input.parse_input_event(jb3); await w(0.1)
			await w(0.6); print("AFTER PAD A on main ", UI.cur_name)
			for el in [false, true]:
				var gs = [0, 0]; var sv = 0; var sh = 0; var tk = 0
				for g in 3:
					var sim := MatchSim.new({"home": Sys.club_team("RMA"), "away": Sys.club_team("MCI"), "user_side": "", "difficulty": "professional", "ai": 0.9, "elite": el, "half_len": 3, "mode": "test"})
					var n := 0
					while not sim.finished and n < 60 * 500: sim.update(1.0 / 60.0); n += 1
					gs[0] += sim.score.home; gs[1] += sim.score.away; sh += sim.stats.shots[0] + sim.stats.shots[1]; tk += sim.stats.tackles[0] + sim.stats.tackles[1]
				print("ELITE ", el, " goals ", gs, " shots ", sh, " tackles ", tk)
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
