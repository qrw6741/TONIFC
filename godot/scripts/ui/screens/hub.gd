extends RefCounted
## Ultimate XI hub: Home, Objectives, Club, Squad Builder, Store, pack opening.

func _hub(f: Dictionary, tab: String) -> Dictionary:
	return {"node": f.node, "bg": "hub", "tab": tab, "back": func(): UI.reset("main")}

func page_title(t: String) -> Label: return UI.head(t.to_upper(), 38)

# ------------------------------------------------------------------ HOME
func s_home(_p) -> Dictionary:
	if UI.mobile: return _home_mobile()
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
	var objs: Array = Data.objectives.filter(func(o): return Sys.obj_live(o) and not Sys.obj_claimed(o))
	objs.sort_custom(func(a, b): return (1 if Sys.obj_done(a) else 0) * 2 + float(Sys.obj_progress(a)) / a.target > (1 if Sys.obj_done(b) else 0) * 2 + float(Sys.obj_progress(b)) / b.target)
	var ob = [UI.caps("Active objectives")]
	for o in objs.slice(0, 3):
		ob.append(UI.hb(6, [UI.bold(o.title, 13), UI.spacer(), UI.bold("CLAIM" if Sys.obj_done(o) else "%d/%d" % [Sys.obj_progress(o), o.target], 13, UI.GREEN if Sys.obj_done(o) else UI.DIM)]))
		ob.append(UI.bar(Sys.obj_progress(o), o.target))
	var ot = UI.tile(ob, func(): UI.replace("objectives")); UI.grow(ot, true, false); left.add_child(ot)
	var rv: Dictionary = Save.data.modes.rivals; var sb: Dictionary = Save.data.modes.sb
	var g = GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 14)
	for kv in [["Division Rivals", "%s · rank %d/12" % [Rivals.div_name(int(rv.div)), int(rv.get("step", 0))]], ["Squad Battles", "%s pts" % Sys.fmt(sb.points if sb.week == Sys.week_key() else 0)], ["Champions", ("%d pts · %d/%d" % [int(Champs.run().pts), int(Champs.run().played), Champs.MATCHES]) if Champs.run() != null else ("Qualified" if Champs.qualified() else "%d/1,000 QP" % int(Champs.st().qp))]]:
		g.add_child(UI.label(kv[0], 13, UI.DIM)); g.add_child(UI.label(kv[1], 13))
	left.add_child(UI.tile([UI.caps("Competitions"), g], func(): UI.replace("play"), Vector2(0, 120)))
	var gcl = Gallery.set_ids().filter(func(id): return Gallery.claimable(id) or Gallery.upgrade_gain(id) > 0).size()
	left.add_child(UI.tile([UI.hb(8, [UI.bold("Gallery ✦", 18, Color("#ff6fd8")), UI.spacer(), UI.bold("Lv %d · ◈ %s" % [Gallery.level(), Sys.fmt(Gallery.tokens())], 13, Color("#9fe8ff"))]), UI.label(("%d sets to upgrade or grade" % gcl) if gcl else "Collect players from the top 6 clubs of each league", 12, UI.GREEN if gcl else UI.DIM)], func(): UI.go("gallery")))
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
	for p in Fright.fright.slice(0, 3): var c = UI.card(p, 7.6); pc.add_child(c)
	var pt = UI.tile([UI.bold("Fright Night  ·  Halloween", 24, Color("#ff8a1f")), UI.bold("New promo, TOTW 2, Halloween objectives & SBCs — Fright Night Pack in the Store", 13, Color("#c99bff")), CenterContainer.new()], func(): UI.replace("objectives", {"cat": "halloween"}))
	pt.get_child(0).get_child(0).get_child(2).add_child(pc); UI._ignore_mouse(pt.get_child(0)); UI.grow(pt, true, true); right.add_child(pt)
	var slv: int = Season.level(); var scl: int = Season.claim_count()
	right.add_child(UI.tile([UI.hb(10, [UI.vb(2, [UI.bold("Season Pass · Level %d" % slv, 20, Color("#ff8a5c")), UI.bold(("%d rewards to claim" % scl) if scl else "Season 2 · Fright Night — earn Phantom Pass cards", 13, UI.GREEN if scl else Color("#ff9a3c"))]), UI.spacer(), UI.card(Fright.phantom_finale[0], 3.6, true) if not Fright.phantom_finale.is_empty() else UI.spacer()]), UI.bar(Season.level_xp(), Season.XP_PER, "GoldBar")], func(): UI.replace("season")))
	var un: int = Save.data.unopened.size()
	right.add_child(UI.tile([UI.hb(10, [UI.vb(2, [UI.bold(("%d unopened" % un) if un else "Store", 22), UI.bold("Open your packs" if un else "Packs from 400 coins", 13, UI.TEAL)]), UI.spacer(), UI.icon("pack", Save.data.unopened[0] if un else "premium", Vector2(52, 74))])], func(): UI.replace("store", {"tab": "mine" if un else "packs"})))
	right.add_child(UI.panel(UI.vb(4, [UI.caps("Balance"), UI.hb(18, [UI.head("● " + Sys.fmt(Save.data.coins), 22, UI.GOLD2), UI.head("◆ " + Sys.fmt(Save.data.points), 22, UI.TEAL)]), UI.label("Prime Points are free in-game credits — no real money.", 12, UI.DIM)])))
	row.add_child(right)
	f.body.add_child(row)
	return _hub(f, "home")

# ------------------------------------------------------------------ OBJECTIVES
func s_objectives(p) -> Dictionary:
	var f = UI.hub_shell("objectives")
	var cat: String = p.get("cat", "quick")
	var cats = [["halloween", "Halloween"], ["quick", "⚡ Quick · 3 min"], ["daily", "Daily"], ["weekly", "Weekly"], ["season", "Season"], ["milestone", "Milestones"]]
	var labs = cats.map(func(c): return [c[0], c[1] + (" •" if Data.objectives.any(func(o): return o.cat == c[0] and Sys.obj_done(o) and not Sys.obj_claimed(o)) else "")])
	f.body.add_child(UI.hb(10, [page_title("Objectives"), UI.spacer(), UI.seg(labs, cat, func(v): UI.replace("objectives", {"cat": v}))]))
	var qlab = UI.bold("", 14, Color("#ffd23f"))
	if cat == "quick":
		var per = {"p": Sys.quick_period()}
		var upd = func():
			qlab.text = "⚡ New quick objectives in %s · rewards are given automatically when you complete them" % Sys.fmt_time(Sys.quick_left())
			if Sys.quick_period() != per.p and UI.modals.is_empty() and UI.cur_name == "objectives": per.p = Sys.quick_period(); UI.replace("objectives", {"cat": "quick"})
		upd.call()
		var tm = Timer.new(); tm.wait_time = 1.0; tm.autostart = true; f.node.add_child(tm); tm.timeout.connect(upd)
		f.body.add_child(qlab)
	var sub = {"quick": "4 objectives live right now — 2 quick actions and 2 match goals", "daily": "Resets in " + Sys.fmt_time(Sys.secs_to_reset("daily")), "weekly": "Resets in " + Sys.fmt_time(Sys.secs_to_reset("weekly")), "season": "Season 2 · rewards Foundations players", "milestone": "Permanent milestones", "halloween": "Fright Night · Trick or Treat packs, a Fright Night pack and 87 Fright Night Doku"}[cat]
	f.body.add_child(UI.label(sub, 13, UI.DIM))
	var list = UI.vb(10)
	for o in Data.objectives.filter(func(x): return x.cat == cat and Sys.obj_live(x)):
		var pr = Sys.obj_progress(o); var done = Sys.obj_done(o); var cl = Sys.obj_claimed(o)
		var right: Control
		if cl: right = UI.pill("Completed ✓" if cat == "quick" else "Claimed", UI.GREEN)
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
	var p = Sys.item_player(u)
	var acts = []
	acts.append(["Apply Chemistry Style", "style", "Primary"])
	if Data.P(it.pid).pos != "GK": acts.append(["Change Position", "pos", ""])
	if not Sys.in_market(u) and not it.untr: acts.append(["List on Transfer Market", "list", ""])
	if not Sys.in_market(u): acts.append(["Quick sell (%s)" % Sys.fmt(Data.quick_sell_value(p)), "qs", "Danger"])
	var best = best_owned(p.pos, u)
	if not best.is_empty(): acts.append(["Compare", "cmp", ""])
	var v = await UI.inspect(p, acts, it)
	if v == "qs":
		if Sys.in_any_squad(u) and not await UI.modal("Player is in a squad", "Quick selling removes him from your squads. Continue?", [["Cancel", null, ""], ["Quick sell", true, "Danger"]]): return
		Sys.club_remove(u); Sys.add("coins", Data.quick_sell_value(p), "Quick sold " + p.name, "quicksell"); Sys.track("quicksell"); UI.toast("Quick sold " + p.name, "good")
	elif v == "list": await list_dialog(u)
	elif v == "cmp": await UI.compare(p, best)
	elif v == "style": await style_dialog(u)
	elif v == "pos": await pos_dialog(u)
	after.call()

## Chemistry Style picker: every style with its boosts, how many you own, or the coin price
func style_dialog(u: String) -> void:
	var p: Dictionary = Sys.item_player(u)
	var gk: bool = p.pos == "GK"
	var g = GridContainer.new(); g.columns = 3; g.add_theme_constant_override("h_separation", 10); g.add_theme_constant_override("v_separation", 10)
	var first = true
	for sname in Cons.styles_for(p):
		var cur: bool = p.get("style", "") == sname
		var own: int = Cons.owned(sname)
		var cost = ("✓ Applied" if cur else ("Owned x%d" % own if own > 0 else "● %s coins" % Sys.fmt(Cons.price(sname))))
		var t = UI.tile([UI.bold(sname.to_upper(), 17, Color("#7fd4ff") if not cur else UI.GREEN), UI.label(Cons.boost_text(sname, gk), 13, UI.DIM), UI.caps(cost, 11, UI.GREEN if own > 0 or cur else UI.GOLD2)],
			func(): UI.close_top(sname), Vector2(250, 92), first)
		first = false
		g.add_child(t)
	var body = UI.vb(8, [UI.label("%s · %s%s" % [p.name, p.pos, ("  ·  current style: " + p.style) if p.has("style") else ""], 14, UI.DIM),
		UI.wrapl(UI.label("Boosts apply in your squad: 1 chem = ⅓, 2 chem = ⅔, 3 chem = full boost. Owned cards are used first, otherwise you pay coins.", 13, UI.DIM), 780), g])
	var sc = UI.scroll(body); sc.custom_minimum_size = Vector2(800, 460)
	var r = await UI.modal("Apply Chemistry Style", sc, [["Cancel", null, ""]], true)
	if r == null: return
	if Cons.apply_style(u, str(r)): Sfx.play("reveal"); UI.toast("%s applied to %s" % [r, p.name], "good")

## Position Change: any outfield position; going back to the original position is free
func pos_dialog(u: String) -> void:
	var p: Dictionary = Sys.item_player(u)
	var orig: String = p.get("orig_pos", p.pos)
	var row = HFlowContainer.new(); row.add_theme_constant_override("h_separation", 8); row.add_theme_constant_override("v_separation", 8); row.custom_minimum_size.x = 620
	var first = true
	for pos in Cons.OUTFIELD:
		if pos == p.pos: continue
		var b = UI.btn(pos + ("  (original · free)" if pos == orig else ""), func(): UI.close_top(pos), "Primary" if pos == orig else "", first)
		b.custom_minimum_size = Vector2(96, 44); first = false
		row.add_child(b)
	var payl = ("You own %d Position Change card%s." % [Cons.pos_owned(), "" if Cons.pos_owned() == 1 else "s"]) if Cons.pos_owned() > 0 else "No Position Change cards — costs %s coins." % Sys.fmt(Cons.POS_PRICE)
	var body = UI.vb(10, [UI.label("%s · currently %s%s" % [p.name, p.pos, ("  (original %s)" % orig) if orig != p.pos else ""], 15), UI.label(payl, 13, UI.DIM), row])
	var r = await UI.modal("Change Position", body, [["Cancel", null, ""]])
	if r == null: return
	if Cons.change_pos(u, str(r)): Sfx.play("reveal"); UI.toast("%s is now a %s" % [p.name, r], "good")

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
## FC-style squad screen: club/chemistry panel (left), angled pitch (centre), hovered player's stats (right),
## SUB + RES strip along the bottom. □ / X / F on a hovered card opens the player's details.
func s_squad(_p) -> Dictionary:
	var sq = Sys.active_squad()
	var f = UI.sub_shell("Squad", "Ultimate XI")
	var holder = UI.vb(10); UI.grow(holder)
	f.body.add_child(holder)
	var S = SquadEditor.new(sq, holder)
	holder.set_meta("editor", S)   # keep the editor alive with the screen
	S.draw(-1)
	UI.keyhook(f.node, {"j2": func(): S.details(), "k%d" % KEY_F: func(): S.details(),
		"j3": func(): S.search(), "k%d" % KEY_T: func(): S.search(),
		"j6": func(): S.team_mgmt(), "k%d" % KEY_M: func(): S.team_mgmt()})
	return {"node": f.node, "bg": "hub"}

class Stars extends Control:
	var v = 4.0
	func _init() -> void: custom_minimum_size = Vector2(92, 16)
	func _draw() -> void:
		for i in 5:
			var c = Vector2(8 + i * 18, 8)
			var pts = PackedVector2Array()
			for k in 10:
				var a = -PI / 2 + k * PI / 5; var r = 7.5 if k % 2 == 0 else 3.2
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, Color(1, 1, 1, 0.22))
			var fill = clamp(v - i, 0.0, 1.0)
			if fill > 0:
				var clip = pts.duplicate()
				if fill < 1.0:
					var res = Geometry2D.intersect_polygons(pts, PackedVector2Array([c + Vector2(-9, -9), c + Vector2(-9 + 18 * fill, -9), c + Vector2(-9 + 18 * fill, 9), c + Vector2(-9, 9)]))
					clip = res[0] if not res.is_empty() else PackedVector2Array()
				if clip.size() >= 3: draw_colored_polygon(clip, Color("#e8c25a"))

class ChemPips extends Control:
	var n = 0
	func _init() -> void: custom_minimum_size = Vector2(40, 14); size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		for i in 3:
			var c = Vector2(6 + i * 13, 7)
			var pts = PackedVector2Array([c + Vector2(0, -6), c + Vector2(5, 0), c + Vector2(0, 6), c + Vector2(-5, 0)])
			draw_colored_polygon(pts, Color("#3fb6e0") if i < n else Color(1, 1, 1, 0.18))

class SquadEditor extends RefCounted:
	var sq: Dictionary
	var holder: VBoxContainer
	var sel = -1
	var moving = -1
	var pitch: PitchView
	var bench_row: HBoxContainer
	var selbox: VBoxContainer
	var detail: VBoxContainer
	var hov = {"u": "", "i": -1}
	func _init(s: Dictionary, h: VBoxContainer) -> void: sq = s; holder = h
	func get_u(i: int) -> String: return sq.slots[i] if i < 11 else sq.subs[i - 11]
	func set_u(i: int, u: String) -> void:
		if i < 11: sq.slots[i] = u
		else: sq.subs[i - 11] = u
	func swap(a: int, b: int) -> void:
		var ua = get_u(a); var ub = get_u(b)
		set_u(a, ub); set_u(b, ua); Save.dirty(); Sfx.play("select")
	func in_squad_pid(pid: String) -> int:
		for k in 18:
			var u = get_u(k)
			if u != "" and Sys.item(u).get("pid", "") == pid: return k
		return -1
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
	func reserve_pressed(u: String) -> void:
		var target = sel if sel >= 0 else moving
		if target < 0:
			UI.toast("Select a squad slot first, then pick a reserve to bring in"); return
		var pid: String = Sys.item(u).pid
		var dup = in_squad_pid(pid)
		if dup >= 0 and dup != target: UI.toast("That player is already in your squad", "bad"); return
		var old = get_u(target)
		set_u(target, u)
		if target < 11 and sq.captain == old: sq.captain = u
		Save.dirty(); Sfx.play("select"); sel = -1; moving = -1; draw(target)
	func details() -> void:
		if hov.u == "": UI.toast("Hover a player to see their details"); return
		Sfx.play("select")
		var keep = hov.i
		await UI.modules[1].item_actions(hov.u, func(): draw(keep))
	func search() -> void:
		if hov.i >= 0: pick(hov.i)
	func team_mgmt() -> void:
		var st = {"form": sq.formation, "sq": int(Save.data.active_squad)}
		var body = UI.vb(12, [
			UI.field("Squad", UI.option(range(Save.data.squads.size()).map(func(k): return [k, Save.data.squads[k].name]), st.sq, func(v): st.sq = v)),
			UI.field("Formation", UI.option(Data.formation_names.map(func(x): return [x, x]), sq.formation, func(v): st.form = v)),
			UI.wrapl(UI.label("Chemistry: each player earns 0–3 from teammates sharing his club, nation and league. Out-of-position players get 0.", 13, UI.DIM), 420)])
		var r = await UI.modal("Team Management", body, [["Done", "done", "Primary"], ["Auto-build best XI", "auto", ""], ["Rename", "rename", ""], ["New squad", "new", ""]])
		if st.sq != int(Save.data.active_squad):
			Save.data.active_squad = st.sq; Save.dirty(); UI.replace("squad"); return
		if st.form != sq.formation: sq.formation = st.form; Save.dirty()
		match r:
			"auto": Sys.auto_build(sq); Sfx.play("reveal"); UI.toast("Best XI auto-built", "good")
			"rename": await UI.modules[1].rename_squad(sq)
			"new":
				Sys.squad_create("Squad %d" % (Save.data.squads.size() + 1)); Save.data.active_squad = Save.data.squads.size() - 1; UI.replace("squad"); return
		draw(-1)
	func hover(u: String, i: int) -> void:
		hov.u = u; hov.i = i
		if not is_instance_valid(detail): return
		for c in detail.get_children(): detail.remove_child(c); c.queue_free()
		var pl: Dictionary = Sys.item_player(u) if u != "" else {}
		if pl.is_empty():
			var pos: String = (Data.formations[sq.formation][i][0] if i >= 0 and i < 11 else "SUB") if i >= 0 else ""
			detail.add_child(UI.bold("Empty slot", 22)); detail.add_child(UI.label(pos, 15, UI.DIM))
			detail.add_child(UI.wrapl(UI.label("Press %s to add a player." % Pad.glyph("A"), 13, UI.DIM), 200))
			return
		detail.add_child(UI.wrapl(UI.bold(Data.short_name(pl.name), 26), 210))
		detail.add_child(UI.label("%s · %s" % [Data.rarity_name(pl), pl.pos], 14, UI.DIM))
		if pl.has("style"): detail.add_child(UI.bold("◈ " + pl.style, 15, Color("#7fd4ff")))
		if pl.has("orig_pos"): detail.add_child(UI.label("Position changed from " + pl.orig_pos, 12, UI.TEAL))
		detail.add_child(Control.new())
		var lab: Array = Data.GK_LABELS if pl.pos == "GK" else Data.STAT_LABELS
		var g = GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 18); g.add_theme_constant_override("v_separation", 8)
		g.add_child(UI.bold(str(pl.ovr), 19)); g.add_child(UI.label("OVR", 16, UI.DIM))
		for k in 6:
			var v: int = int(pl.stats[k])
			g.add_child(UI.bold(str(v), 17, UI.GREEN if v >= 85 else (UI.TEXT if v >= 70 else Color("#ffb070"))))
			g.add_child(UI.label(lab[k], 15, UI.DIM))
		detail.add_child(g)
		detail.add_child(Control.new())
		detail.add_child(UI.label("%s  Details" % Pad.glyph("X") if Pad.style != "" else "[F]  Details", 13, UI.TEAL))
	func _hook(c: Control, u_fn: Callable, i: int) -> void:
		c.focus_entered.connect(func(): hover(u_fn.call(), i))
		c.mouse_entered.connect(func(): hover(u_fn.call(), i))
	# ------------------------------------------------------------ phone layout (companion)
	func draw_mobile() -> void:
		for c in holder.get_children(): c.queue_free()
		var info = Sys.squad_info(sq)
		var cap_idx: int = sq.slots.find(sq.captain) if sq.captain != "" else -1
		# header: name + stars, then Rating · Chemistry · Formation
		var stars: float = 5.0 if info.rating >= 85 else (4.5 if info.rating >= 82 else (4.0 if info.rating >= 79 else (3.5 if info.rating >= 76 else (3.0 if info.rating >= 72 else 2.5))))
		var stw = Stars.new(); stw.v = stars
		holder.add_child(UI.hb(10, [UI.icon("badge", Sys.D().profile.badge, Vector2(40, 44)), UI.vb(2, [UI.bold(sq.name, 19), stw]), UI.spacer(),
			UI.btn("⋯", func(): team_mgmt(), "Small")]))
		var chem_col = UI.GREEN if info.chem.total >= 24 else (UI.YELLOW if info.chem.total >= 12 else UI.RED)
		var stat = func(val: String, cap: String, col: Color, cb = null) -> Control:
			var pn = PanelContainer.new(); pn.add_theme_stylebox_override("panel", UI._sb(Color("#141c27"), Color(1, 1, 1, 0.08), 1, 12, Vector4(10, 6, 10, 6)))
			pn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var vv = UI.vb(0, [UI.head(val, 22, col), UI.caps(cap, 9, Color("#8a93a3"))])
			for c in vv.get_children(): c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pn.add_child(vv)
			if cb is Callable:
				var b = Button.new(); b.flat = true; b.set_anchors_preset(Control.PRESET_FULL_RECT); b.focus_mode = Control.FOCUS_NONE
				for st in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
				b.pressed.connect(cb); pn.add_child(b)
			return pn
		var sr = UI.hb(8, [stat.call(str(info.rating), "Rating", UI.TEXT), stat.call("%d/33" % info.chem.total, "Chemistry", chem_col), stat.call(sq.formation, "Formation ▾", UI.TEAL, func(): formation_sheet())])
		holder.add_child(sr)
		if moving >= 0:
			var mu = get_u(moving); var mp: Dictionary = Sys.item_player(mu) if mu != "" else {}
			var ban = PanelContainer.new(); ban.add_theme_stylebox_override("panel", UI._sb(Color(0.25, 0.88, 0.77, 0.15), UI.TEAL, 1, 10, Vector4(12, 8, 8, 8)))
			ban.add_child(UI.hb(8, [UI.wrapl(UI.bold("Tap a player, sub or reserve to swap with %s" % (Data.short_name(mp.name) if not mp.is_empty() else "this slot"), 13, UI.TEAL), 300), UI.spacer(), UI.btn("Cancel", func(): moving = -1; draw_mobile(), "Small")]))
			holder.add_child(ban)
		# pitch
		pitch = PitchView.new(); pitch.card_cs = 6.0
		pitch.setup(sq.formation, info.players, info.chem, cap_idx, moving if moving >= 0 and moving < 11 else -1)
		pitch.custom_minimum_size = Vector2(UI.root.size.x - 24, (UI.root.size.x - 24) * 1.18)
		pitch.slot_pressed.connect(func(i): tap(i))
		pitch.slot_drop.connect(func(a, b): swap(a, b); moving = -1; draw_mobile())
		holder.add_child(pitch)
		# substitutes & reserves: swipe strips
		holder.add_child(UI.caps("Substitutes", 11, Color("#8a93a3")))
		var subs = UI.hb(6)
		for k in 7:
			var u: String = sq.subs[k]
			var c = PlayerCard.make(Sys.item_player(u) if u != "" else {}, 6.0, true); c.empty_pos = "SUB"
			if moving == 11 + k: c.modulate = Color(1.3, 1.3, 1.3)
			c.pressed.connect(func(): Sfx.play("select"); tap(11 + k))
			subs.add_child(c)
		holder.add_child(_strip(subs))
		holder.add_child(UI.caps("Reserves", 11, Color("#8a93a3")))
		var res = UI.hb(6)
		for u in _reserve_uids(30):
			var c = PlayerCard.make(Sys.item_player(u), 6.0, true)
			c.pressed.connect(func(): Sfx.play("select"); reserve_tap(u))
			res.add_child(c)
		holder.add_child(_strip(res))
		holder.add_child(UI.hb(8, [UI.btn("Auto-build best XI", func(): Sys.auto_build(sq); Sfx.play("reveal"); UI.toast("Best XI auto-built", "good"); draw_mobile(), "Primary"), UI.btn("Team Management", func(): team_mgmt(), "")]))
	func _strip(row: Control) -> Control:
		var sc = ScrollContainer.new(); sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		sc.follow_focus = false; sc.custom_minimum_size.y = 6.0 * 12.0 + 8; sc.add_child(row); return sc
	func _reserve_uids(n: int) -> Array:
		var used = {}
		for k in 18:
			var u = get_u(k)
			if u != "": used[Sys.item(u).pid] = true
		var res = Sys.club_items().filter(func(it): return not used.has(it.pid) and not Data.P(it.pid).is_empty())
		res.sort_custom(func(a, b): return int(Data.P(a.pid).ovr) > int(Data.P(b.pid).ovr))
		var seen = {}; var out = []
		for it in res:
			if seen.has(it.pid): continue
			seen[it.pid] = true; out.append(it.uid)
			if out.size() >= n: break
		return out
	## tap on a pitch slot or sub: swap target while swapping, otherwise the player sheet
	func tap(i: int) -> void:
		if moving >= 0:
			if moving != i: swap(moving, i)
			moving = -1; draw_mobile(); return
		var u = get_u(i)
		if u == "": await pick(i); draw_mobile(); return
		var pl: Dictionary = Sys.item_player(u)
		var pos: String = Data.formations[sq.formation][i][0] if i < 11 else "SUB"
		var row = UI.hb(12, [UI.card(pl, 6.0, true), UI.vb(2, [UI.bold(pl.name, 17), UI.label("%s · %s · in %s" % [Data.rarity_name(pl), pl.pos, pos], 12, UI.DIM),
			UI.label(("◈ " + pl.style) if pl.has("style") else "No chemistry style", 12, Color("#7fd4ff") if pl.has("style") else UI.DIM)])])
		var acts = [["Swap", "swap", "Primary"], ["Replace from club", "replace", ""], ["Player details & items", "view", ""]]
		if i < 11 and sq.captain != u: acts.append(["Make captain", "cap", ""])
		acts.append(["Remove from squad", "remove", "Danger"])
		var v = await UI.sheet("", row, acts)
		match v:
			"swap": moving = i; draw_mobile()
			"replace": await pick(i); draw_mobile()
			"view": await UI.modules[1].item_actions(u, func(): pass); draw_mobile()
			"cap": sq.captain = u; Save.dirty(); UI.toast("Captain set", "good"); draw_mobile()
			"remove":
				set_u(i, "")
				if sq.captain == u: sq.captain = ""
				Save.dirty(); draw_mobile()
	func reserve_tap(u: String) -> void:
		if moving >= 0:
			sel = moving; reserve_pressed(u); moving = -1; sel = -1; draw_mobile(); return
		var pl: Dictionary = Sys.item_player(u)
		var v = await UI.sheet("", UI.hb(12, [UI.card(pl, 6.0, true), UI.vb(2, [UI.bold(pl.name, 17), UI.label("%s · %s · in your club" % [Data.rarity_name(pl), pl.pos], 12, UI.DIM)])]),
			[["Player details & items", "view", ""]])
		if v == "view": await UI.modules[1].item_actions(u, func(): pass); draw_mobile()
	func formation_sheet() -> void:
		var g = GridContainer.new(); g.columns = 3; g.add_theme_constant_override("h_separation", 8); g.add_theme_constant_override("v_separation", 8)
		for fm in Data.formation_names:
			var b = UI.btn(fm, func(): UI.close_top(fm), "Primary" if fm == sq.formation else "")
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; g.add_child(b)
		var v = await UI.sheet("Formation", g, [["Cancel", null, ""]])
		if v != null and v != sq.formation: sq.formation = v; Save.dirty(); Sfx.play("select"); draw_mobile()

	func draw(focus_i: int) -> void:
		if UI.mobile: draw_mobile(); return
		for c in holder.get_children(): c.queue_free()
		var info = Sys.squad_info(sq)
		var cap_idx: int = sq.slots.find(sq.captain) if sq.captain != "" else -1
		# ---------- left: club card, chemistry, actions
		var side = UI.vb(10); side.custom_minimum_size.x = 290
		var stars: float = 5.0 if info.rating >= 85 else (4.5 if info.rating >= 82 else (4.0 if info.rating >= 79 else (3.5 if info.rating >= 76 else (3.0 if info.rating >= 72 else 2.5))))
		var stw = Stars.new(); stw.v = stars
		side.add_child(UI.hb(12, [UI.icon("badge", Sys.D().profile.badge, Vector2(56, 62)), UI.vb(3, [UI.bold(sq.name, 22), stw, UI.hb(6, [UI.label("Rating", 15, UI.DIM), UI.bold(str(info.rating), 17)])])]))
		var tm = UI.btn("Team Management  (%s)" % (Pad.glyph("START") if Pad.style != "" else "M"), func(): team_mgmt(), "Small")
		side.add_child(tm)
		var chem_col = UI.GREEN if info.chem.total >= 24 else (UI.YELLOW if info.chem.total >= 12 else UI.RED)
		side.add_child(UI.hb(8, [UI.label("Total Chemistry", 15, UI.DIM), UI.spacer(), UI.bold("%d / 33" % info.chem.total, 17, chem_col)]))
		selbox = UI.vb(8)
		if sel >= 0 or moving >= 0:
			var si = sel if sel >= 0 else moving
			var u = get_u(si); var pl: Dictionary = Sys.item_player(u) if u != "" else {}
			var pos: String = Data.formations[sq.formation][si][0] if si < 11 else "SUB"
			selbox.add_child(UI.caps(("Swapping: " if moving >= 0 else "Selected: ") + pos, 11, UI.TEAL))
			selbox.add_child(UI.bold(("%s (%d)" % [pl.name, pl.ovr]) if not pl.is_empty() else "Empty slot", 14))
			var acts = HFlowContainer.new(); acts.add_theme_constant_override("h_separation", 6); acts.add_theme_constant_override("v_separation", 6)
			if moving >= 0:
				acts.add_child(UI.wrapl(UI.label("Pick a pitch, bench or reserve card to swap in.", 12, UI.DIM), 240))
				acts.add_child(UI.btn("Cancel", func(): moving = -1; draw(si), "Small", true))
			else:
				acts.add_child(UI.btn("Replace" if not pl.is_empty() else "Add player", func(): act("replace"), "Small", true))
				if not pl.is_empty():
					acts.add_child(UI.btn("Swap", func(): act("move"), "Small"))
					acts.add_child(UI.btn("Details", func(): act("view"), "Small"))
					if sel < 11: acts.add_child(UI.btn("Captain", func(): act("cap"), "Small"))
					acts.add_child(UI.btn("Remove", func(): act("remove"), "Small"))
				acts.add_child(UI.btn("Cancel", func(): act("cancel"), "Small"))
			selbox.add_child(acts)
			side.add_child(UI.panel(selbox, "Glass"))
		# chemistry sources (league / nation / club counts with 3-step pips like FC)
		var xi = info.players.filter(func(p): return not p.is_empty())
		var cnt = {"lg": {}, "nat": {}, "club": {}}
		for pl in xi:
			if pl.type != "icon": cnt.lg[pl.lg] = cnt.lg.get(pl.lg, 0) + (2 if pl.type == "hero" else 1)
			cnt.nat[pl.nat] = cnt.nat.get(pl.nat, 0) + (2 if pl.type == "icon" else 1)
			if pl.club != "ICN" and pl.club != "HER" and pl.club != "GAL": cnt.club[pl.club] = cnt.club.get(pl.club, 0) + 1
		var thr = {"lg": [3, 5, 8], "nat": [2, 5, 8], "club": [2, 5, 7]}
		var rows = []
		for kind in ["lg", "nat", "club"]:
			for k in cnt[kind]: rows.append([kind, k, int(cnt[kind][k])])
		rows.sort_custom(func(a, b): return a[2] > b[2])
		var list = UI.vb(6)
		for r in rows:
			var ic: Control
			var nm = ""
			if r[0] == "lg": ic = UI.icon("league", r[1], Vector2(22, 22)); nm = Data.leagues.get(r[1], {}).get("short", r[1])
			elif r[0] == "nat": ic = UI.icon("flag", r[1], Vector2(24, 16)); nm = Data.nations.get(r[1], {}).get("name", r[1])
			else: ic = UI.icon("crest", r[1], Vector2(22, 22)); nm = Data.clubs.get(r[1], {}).get("name", r[1])
			var hold = CenterContainer.new(); hold.custom_minimum_size = Vector2(28, 22); hold.add_child(ic)
			var pips = ChemPips.new(); var t: Array = thr[r[0]]
			pips.n = (1 if r[2] >= t[0] else 0) + (1 if r[2] >= t[1] else 0) + (1 if r[2] >= t[2] else 0)
			var nml = UI.label("%s" % nm, 13); nml.clip_text = true; nml.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nml.custom_minimum_size.x = 120
			list.add_child(UI.hb(8, [hold, nml, UI.label("%d" % r[2], 13, UI.DIM), pips]))
		var lsc = UI.scroll(list); UI.grow(lsc)
		if UI.mobile: lsc.custom_minimum_size.y = 190; lsc.set_meta("keep_scroll", true)
		var cp = UI.panel(UI.vb(6, [UI.caps("Chemistry", 11), lsc]), "Glass"); UI.grow(cp)
		side.add_child(cp)
		# ---------- centre: the pitch
		pitch = PitchView.new(); pitch.persp = true; pitch.card_cs = 6.0 if UI.mobile else 8.4
		pitch.setup(sq.formation, info.players, info.chem, cap_idx, sel if sel < 11 else -1)
		pitch.custom_minimum_size = Vector2(520, 480)
		pitch.slot_pressed.connect(click)
		pitch.slot_drop.connect(func(a, b): swap(a, b); sel = -1; draw(b))
		for i in pitch.cards.size():
			_hook(pitch.cards[i], func(): return get_u(i), i)
		# ---------- right: hovered player
		detail = UI.vb(6); detail.custom_minimum_size.x = 210
		var top = UI.hb(18, [pitch, detail, side] if UI.mobile else [side, pitch, detail]); UI.grow(top)
		holder.add_child(top)
		# ---------- bottom: SUB + RES strip
		bench_row = UI.hb(8)
		var tagl = func(t: String) -> Control:
			var l = UI.caps(t, 12, UI.DIM); l.custom_minimum_size = Vector2(34, 0); l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; return l
		bench_row.add_child(tagl.call("SUB"))
		var bench_cards = []
		for k in 7:
			var u: String = sq.subs[k]
			var c = PlayerCard.make(Sys.item_player(u) if u != "" else {}, 7.2, true); c.empty_pos = "SUB"
			c.drag_id = 11 + k; c.drop_cb = func(a, b): swap(a, b); sel = -1; draw(b)
			c.pressed.connect(func(): Sfx.play("select"); click(11 + k))
			if sel == 11 + k or moving == 11 + k: c.modulate = Color(1.3, 1.3, 1.3)
			_hook(c, func(): return get_u(11 + k), 11 + k)
			bench_row.add_child(c); bench_cards.append(c)
		var sep = ColorRect.new(); sep.color = Color(1, 1, 1, 0.18); sep.custom_minimum_size = Vector2(2, 70); sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bench_row.add_child(sep)
		bench_row.add_child(tagl.call("RES"))
		var used = {}
		for k in 18:
			var u = get_u(k)
			if u != "": used[Sys.item(u).pid] = true
		var res = Sys.club_items().filter(func(it): return not used.has(it.pid))
		var seen = {}
		var res_u = []
		res.sort_custom(func(a, b): return int(Data.P(a.pid).get("ovr", 0)) > int(Data.P(b.pid).get("ovr", 0)))
		for it in res:
			if seen.has(it.pid) or Data.P(it.pid).is_empty(): continue
			seen[it.pid] = true; res_u.append(it.uid)
			if res_u.size() >= 24: break
		for u in res_u:
			var c = PlayerCard.make(Sys.item_player(u), 7.2, true)
			c.pressed.connect(func(): reserve_pressed(u))
			_hook(c, func(): return u, -1)
			bench_row.add_child(c)
		var bsc = UI.scroll(bench_row, true); bsc.custom_minimum_size.y = 7.2 * 10.4 + 18
		var strip = PanelContainer.new()
		strip.add_theme_stylebox_override("panel", UI._sb(Color(0.03, 0.05, 0.08, 0.75), Color(1, 1, 1, 0.07), 1, 6, Vector4(10, 6, 10, 4)))
		strip.add_child(bsc)
		holder.add_child(strip)
		var g = func(k, kb): return Pad.glyph(k) if Pad.style != "" else kb
		holder.add_child(UI.label("%s Select / Swap     %s Details     %s Search     %s Team Management     Drag cards to swap" % [g.call("A", "[Enter]"), g.call("X", "[F]"), g.call("Y", "[T]"), g.call("START", "[M]")], 13, UI.DIM))
		var fu = get_u(focus_i) if focus_i >= 0 else (sq.slots[9] if sq.slots.size() > 9 else "")
		hover(fu, focus_i if focus_i >= 0 else 9)
		_refocus(focus_i, bench_cards)
	func act(a: String) -> void:
		var i = sel; var u = get_u(i)
		match a:
			"replace": pick(i); return
			"move": moving = i; sel = -1; UI.toast("Now select the card to swap with"); draw(i); return
			"view":
				sel = -1
				await UI.modules[1].item_actions(u, func(): draw(i))
				return
			"cap":
				sq.captain = u; Save.dirty(); UI.toast("Captain set", "good"); sel = -1
			"remove":
				set_u(i, "")
				if sq.captain == u: sq.captain = ""
				Save.dirty(); sel = -1
			"cancel": sel = -1
		draw(i)
	func _refocus(focus_i: int, bench_cards: Array) -> void:
		await UI.get_tree().process_frame
		if not is_instance_valid(pitch) or not pitch.is_inside_tree(): return
		if sel >= 0: UI.focus_first(selbox)
		elif focus_i >= 0 and focus_i < 11 and focus_i < pitch.cards.size(): pitch.cards[focus_i].grab_focus()
		elif focus_i >= 11 and focus_i - 11 < bench_cards.size(): bench_cards[focus_i - 11].grab_focus()
		elif focus_i < 0 and pitch.cards.size() > 9: pitch.cards[9].grab_focus()

# ------------------------------------------------------------------ STORE
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
	if UI.modules[11].promo_left(id) == 0: UI.toast("You've bought the maximum of this pack this week", "bad"); return
	if not Sys.spend(cur, pk.coins if cur == "coins" else pk.points, "Bought " + pk.name, "store"): return
	UI.modules[11].promo_bought(id)
	open_pack(id, true)

## cinematic pack opening: pack → light beams → walkout (nation, position, club, rating) → card
func open_pack(id: String, tradeable: bool, preset := []) -> void:
	if Data.packs[id].has("pick"):
		UI.modules[3].start_pick(id); return
	if not Save.data.pending.is_empty(): Sys.apply_pending()
	var items = preset if not preset.is_empty() else Sys.generate_pack(id)
	Save.data.pending = items.map(func(p): return {"pid": p.id, "untr": Sys.exclusive(p.id), "dest": "keep"})
	for p in items: Gallery.record(p.id, "pack", true)
	Save.data.stats.packs += 1; Sys.track("pack"); Sys.add_xp(50)
	Save.write_now()
	var best: Dictionary = items[0]
	# walkouts are rare: 87+ cards, or icons/heroes, or 85+ special promo cards
	var walkout: bool = best.ovr >= 87 or ["icon", "hero"].has(best.type) or (best.ovr >= 85 and ["promo", "totw", "rising", "pass", "potm", "fright", "phantom"].has(best.type))
	var lvl = 4 if best.type == "icon" else (3 if best.type in ["hero", "promo", "rising", "fright"] else (2 if best.ovr >= 86 or best.type == "totw" else (1 if best.ovr >= 80 else 0)))
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


# ------------------------------------------------------------------ MOBILE HOME (companion on a phone)
## rounded tile with a coloured accent bar, title, subtitle and an optional art piece on the right
func m_tile(title: String, sub: String, accent: Color, cb: Callable, art: Control = null, tall := false, badge := "") -> Control:
	var t = Button.new(); t.focus_mode = Control.FOCUS_ALL; t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size.y = 118 if tall else 86
	var n = StyleBoxFlat.new(); n.bg_color = Color("#141c27"); n.set_corner_radius_all(14); n.border_width_left = 4; n.border_color = accent
	var h = n.duplicate(); h.bg_color = Color("#1b2633")
	for st in ["normal", "focus"]: t.add_theme_stylebox_override(st, n)
	for st in ["hover", "pressed"]: t.add_theme_stylebox_override(st, h)
	var row = UI.hb(10); row.set_anchors_preset(Control.PRESET_FULL_RECT); row.offset_left = 18; row.offset_right = -12; row.offset_top = 10; row.offset_bottom = -10
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var txt = UI.vb(2, [UI.bold(title, 18), UI.label(sub, 12, Color("#9aa6b4"))]); txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL; txt.alignment = BoxContainer.ALIGNMENT_CENTER
	txt.get_child(1).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(txt)
	if badge != "":
		var bp = PanelContainer.new(); bp.add_theme_stylebox_override("panel", UI._sb(accent, Color(0, 0, 0, 0), 0, 10, Vector4(8, 2, 8, 2)))
		bp.add_child(UI.bold(badge, 12, Color("#0b1018"))); bp.size_flags_vertical = Control.SIZE_SHRINK_CENTER; row.add_child(bp)
	if art: art.size_flags_vertical = Control.SIZE_SHRINK_CENTER; row.add_child(art)
	for c in row.find_children("*", "Control", true, false): c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(row)
	t.pressed.connect(func(): Sfx.play("select"); cb.call())
	return t

func _home_mobile() -> Dictionary:
	var f = UI.hub_shell("home")
	var sq = Sys.active_squad(); var info = Sys.squad_info(sq)
	var b = f.body
	# squad hero card
	var mp = UI.icon("minipitch", {"formation": sq.formation, "players": info.players}, Vector2(96, 110))
	b.add_child(m_tile(sq.name, "Rating %d  ·  Chemistry %d/33  ·  %s\nTap to manage your squad" % [info.rating, info.chem.total, sq.formation], UI.TEAL, func(): UI.go("squad"), mp, true))
	# live event
	if Fright.THEME:
		var fc = HBoxContainer.new(); fc.add_theme_constant_override("separation", -14)
		for p in Fright.fright.slice(0, 2): var c = UI.card(p, 4.6, true); c.focus_mode = Control.FOCUS_NONE; fc.add_child(c)
		b.add_child(m_tile("Fright Night", "Halloween objectives, SBCs & the Fright Night Pack", Color("#ff7a1a"), func(): UI.replace("objectives", {"cat": "halloween"}), fc, true))
	# play (simulated)
	b.add_child(UI.caps("Play · matches are simulated", 11, Color("#8a93a3")))
	var rv = Sys.D().modes.rivals
	var play = UI.hb(8)
	for x in [["Rivals", "Div %d" % int(rv.div), Rivals.div_color(int(rv.div)), func(): UI.go("rivals")],
			["Champions", ("%d pts" % int(Champs.run().pts)) if Champs.run() != null else ("Qualified" if Champs.qualified() else "%d/1k QP" % int(Champs.st().qp)), Color("#e8b631"), func(): UI.go("champions")],
			["Battles", "Squad Battles", Color("#6fa8ff"), func(): UI.go("squadbattles")]]:
		var t = m_tile(x[0], x[1], x[2], x[3]); t.custom_minimum_size.y = 72; play.add_child(t)
	b.add_child(play)
	# everything else
	b.add_child(UI.caps("Ultimate Team", 11, Color("#8a93a3")))
	var oc: int = Sys.obj_claimable(); var sc: int = Season.claim_count(); var un: int = Save.data.unopened.size()
	var g = GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 8); g.add_theme_constant_override("v_separation", 8)
	for x in [["Objectives", "Daily, weekly & Halloween", Color("#3fe0a0"), func(): UI.reset("objectives"), str(oc) if oc else ""],
			["Season Pass", "Level %d / %d" % [Season.level(), Season.LEVELS], Color("#9b6bff"), func(): UI.reset("season"), str(sc) if sc else ""],
			["Store", ("%d packs to open" % un) if un else "Packs & Player Picks", Color("#ffd86b"), func(): UI.replace("store", {"tab": "mine" if un else "browse"}), str(un) if un else ""],
			["Transfer Market", "Buy, sell & watch", Color("#4fd1ff"), func(): UI.reset("transfers"), ""],
			["SBC", "Gem exchanges & players", Color("#5fe3c8"), func(): UI.reset("sbc"), ""],
			["Club", "%d players" % Save.data.club.size(), Color("#c8d0db"), func(): UI.reset("club"), ""],
			["Evolutions", "Upgrade your players", Color("#ff6fd8"), func(): UI.reset("evolutions"), ""],
			["Gallery", "Lv %d · ◈ %s" % [Gallery.level(), Sys.fmt(Gallery.tokens())], Color("#ff9be6"), func(): UI.go("gallery"), ""]]:
		g.add_child(m_tile(x[0], x[1], x[2], x[3], null, false, x[4]))
	b.add_child(g)
	b.add_child(m_tile("☁ " + (Cloud.username() if Cloud.signed_in() else "Cloud Account"), Cloud.status, UI.GREEN if Cloud.signed_in() else Color("#8a93a3"), func(): UI.go("cloud")))
	return {"node": f.node, "bg": "hub", "tab": "home", "back": func(): pass}

## "More" tab on phones
func s_more(_p) -> Dictionary:
	var f = UI.hub_shell("more")
	var b = f.body
	b.add_child(UI.head("MORE", 30))
	for x in [["Objectives", "Daily, weekly, season & Halloween", Color("#3fe0a0"), func(): UI.reset("objectives")],
			["Season Pass", Season.NAME, Color("#9b6bff"), func(): UI.reset("season")],
			["Play", "Rivals, Champions, Squad Battles, Draft", Color("#6fa8ff"), func(): UI.reset("play")],
			["Club", "Players, squads & duplicates", Color("#c8d0db"), func(): UI.reset("club")],
			["Evolutions", "Upgrade players", Color("#ff6fd8"), func(): UI.reset("evolutions")],
			["Gallery", "Sets, grades & Gallery cards", Color("#ff9be6"), func(): UI.go("gallery")],
			["☁ Cloud Account", Cloud.status, UI.GREEN, func(): UI.go("cloud")]]:
		b.add_child(m_tile(x[0], x[1], x[2], x[3]))
	return {"node": f.node, "bg": "hub", "tab": "more", "back": func(): UI.reset("home")}
