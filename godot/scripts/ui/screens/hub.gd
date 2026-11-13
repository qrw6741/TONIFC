extends RefCounted
## Ultimate XI hub: Home, Objectives, Club, Squad Builder, Store, pack opening.

func _hub(f: Dictionary, tab: String) -> Dictionary:
	return {"node": f.node, "bg": "hub", "tab": tab, "back": func(): UI.reset("main")}

func page_title(t: String) -> Label: return UI.head(t.to_upper(), 38)

# ------------------------------------------------------------------ HOME
func s_home(_p) -> Dictionary:
	var f = UI.hub_shell("home")
	var pr: Dictionary = Save.data.profile
	var sq = Sys.active_squad(); var info = Sys.squad_info(sq)
	var top = UI.hb(14, [page_title("Welcome back"), UI.spacer(), UI.vb(4, [UI.hb(8, [UI.bold("Club Level %d" % pr.level, 13), UI.spacer(), UI.label("%s / %s XP" % [Sys.fmt(pr.xp), Sys.fmt(Sys.xp_need(pr.level))], 13, UI.DIM)]), UI.bar(pr.xp, Sys.xp_need(pr.level), "GoldBar")])])
	top.get_child(-1).custom_minimum_size.x = 300
	f.body.add_child(top)
	var row = UI.hb(18); UI.grow(row)
	# left column
	var left = UI.vb(14); left.custom_minimum_size.x = 300
	left.add_child(UI.tile([UI.caps("Club overview"), UI.hb(10, [UI.icon("badge", pr.badge, Vector2(54, 58)), UI.vb(2, [UI.bold(pr.club_name, 20), UI.label("%d players · %d wins" % [Save.data.club.size(), Save.data.stats.wins], 13, UI.DIM)])])], func(): UI.replace("club"), Vector2(0, 120)))
	var objs: Array = Data.objectives.filter(func(o): return not Sys.obj_claimed(o))
	objs.sort_custom(func(a, b): return (1 if Sys.obj_done(a) else 0) * 2 + float(Sys.obj_progress(a)) / a.target > (1 if Sys.obj_done(b) else 0) * 2 + float(Sys.obj_progress(b)) / b.target)
	var ob = [UI.caps("Active objectives")]
	for o in objs.slice(0, 3):
		ob.append(UI.hb(6, [UI.bold(o.title, 13), UI.spacer(), UI.bold("CLAIM" if Sys.obj_done(o) else "%d/%d" % [Sys.obj_progress(o), o.target], 13, UI.GREEN if Sys.obj_done(o) else UI.DIM)]))
		ob.append(UI.bar(Sys.obj_progress(o), o.target))
	var ot = UI.tile(ob, func(): UI.replace("objectives")); UI.grow(ot, true, false); left.add_child(ot)
	var rv: Dictionary = Save.data.modes.rivals; var sb: Dictionary = Save.data.modes.sb
	var g = GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 14)
	for kv in [["Division Rivals", "%s · %d/10" % [Data.division(int(rv.div)).name, rv.pts]], ["Squad Battles", "%s pts" % Sys.fmt(sb.points if sb.week == Sys.week_key() else 0)], ["Champions", ("%d pts · %d/%d" % [int(Champs.run().pts), int(Champs.run().played), Champs.MATCHES]) if Champs.run() != null else ("Qualified" if Champs.qualified() else "%d/1,000 QP" % int(Champs.st().qp))]]:
		g.add_child(UI.label(kv[0], 13, UI.DIM)); g.add_child(UI.label(kv[1], 13))
	left.add_child(UI.tile([UI.caps("Competitions"), g], func(): UI.replace("play"), Vector2(0, 120)))
	var gcl = Gallery.set_ids().filter(func(id): return Gallery.claimable(id)).size()
	left.add_child(UI.tile([UI.hb(8, [UI.bold("Gallery ✦", 18, Color("#ff6fd8")), UI.spacer(), UI.bold("Lv %d · ◈ %s" % [Gallery.level(), Sys.fmt(Gallery.tokens())], 13, Color("#9fe8ff"))]), UI.label(("%d sets ready to grade" % gcl) if gcl else "Collect players from the top 6 clubs of each league", 12, UI.GREEN if gcl else UI.DIM)], func(): UI.go("gallery")))
	row.add_child(left)
	# squad tile
	var mp = UI.icon("minipitch", {"formation": sq.formation, "players": info.players}, Vector2(300, 330)); mp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; mp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var stat = func(v: int, l: String, col := UI.TEXT): return UI.panel(UI.vb(0, [UI.head(str(v), 28, col), UI.caps(l, 10)]), "Glass")
	var chem_col = UI.GREEN if info.chem.total >= 24 else (UI.YELLOW if info.chem.total >= 12 else UI.RED)
	var st = UI.tile([UI.hb(10, [UI.vb(2, [UI.bold(sq.name, 30), UI.bold("Manage your squad, formation & chemistry", 13, UI.TEAL)]), UI.spacer(), stat.call(info.rating, "Rating"), stat.call(info.chem.total, "Chem", chem_col)]), mp], func(): UI.go("squad"), Vector2.ZERO, true)
	UI.grow(st); st.size_flags_stretch_ratio = 1.3; row.add_child(st)
	# right column
	var right = UI.vb(14); UI.grow(right)
	var pc = UI.hb(6)
	for p in Event.stars.slice(0, 3): var c = UI.card(p, 7.6); pc.add_child(c)
	var pt = UI.tile([UI.bold("Rising Stars", 24, Color("#8af4ff")), UI.bold("Event live · the best young players, boosted — objectives, Evolutions & SBCs", 13, UI.TEAL), CenterContainer.new()], func(): UI.go("event"))
	pt.get_child(0).get_child(0).get_child(2).add_child(pc); UI._ignore_mouse(pt.get_child(0)); UI.grow(pt, true, true); right.add_child(pt)
	var slv: int = Season.level(); var scl: int = Season.claim_count()
	right.add_child(UI.tile([UI.hb(10, [UI.vb(2, [UI.bold("Season Pass · Level %d" % slv, 20, Color("#ff8a5c")), UI.bold(("%d rewards to claim" % scl) if scl else "Earn XP to unlock Ascension cards", 13, UI.GREEN if scl else UI.TEAL)]), UI.spacer(), UI.card(Data.ascension_finale[0], 3.6, true) if not Data.ascension_finale.is_empty() else UI.spacer()]), UI.bar(Season.level_xp(), Season.XP_PER, "GoldBar")], func(): UI.replace("season")))
	var un: int = Save.data.unopened.size()
	right.add_child(UI.tile([UI.hb(10, [UI.vb(2, [UI.bold(("%d unopened" % un) if un else "Store", 22), UI.bold("Open your packs" if un else "Packs from 400 coins", 13, UI.TEAL)]), UI.spacer(), UI.icon("pack", Save.data.unopened[0] if un else "premium", Vector2(52, 74))])], func(): UI.replace("store", {"tab": "mine" if un else "packs"})))
	right.add_child(UI.panel(UI.vb(4, [UI.caps("Balance"), UI.hb(18, [UI.head("● " + Sys.fmt(Save.data.coins), 22, UI.GOLD2), UI.head("◆ " + Sys.fmt(Save.data.points), 22, UI.TEAL)]), UI.label("Prime Points are free in-game credits — no real money.", 12, UI.DIM)])))
	row.add_child(right)
	f.body.add_child(row)
	return _hub(f, "home")

# ------------------------------------------------------------------ OBJECTIVES
func s_objectives(p) -> Dictionary:
	var f = UI.hub_shell("objectives")
	var cat: String = p.get("cat", "daily")
	var cats = [["daily", "Daily"], ["weekly", "Weekly"], ["season", "Season"], ["milestone", "Milestones"]]
	var labs = cats.map(func(c): return [c[0], c[1] + (" •" if Data.objectives.any(func(o): return o.cat == c[0] and Sys.obj_done(o) and not Sys.obj_claimed(o)) else "")])
	f.body.add_child(UI.hb(10, [page_title("Objectives"), UI.spacer(), UI.seg(labs, cat, func(v): UI.replace("objectives", {"cat": v}))]))
	var sub = {"daily": "Resets in " + Sys.fmt_time(Sys.secs_to_reset("daily")), "weekly": "Resets in " + Sys.fmt_time(Sys.secs_to_reset("weekly")), "season": "Season 1 · rewards Foundations players", "milestone": "Permanent milestones"}[cat]
	f.body.add_child(UI.label(sub, 13, UI.DIM))
	var list = UI.vb(10)
	for o in Data.objectives.filter(func(x): return x.cat == cat):
		var pr = Sys.obj_progress(o); var done = Sys.obj_done(o); var cl = Sys.obj_claimed(o)
		var right: Control
		if cl: right = UI.pill("Claimed", UI.GREEN)
		else:
			var b = UI.btn("Claim reward" if done else "%d / %d" % [pr, o.target], func():
				if Sys.obj_claim(o): Sfx.play("reveal"); UI.toast("Claimed: " + Sys.reward_text(o.reward), "good"); UI.replace("objectives", {"cat": cat}), "Primary" if done else "Small")
			b.disabled = not done; right = b
		var circle = UI.head("✓" if cl else ("!" if done else "%d%%" % int(100.0 * pr / o.target)), 16, UI.GREEN if cl else (UI.TEAL if done else UI.TEXT)); circle.custom_minimum_size.x = 54; circle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var mid = UI.vb(4, [UI.bold(o.title, 17), UI.label(o.desc, 13, UI.DIM), UI.bar(pr, o.target)]); UI.grow(mid, false, true)
		var rv = UI.vb(6, [UI.bold(Sys.reward_text(o.reward), 13, UI.TEAL), right]); rv.custom_minimum_size.x = 260
		list.add_child(UI.panel(UI.hb(18, [circle, mid, rv])))
	f.body.add_child(UI.scroll(list))
	return _hub(f, "objectives")

# ------------------------------------------------------------------ CLUB
func s_club(p) -> Dictionary:
	var f = UI.hub_shell("club")
	var view: String = p.get("view", "players")
	f.body.add_child(UI.hb(10, [page_title("Club"), UI.spacer(), UI.seg([["players", "Players"], ["dupes", "Duplicates"], ["squads", "Squads"], ["gallery", "Gallery ✦"], ["stats", "Club Stats"], ["custom", "Customize"]], view, func(v):
		if v == "custom": UI.go("customize")
		elif v == "gallery": UI.go("gallery")
		else: UI.replace("club", {"view": v}))]))
	if view == "players" or view == "dupes":
		var st = {"q": "", "pos": "", "lg": "", "rar": "", "sort": "ovr"}
		var grid = HFlowContainer.new(); grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 14)
		var cnt = UI.bold("", 13, UI.DIM)
		var render = func():
			for c in grid.get_children(): c.queue_free()
			var items: Array = Sys.duplicates() if view == "dupes" else Save.data.club.duplicate()
			var arr = items.map(func(it): return [it, Data.P(it.pid)]).filter(func(x):
				var pl: Dictionary = x[1]
				return (st.q == "" or pl.name.to_lower().contains(st.q)) and (st.pos == "" or pl.pos == st.pos) and (st.lg == "" or pl.lg == st.lg) and \
					(st.rar == "" or (pl.rare if st.rar == "rare" else (pl.type != "base" if st.rar == "special" else (pl.type == "base" and Data.tier_of(pl.ovr) == st.rar)))))
			match st.sort:
				"ovr": arr.sort_custom(func(a, b): return a[1].ovr > b[1].ovr)
				"new": arr.sort_custom(func(a, b): return a[0].at > b[0].at)
				"name": arr.sort_custom(func(a, b): return Data.short_name(a[1].name) < Data.short_name(b[1].name))
				"val": arr.sort_custom(func(a, b): return Sys.value(a[1]) > Sys.value(b[1]))
				"pace": arr.sort_custom(func(a, b): return a[1].stats[0] > b[1].stats[0])
			cnt.text = "%d players" % arr.size()
			for x in arr.slice(0, 200):
				var it: Dictionary = x[0]
				var c = UI.card(x[1], 9.4, false, func(): item_actions(it.uid, func(): UI.replace("club", {"view": view})))
				c.untr = it.untr
				c.tag = "ON MARKET" if Sys.in_market(it.uid) else ("IN SQUAD" if Sys.in_active_squad(it.uid) else "")
				grid.add_child(c)
		var filters = UI.hb(8, [UI.line("", func(t): st.q = t.to_lower(); render.call(), "Search players", 200),
			UI.option([["", "Position"]] + Data.positions.map(func(x): return [x, x]), "", func(v): st.pos = v; render.call()),
			UI.option([["", "League"]] + ["ENG1", "ESP1", "ITA1", "GER1", "FRA1", "LEG"].map(func(k): return [k, Data.leagues[k].name]), "", func(v): st.lg = v; render.call()),
			UI.option([["", "Rarity"], ["bronze", "Bronze"], ["silver", "Silver"], ["gold", "Gold"], ["rare", "Rare"], ["special", "Special"]], "", func(v): st.rar = v; render.call()),
			UI.option([["ovr", "Sort: Rating"], ["new", "Sort: Newest"], ["name", "Sort: Name"], ["val", "Sort: Value"], ["pace", "Sort: Pace"]], "ovr", func(v): st.sort = v; render.call()), UI.spacer(), cnt])
		if view == "dupes":
			filters.add_child(UI.btn("Quick sell all duplicates", func():
				var d: Array = Sys.duplicates().filter(func(it): return not Sys.in_market(it.uid) and not Sys.in_any_squad(it.uid))
				if d.is_empty(): UI.toast("No duplicates to sell"); return
				var tot = 0
				for it in d: tot += Data.quick_sell_value(Data.P(it.pid))
				if await UI.modal("Quick sell duplicates?", "Sell %d duplicate players for %s coins." % [d.size(), Sys.fmt(tot)], [["Cancel", null, ""], ["Quick sell", true, "Primary"]]):
					for it in d: Sys.club_remove(it.uid)
					Sys.add("coins", tot, "Quick sold %d duplicates" % d.size(), "quicksell"); render.call(), "Small"))
		f.body.add_child(filters)
		f.body.add_child(UI.scroll(grid))
		render.call()
	elif view == "squads":
		var list = UI.vb(10)
		list.add_child(UI.btn("+ New squad", func(): Sys.squad_create("Squad %d" % (Save.data.squads.size() + 1)); Save.data.active_squad = Save.data.squads.size() - 1; UI.go("squad"), "Primary"))
		for i in Save.data.squads.size():
			var s: Dictionary = Save.data.squads[i]; var inf = Sys.squad_info(s)
			var r = UI.hb(12)
			if i == int(Save.data.active_squad): r.add_child(UI.pill("ACTIVE", UI.GREEN))
			var nm = UI.vb(2, [UI.bold(s.name, 17), UI.label("%s · Rating %d · Chem %d/33 · %d/11" % [s.formation, inf.rating, inf.chem.total, inf.filled], 13, UI.DIM)]); UI.grow(nm, false, true); r.add_child(nm)
			r.add_child(UI.btn("Edit", func(): Save.data.active_squad = i; Save.dirty(); UI.go("squad"), "Small"))
			if i != int(Save.data.active_squad): r.add_child(UI.btn("Set active", func(): Save.data.active_squad = i; Save.dirty(); UI.rerender(), "Small"))
			r.add_child(UI.btn("Rename", func(): await rename_squad(s); UI.rerender(), "Small"))
			if Save.data.squads.size() > 1:
				r.add_child(UI.btn("Delete", func():
					if await UI.modal("Delete squad?", s.name, [["Cancel", null, ""], ["Delete", true, "Danger"]]):
						Save.data.squads.remove_at(i); Save.data.active_squad = 0; Save.dirty(); UI.rerender(), "Danger"))
			list.add_child(UI.panel(r))
		f.body.add_child(UI.scroll(list))
	else:
		var items: Array = Save.data.club.map(func(i): return Data.P(i.pid))
		var cnt = func(fn: Callable) -> int: return items.filter(fn).size()
		var val = 0
		for pl in items: val += Sys.value(pl)
		var s: Dictionary = Save.data.stats
		var kvbox = func(title: String, rows: Array) -> Control:
			var g = GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 24)
			for r in rows: g.add_child(UI.label(r[0], 14, UI.DIM)); g.add_child(UI.bold(str(r[1]), 14))
			var pn = UI.panel(UI.vb(10, [UI.caps(title), g])); pn.custom_minimum_size.x = 340; return pn
		var hist = UI.vb(4, [UI.caps("Club history")])
		for x in Save.data.profile.history.slice(0, 30): hist.add_child(UI.label(Time.get_date_string_from_unix_time(int(x.t)) + " · " + x.text, 13))
		var hp = UI.panel(UI.scroll(hist)); UI.grow(hp)
		f.body.add_child(UI.hb(18, [kvbox.call("Collection", [["Total players", items.size()], ["Gold / Silver / Bronze", "%d / %d / %d" % [cnt.call(func(p): return Data.tier_of(p.ovr) == "gold"), cnt.call(func(p): return Data.tier_of(p.ovr) == "silver"), cnt.call(func(p): return Data.tier_of(p.ovr) == "bronze")]],
			["Rare", cnt.call(func(p): return p.rare)], ["Special cards", cnt.call(func(p): return p.type != "base")], ["Icons / Heroes", "%d / %d" % [cnt.call(func(p): return p.type == "icon"), cnt.call(func(p): return p.type == "hero")]], ["Duplicates", Sys.duplicates().size()], ["Est. club value", "● " + Sys.fmt(val)]]),
			kvbox.call("Record", [["Matches", s.played], ["Wins / Draws / Losses", "%d / %d / %d" % [s.wins, s.draws, s.losses]], ["Goals scored", s.gf], ["Goals conceded", s.ga], ["Packs opened", s.packs], ["SBCs", s.sbcs]]), hp]))
	return _hub(f, "club")

func rename_squad(s: Dictionary) -> void:
	var st = {"n": s.name}
	var v = await UI.modal("Rename squad", UI.line(s.name, func(t): st.n = t, "", 360), [["Cancel", null, ""], ["Save", true, "Primary"]])
	if v and st.n.strip_edges() != "": s.name = st.n.strip_edges(); Save.dirty()

func item_actions(u: String, after: Callable) -> void:
	var it = Sys.item(u)
	if it.is_empty(): return
	var p = Data.P(it.pid)
	var acts = []
	if not Sys.in_market(u) and not it.untr: acts.append(["List on Transfer Market", "list", ""])
	if not Sys.in_market(u): acts.append(["Quick sell (%s)" % Sys.fmt(Data.quick_sell_value(p)), "qs", "Danger"])
	var best = best_owned(p.pos, u)
	if not best.is_empty(): acts.append(["Compare", "cmp", ""])
	var v = await UI.inspect(p, acts, it)
	if v == "qs":
		if Sys.in_any_squad(u) and not await UI.modal("Player is in a squad", "Quick selling removes him from your squads. Continue?", [["Cancel", null, ""], ["Quick sell", true, "Danger"]]): return
		Sys.club_remove(u); Sys.add("coins", Data.quick_sell_value(p), "Quick sold " + p.name, "quicksell"); UI.toast("Quick sold " + p.name, "good")
	elif v == "list": await list_dialog(u)
	elif v == "cmp": await UI.compare(p, best)
	after.call()

func best_owned(pos: String, exclude := "") -> Dictionary:
	var best = {}
	for it in Save.data.club:
		if it.uid == exclude: continue
		var p = Data.P(it.pid)
		if p.pos == pos and (best.is_empty() or p.ovr > best.ovr): best = p
	return best

func list_dialog(u: String) -> bool:
	var it = Sys.item(u); var p = Data.P(it.pid); var rg = Sys.price_range(p); var v = Sys.value(p)
	var st = {"start": int(round(v * 0.75 / 50.0)) * 50, "bin": int(round(v * 1.05 / 50.0)) * 50, "dur": 10}
	var net = UI.label("", 13, UI.DIM)
	var upd = func(): net.text = "If sold at Buy Now you receive %s coins (5%% tax)." % Sys.fmt(int(round(st.bin * 0.95)))
	var sp = func(key: String) -> SpinBox:
		var s = SpinBox.new(); s.min_value = 150; s.max_value = 20000000; s.step = 50; s.value = st[key]; s.custom_minimum_size.x = 180
		s.value_changed.connect(func(x): st[key] = int(x); upd.call()); return s
	upd.call()
	var body = UI.vb(12, [UI.player_row(p, [], func(): pass), UI.label("Estimated value ● %s · allowed range %s – %s" % [Sys.fmt(v), Sys.fmt(rg.min), Sys.fmt(rg.max)], 13, UI.DIM),
		UI.hb(14, [UI.field("Start price", sp.call("start")), UI.field("Buy Now price", sp.call("bin")), UI.field("Duration", UI.option([[2, "2 minutes"], [10, "10 minutes"], [60, "1 hour"], [180, "3 hours"]], 10, func(x): st.dur = x))]), net])
	var r = await UI.modal("List on Transfer Market", body, [["Cancel", null, ""], ["List player", true, "Primary"]])
	if r and Sys.list_item(u, st.start, st.bin, st.dur): UI.toast(p.name + " listed", "good"); return true
	return false

# ------------------------------------------------------------------ SQUAD BUILDER
func s_squad(_p) -> Dictionary:
	var sq = Sys.active_squad()
	var f = UI.sub_shell(sq.name, "Squad Builder")
	var holder = UI.hb(22); UI.grow(holder)
	f.body.add_child(holder)
	var S = SquadEditor.new(sq, holder)
	holder.set_meta("editor", S)   # keep the editor alive with the screen
	S.draw(-1)
	return {"node": f.node, "bg": "hub"}

class SquadEditor extends RefCounted:
	var sq: Dictionary
	var holder: HBoxContainer
	var sel = -1
	var moving = -1
	var pitch: PitchView
	var bench_grid: GridContainer
	var selbox: VBoxContainer
	func _init(s: Dictionary, h: HBoxContainer) -> void: sq = s; holder = h
	func get_u(i: int) -> String: return sq.slots[i] if i < 11 else sq.subs[i - 11]
	func set_u(i: int, u: String) -> void:
		if i < 11: sq.slots[i] = u
		else: sq.subs[i - 11] = u
	func swap(a: int, b: int) -> void:
		var ua = get_u(a); var ub = get_u(b)
		set_u(a, ub); set_u(b, ua); Save.dirty(); Sfx.play("select")
	func pick(i: int) -> void:
		var pos: String = Data.formations[sq.formation][i][0] if i < 11 else ""
		var cur = {}
		for u in sq.slots + sq.subs: if u != "": cur[u] = true
		var cur_pids = {}
		for u in cur: cur_pids[Sys.item(u).pid] = true
		var u = await UI.pick_player("Select " + (pos if pos != "" else "player"), pos, func(it): return not cur_pids.has(it.pid) or cur.has(it.uid))
		if u != null:
			var other = -1
			for k in 18: if get_u(k) == u: other = k
			if other >= 0: swap(i, other)
			else:
				set_u(i, u); Save.dirty(); Sfx.play("select")
		sel = -1; draw(i)
	func click(i: int) -> void:
		if moving >= 0:
			if moving != i: swap(moving, i)
			moving = -1; sel = -1; draw(i); return
		sel = -1 if sel == i else i
		if sel >= 0 and get_u(i) == "": pick(i); return
		draw(i)
	func act(a: String) -> void:
		var i = sel; var u = get_u(i)
		match a:
			"replace": pick(i); return
			"move": moving = i; UI.toast("Now select the slot to swap with"); return
			"view":
				await UI.inspect(Sys.item_player(u), [], Sys.item(u))
			"cap":
				sq.captain = u; Save.dirty(); UI.toast("Captain set", "good"); sel = -1
			"remove":
				set_u(i, "")
				if sq.captain == u: sq.captain = ""
				Save.dirty(); sel = -1
			"cancel": sel = -1
		draw(i)
	func draw(focus_i: int) -> void:
		for c in holder.get_children(): c.queue_free()
		var info = Sys.squad_info(sq)
		var cap_idx: int = sq.slots.find(sq.captain) if sq.captain != "" else -1
		var side = UI.vb(12); side.custom_minimum_size.x = 300
		var chem_col = UI.GREEN if info.chem.total >= 24 else (UI.YELLOW if info.chem.total >= 12 else UI.RED)
		side.add_child(UI.hb(10, [UI.panel(UI.vb(0, [UI.head(str(info.rating), 30), UI.caps("Squad rating", 10)]), "Glass"), UI.panel(UI.vb(0, [UI.head(str(info.chem.total), 30, chem_col), UI.caps("Chemistry /33", 10)]), "Glass")]))
		side.add_child(UI.field("Squad", UI.option(range(Save.data.squads.size()).map(func(k): return [k, Save.data.squads[k].name]), int(Save.data.active_squad), func(v): Save.data.active_squad = v; Save.dirty(); UI.replace("squad"))))
		side.add_child(UI.field("Formation", UI.option(Data.formation_names.map(func(x): return [x, x]), sq.formation, func(v): sq.formation = v; Save.dirty(); draw(-1))))
		side.add_child(UI.hb(8, [UI.btn("Auto-build best XI", func(): Sys.auto_build(sq); Sfx.play("reveal"); UI.toast("Best XI auto-built", "good"); draw(-1), "Small"),
			UI.btn("Rename", func(): await UI.modules[1].rename_squad(sq); UI.replace("squad"), "Small"),
			UI.btn("New", func(): Sys.squad_create("Squad %d" % (Save.data.squads.size() + 1)); Save.data.active_squad = Save.data.squads.size() - 1; UI.replace("squad"), "Small")]))
		side.add_child(UI.panel(UI.vb(6, [UI.caps("Chemistry links", 11), UI.label("■ Green: same club, or nation + league", 12, UI.GREEN), UI.label("■ Yellow: same nation or league", 12, UI.YELLOW), UI.label("■ Red: no link", 12, UI.RED),
			UI.wrapl(UI.label("Each player earns 0–3 chem from teammates sharing his club, nation and league. Out-of-position players get 0.", 12, UI.DIM), 260)]), "Glass"))
		selbox = UI.vb(8)
		if sel >= 0:
			var u = get_u(sel); var pl: Dictionary = Sys.item_player(u) if u != "" else {}
			var pos: String = Data.formations[sq.formation][sel][0] if sel < 11 else "SUB"
			selbox.add_child(UI.caps("Selected: " + pos, 11))
			selbox.add_child(UI.bold(("%s (%d)" % [pl.name, pl.ovr]) if not pl.is_empty() else "Empty slot", 14))
			var acts = HFlowContainer.new(); acts.add_theme_constant_override("h_separation", 6); acts.add_theme_constant_override("v_separation", 6)
			acts.add_child(UI.btn("Replace" if not pl.is_empty() else "Add player", func(): act("replace"), "Small", true))
			if not pl.is_empty():
				acts.add_child(UI.btn("Swap with…", func(): act("move"), "Small"))
				acts.add_child(UI.btn("View", func(): act("view"), "Small"))
				if sel < 11: acts.add_child(UI.btn("Make captain", func(): act("cap"), "Small"))
				acts.add_child(UI.btn("Remove", func(): act("remove"), "Small"))
			acts.add_child(UI.btn("Cancel", func(): act("cancel"), "Small"))
			selbox.add_child(acts)
		else: selbox.add_child(UI.wrapl(UI.label("Select a player on the pitch or bench. Drag cards to swap.", 13, UI.DIM), 260))
		side.add_child(UI.panel(selbox, "Glass"))
		holder.add_child(side)
		pitch = PitchView.new().setup(sq.formation, info.players, info.chem, cap_idx, sel if sel < 11 else -1)
		pitch.slot_pressed.connect(click)
		pitch.slot_drop.connect(func(a, b): swap(a, b); sel = -1; draw(b))
		holder.add_child(pitch)
		var bench = UI.vb(10, [UI.caps("Substitutes")]); bench.custom_minimum_size.x = 250
		bench_grid = GridContainer.new(); bench_grid.columns = 3; bench_grid.add_theme_constant_override("h_separation", 8); bench_grid.add_theme_constant_override("v_separation", 10)
		for k in 7:
			var u: String = sq.subs[k]
			var c = PlayerCard.make(Sys.item_player(u) if u != "" else {}, 7.4, true); c.empty_pos = "SUB"
			c.drag_id = 11 + k; c.drop_cb = func(a, b): swap(a, b); sel = -1; draw(b)
			c.pressed.connect(func(): Sfx.play("select"); click(11 + k))
			if sel == 11 + k: c.modulate = Color(1.25, 1.25, 1.25)
			bench_grid.add_child(c)
		bench.add_child(bench_grid)
		bench.add_child(UI.wrapl(UI.label("Changes save automatically.", 12, UI.DIM), 230))
		holder.add_child(bench)
		_refocus(focus_i)
	func _refocus(focus_i: int) -> void:
		await UI.get_tree().process_frame
		if not is_instance_valid(pitch) or not pitch.is_inside_tree(): return
		if sel >= 0: UI.focus_first(selbox)
		elif focus_i >= 0 and focus_i < 11 and focus_i < pitch.cards.size(): pitch.cards[focus_i].grab_focus()
		elif focus_i >= 11: bench_grid.get_child(focus_i - 11).grab_focus()

# ------------------------------------------------------------------ STORE
func s_store(p) -> Dictionary:
	var f = UI.hub_shell("store")
	var tab: String = p.get("tab", "mine" if (not Save.data.unopened.is_empty() or not Save.data.pending.is_empty()) else "packs")
	f.body.add_child(UI.hb(10, [page_title("Store"), UI.spacer(), UI.seg([["packs", "Packs"], ["promo", "Special Promos"], ["mine", "My Packs (%d)" % Save.data.unopened.size()], ["odds", "Pack Odds"]], tab, func(v): UI.replace("store", {"tab": v}))]))
	var content = UI.vb(14)
	var flow = HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 16); flow.add_theme_constant_override("v_separation", 16)
	var tile = func(id: String, owned := false, idx := -1) -> Control:
		var pk: Dictionary = Data.packs[id]
		var price = []
		if pk.coins: price.append("● " + Sys.fmt(pk.coins))
		if pk.points: price.append("◆ " + Sys.fmt(pk.points))
		var art = UI.icon("pack", id, Vector2(100, 140)); art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var t = UI.tile([art, UI.bold(pk.name, 16), UI.wrapl(UI.label(pk.desc, 12, UI.DIM), 180), UI.bold("Open now" if owned else "   ".join(price), 14, UI.GREEN if owned else UI.GOLD2)],
			func():
				if owned:
					Save.data.unopened.remove_at(idx); Save.dirty(); open_pack(id, false)
				else: buy_pack(id), Vector2(220, 300))
		return t
	if tab == "packs" or tab == "promo":
		if tab == "packs":
			var today = Sys.day_key()
			var claimed: bool = Save.data.daily_pts == today
			var b = UI.btn("Claimed today" if claimed else "Claim 100", func(): Save.data.daily_pts = today; Sys.add("points", 100, "Daily Prime Points"); UI.rerender(), "" if claimed else "Primary")
			b.disabled = claimed
			var info = UI.vb(2, [UI.bold("Daily Prime Points", 15), UI.label("Claim 100 free Prime Points every day. Prime Points are fictional credits — there are no real-money purchases in this game.", 13, UI.DIM)]); UI.grow(info, false, true)
			content.add_child(UI.panel(UI.hb(14, [info, b])))
		for id in Data.pack_order:
			if Data.packs[id].get("promo", false) == (tab == "promo"): flow.add_child(tile.call(id))
		content.add_child(flow)
	elif tab == "mine":
		if Save.data.get("pick_cur") != null:
			var pinfo = UI.vb(2, [UI.bold("Player Pick in progress", 15), UI.label("Finish choosing your player from %s." % Data.packs[Save.data.pick_cur.pack].name, 13, UI.DIM)]); UI.grow(pinfo, false, true)
			content.add_child(UI.panel(UI.hb(14, [pinfo, UI.btn("Continue pick", func(): UI.go("pick"), "Primary")])))
		if not Save.data.pending.is_empty():
			var info = UI.vb(2, [UI.bold("%d unassigned items" % Save.data.pending.size(), 15), UI.label("From your last pack — keep, send to the Transfer List or quick sell.", 13, UI.DIM)]); UI.grow(info, false, true)
			content.add_child(UI.panel(UI.hb(14, [info, UI.btn("View items", func(): UI.go("packresult"), "Primary")])))
		if Save.data.unopened.is_empty(): content.add_child(UI.label("No unopened packs. Earn them from objectives, SBCs and competitions, or buy them in the Store.", 15, UI.DIM))
		for i in Save.data.unopened.size(): flow.add_child(tile.call(Save.data.unopened[i], true, i))
		content.add_child(flow)
	else:
		content.add_child(UI.wrapl(UI.label("Every pack's contents are generated from these configurable odds (data/gamedata.json → packs). Guaranteed slots are filled first; remaining slots roll the per-slot odds.", 13, UI.DIM), 1100))
		var g = HFlowContainer.new(); g.add_theme_constant_override("h_separation", 14); g.add_theme_constant_override("v_separation", 14)
		for id in Data.pack_order:
			var pk: Dictionary = Data.packs[id]
			var t = GridContainer.new(); t.columns = 3; t.add_theme_constant_override("h_separation", 18)
			for hdr in ["Item", "Per slot", "≥1 in pack"]: t.add_child(UI.caps(hdr, 10))
			for o in Sys.pack_odds(id):
				t.add_child(UI.label(Data.tier_label[o.tier], 13)); t.add_child(UI.label("%.2f%%" % (o.per * 100) if o.per < 0.01 else "%.1f%%" % (o.per * 100), 13)); t.add_child(UI.label("%.2f%%" % (o.least * 100) if o.least < 0.01 else "%.1f%%" % (o.least * 100), 13))
			var gtxt = ", ".join(pk.guar.map(func(x): return "%d× %s" % [int(x[1]), Data.tier_label[x[0]]]))
			var pn = UI.panel(UI.vb(6, [UI.bold(pk.name, 15), UI.wrapl(UI.label("%d items · Guaranteed: %s" % [int(pk.items), gtxt], 12, UI.DIM), 300), t])); pn.custom_minimum_size.x = 340
			g.add_child(pn)
		content.add_child(g)
	f.body.add_child(UI.scroll(content))
	return _hub(f, "store")

func buy_pack(id: String) -> void:
	var pk: Dictionary = Data.packs[id]
	var btns = []
	if pk.coins: btns.append(["%s Coins" % Sys.fmt(pk.coins), "coins", "Primary"])
	if pk.points: btns.append(["%s Prime Points" % Sys.fmt(pk.points), "points", "" if pk.coins else "Primary"])
	btns.append(["Cancel", null, ""])
	var odds = Sys.pack_odds(id).slice(0, 4).map(func(o): return "%s %.1f%%" % [Data.tier_label[o.tier], o.per * 100])
	var body = UI.hb(20, [UI.icon("pack", id, Vector2(110, 154)), UI.vb(8, [UI.bold(pk.desc, 15), UI.wrapl(UI.label("Odds: " + " · ".join(odds) + " …", 13, UI.DIM), 360), UI.label("Balance: ● %s · ◆ %s" % [Sys.fmt(Save.data.coins), Sys.fmt(Save.data.points)], 13, UI.DIM)])])
	var cur = await UI.modal("Buy %s?" % pk.name, body, btns)
	if cur == null: return
	if not Save.data.pending.is_empty(): UI.toast("Assign your previous pack items first", "bad"); UI.go("packresult"); return
	if not Sys.spend(cur, pk.coins if cur == "coins" else pk.points, "Bought " + pk.name, "store"): return
	open_pack(id, true)

## cinematic pack opening: pack → light beams → walkout (nation, position, club, rating) → card
func open_pack(id: String, tradeable: bool) -> void:
	if Data.packs[id].has("pick"):
		UI.modules[3].start_pick(id); return
	if not Save.data.pending.is_empty(): Sys.apply_pending()
	var items = Sys.generate_pack(id)
	var untr: bool = (not tradeable) or Data.packs[id].get("reward", false)
	Save.data.pending = items.map(func(p): return {"pid": p.id, "untr": untr, "dest": "keep"})
	for p in items: Gallery.record(p.id, "pack", true)
	Save.data.stats.packs += 1; Sys.track("pack"); Sys.add_xp(50)
	Save.write_now()
	var best: Dictionary = items[0]
	var walkout: bool = best.ovr >= 84 or ["icon", "hero", "promo", "totw", "rising"].has(best.type)
	var lvl = 4 if best.type == "icon" else (3 if best.type in ["hero", "promo", "rising"] else (2 if best.ovr >= 86 or best.type == "totw" else (1 if best.ovr >= 80 else 0)))
	Sfx.music_off()
	var o = preload("res://scripts/ui/pack_fx.gd").new()
	o.setup(id, best, walkout, lvl)
	UI.overlay.add_child(o)
	var close = {"cb": Callable()}
	UI.modals.append({"node": o, "cancel": func(): o.skip()})
	o.finished.connect(func():
		for i in UI.modals.size():
			if UI.modals[i].node == o: UI.modals.remove_at(i); break
		o.queue_free(); Sfx.music_on(); UI.go("packresult", {"pack": id}), CONNECT_ONE_SHOT)

## New Items screen (FC-style): three bands — Send To Transfer List / Keep Items / Quick Sell Now.
## ▲/▼ on a card moves it between bands, ◀/▶ browses. Confirm applies everything at once.
func s_packresult(p) -> Dictionary:
	var pend: Array = Save.data.pending
	for x in pend: if not x.has("dest"): x.dest = "keep"
	var page = Control.new(); page.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mg = MarginContainer.new(); mg.set_anchors_preset(Control.PRESET_FULL_RECT)
	for kv in [["left", 70], ["right", 70], ["top", 24], ["bottom", 14]]: mg.add_theme_constant_override("margin_" + kv[0], kv[1])
	page.add_child(mg)
	var v = UI.vb(10); mg.add_child(v)
	var crumbs = UI.hb(12, [UI.label("Ultimate XI", 20, UI.DIM), UI.label("›", 20, UI.DIM), UI.label("Store", 20, UI.DIM), UI.label("›", 20, UI.DIM), UI.bold("New Items", 20), UI.spacer(), UI.currency_bar()])
	v.add_child(crumbs)
	var bands = {}
	var R = {"focus_band": "keep", "focus_i": 0}
	var banner = PanelContainer.new()
	var bsb = StyleBoxFlat.new(); bsb.bg_color = Color(0.1, 0.25, 0.55, 0.55); bsb.set_corner_radius_all(10); bsb.content_margin_left = 16; bsb.content_margin_right = 16; bsb.content_margin_top = 6; bsb.content_margin_bottom = 6
	banner.add_theme_stylebox_override("panel", bsb)
	banner.add_child(UI.bold("ⓘ  Untradeable items can't be added to the Transfer List.", 16, Color("#7fb8ff")))
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var flash = func():
		Sfx.play("error"); banner.modulate = Color(1.6, 1.2, 1.2)
		banner.create_tween().tween_property(banner, "modulate", Color.WHITE, 0.6)
	var band_style = func(active: bool) -> StyleBoxFlat:
		var sb = StyleBoxFlat.new(); sb.bg_color = Color(0.09, 0.12, 0.17, 0.92) if active else Color(0.1, 0.13, 0.19, 0.78)
		sb.set_corner_radius_all(6); sb.border_color = Color(1, 1, 1, 0.75) if active else Color(1, 1, 1, 0.0); sb.set_border_width_all(2 if active else 0)
		sb.content_margin_left = 26; sb.content_margin_right = 22; sb.content_margin_top = 10; sb.content_margin_bottom = 10
		return sb
	var stack_icon = func(col: Color) -> Control:
		var c = PanelContainer.new(); var sb = StyleBoxFlat.new(); sb.bg_color = col; sb.set_corner_radius_all(6); sb.corner_radius_bottom_left = 16; sb.corner_radius_bottom_right = 16
		c.add_theme_stylebox_override("panel", sb); c.custom_minimum_size = Vector2(54, 68); return c
	for key in ["tl", "keep", "qs"]:
		var pn = PanelContainer.new()
		var title = UI.head({"tl": "Send To Transfer List", "keep": "Keep Items", "qs": "Quick Sell Now"}[key], 40 if key == "keep" else 32)
		var big = UI.head("", 36 if key == "keep" else 30); var small = UI.label("", 17, UI.DIM)
		var right = UI.vb(0, [big, small]); right.alignment = BoxContainer.ALIGNMENT_CENTER
		for c in right.get_children(): c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var icon = stack_icon.call(Color("#e8c96a") if key != "qs" else Color(1, 1, 1, 0.12))
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", -24 if key == "keep" else -10)
		var sc = ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER; sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; sc.follow_focus = false
		sc.add_child(row)
		var col: VBoxContainer
		if key == "keep":
			sc.custom_minimum_size.y = 222
			col = UI.vb(6, [UI.hb(14, [title, UI.label("▲ ▼  Move     ◀ ▶  Browse", 16, UI.DIM), UI.spacer(), right, icon]), sc])
		else:
			# compact band: title · the cards waiting here · count — all on one line
			sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.custom_minimum_size.y = 96
			col = UI.vb(0, [UI.hb(18, [title, sc, right, icon])])
		pn.add_child(col)
		bands[key] = {"panel": pn, "row": row, "big": big, "small": small, "sc": sc}
		v.add_child(pn)
		if key == "keep": UI.grow(pn, true, true)
	v.add_child(banner)
	# footer hints
	var g = func(k_ps: String, k_xb: String, k_kb: String) -> String: return k_ps if Pad.style == "ps" else (k_xb if Pad.style == "xbox" else k_kb)
	var foot = UI.hb(22, [UI._key_hint(g.call("○", "B", "Esc"), "Back"), UI._key_hint(g.call("□", "X", "D"), "Compare Price"), UI._key_hint(g.call("△", "Y", "W"), "Move All to Quick Sell"),
		UI._key_hint(g.call("OPTIONS", "Start", "E"), "Confirm Items"), UI._key_hint(g.call("✕", "A", "Enter"), "Details")])
	v.add_child(foot)
	var finish = func():
		var r = Sys.apply_pending()
		var parts = []
		if r.keep: parts.append("%d kept" % r.keep)
		if r.tl: parts.append("%d to Transfer List" % r.tl)
		if r.qs: parts.append("%d quick sold (+%s)" % [r.qs, Sys.fmt(r.coins)])
		Sfx.play("coin"); UI.toast("Items confirmed · " + ", ".join(parts), "good")
		UI.reset("store", {"tab": "mine" if not Save.data.unopened.is_empty() else "packs"})
	var move = func(x: Dictionary, d: int) -> bool:
		var order = ["tl", "keep", "qs"]
		var i = order.find(x.dest) + d
		if i < 0 or i > 2: return false
		if order[i] == "tl":
			if x.untr: flash.call(); return false
			if Sys.M().tl.size() + pend.filter(func(y): return y.dest == "tl").size() >= Sys.TL_MAX: UI.toast("Transfer List is full (%d)" % Sys.TL_MAX, "bad"); return false
		x.dest = order[i]; Sfx.play("whoosh"); return true
	R.render = func():
		var counts = {"tl": 0, "keep": 0, "qs": 0}; var qs_coins = 0; var new_n = 0
		for x in pend:
			counts[x.dest] += 1
			if x.dest == "qs": qs_coins += Data.quick_sell_value(Data.P(x.pid))
			if x.dest == "keep" and not Sys.owns_pid(x.pid): new_n += 1
		bands.tl.big.text = "%d/%d Items" % [Sys.M().tl.size() + counts.tl, Sys.TL_MAX]; bands.tl.small.text = ""
		bands.keep.big.text = "%d Items" % counts.keep; bands.keep.small.text = "%d New Items" % new_n
		bands.qs.big.text = "%s Coins   %d Items" % [Sys.fmt(qs_coins), counts.qs]; bands.qs.small.text = ""
		banner.visible = pend.any(func(x): return x.untr)
		var focus_target = null
		for key in bands:
			var B: Dictionary = bands[key]
			for c in B.row.get_children(): B.row.remove_child(c); c.queue_free()
			var items: Array = pend.filter(func(x): return x.dest == key)
			if key != "keep": B.sc.custom_minimum_size.y = 96 if not items.is_empty() else 64
			B.panel.add_theme_stylebox_override("panel", band_style.call(key == R.focus_band))
			var i = 0
			for x in items:
				var pl = Data.P(x.pid)
				var c = UI.card(pl, 11.6 if key == "keep" else 5.2, false, func(): _item_details(x, R))
				c.untr = x.untr; c.brackets = true
				c.tag = "DUPLICATE" if Sys.owns_pid(pl.id) else "NEW"
				var idx = i; var bk = key
				c.focus_entered.connect(func():
					c.z_index = 10
					if R.focus_band != bk:
						R.focus_band = bk
						for kk in bands: bands[kk].panel.add_theme_stylebox_override("panel", band_style.call(kk == bk))
					R.focus_i = idx)
				c.focus_exited.connect(func(): c.z_index = 0)
				c.gui_input.connect(func(e: InputEvent):
					var d = 0
					if e.is_action_pressed("ui_up"): d = -1
					elif e.is_action_pressed("ui_down"): d = 1
					if d != 0:
						c.accept_event()
						if move.call(x, d): R.focus_i = idx; R.render.call()
					elif e.is_action_pressed("ui_left") and idx == 0: c.accept_event()
					elif e.is_action_pressed("ui_right") and idx == items.size() - 1: c.accept_event())
				B.row.add_child(c)
				if key == R.focus_band and i == min(R.focus_i, items.size() - 1): focus_target = c
				i += 1
		if focus_target == null:
			for key in ["keep", "tl", "qs"]:
				if bands[key].row.get_child_count() > 0:
					R.focus_band = key; R.focus_i = 0; focus_target = bands[key].row.get_child(0)
					for kk in bands: bands[kk].panel.add_theme_stylebox_override("panel", band_style.call(kk == key))
					break
		if focus_target: focus_target.call_deferred("grab_focus")
	R.render.call()
	var focused_item = func():
		var fo = UI.get_viewport().gui_get_focus_owner()
		if fo is PlayerCard:
			for x in pend: if x.pid == fo.p.id: return x
		return null
	UI.keyhook(page, {
		"k%d" % KEY_E: finish, "j%d" % JOY_BUTTON_START: finish,
		"k%d" % KEY_D: func(): var x = focused_item.call(); if x: UI.compare_price(Data.P(x.pid)),
		"j%d" % JOY_BUTTON_X: func(): var x = focused_item.call(); if x: UI.compare_price(Data.P(x.pid)),
		"k%d" % KEY_W: func(): _all_qs(pend, R), "j%d" % JOY_BUTTON_Y: func(): _all_qs(pend, R),
		"k%d" % KEY_Q: func(): var x = focused_item.call(); if x: _item_details(x, R)})
	return {"node": page, "bg": "hub", "back": func(): UI.toast("Items kept in My Packs — confirm them any time"); UI.replace("store", {"tab": "mine"})}

func _all_qs(pend: Array, R: Dictionary) -> void:
	var all_q = pend.all(func(x): return x.dest == "qs")
	for x in pend: x.dest = "keep" if all_q else "qs"
	Sfx.play("whoosh"); R.focus_band = "qs" if not all_q else "keep"; R.focus_i = 0; Save.dirty(); R.render.call()

func _item_details(x: Dictionary, R: Dictionary) -> void:
	var pl = Data.P(x.pid)
	var acts = []
	if x.dest != "keep": acts.append(["Keep (send to club)", "keep", "Primary" if x.dest != "keep" else ""])
	if x.dest != "tl" and not x.untr: acts.append(["Send to Transfer List", "tl", ""])
	if x.dest != "qs": acts.append(["Quick sell (%s)" % Sys.fmt(Data.quick_sell_value(pl)), "qs", "Danger"])
	acts.append(["Compare price", "cmp", ""])
	var best = best_owned(pl.pos)
	if not best.is_empty(): acts.append(["Compare with %d %s" % [best.ovr, Data.short_name(best.name)], "cmpo", ""])
	var v = await UI.inspect(pl, acts, {"untr": x.untr})
	match v:
		"keep", "tl", "qs": x.dest = v; R.focus_band = v; Save.dirty(); R.render.call()
		"cmp": await UI.compare_price(pl)
		"cmpo": await UI.compare(pl, best)
