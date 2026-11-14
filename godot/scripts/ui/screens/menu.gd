extends RefCounted
## Main menu & non-Ultimate-XI screens.

func _ret(node: Control, back = null, bg := "menu", extra := {}) -> Dictionary:
	var d = {"node": node, "bg": bg}
	if back != null: d.back = back
	d.merge(extra)
	return d

func to_main() -> void: UI.reset("main")

# ------------------------------------------------------------------ title
func s_title(_p) -> Dictionary:
	var page = Control.new()
	var c = CenterContainer.new(); c.set_anchors_preset(Control.PRESET_FULL_RECT); page.add_child(c)
	var v = UI.vb(10); v.alignment = BoxContainer.ALIGNMENT_CENTER
	var logo = UI.hb(0, [UI.head("PRIME", 110, Color("#e9edf2")), UI.head("27", 110, Color("#36f0ff") if Black.THEME else (Color("#ff7a1a") if Fright.THEME else UI.GOLD))]); logo.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(logo)
	var sub = UI.label("F O O T B A L L" + ("   ·   B L A C K O U T" if Black.THEME else ("   ·   F R I G H T   N I G H T" if Fright.THEME else "")), 18, Color("#ffe633") if Black.THEME else (Color("#ffb35a") if Fright.THEME else UI.GOLD2), UI.font_head); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(sub)
	v.add_child(UI.vb(0, [Control.new()])); v.get_child(-1).custom_minimum_size.y = 50
	var b = UI.btn("Ⓐ  Press Start", func():
		Sfx.play("boom"); Sfx.music_on()
		if Cloud.companion() and not Cloud.signed_in(): UI.reset("cloud"); return
		UI.reset("onboard" if Save.data == null else "main"), "Primary", true)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; v.add_child(b)
	if not Cloud.companion():
		var sl = UI.btn("Save Slots  ·  Slot %d" % Save.slot, func(): Sfx.play("select"); Sfx.music_on(); UI.go("slots"), "")
		sl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; v.add_child(sl)
	var cb = UI.btn(("☁  Cloud · " + Cloud.username()) if Cloud.signed_in() else "☁  Cloud Account", func(): Sfx.play("select"); Sfx.music_on(); UI.go("cloud"), "")
	cb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; v.add_child(cb)
	if Cloud.companion(): logo.add_child(UI.head(" COMPANION", 40, UI.TEAL))
	var hint = UI.label("Keyboard, mouse, Xbox or PS5 controller · Top 5 leagues 2025/26", 13, UI.DIM); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(hint)
	c.add_child(v)
	return _ret(page, func(): pass, "menu", {"no_music": true})

# ------------------------------------------------------------------ onboarding
func s_onboard(_p) -> Dictionary:
	var page = Control.new()
	var c = CenterContainer.new(); c.set_anchors_preset(Control.PRESET_FULL_RECT); page.add_child(c)
	var st = {"name": "Manager", "club": "Phoenix FC", "c1": "#e8b631", "c2": "#14161c", "icon": "star", "extreme": false}
	var badge = UI.icon("badge", {"shape": "shield", "c1": st.c1, "c2": st.c2, "icon": st.icon}, Vector2(70, 74))
	var upd = func(): badge.arg = {"shape": "shield", "c1": st.c1, "c2": st.c2, "icon": st.icon}; badge.queue_redraw()
	var v = UI.vb(14)
	v.add_child(UI.caps("Welcome to Ultimate XI", 13, UI.GOLD2))
	v.add_child(UI.head("CREATE YOUR CLUB", 34))
	v.add_child(UI.field("Manager name", UI.line(st.name, func(t): st.name = t, "", 420)))
	v.add_child(UI.field("Club name", UI.line(st.club, func(t): st.club = t, "", 420)))
	var colors = [["#e8b631", "Gold"], ["#c8102e", "Red"], ["#034694", "Blue"], ["#00954c", "Green"], ["#ffffff", "White"], ["#6b2ea6", "Purple"], ["#14161c", "Black"], ["#ff7f00", "Orange"]]
	v.add_child(UI.hb(18, [badge, UI.field("Primary", UI.option(colors, st.c1, func(x): st.c1 = x; upd.call())), UI.field("Secondary", UI.option(colors, st.c2, func(x): st.c2 = x; upd.call())),
		UI.field("Icon", UI.option(["star", "ball", "crown", "bolt", "bird", "flame"].map(func(x): return [x, x.capitalize()]), st.icon, func(x): st.icon = x; upd.call()))]))
	var ex = CheckBox.new(); ex.text = "EXTREME MODE — top pulls 1000× rarer, maxed AI (can be turned off later in Settings)"; ex.focus_mode = Control.FOCUS_ALL
	ex.add_theme_color_override("font_color", Color("#ff5a5a")); ex.toggled.connect(func(x): st.extreme = x)
	v.add_child(ex)
	v.add_child(UI.wrapl(UI.label("You'll receive a starter squad of real players, 5,000 coins, 500 Prime Points (free in-game credits) and a Premium Gold Pack.", 13, UI.DIM), 520))
	var go = UI.btn("Ⓐ  Start Ultimate XI", func():
		Save.create(st.name.strip_edges() if st.name.strip_edges() != "" else "Manager")
		var pr: Dictionary = Save.data.profile
		pr.club_name = st.club.strip_edges() if st.club.strip_edges() != "" else "Phoenix FC"
		pr.badge = {"shape": "shield", "c1": st.c1, "c2": st.c2, "icon": st.icon}
		pr.kit.home.c1 = st.c1; pr.kit.home.c2 = st.c2
		Save.data.settings.extreme = st.extreme
		grant_starter(); Save.write_now()
		ut_transition(func(): UI.reset("home")), "Primary", true)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(go)
	c.add_child(UI.panel(v))
	return _ret(page, func(): UI.reset("title"))

func grant_starter() -> void:
	var need = {"GK": 2, "CB": 4, "LB": 2, "RB": 2, "CDM": 2, "CM": 3, "CAM": 1, "LW": 1, "RW": 1, "ST": 3}
	var base: Array = Data.players.filter(func(p): return p.type == "base")
	var lg: String = Sys.pick(["ENG1", "ESP1", "ITA1", "GER1", "FRA1"])
	for pos in need:
		for i in need[pos]:
			var target = Sys.rint(73, 77) if i == 0 else Sys.rint(67, 73)
			var pool = base.filter(func(p): return p.pos == pos and abs(p.ovr - target) <= 3 and (p.lg == lg if i == 0 else true) and not Sys.owns_pid(p.id))
			if pool.is_empty(): pool = base.filter(func(p): return p.pos == pos and not Sys.owns_pid(p.id))
			Sys.club_add(Sys.pick(pool).id, false, "starter")
	var s = Sys.squad_create("Starter XI", "4-3-3"); Sys.auto_build(s)
	Save.data.unopened.append("premium")
	Sys.history(Save.data.profile.club_name + " joined Ultimate XI")

func ut_transition(cb: Callable) -> void:
	Sfx.play("whoosh")
	var o = Control.new(); o.set_anchors_preset(Control.PRESET_FULL_RECT); o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wipe = Polygon2D.new(); var W = UI.root.size.x; var H = UI.root.size.y
	wipe.polygon = PackedVector2Array([Vector2(-W * 0.2, 0), Vector2(W * 1.1, 0), Vector2(W * 0.9, H), Vector2(-W * 0.4, H)])
	wipe.vertex_colors = PackedColorArray([Color("#0a1a1d"), Color("#3fe0c5"), Color("#0f3b3a"), Color("#05090c")])
	wipe.position.x = -W * 1.5
	o.add_child(wipe)
	var lg = CenterContainer.new(); lg.set_anchors_preset(Control.PRESET_FULL_RECT); lg.modulate.a = 0
	lg.add_child(UI.vb(0, [UI.hb(14, [UI.head("ULTIMATE", 84), UI.head("XI", 84, UI.TEAL)]), UI.label("P R I M E   F O O T B A L L   2 7", 14, UI.DIM, UI.font_bold)]))
	o.add_child(lg)
	UI.overlay.add_child(o)
	var tw = UI.create_tween()
	tw.tween_property(wipe, "position:x", 0.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): Sfx.play("boom"); cb.call())
	tw.tween_property(lg, "modulate:a", 1.0, 0.3)
	tw.tween_interval(0.45)
	tw.tween_property(lg, "modulate:a", 0.0, 0.25)
	tw.tween_property(wipe, "position:x", W * 1.5, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(o.queue_free)

# ------------------------------------------------------------------ main menu
const ITEMS := [["ut", "Ultimate XI", "Build your dream squad"], ["kickoff", "Kick Off", "Quick match with any club"], ["career", "Career Mode", "Manage a club through a season"],
	["clubs", "Clubs", "Explore every league & club"], ["tourn", "Tournaments", "Knockout cups"], ["customize", "Customize", "Badge, kits & stadium"], ["profile", "Profile", "Stats & history"], ["slots", "Save Slots", "3 clubs · switch or start new"], ["settings", "Settings", "Audio, gameplay & saves"]]

func s_main(_p) -> Dictionary:
	if Cloud.companion():
		# the companion only has Ultimate Team
		UI.reset.call_deferred("home" if Save.data != null else "cloud")
		return _ret(Control.new(), func(): pass, "hub")
	var pr: Dictionary = Save.data.profile
	var top = UI.hb(14, [UI.head("PRIME", 30, Color("#e9edf2")), UI.head("27", 30, UI.GOLD), UI.spacer(), UI.bold(pr.name, 15), UI.label("LVL %d" % pr.level, 15, UI.DIM)])
	var f = UI.frame(top, "Prime Football 27 · top 5 leagues 2025/26")
	var row = UI.hb(30); UI.grow(row)
	var list = UI.vb(2); list.custom_minimum_size.x = 340; list.alignment = BoxContainer.ALIGNMENT_CENTER
	var feat = UI.vb(0); UI.grow(feat)
	for it in ITEMS:
		var b = UI.btn(it[1].to_upper(), func(): go_item(it[0]), "MenuItem", it[0] == "ut")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_entered.connect(func():
			b.add_theme_font_size_override("font_size", 27); b.add_theme_color_override("font_focus_color", Color.WHITE)
			for c in feat.get_children(): c.queue_free()
			feat.add_child(feature(it[0])))
		b.focus_exited.connect(func(): b.add_theme_font_size_override("font_size", 17))
		list.add_child(b)
	row.add_child(list); row.add_child(feat)
	f.body.add_child(row)
	feat.add_child(feature("ut"))
	UI.keyhook(f.node, {"j3": func(): UI.go("promo", {"tab": "totw"}), "k%d" % KEY_T: func(): UI.go("promo", {"tab": "totw"}), "j2": func(): UI.go("promo"), "k%d" % KEY_N: func(): UI.go("promo")})
	return _ret(f.node, func():
		var v = await UI.modal("Quit?", "Your progress is saved automatically.", [["Stay", null, ""], ["Title screen", "title", ""], ["Quit game", "quit", "Danger"]])
		if v == "title": UI.reset("title")
		elif v == "quit": Save.write_now(); UI.get_tree().quit())

func go_item(k: String) -> void:
	if k == "ut": ut_transition(func(): UI.go("home")); return
	UI.go(k)

func feature(k: String) -> Control:
	var h = UI.hb(20); UI.grow(h)
	var v = UI.vb(12); v.alignment = BoxContainer.ALIGNMENT_CENTER; UI.grow(v)
	var title = ""; var sub = ""; var label = ""; var art: Control = null
	match k:
		"ut":
			title = "BLACKOUT\n& TOTW 3"; sub = "Black Friday is here — Blackout cards upgrade every time their club wins, Flash packs restock every hour, and TOTW 3 is live!"; label = "Enter Ultimate XI"
			var totw: Array = Black.cards.duplicate(); totw.sort_custom(func(a, b): return a.ovr > b.ovr)
			var g = GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 16); g.add_theme_constant_override("v_separation", 16)
			for p in totw.slice(0, 4): var c = UI.card(p, 12.5); c.focus_mode = Control.FOCUS_NONE; c.mouse_filter = Control.MOUSE_FILTER_IGNORE; g.add_child(c)
			art = g
		"kickoff":
			title = "KICK OFF"; sub = "Pick any two of 96 clubs from Europe's top five leagues and play a full 11v11 match."; label = "Play Kick Off"
			art = UI.hb(30, [UI.icon("crest", "MCI", Vector2(150, 150)), UI.head("VS", 40), UI.icon("crest", "RMA", Vector2(150, 150))])
		"career":
			var c = Save.data.career
			title = "MANAGER CAREER"; label = "Continue Career" if c else "New Career"
			sub = ("Continue with %s — Matchday %d." % [Data.clubs[c.club].name, min(int(c.round) + 1, c.fixtures.size())]) if c else "Take charge of a real club and chase the league title over a full double round-robin season."
			art = UI.icon("crest", c.club if c else "ARS", Vector2(200, 200))
		"clubs":
			title = "CLUBS"; sub = "Explore the Premier League, LaLiga, Serie A, Bundesliga and Ligue 1 — every club and squad. Play a friendly as any club."; label = "Explore Clubs"
			var g = GridContainer.new(); g.columns = 4
			for code in ["ARS", "LIV", "MCI", "RMA", "FCB", "ATM", "INT", "ACM", "JUV", "FCB2", "BVB", "PSG"]: g.add_child(UI.icon("crest", code, Vector2(64, 64)))
			art = g
		"tourn":
			title = "TOURNAMENTS"; sub = "Enter the 8-team Prime Cup knockout. Win three matches to lift the trophy."; label = "Enter Tournament"
			art = UI.icon("badge", {"shape": "crest", "c1": "#e8b631", "c2": "#14161c", "icon": "crown"}, Vector2(190, 190))
		"customize":
			title = "CUSTOMIZE"; sub = "Club name, badge, home & away kits, stadium and tifo."; label = "Customize Club"
			art = UI.hb(20, [UI.icon("badge", Save.data.profile.badge, Vector2(170, 170)), UI.icon("kit", Save.data.profile.kit.home, Vector2(140, 140))])
		"profile":
			var s: Dictionary = Save.data.stats
			title = Save.data.profile.name.to_upper(); sub = "%d matches · %dW %dD %dL · %d goals" % [s.played, s.wins, s.draws, s.losses, s.gf]; label = "View Profile"
		_:
			title = "SETTINGS"; sub = "Audio, gameplay difficulty, match length, camera, controls and save management."; label = "Open Settings"
	v.add_child(UI.head(title, 36))
	v.add_child(UI.wrapl(UI.label(sub, 16, Color("#f0e6c8")), 480))
	var b = UI.btn("Ⓐ  " + label, func(): go_item(k), "Primary"); b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; b.focus_mode = Control.FOCUS_CLICK
	v.add_child(b)
	if k == "ut":
		var gy = (Pad.glyph("Y") + "  ") if Pad.style != "" else "[T] "; var gx = (Pad.glyph("X") + "  ") if Pad.style != "" else "[N] "
		var e1 = UI.btn(gy + "TOTW 3 squad", func(): UI.go("promo", {"tab": "totw"}), "Small"); e1.focus_mode = Control.FOCUS_CLICK
		var e2 = UI.btn(gx + "New cards", func(): UI.go("promo"), "Small"); e2.focus_mode = Control.FOCUS_CLICK
		v.add_child(UI.hb(8, [e1, e2]))
	h.add_child(v)
	if art: var cc = CenterContainer.new(); cc.add_child(art); h.add_child(cc)
	return h

# ------------------------------------------------------------------ kick off
func club_items(sel := "") -> Array:
	var out = []
	for lg in ["ENG1", "ESP1", "ITA1", "GER1", "FRA1"]:
		for code in Data.clubs:
			if Data.clubs[code].get("lg", "") == lg: out.append([code, "%s  (%s)" % [Data.clubs[code].name, Data.leagues[lg].short]])
	return out

func team_ovr(code: String) -> int: return Sys.squad_rating(Sys.club_team(code).players)

func s_kickoff(p) -> Dictionary:
	var f = UI.sub_shell("Kick Off", "Play Now", true)
	var st = {"home": p.get("home", "MCI"), "away": p.get("away", "RMA"), "diff": Save.data.settings.difficulty, "half": int(Save.data.settings.half_len)}
	var row = UI.hb(40); row.alignment = BoxContainer.ALIGNMENT_CENTER; UI.grow(row)
	for side in ["home", "away"]:
		var crest = UI.icon("crest", st[side], Vector2(150, 150))
		var ovr = UI.bold("Team rating %d" % team_ovr(st[side]), 15)
		var sel = UI.option(club_items(), st[side], func(v): st[side] = v; crest.arg = v; crest.queue_redraw(); ovr.text = "Team rating %d" % team_ovr(v))
		sel.custom_minimum_size.x = 320
		var pv = UI.vb(14, [UI.caps("Home (you)" if side == "home" else "Away (CPU)"), crest, sel, ovr]); pv.alignment = BoxContainer.ALIGNMENT_CENTER
		for c in pv.get_children(): c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(UI.panel(pv))
		if side == "home": row.add_child(UI.head("VS", 44))
	f.body.add_child(row)
	var ctrl = UI.hb(14); ctrl.alignment = BoxContainer.ALIGNMENT_CENTER
	ctrl.add_child(UI.field("Difficulty", UI.option(Data.difficulty_order.map(func(k): return [k, Data.difficulties[k].name]), st.diff, func(v): st.diff = v)))
	ctrl.add_child(UI.field("Half length", UI.option([2, 3, 4, 5, 6, 8, 10].map(func(m): return [m, "%d min" % m]), st.half, func(v): st.half = v)))
	var go = func(sim: bool):
		var home = Sys.club_team(st.home); var away = Sys.club_team(st.away)
		UI.run_match({"home": home, "away": away, "user_side": "home", "difficulty": st.diff, "half_len": st.half, "sim": sim, "mode": "kickoff", "title": "Kick Off"},
			func(res): UI.show_results(res, "Kick Off", "", func(): UI.replace("kickoff", {"home": st.home, "away": st.away})))
	ctrl.add_child(UI.btn("Ⓐ  Play Match", func(): go.call(false), "Primary", true)); ctrl.add_child(UI.btn("Simulate", func(): go.call(true)))
	f.body.add_child(ctrl)
	return _ret(f.node, to_main)

# ------------------------------------------------------------------ career
func round_robin(teams: Array) -> Array:
	var t = teams.duplicate(); var n = t.size(); var rounds = []
	for r in n - 1:
		var rd = []
		for i in n / 2:
			var a = t[i]; var b = t[n - 1 - i]
			rd.append([b, a] if r % 2 else [a, b])
		rounds.append(rd)
		t.insert(1, t.pop_back())
	var second = rounds.map(func(rd): return rd.map(func(f): return [f[1], f[0]]))
	return rounds + second

func s_career(_p) -> Dictionary:
	var f = UI.sub_shell("Manager Career", "Career Mode", true)
	var c = Save.data.career
	if c == null:
		var st = {"club": "ARS"}
		var v = UI.vb(14, [UI.head("START A NEW CAREER", 24), UI.wrapl(UI.label("Choose a club. You'll play a full double round-robin league against every other club in its division. Play or simulate each fixture; finish top to win the title and earn Ultimate XI coins.", 15, UI.DIM), 560),
			UI.option(club_items(), "ARS", func(v): st.club = v),
			UI.btn("Ⓐ  Start Career", func():
				var lg: String = Data.clubs[st.club].lg
				var teams: Array = Data.clubs.keys().filter(func(k): return Data.clubs[k].get("lg", "") == lg)
				var tb = {}
				for t in teams: tb[t] = {"p": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0}
				Save.data.career = {"club": st.club, "lg": lg, "season": 1, "round": 0, "fixtures": round_robin(Sys.shuffled(teams)), "table": tb, "results": []}
				Save.dirty(); UI.rerender(), "Primary", true)])
		f.body.add_child(UI.panel(v))
		return _ret(f.node, to_main)
	var tbl: Array = c.table.keys()
	tbl.sort_custom(func(a, b):
		var A: Dictionary = c.table[a]; var B: Dictionary = c.table[b]
		if A.pts != B.pts: return A.pts > B.pts
		if A.gf - A.ga != B.gf - B.ga: return A.gf - A.ga > B.gf - B.ga
		return A.gf > B.gf)
	var done: bool = int(c.round) >= c.fixtures.size()
	var fx = null
	if not done:
		for fx2 in c.fixtures[int(c.round)]: if fx2.has(c.club): fx = fx2
	var row = UI.hb(24); UI.grow(row)
	var tv = UI.vb(4, [UI.caps("%s · Season %d" % [Data.leagues[c.lg].name, c.season])])
	var g = GridContainer.new(); g.columns = 9; g.add_theme_constant_override("h_separation", 18)
	for hdr in ["#", "", "Club", "P", "W", "D", "L", "GD", "Pts"]: g.add_child(UI.caps(hdr, 11))
	for i in tbl.size():
		var k: String = tbl[i]; var r: Dictionary = c.table[k]; var me: bool = k == c.club
		var col = UI.TEAL if me else UI.TEXT
		g.add_child(UI.label(str(i + 1), 14, col)); g.add_child(UI.icon("crest", k, Vector2(20, 20))); g.add_child(UI.bold(Data.clubs[k].name, 14, col))
		for v in [r.p, r.w, r.d, r.l, r.gf - r.ga]: g.add_child(UI.label(str(v), 14, col))
		g.add_child(UI.bold(str(r.pts), 14, col))
	tv.add_child(g)
	var tp = UI.panel(UI.scroll(tv)); UI.grow(tp); row.add_child(tp)
	var side = UI.vb(14); side.custom_minimum_size.x = 440
	if done:
		var pos: int = tbl.find(c.club) + 1
		side.add_child(UI.panel(UI.vb(10, [UI.head("SEASON COMPLETE", 22), UI.bold("🏆 Champions!" if pos == 1 else "Finished %d of %d" % [pos, tbl.size()], 18),
			UI.btn("Ⓐ  Next season", func():
				c.season += 1; c.round = 0; c.results = []; c.fixtures = round_robin(Sys.shuffled(c.table.keys()))
				for t in c.table: c.table[t] = {"p": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0}
				Save.dirty(); UI.rerender(), "Primary", true)])))
	else:
		var go = func(sim: bool):
			var home = Sys.club_team(fx[0]); var away = Sys.club_team(fx[1])
			UI.run_match({"home": home, "away": away, "user_side": "home" if fx[0] == c.club else "away", "difficulty": Save.data.settings.difficulty, "half_len": int(Save.data.settings.half_len), "sim": sim, "mode": "career", "title": "Matchday %d" % (int(c.round) + 1)},
				func(res):
					play_round(c, fx, res)
					UI.show_results(res, "Career · Matchday %d" % int(c.round), "", func(): UI.replace("career")))
		side.add_child(UI.panel(UI.vb(12, [UI.caps("Matchday %d of %d" % [int(c.round) + 1, c.fixtures.size()]),
			UI.hb(20, [UI.icon("crest", fx[0], Vector2(80, 80)), UI.head("VS", 26), UI.icon("crest", fx[1], Vector2(80, 80))]),
			UI.bold("%s vs %s" % [Data.clubs[fx[0]].name, Data.clubs[fx[1]].name], 15),
			UI.hb(10, [UI.btn("Ⓐ  Play", func(): go.call(false), "Primary", true), UI.btn("Simulate", func(): go.call(true))])])))
	var res = UI.vb(4, [UI.caps("Your results")])
	for r in c.results.slice(-12): res.add_child(UI.label("MD%d  %s  %d - %d  %s" % [r.md, Data.clubs[r.h].name, r.hg, r.ag, Data.clubs[r.a].name], 13))
	var rp = UI.panel(UI.scroll(res)); UI.grow(rp, true, false); side.add_child(rp)
	side.add_child(UI.btn("Abandon career", func():
		if await UI.modal("Abandon career?", "This deletes your current career save.", [["Cancel", null, ""], ["Abandon", true, "Danger"]]):
			Save.data.career = null; Save.dirty(); UI.rerender(), "Danger"))
	row.add_child(side)
	f.body.add_child(row)
	return _ret(f.node, to_main)

func play_round(c: Dictionary, fx: Array, my: Dictionary) -> void:
	for f2 in c.fixtures[int(c.round)]:
		var hg: int; var ag: int
		if f2[0] == fx[0] and f2[1] == fx[1]:
			hg = my.hg; ag = my.ag; c.results.append({"md": int(c.round) + 1, "h": f2[0], "a": f2[1], "hg": hg, "ag": ag})
		else:
			var sc = Sys.sim_score(team_ovr(f2[0]), team_ovr(f2[1])); hg = sc[0]; ag = sc[1]
		var H: Dictionary = c.table[f2[0]]; var A: Dictionary = c.table[f2[1]]
		H.p += 1; A.p += 1; H.gf += hg; H.ga += ag; A.gf += ag; A.ga += hg
		if hg > ag: H.w += 1; H.pts += 3; A.l += 1
		elif hg < ag: A.w += 1; A.pts += 3; H.l += 1
		else: H.d += 1; A.d += 1; H.pts += 1; A.pts += 1
	c.round = int(c.round) + 1
	if int(c.round) >= c.fixtures.size():
		var tb: Array = c.table.keys(); tb.sort_custom(func(a, b): return c.table[a].pts > c.table[b].pts)
		var pos: int = tb.find(c.club) + 1
		Sys.add("coins", max(1000, 15000 - pos * 700), "Career season %d: finished #%d" % [c.season, pos])
		Sys.history("Career: %s finished #%d in season %d" % [Data.clubs[c.club].name, pos, c.season])
	Save.dirty()

# ------------------------------------------------------------------ clubs explorer
func s_clubs(p) -> Dictionary:
	var f = UI.sub_shell("Clubs", "Explore", true)
	var lg: String = p.get("lg", "ENG1"); var club: String = p.get("club", "")
	var row = UI.hb(20); UI.grow(row)
	var l1 = UI.vb(4)
	for k in ["ENG1", "ESP1", "ITA1", "GER1", "FRA1"]:
		var b = UI.btn(Data.leagues[k].name, func(): UI.replace("clubs", {"lg": k}), "Row", k == lg and club == "")
		if k == lg: b.add_theme_color_override("font_color", UI.TEAL)
		l1.add_child(b)
	var p1 = UI.panel(l1); p1.custom_minimum_size.x = 220; row.add_child(p1)
	var l2 = UI.vb(4)
	for code in Data.clubs:
		if Data.clubs[code].get("lg", "") != lg: continue
		var b = UI.btn(Data.clubs[code].name, func(): UI.replace("clubs", {"lg": lg, "club": code}), "Row", code == club)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if code == club: b.add_theme_color_override("font_color", UI.TEAL)
		l2.add_child(b)
	var p2 = UI.panel(UI.scroll(l2)); p2.custom_minimum_size.x = 300; p2.size_flags_vertical = Control.SIZE_EXPAND_FILL; row.add_child(p2)
	var right = UI.vb(10)
	if club != "":
		var roster: Array = Data.by_club[club].filter(func(x): return x.type == "base"); roster.sort_custom(func(a, b): return a.ovr > b.ovr)
		right.add_child(UI.hb(14, [UI.icon("crest", club, Vector2(60, 60)), UI.vb(2, [UI.head(Data.clubs[club].name.to_upper(), 22), UI.label("%s · %d players · Team rating %d" % [Data.leagues[lg].name, roster.size(), team_ovr(club)], 13, UI.DIM)]), UI.spacer(),
			UI.btn("Play friendly as %s" % Data.clubs[club].name, func(): UI.go("kickoff", {"home": club, "away": Sys.pick(Data.clubs.keys().filter(func(k): return not Data.clubs[k].get("special", false) and k != club))}), "Primary")]))
		var g = HFlowContainer.new(); g.add_theme_constant_override("h_separation", 10); g.add_theme_constant_override("v_separation", 12)
		for pl in roster: g.add_child(UI.card(pl, 9.0, false, func(): UI.inspect(pl)))
		right.add_child(UI.scroll(g))
	else:
		right.add_child(UI.label("Select a club to view its squad", 16, UI.DIM))
	var p3 = UI.panel(right); UI.grow(p3); row.add_child(p3)
	f.body.add_child(row)
	return _ret(f.node, to_main)

# ------------------------------------------------------------------ tournaments
func s_tourn(_p) -> Dictionary:
	var f = UI.sub_shell("Prime Cup", "Tournaments", true)
	var T = Save.data.tourn
	if T == null:
		var st = {"club": "PSG"}
		f.body.add_child(UI.panel(UI.vb(14, [UI.head("ENTER THE PRIME CUP", 24), UI.wrapl(UI.label("8 clubs, single elimination. Win the Quarter-Final, Semi-Final and Final. Winners earn 15,000 Ultimate XI coins.", 15, UI.DIM), 520),
			UI.option(club_items(), "PSG", func(v): st.club = v),
			UI.btn("Ⓐ  Start Tournament", func():
				var others: Array = Sys.shuffled(Data.clubs.keys().filter(func(k): return not Data.clubs[k].get("special", false) and k != st.club)).slice(0, 7)
				Save.data.tourn = {"me": st.club, "rounds": [Sys.shuffled([st.club] + others)], "stage": 0, "out": false}
				Save.dirty(); UI.rerender(), "Primary", true)])))
		return _ret(f.node, to_main)
	var names = ["Quarter-Finals", "Semi-Finals", "Final", "Champion"]
	var stage: int = T.stage
	var cur: Array = T.rounds[stage] if stage < T.rounds.size() else []
	var champion = T.rounds[3][0] if stage == 3 else null
	var my_idx: int = cur.find(T.me)
	var opp = cur[my_idx ^ 1] if my_idx >= 0 and cur.size() > 1 else null
	var row = UI.hb(30); row.alignment = BoxContainer.ALIGNMENT_CENTER; UI.grow(row)
	for ri in T.rounds.size():
		var col = UI.vb(10 + ri * 30, [UI.caps(names[ri])]); col.alignment = BoxContainer.ALIGNMENT_CENTER
		for code in T.rounds[ri]:
			var pnl = UI.panel(UI.hb(8, [UI.icon("crest", code, Vector2(24, 24)), UI.bold(Data.clubs[code].name, 14, UI.GOLD2 if code == T.me else UI.TEXT)]), "Glass")
			pnl.custom_minimum_size.x = 220; col.add_child(pnl)
		row.add_child(col)
	var box = UI.vb(12); box.alignment = BoxContainer.ALIGNMENT_CENTER
	if champion != null:
		box.add_child(UI.icon("badge", {"shape": "crest", "c1": "#e8b631", "c2": "#14161c", "icon": "crown"}, Vector2(90, 90)))
		box.add_child(UI.head(Data.clubs[champion].name.to_upper(), 22)); box.add_child(UI.bold("You won the Prime Cup!" if champion == T.me else "Cup winners", 15))
		box.add_child(UI.btn("New tournament", func(): Save.data.tourn = null; Save.dirty(); UI.rerender(), "Primary", true))
	elif T.out:
		box.add_child(UI.head("KNOCKED OUT", 22)); box.add_child(UI.btn("New tournament", func(): Save.data.tourn = null; Save.dirty(); UI.rerender(), "Primary", true))
	else:
		var go = func(sim: bool):
			UI.run_match({"home": Sys.club_team(T.me), "away": Sys.club_team(opp), "user_side": "home", "difficulty": Save.data.settings.difficulty, "half_len": int(Save.data.settings.half_len), "sim": sim, "knockout": true, "mode": "tourn", "title": names[stage]},
				func(res):
					advance(T, cur, res.winner == "home")
					UI.show_results(res, "Prime Cup · " + names[stage], "", func(): UI.replace("tourn")))
		box.add_child(UI.caps(names[stage])); box.add_child(UI.hb(16, [UI.icon("crest", T.me, Vector2(64, 64)), UI.head("VS", 22), UI.icon("crest", opp, Vector2(64, 64))]))
		box.add_child(UI.hb(10, [UI.btn("Ⓐ  Play", func(): go.call(false), "Primary", true), UI.btn("Simulate", func(): go.call(true))]))
	row.add_child(UI.panel(box))
	f.body.add_child(row)
	return _ret(f.node, to_main)

func advance(T: Dictionary, cur: Array, my_won: bool) -> void:
	var nxt = []
	for i in range(0, cur.size(), 2):
		var a: String = cur[i]; var b: String = cur[i + 1]
		if a == T.me or b == T.me: nxt.append(T.me if my_won else (b if a == T.me else a))
		else:
			var sc = Sys.sim_score(team_ovr(a), team_ovr(b), 0)
			nxt.append(a if sc[0] > sc[1] else (b if sc[1] > sc[0] else Sys.pick([a, b])))
	T.rounds.append(nxt); T.stage = int(T.stage) + 1
	if not my_won: T.out = true
	while T.out and T.rounds[int(T.stage)].size() > 1:
		var rd: Array = T.rounds[int(T.stage)]; var nx = []
		for i in range(0, rd.size(), 2):
			var sc = Sys.sim_score(team_ovr(rd[i]), team_ovr(rd[i + 1]), 0); nx.append(rd[i] if sc[0] >= sc[1] else rd[i + 1])
		T.rounds.append(nx); T.stage = int(T.stage) + 1
	if int(T.stage) == 3 and T.rounds[3][0] == T.me:
		Sys.add("coins", 15000, "Prime Cup winners"); Sys.history("Won the Prime Cup with " + Data.clubs[T.me].name)
	Save.dirty()

# ------------------------------------------------------------------ settings
const CONTROLS := [["Move", "WASD / Arrows", "Left stick", "Left stick"], ["Sprint", "Shift", "RT", "R2"], ["Pass (hold for power) / Header", "J", "A", "✕"], ["Driven pass", "R + J", "RB + A", "R1 + ✕"], ["Lobbed through ball", "R + I", "RB + Y", "R1 + △"], ["One-two", "F + J", "LB + A", "L1 + ✕"], ["Through ball", "I", "Y", "△"], ["Shoot (hold) · tap again = timed", "K", "X", "□"], ["Chip shot", "U", "LB + X", "L1 + □"], ["Close control (attacking)", "Ctrl", "LT", "L2"],
	["Finesse shot", "O (hold)", "RB + X", "R1 + □"], ["Lob pass / Cross", "L", "B", "○"], ["Skill moves: flick fwd/back/side", "E + direction", "R-stick flick", "R-stick flick"], ["Step Over / La Croqueta", "E + side ×2", "Flick side ×2", "Flick side ×2"], ["Roulette / McGeady spin", "E E / Shift+E E", "R-stick half / full circle", "R-stick half / full circle"], ["Elastico / Rainbow flick", "E fwd→back / back→fwd", "Flick fwd→back / back→fwd", "Flick fwd→back / back→fwd"], ["Standing tackle", "J (defending)", "B", "○"],
	["Slide tackle", "K (defending)", "X", "□"], ["Switch player", "Q", "LB", "L1"], ["Jockey (defending)", "Ctrl (hold)", "LT", "L2"], ["Teammate press (defending)", "C (hold)", "RB", "R1"], ["Pause / Subs", "Esc / P", "Start", "OPTIONS"], ["Show/hide controls", "H", "Back", "Touchpad"],
	["Menu navigate", "Arrows / mouse", "D-pad", "D-pad / Left stick"], ["Menu select / back", "Enter / Esc", "A / B", "✕ / ○"], ["Menu tabs", "Q / E", "LB / RB", "L1 / R1"]]

func s_settings(_p) -> Dictionary:
	var f = UI.sub_shell("Settings", "Options", true)
	var s: Dictionary = Save.data.settings
	var row = UI.hb(20); UI.grow(row)
	var a = UI.vb(12, [UI.caps("Audio")])
	for kv in [["music", "Music volume"], ["sfx", "Effects volume"], ["crowd", "Crowd volume"]]:
		var sl = HSlider.new(); sl.min_value = 0; sl.max_value = 1; sl.step = 0.05; sl.value = s[kv[0]]; sl.custom_minimum_size.x = 320; sl.focus_mode = Control.FOCUS_ALL
		sl.value_changed.connect(func(v): s[kv[0]] = v; Sfx.apply_volumes(); Save.dirty())
		a.add_child(UI.field(kv[1], sl))
	a.add_child(UI.caps("Gameplay"))
	a.add_child(UI.field("Default difficulty", UI.option(Data.difficulty_order.map(func(k): return [k, Data.difficulties[k].name]), s.difficulty, func(v): s.difficulty = v; Save.dirty())))
	a.add_child(UI.field("Half length", UI.option([2, 3, 4, 5, 6, 8, 10].map(func(m): return [m, "%d minutes" % m]), int(s.half_len), func(v): s.half_len = v; Save.dirty())))
	a.add_child(UI.field("Camera", UI.option([["broadcast", "Broadcast"], ["tele", "Tele Broadcast (closer)"], ["wide", "Wide"]], s.camera, func(v): s.camera = v; Save.dirty())))
	var ck = CheckBox.new(); ck.text = "Show chemistry links on pitch"; ck.button_pressed = s.show_links; ck.toggled.connect(func(v): s.show_links = v; Save.dirty()); a.add_child(ck)
	var fs = CheckBox.new(); fs.text = "Fullscreen"; fs.button_pressed = s.get("fullscreen", false)
	fs.toggled.connect(func(v): s.fullscreen = v; Save.dirty(); DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED)); a.add_child(fs)
	var vib = CheckBox.new(); vib.text = "Controller vibration"; vib.button_pressed = s.get("vibration", true)
	vib.toggled.connect(func(v): s.vibration = v; Save.dirty(); if v: Pad.rumble(0.4, 0.4, 0.3)); a.add_child(vib)
	row.add_child(UI.panel(a))
	var pad_name = Input.get_joy_name(Pad.device) if Pad.device >= 0 else "none connected"
	var c = UI.vb(6, [UI.caps("Controls"), UI.label("Controller: " + pad_name, 12, UI.TEAL if Pad.device >= 0 else UI.DIM)])
	var g = GridContainer.new(); g.columns = 4; g.add_theme_constant_override("h_separation", 10)
	for hdr in ["Action", "Keyboard", "Xbox", "PS5 DualSense"]: g.add_child(UI.caps(hdr, 10))
	for r in CONTROLS: g.add_child(UI.label(r[0], 13, UI.DIM)); g.add_child(UI.bold(r[1], 13)); g.add_child(UI.label(r[2], 13, UI.DIM)); g.add_child(UI.bold(r[3], 13, UI.TEAL if Pad.style == "ps" else UI.TEXT))
	c.add_child(g)
	var csc = UI.scroll(c, true); csc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; csc.custom_minimum_size.x = 380
	var cpn = UI.panel(csc); cpn.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(cpn)
	var gp = UI.vb(10, [UI.caps("Graphics & performance")])
	gp.add_child(UI.field("Frame rate cap", UI.option([[30, "30 FPS (battery saver)"], [60, "60 FPS (recommended)"], [120, "120 FPS"], [0, "Unlimited (not recommended)"]], int(s.get("fps_cap", 60)), func(v): s.fps_cap = int(v); Save.dirty(); UI.apply_display())))
	var vs = CheckBox.new(); vs.text = "V-Sync (no tearing / GPU overload)"; vs.button_pressed = s.get("vsync", true)
	vs.toggled.connect(func(v): s.vsync = v; Save.dirty(); UI.apply_display()); gp.add_child(vs)
	var rp = CheckBox.new(); rp.text = "Goal replays"; rp.button_pressed = s.get("replays", true)
	rp.toggled.connect(func(v): s.replays = v; Save.dirty()); gp.add_child(rp)
	var pm = CheckBox.new(); pm.text = "Performance mode"; pm.button_pressed = s.get("perf_mode", false)
	pm.toggled.connect(func(v): s.perf_mode = v; Save.dirty()); gp.add_child(pm)
	gp.add_child(UI.field("Match speed", UI.option([["slow", "Slow"], ["normal", "Normal"], ["fast", "Fast"]], s.get("game_speed", "normal"), func(v): s.game_speed = v; Save.dirty())))
	gp.add_child(UI.caps("Extreme mode", 12, Color("#ff5a5a")))
	var exb = CheckBox.new(); exb.text = "EXTREME (×1000 difficulty)"; exb.button_pressed = s.get("extreme", false); exb.add_theme_color_override("font_color", Color("#ff7a7a"))
	exb.toggled.connect(func(v):
		if v and not await UI.modal("Turn on EXTREME?", UI.wrapl(UI.label("For this save only:\n• 84+ and special players from packs are 1,000× rarer\n• every AI opponent is maxed out (Ultimate, elite keepers & defenders, 92+ rated squads)\n\nYou can turn it off again here.", 14), 460), [["Cancel", null, ""], ["Go Extreme", true, "Danger"]]):
			exb.set_pressed_no_signal(false); return
		s.extreme = v; Save.dirty(); UI.toast("Extreme mode " + ("ON" if v else "off"), "bad" if v else "good"))
	gp.add_child(exb)
	var d = UI.vb(12, [gp, UI.caps("Save data"), UI.label("Playing on Slot %d of %d" % [Save.slot, Save.SLOTS], 14, UI.TEAL),
		UI.btn("Save Slots…", func(): UI.go("slots"), "Primary"),
		UI.btn(("☁ Cloud · " + Cloud.username()) if Cloud.signed_in() else "☁ Cloud Account…", func(): UI.go("cloud"), ""),
		UI.wrapl(UI.label("Progress saves automatically. This slot's file:\n" + ProjectSettings.globalize_path(Save.path()), 13, UI.DIM), 300),
		UI.btn("Reset all progress", func():
			if await UI.modal("Reset this slot?", "This permanently deletes the club, players, coins and history in Slot %d. Other slots are not touched." % Save.slot, [["Cancel", null, ""], ["Delete Slot %d" % Save.slot, true, "Danger"]]):
				Save.wipe(); UI.reset("title"), "Danger")])
	var dp = UI.panel(d); dp.custom_minimum_size.x = 340; row.add_child(dp)
	f.body.add_child(row)
	return _ret(f.node, to_main)

# ------------------------------------------------------------------ customize
func s_customize(_p) -> Dictionary:
	var pr: Dictionary = Save.data.profile
	var f = UI.sub_shell("Customize", pr.club_name, true)
	var colors = [["#e8b631", "Gold"], ["#c8102e", "Red"], ["#8e1f2f", "Maroon"], ["#034694", "Blue"], ["#6cabdd", "Sky blue"], ["#00954c", "Green"], ["#ffffff", "White"], ["#6b2ea6", "Purple"], ["#14161c", "Black"], ["#ff7f00", "Orange"], ["#fde100", "Yellow"], ["#3a3f4d", "Grey"]]
	var badge = UI.icon("badge", pr.badge, Vector2(110, 110)); var kh = UI.icon("kit", pr.kit.home, Vector2(110, 110)); var ka = UI.icon("kit", pr.kit.away, Vector2(110, 110))
	var upd = func(): for i in [badge, kh, ka]: i.queue_redraw()
	var set_v = func(obj: Dictionary, key: String): return func(v): obj[key] = v; upd.call(); Save.dirty()
	var row = UI.hb(20); row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UI.panel(UI.vb(10, [UI.caps("Club & badge"), badge,
		UI.field("Club name", UI.line(pr.club_name, func(t): pr.club_name = t; Save.dirty(), "", 260)),
		UI.field("Badge shape", UI.option(["shield", "round", "hex", "crest"].map(func(x): return [x, x.capitalize()]), pr.badge.shape, set_v.call(pr.badge, "shape"))),
		UI.field("Badge icon", UI.option(["star", "ball", "crown", "bolt", "bird", "flame"].map(func(x): return [x, x.capitalize()]), pr.badge.icon, set_v.call(pr.badge, "icon"))),
		UI.field("Primary", UI.option(colors, pr.badge.c1, set_v.call(pr.badge, "c1"))), UI.field("Secondary", UI.option(colors, pr.badge.c2, set_v.call(pr.badge, "c2")))])))
	for k in ["home", "away"]:
		row.add_child(UI.panel(UI.vb(10, [UI.caps(k + " kit"), kh if k == "home" else ka,
			UI.field("Main", UI.option(colors, pr.kit[k].c1, set_v.call(pr.kit[k], "c1"))), UI.field("Trim", UI.option(colors, pr.kit[k].c2, set_v.call(pr.kit[k], "c2"))),
			UI.field("Pattern", UI.option(["plain", "stripes", "hoops", "sash", "half"].map(func(x): return [x, x.capitalize()]), pr.kit[k].pattern, set_v.call(pr.kit[k], "pattern")))])))
	row.add_child(UI.panel(UI.vb(10, [UI.caps("Stadium"), UI.field("Stadium name", UI.line(pr.stadium.name, func(t): pr.stadium.name = t; Save.dirty(), "", 240)),
		UI.field("Seat colour", UI.option(colors, pr.stadium.seats, set_v.call(pr.stadium, "seats"))),
		UI.field("Tifo", UI.option(["flames", "stripes", "badge", "none"].map(func(x): return [x, x.capitalize()]), pr.stadium.tifo, set_v.call(pr.stadium, "tifo"))),
		UI.field("Pitch pattern", UI.option(["gold", "classic", "checker"].map(func(x): return [x, x.capitalize()]), pr.stadium.theme, set_v.call(pr.stadium, "theme"))),
		UI.wrapl(UI.label("Your kits, badge, seats and tifo appear in your Ultimate XI matches.", 12, UI.DIM), 240)])))
	f.body.add_child(row)
	return _ret(f.node, func(): UI.back() if not UI.stack.is_empty() else to_main())

# ------------------------------------------------------------------ profile
func s_profile(p) -> Dictionary:
	var pr: Dictionary = Save.data.profile; var s: Dictionary = Save.data.stats
	var f = UI.sub_shell(pr.name, "Profile", true)
	var tab: String = p.get("tab", "matches")
	var row = UI.hb(20); UI.grow(row)
	var g = GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 20)
	for kv in [["Matches", s.played], ["W / D / L", "%d / %d / %d" % [s.wins, s.draws, s.losses]], ["Goals for / against", "%d / %d" % [s.gf, s.ga]], ["Packs opened", s.packs], ["SBCs completed", s.sbcs],
		["Players bought / sold", "%d / %d" % [s.bought, s.sold]], ["Club size", Save.data.club.size()], ["Rivals best", Data.division(int(Save.data.modes.rivals.best)).name]]:
		g.add_child(UI.label(kv[0], 14, UI.DIM)); g.add_child(UI.bold(str(kv[1]), 14))
	var left = UI.vb(12, [UI.hb(12, [UI.icon("badge", pr.badge, Vector2(64, 64)), UI.vb(2, [UI.head(pr.club_name.to_upper(), 20), UI.label("Manager " + pr.name, 13, UI.DIM)])]),
		UI.hb(6, [UI.bold("Club Level %d" % pr.level, 14), UI.spacer(), UI.label("%s / %s XP" % [Sys.fmt(pr.xp), Sys.fmt(Sys.xp_need(pr.level))], 13, UI.DIM)]), UI.bar(pr.xp, Sys.xp_need(pr.level), "GoldBar"), g])
	var lp = UI.panel(left); lp.custom_minimum_size.x = 360; row.add_child(lp)
	var right = UI.vb(10, [UI.seg([["matches", "Match history"], ["history", "Club history"], ["tx", "Transactions"]], tab, func(v): UI.replace("profile", {"tab": v}))])
	var list = UI.vb(4)
	if tab == "matches":
		if Save.data.matches.is_empty(): list.add_child(UI.label("No matches yet", 14, UI.DIM))
		for m in Save.data.matches:
			list.add_child(UI.hb(12, [UI.label(Time.get_date_string_from_unix_time(int(m.t)), 13, UI.DIM), UI.label(m.mode, 13, UI.DIM), UI.bold("%s %d - %d %s" % [m.home, m.hg, m.ag, m.away], 14), UI.spacer(), UI.bold(m.res, 14, UI.GREEN if m.res == "W" else (UI.RED if m.res == "L" else UI.YELLOW))]))
	elif tab == "history":
		for x in pr.history: list.add_child(UI.hb(12, [UI.label(Time.get_date_string_from_unix_time(int(x.t)), 13, UI.DIM), UI.label(x.text, 14)]))
	else:
		for t in Save.data.tx:
			list.add_child(UI.hb(12, [UI.label(Time.get_datetime_string_from_unix_time(int(t.t)).replace("T", " "), 12, UI.DIM), UI.label(t.kind, 12, UI.DIM), UI.label(t.desc, 13), UI.spacer(),
				UI.bold(("+" if t.amount >= 0 else "") + Sys.fmt(t.amount) + (" coins" if t.cur == "coins" else " pts"), 13, UI.GREEN if t.amount >= 0 else UI.RED)]))
	right.add_child(UI.scroll(list))
	var rp = UI.panel(right); UI.grow(rp); row.add_child(rp)
	f.body.add_child(row)
	return _ret(f.node, to_main)

# ------------------------------------------------------------------ save slots
func s_slots(_p) -> Dictionary:
	var f = UI.sub_shell("Save Slots", "Prime Football 27", true) if Save.data != null else {"node": Control.new(), "body": UI.vb(14)}
	if Save.data == null:
		var mg = MarginContainer.new(); mg.set_anchors_preset(Control.PRESET_FULL_RECT)
		for kv in [["left", 60], ["right", 60], ["top", 40], ["bottom", 30]]: mg.add_theme_constant_override("margin_" + kv[0], kv[1])
		f.node.add_child(mg); mg.add_child(f.body)
	f.body.add_child(UI.vb(2, [UI.head("SAVE SLOTS", 40), UI.label("Three separate clubs. Pick a slot to play it, or start a new club in an empty slot. %s on a slot deletes it." % ("□" if Pad.style == "ps" else ("X" if Pad.style == "xbox" else "Delete button")), 14, UI.DIM)]))
	var row = UI.hb(22); row.alignment = BoxContainer.ALIGNMENT_CENTER
	var tiles = []
	for n in range(1, Save.SLOTS + 1):
		var info = Save.slot_info(n)
		var cur: bool = n == Save.slot and Save.data != null
		var kids = [UI.hb(8, [UI.caps("Slot %d" % n, 13, UI.GOLD2), UI.spacer(), UI.caps("● PLAYING" if cur else "", 11, UI.GREEN)])]
		if info.is_empty():
			kids.append(UI.head("EMPTY", 34, UI.DIM)); kids.append(UI.label("Start a new club in this slot", 14, UI.DIM))
		else:
			kids.append(UI.hb(12, [UI.icon("badge", info.badge, Vector2(54, 58)) if not info.badge.is_empty() else Control.new(), UI.vb(0, [UI.bold(info.club, 22), UI.label(info.name, 14, UI.DIM)])]))
			kids.append(UI.label("Club Level %d  ·  ● %s coins" % [info.level, Sys.fmt(info.coins)], 14))
			kids.append(UI.label("%d players  ·  %d matches played" % [info.players, info.played], 13, UI.DIM))
			if info.saved > 0: kids.append(UI.label("Last saved " + Time.get_datetime_string_from_unix_time(info.saved + Time.get_time_zone_from_system().bias * 60, true), 12, UI.DIM))
			if info.extreme: kids.append(UI.bold("☠ EXTREME", 15, Color("#ff5a5a")))
		var t = UI.tile(kids, func(): _open_slot(n), Vector2(330, 270), n == Save.slot)
		t.set_meta("slot", n)
		if cur:
			var sb = StyleBoxFlat.new(); sb.bg_color = Color(0.18, 0.85, 0.5, 0.08); sb.border_color = UI.GREEN; sb.set_border_width_all(2); sb.set_corner_radius_all(10)
			t.add_theme_stylebox_override("normal", sb)
		var del = UI.btn("Delete", func(): _delete_slot(n), "Small")
		del.disabled = info.is_empty()
		row.add_child(UI.vb(8, [t, del])); tiles.append(t)
	var cc = CenterContainer.new(); UI.grow(cc); cc.add_child(row)
	f.body.add_child(cc)
	var del_focused = func():
		var fo = UI.get_viewport().gui_get_focus_owner()
		if fo and fo.has_meta("slot"): _delete_slot(int(fo.get_meta("slot")))
	UI.keyhook(f.node, {"j%d" % JOY_BUTTON_X: del_focused, "k%d" % KEY_DELETE: del_focused})
	return _ret(f.node, func(): UI.reset("main" if Save.data != null else "title"), "menu" if Save.data == null else "hub")

func _open_slot(n: int) -> void:
	if n == Save.slot and Save.data != null: UI.reset("main"); return
	var info = Save.slot_info(n)
	var msg = ("Load %s (Slot %d)?" % [info.club, n]) if not info.is_empty() else "Start a new club in Slot %d?" % n
	if not await UI.modal("Switch save slot", msg + "\nYour current club is saved first.", [["Cancel", null, ""], ["Load" if not info.is_empty() else "New club", true, "Primary"]]): return
	var has = Save.use_slot(n)
	Sfx.play("boom")
	if has:
		Sys.market_tick()
		UI.toast("Loaded Slot %d · %s" % [n, info.club], "good"); UI.reset("main")
	else: UI.reset("onboard")

func _delete_slot(n: int) -> void:
	var info = Save.slot_info(n)
	if info.is_empty(): return
	if not await UI.modal("Delete Slot %d?" % n, "This permanently deletes %s (%d players, ● %s coins). This can't be undone." % [info.club, info.players, Sys.fmt(info.coins)], [["Cancel", null, ""], ["Delete forever", true, "Danger"]]): return
	var was_cur: bool = n == Save.slot
	Save.delete_slot(n)
	UI.toast("Slot %d deleted" % n, "bad")
	if was_cur: UI.reset("slots")
	else: UI.replace("slots")

# ------------------------------------------------------------------ cloud account
func s_cloud(_p) -> Dictionary:
	var f = UI.sub_shell("Cloud Account", "Prime Football 27", true) if Save.data != null else {"node": Control.new(), "body": UI.vb(14)}
	if Save.data == null:
		var mg = MarginContainer.new(); mg.set_anchors_preset(Control.PRESET_FULL_RECT)
		for kv in [["left", 60], ["right", 60], ["top", 40], ["bottom", 30]]: mg.add_theme_constant_override("margin_" + kv[0], kv[1])
		f.node.add_child(mg); mg.add_child(f.body)
	f.body.add_child(UI.vb(2, [UI.head("CLOUD ACCOUNT", 40), UI.label("Save your club online and use it in the companion app — simulate matches, packs, market, SBCs and objectives from your phone.", 14, UI.DIM)]))
	var st = UI.bold(Cloud.status, 16, UI.TEAL)
	var upd = func(): if is_instance_valid(st): st.text = Cloud.status
	Cloud.status_changed.connect(upd)
	f.body.add_child(UI.panel(UI.hb(10, [UI.caps("Status", 11), st]), "Glass"))
	var row = UI.hb(20)
	var edit_server: bool = not Cloud.configured() or _p.get("server", false)
	if Cloud.configured() and not edit_server:
		f.body.add_child(UI.hb(8, [UI.label("Server: " + Cloud.url, 12, UI.DIM), UI.btn("Change server", func(): UI.replace("cloud", {"server": true}), "Small")]))
	if edit_server:
		var S = {"u": Cloud.url, "k": Cloud.key}
		row.add_child(UI.panel(UI.vb(10, [UI.caps("Server setup (one time)", 12, UI.GOLD2),
			UI.wrapl(UI.label("Paste your Supabase Project URL and the Publishable key (sb_publishable_…, or the legacy anon key). Never the Secret key.", 13, UI.DIM), 440),
			UI.field("Project URL", UI.line(S.u, func(t): S.u = t, "https://xxxx.supabase.co", 440)),
			UI.field("Publishable key", UI.line(S.k, func(t): S.k = t, "sb_publishable_…", 440)),
			UI.btn("Save server", func():
				if not S.u.strip_edges().begins_with("https://") or S.k.strip_edges().length() < 20: UI.toast("Check the URL and key", "bad"); return
				if S.k.strip_edges().begins_with("sb_secret"): UI.toast("That's the Secret key — use the Publishable key", "bad"); return
				Cloud.set_server(S.u, S.k); UI.toast("Server saved", "good"); UI.replace("cloud"), "Primary")])))
	elif not Cloud.signed_in():
		var A = {"u": "", "p": ""}
		var pin = UI.line("", func(t): A.p = t, "4–6 digits", 260); pin.secret = true; pin.max_length = 6
		row.add_child(UI.panel(UI.vb(10, [UI.caps("Sign in or create an account", 12, UI.GOLD2),
			UI.field("Username", UI.line("", func(t): A.u = t, "3–20 letters, numbers or _", 260)),
			UI.field("PIN", pin),
			UI.hb(10, [UI.btn("Sign in", func(): _cloud_sign_in(A.u, A.p), "Primary", true), UI.btn("Create account", func(): _cloud_register(A.u, A.p), "")]),
			UI.wrapl(UI.label(("Creating an account uploads this slot's club (Slot %d)." % Save.slot) if Save.data != null else "Sign in with the account you made in the game.", 12, UI.DIM), 360)])))
	else:
		var a = Cloud.auth()
		row.add_child(UI.panel(UI.vb(10, [UI.caps("Signed in", 12, UI.GOLD2), UI.head(str(a.user), 30), UI.label("Linked to Slot %d · cloud revision %d%s" % [Save.slot, int(a.get("rev", 0)), "  ·  changes waiting to upload" if a.get("dirty", false) else ""], 13, UI.DIM),
			UI.hb(10, [UI.btn("Sync now", func(): _cloud_sync(), "Primary", true), UI.btn("Download from cloud", func(): _cloud_download(), ""), UI.btn("Sign out", func(): Cloud.sign_out(); UI.replace("cloud"), "Small")]),
			UI.wrapl(UI.label("Progress uploads automatically a few seconds after you play. When you start the game, newer progress from the companion app is downloaded.", 12, UI.DIM), 440)])))
	row.add_child(UI.panel(UI.vb(6, [UI.caps("Companion app", 12, UI.GOLD2),
		UI.wrapl(UI.label("Open it in any phone browser and sign in with the same username and PIN. It's Ultimate Team only, and matches are simulated.", 13), 380),
		UI.bold(COMPANION_URL, 14, UI.TEAL)]), "Glass"))
	f.body.add_child(row)
	return _ret(f.node, func(): UI.reset(("home" if Cloud.companion() else "main") if Save.data != null else "title"), "hub" if Save.data != null else "menu")

const COMPANION_URL := "https://qrw6741.github.io/TONIFC/companion/"

func _cloud_sign_in(u: String, p: String) -> void:
	var r = await Cloud.sign_in(u, p)
	if not r.get("ok", false): UI.toast(str(r.get("error", "Sign in failed")), "bad"); return
	var cloud_save = r.get("save")
	if cloud_save == null:
		if Save.data != null: await Cloud.push(true); UI.toast("Signed in — uploaded this club to your new cloud account", "good")
		elif Cloud.companion(): UI.toast("No club on this account yet — create one", "info"); UI.reset("onboard"); return
	elif Save.data == null:
		Cloud.apply_cloud(cloud_save, int(r.rev)); UI.toast("Welcome back, " + Cloud.username(), "good")
	else:
		var cl = str(cloud_save.get("profile", {}).get("club_name", "Club")); var here = str(Save.data.profile.club_name)
		var v = await UI.modal("Which club?", "The cloud has %s (from %s). This device has %s in Slot %d." % [cl, str(r.get("device", "another device")), here, Save.slot],
			[["Use cloud club", "cloud", "Primary"], ["Upload this device's club", "local", ""]])
		if v == "local": await Cloud.push(true)
		else: Cloud.apply_cloud(cloud_save, int(r.rev))
	UI.reset("home" if Cloud.companion() and Save.data != null else "cloud")

func _cloud_register(u: String, p: String) -> void:
	if Save.data == null and not Cloud.companion(): UI.toast("Create a club first", "bad"); return
	var r = await Cloud.register(u, p)
	if not r.get("ok", false): UI.toast(str(r.get("error", "Couldn't create the account")), "bad"); return
	UI.toast("Account %s created" % Cloud.username(), "good")
	if Save.data == null: UI.reset("onboard"); return
	UI.replace("cloud")

func _cloud_sync() -> void:
	var r = await Cloud.push()
	if r.get("ok", false): UI.toast("Synced to the cloud", "good"); UI.replace("cloud"); return
	if str(r.get("error", "")) == "conflict": await resolve_conflict()
	else: UI.toast(str(r.get("error", "Sync failed")), "bad")

func _cloud_download() -> void:
	if not await UI.modal("Download from cloud?", "This replaces the club in Slot %d with your cloud club." % Save.slot, [["Cancel", null, ""], ["Download", true, "Primary"]]): return
	var r = await Cloud.pull()
	if r.get("ok", false): UI.toast("Cloud club downloaded", "good"); UI.reset("home" if Cloud.companion() else "main")
	else: UI.toast(str(r.get("error", "Download failed")), "bad")

## both this device and the cloud changed since the last sync
func resolve_conflict() -> void:
	var v = await UI.modal("Cloud has newer progress", "Your club was changed on another device (e.g. the companion app) and on this one. Which progress do you want to keep?",
		[["Use cloud progress", "cloud", "Primary"], ["Keep this device (overwrite cloud)", "local", ""], ["Decide later", null, ""]])
	if v == "cloud": await Cloud.pull(); UI.reset("home" if Cloud.companion() else "main")
	elif v == "local": await Cloud.push(true); UI.toast("Cloud updated from this device", "good")
