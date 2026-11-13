extends RefCounted
## Ultimate XI: SBC, Transfers, Play hub, Squad Battles, Rivals, Champions, Draft,
## Friendlies, plus match launching and the full-time results screen.

func _hub(f: Dictionary, tab: String) -> Dictionary:
	return {"node": f.node, "bg": "hub", "tab": tab, "back": func(): UI.reset("main")}
func page_title(t: String) -> Label: return UI.head(t.to_upper(), 38)

# ------------------------------------------------------------------ SBC
func s_sbc(p) -> Dictionary:
	var f = UI.hub_shell("sbc")
	var cat: String = p.get("cat", "Foundations")
	f.body.add_child(UI.hb(10, [page_title("Squad Building Challenges"), UI.spacer(), UI.seg(["Foundations", "Upgrades", "Challenges", "Players"].map(func(c): return [c, c]), cat, func(v): UI.replace("sbc", {"cat": v}))]))
	var flow = HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 16); flow.add_theme_constant_override("v_separation", 16)
	for s in Data.sbcs.filter(func(x): return x.cat == cat):
		var n = Sys.sbc_count(s.id); var av = Sys.sbc_available(s)
		var art: Control
		if s.reward.has("player"): var c = UI.card(Data.P(s.reward.player), 8.0); c.focus_mode = Control.FOCUS_NONE; art = c
		else: art = UI.icon("pack", s.reward.pack, Vector2(90, 126))
		var cc = CenterContainer.new(); cc.add_child(art); cc.custom_minimum_size.y = 150
		var status: String = ("%d/%s" % [n, "∞" if int(s.repeat) >= 99 else str(s.repeat)]) if int(s.repeat) > 1 else ("NEW" if av else "DONE")
		var t = UI.tile([UI.hb(6, [UI.bold(s.name, 19), UI.spacer(), UI.pill(status if av else "DONE", UI.TEXT if av else UI.GREEN)]), UI.wrapl(UI.bold(s.desc, 13, UI.TEAL), 250), cc,
			UI.label("%d players · %d requirement%s" % [int(s.size), s.reqs.size(), "" if s.reqs.size() == 1 else "s"], 12, UI.DIM), UI.wrapl(UI.bold("Reward: " + Sys.reward_text(s.reward), 12, UI.TEAL), 250)],
			func():
				if not Sys.sbc_available(s): UI.toast("Already completed"); return
				UI.go("sbcbuild", {"id": s.id, "cat": cat}), Vector2(290, 380))
		if not av: t.modulate.a = 0.55
		flow.add_child(t)
	f.body.add_child(UI.scroll(flow))
	return _hub(f, "sbc")

func s_sbcbuild(p) -> Dictionary:
	var sbc: Dictionary = {}
	for s in Data.sbcs: if s.id == p.id: sbc = s
	var f = UI.sub_shell(sbc.name, "SBC · " + sbc.cat)
	var size = int(sbc.size)
	var st: Dictionary = Save.data.sbc.draft.get(sbc.id, {"formation": "4-3-3", "uids": []})
	st.uids = st.uids.filter(func(u): return u == "" or not Sys.item(u).is_empty())
	while st.uids.size() < size: st.uids.append("")
	Save.data.sbc.draft[sbc.id] = st
	var row = UI.hb(22); UI.grow(row); f.body.add_child(row)
	var E = SBCEditor.new(sbc, st, row, p.get("cat", sbc.cat))
	row.set_meta("editor", E)
	E.draw(-1)
	return {"node": f.node, "bg": "hub"}

class SBCEditor extends RefCounted:
	var sbc: Dictionary; var st: Dictionary; var row: HBoxContainer; var cat: String
	var cards = []
	func _init(s, state, r, c) -> void: sbc = s; st = state; row = r; cat = c
	func players() -> Array: return st.uids.map(func(u): return {} if u == "" else Sys.item_player(u))
	func draw(focus_i: int) -> void:
		for c in row.get_children(): c.queue_free()
		cards.clear()
		var ps = players(); var chk = Sys.sbc_check(sbc, ps, st.formation)
		var side = UI.vb(12); side.custom_minimum_size.x = 340
		var reqs = UI.vb(4, [UI.caps("Requirements", 11)])
		for r in chk.reqs: reqs.add_child(UI.hb(8, [UI.bold("✓" if r.ok else "✕", 14, UI.GREEN if r.ok else UI.RED), UI.wrapl(UI.label(r.label, 13), 280)]))
		side.add_child(UI.panel(reqs, "Glass"))
		side.add_child(UI.panel(UI.vb(4, [UI.caps("Reward", 11), UI.wrapl(UI.bold(Sys.reward_text(sbc.reward), 14, UI.TEAL), 300)]), "Glass"))
		if int(sbc.size) == 11: side.add_child(UI.field("Formation", UI.option(Data.formation_names.map(func(x): return [x, x]), st.formation, func(v): st.formation = v; Save.dirty(); draw(-1))))
		side.add_child(UI.hb(8, [UI.btn("Auto-fill", func(): autofill(); Save.dirty(); draw(-1), "Small"), UI.btn("Clear", func(): st.uids = st.uids.map(func(_u): return ""); Save.dirty(); draw(-1), "Small")]))
		var sub = UI.btn("Submit squad", submit, "Primary" if chk.ok else ""); sub.disabled = not chk.ok
		side.add_child(sub)
		side.add_child(UI.wrapl(UI.label("Submitted players are permanently removed from your club. Players listed on the market can't be used.", 12, UI.DIM), 320))
		row.add_child(side)
		if int(sbc.size) == 11:
			var pitch = PitchView.new().setup(st.formation, ps, chk.chem)
			pitch.slot_pressed.connect(func(i): slot(i))
			row.add_child(pitch); cards = pitch.cards
		else:
			var flow = HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 14); flow.add_theme_constant_override("v_separation", 14)
			flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for i in ps.size():
				var c = PlayerCard.make(ps[i], 10.0); c.empty_pos = "ANY"
				c.pressed.connect(func(): Sfx.play("select"); slot(i))
				flow.add_child(c); cards.append(c)
			row.add_child(flow)
		_refocus(focus_i)
	func _refocus(i: int) -> void:
		await UI.get_tree().process_frame
		if i >= 0 and i < cards.size() and is_instance_valid(cards[i]): cards[i].grab_focus()
	func slot(i: int) -> void:
		var used = {}; var used_pids = {}
		for u in st.uids: if u != "": used[u] = true; used_pids[Sys.item(u).pid] = true
		if st.uids[i] != "":
			var v = await UI.modal("Slot", UI.player_row(Sys.item_player(st.uids[i]), [], func(): pass), [["Replace", "r", "Primary"], ["Remove", "x", ""], ["Cancel", null, ""]])
			if v == "x": st.uids[i] = ""; Save.dirty(); draw(i); return
			if v != "r": return
		var pos: String = Data.formations[st.formation][i][0] if int(sbc.size) == 11 else ""
		var u = await UI.pick_player("Select player" + ((" · " + pos) if pos != "" else ""), pos, func(it): return not used.has(it.uid) and not used_pids.has(it.pid))
		if u != null: st.uids[i] = u; Save.dirty(); Sfx.play("select")
		draw(i)
	func autofill() -> void:
		var all_tier = null; var min_rat = 0; var same_lg = false
		for r in sbc.reqs:
			if r.t == "tierAll": all_tier = r.v
			if r.t == "rating": min_rat = int(r.v)
			if r.t == "sameLeague": same_lg = true
		var used = {}; var used_pids = {}
		for u in st.uids: if u != "": used[u] = true; used_pids[Sys.item(u).pid] = true
		var pool: Array = Save.data.club.filter(func(it): return not used.has(it.uid) and not Sys.in_market(it.uid) and not used_pids.has(it.pid)).map(func(it): return [it, Data.P(it.pid)])
		if all_tier != null: pool = pool.filter(func(x): return Data.tier_of(x[1].ovr) == all_tier and x[1].type == "base")
		if same_lg:
			var cnt = {}
			for x in pool: cnt[x[1].lg] = cnt.get(x[1].lg, 0) + 1
			var best = ""; var bn = 0
			for k in cnt: if cnt[k] > bn: bn = cnt[k]; best = k
			pool = pool.filter(func(x): return x[1].lg == best)
		pool.sort_custom(func(a, b): return (1 if Sys.in_any_squad(a[0].uid) else 0) * 100 + abs(a[1].ovr - min_rat) < (1 if Sys.in_any_squad(b[0].uid) else 0) * 100 + abs(b[1].ovr - min_rat))
		for i in st.uids.size():
			if st.uids[i] != "": continue
			var pos: String = Data.formations[st.formation][i][0] if int(sbc.size) == 11 else ""
			var k = -1
			for j in pool.size():
				if not used_pids.has(pool[j][1].id) and (pos == "" or Data.fits_pos(pool[j][1], pos)): k = j; break
			if k < 0:
				for j in pool.size():
					if not used_pids.has(pool[j][1].id) and (pos == "" or (pos == "GK") == (pool[j][1].pos == "GK")): k = j; break
			if k < 0: continue
			var x = pool[k]; pool.remove_at(k); used_pids[x[1].id] = true; st.uids[i] = x[0].uid
		Sfx.play("select")
	func submit() -> void:
		var vals = 0
		for p in players(): if not p.is_empty(): vals += Sys.value(p)
		if await UI.modal("Submit SBC?", "%d players (est. value %s coins) will be exchanged for: %s" % [int(sbc.size), Sys.fmt(vals), Sys.reward_text(sbc.reward)], [["Cancel", null, ""], ["Submit", true, "Primary"]]):
			if Sys.sbc_submit(sbc, st.uids, st.formation):
				Sfx.play("bigreveal"); Save.data.sbc.draft.erase(sbc.id)
				UI.toast("SBC complete! " + Sys.reward_text(sbc.reward), "good")
				UI.stack.clear(); UI.replace("sbc", {"cat": cat})

# ------------------------------------------------------------------ TRANSFERS
func s_transfers(p) -> Dictionary:
	var f = UI.hub_shell("transfers")
	var tab: String = p.get("tab", "search")
	var mine: Array = Save.data.market.mine
	var active = mine.filter(func(l): return l.status == "active").size()
	f.body.add_child(UI.hb(10, [page_title("Transfers"), UI.spacer(), UI.seg([["search", "Search Market"], ["list", "Transfer List (%d)" % active], ["bids", "Transfer Targets"], ["history", "History"]], tab, func(v): UI.replace("transfers", {"tab": v}))]))
	var body = UI.vb(10); UI.grow(body); f.body.add_child(body)
	match tab:
		"search": market_search(body, Save.data.market.get("last_filter", {}))
		"list": transfer_list(body)
		"bids": targets(body)
		_:
			var list = UI.vb(4)
			if Save.data.market.history.is_empty(): list.add_child(UI.label("No transfers yet", 14, UI.DIM))
			for x in Save.data.market.history:
				var pl = Data.P(x.pid)
				list.add_child(UI.hb(14, [UI.label(Time.get_datetime_string_from_unix_time(int(x.t)).replace("T", " "), 13, UI.DIM), UI.bold("Bought" if x.kind == "buy" else "Sold", 13, UI.TEXT if x.kind == "buy" else UI.GREEN), UI.label("%d %s" % [pl.ovr, pl.name], 14), UI.spacer(), UI.bold("● " + Sys.fmt(x.price), 14, UI.GOLD2)]))
			body.add_child(UI.scroll(list))
	return _hub(f, "transfers")

func market_search(body: VBoxContainer, f0: Dictionary) -> void:
	var st = {"name": f0.get("name", ""), "pos": f0.get("pos", ""), "lg": f0.get("lg", ""), "nat": f0.get("nat", ""), "club": f0.get("club", ""), "rar": f0.get("rar", ""), "min": f0.get("min", 0), "max": f0.get("max", 0), "max_bin": f0.get("max_bin", 0), "sort": f0.get("sort", "ends")}
	var res = UI.vb(6)
	var R = {}
	R.draw = func(list: Array):
		for c in res.get_children(): c.queue_free()
		if list.is_empty(): res.add_child(UI.label("No results. Try widening your filters.", 14, UI.DIM)); return
		var now = Sys.now()
		for l in list:
			var pl = Data.P(l.pid)
			var bid_txt: String = ("Bid %s%s" % [Sys.fmt(l.bid), " (you)" if l.bidder == "me" else ""]) if l.bid > 0 else "Start %s" % Sys.fmt(l.start)
			var right = [UI.label(Sys.fmt_time(l.ends - now), 12, UI.DIM), UI.label(bid_txt, 13), UI.bold("● " + Sys.fmt(l.bin), 15, UI.GOLD2)]
			right[0].custom_minimum_size.x = 70; right[1].custom_minimum_size.x = 140; right[2].custom_minimum_size.x = 110
			res.add_child(UI.player_row(pl, right, func(): await listing_actions(l); R.draw.call(Save.data.market.listings.filter(func(x): return x.ends > Sys.now()))))
	var search = func():
		var nf = st.duplicate(); Save.data.market.last_filter = nf
		R.draw.call(Sys.market_search(nf))
	var opts = func(arr: Array, first: String) -> Array: return [["", first]] + arr
	var nat_items = Data.nations.keys().map(func(k): return [k, Data.nations[k].name]); nat_items.sort_custom(func(a, b): return a[1] < b[1])
	var club_items = Data.clubs.keys().filter(func(k): return not Data.clubs[k].get("special", false)).map(func(k): return [k, Data.clubs[k].name]); club_items.sort_custom(func(a, b): return a[1] < b[1])
	var spin = func(key: String, mx: int, step: int) -> SpinBox:
		var s = SpinBox.new(); s.min_value = 0; s.max_value = mx; s.step = step; s.value = st[key]; s.custom_minimum_size.x = 96
		s.value_changed.connect(func(v): st[key] = int(v)); return s
	var row1 = HFlowContainer.new(); row1.add_theme_constant_override("h_separation", 8); row1.add_theme_constant_override("v_separation", 8)
	row1.add_child(UI.field("Name", UI.line(st.name, func(t): st.name = t, "", 150)))
	row1.add_child(UI.field("Position", UI.option(opts.call(Data.positions.map(func(x): return [x, x]), "Any"), st.pos, func(v): st.pos = v)))
	row1.add_child(UI.field("League", UI.option(opts.call(["ENG1", "ESP1", "ITA1", "GER1", "FRA1", "LEG"].map(func(k): return [k, Data.leagues[k].name]), "Any"), st.lg, func(v): st.lg = v)))
	row1.add_child(UI.field("Nation", UI.option(opts.call(nat_items, "Any"), st.nat, func(v): st.nat = v)))
	row1.add_child(UI.field("Club", UI.option(opts.call(club_items, "Any"), st.club, func(v): st.club = v)))
	row1.add_child(UI.field("Rarity", UI.option(opts.call([["bronze", "Bronze"], ["bronze-rare", "Rare Bronze"], ["silver", "Silver"], ["silver-rare", "Rare Silver"], ["gold", "Gold"], ["gold-rare", "Rare Gold"], ["rare", "Any rare"], ["special", "Special"]], "Any"), st.rar, func(v): st.rar = v)))
	row1.add_child(UI.field("Min OVR", spin.call("min", 99, 1))); row1.add_child(UI.field("Max OVR", spin.call("max", 99, 1))); row1.add_child(UI.field("Max BIN", spin.call("max_bin", 5000000, 500)))
	row1.add_child(UI.field("Sort", UI.option([["ends", "Time left"], ["bin-asc", "Price ↑"], ["bin-desc", "Price ↓"], ["ovr", "Rating"]], st.sort, func(v): st.sort = v)))
	var sb = UI.btn("Search", search, "Primary", true); row1.add_child(UI.field(" ", sb))
	body.add_child(row1)
	body.add_child(UI.scroll(res))
	var cached: Array = Save.data.market.listings.filter(func(x): return x.ends > Sys.now())
	if cached.is_empty(): search.call()
	else: R.draw.call(cached)

func listing_actions(l: Dictionary) -> void:
	var pl = Data.P(l.pid)
	var v = await UI.inspect(pl, [["Buy Now %s" % Sys.fmt(l.bin), "buy", "Primary"], ["Bid (min %s)" % Sys.fmt(Sys.min_bid(l)), "bid", ""]])
	if v == "buy":
		if await UI.modal("Confirm purchase", "Buy %s (%d) for %s coins?\nBalance after: %s" % [pl.name, pl.ovr, Sys.fmt(l.bin), Sys.fmt(Save.data.coins - l.bin)], [["Cancel", null, ""], ["Buy Now", true, "Primary"]]):
			if Sys.buy_now(l): Sfx.play("bigreveal"); UI.toast(pl.name + " added to your club!", "good")
	elif v == "bid": await bid_dialog(l)

func bid_dialog(l: Dictionary) -> void:
	var pl = Data.P(l.pid)
	var st = {"amt": Sys.min_bid(l)}
	var s = SpinBox.new(); s.min_value = Sys.min_bid(l); s.max_value = l.bin; s.step = 50; s.value = st.amt; s.custom_minimum_size.x = 200
	s.value_changed.connect(func(v): st.amt = int(v))
	var body = UI.vb(10, [UI.player_row(pl, [], func(): pass), UI.label("Current: %s · Buy Now %s · ends in %s" % [Sys.fmt(l.bid) if l.bid > 0 else "no bids", Sys.fmt(l.bin), Sys.fmt_time(l.ends - Sys.now())], 13, UI.DIM), UI.field("Your bid", s)])
	if await UI.modal("Place bid", body, [["Cancel", null, ""], ["Place bid", true, "Primary"]]):
		if Sys.place_bid(l, st.amt): UI.toast("Bid placed — check Transfer Targets", "good")

func transfer_list(body: VBoxContainer) -> void:
	var list = UI.vb(6)
	var R = {}
	R.draw = func():
		for c in list.get_children(): c.queue_free()
		var now = Sys.now()
		var mine: Array = Save.data.market.mine
		if mine.is_empty(): list.add_child(UI.label("No listings. List tradeable players from your Club or pack openings.", 14, UI.DIM))
		for l in mine:
			var pl = Data.P(l.pid)
			var status: String = ("Sold " + Sys.fmt(l.sold)) if l.status == "sold" else l.status
			var right = [UI.label("Start %s" % Sys.fmt(l.start), 12, UI.DIM), UI.label("BIN %s" % Sys.fmt(l.bin), 12, UI.DIM), UI.label("Bid %s" % (Sys.fmt(l.bid) if l.bid > 0 else "—"), 12), UI.label(Sys.fmt_time(l.ends - now) if l.status == "active" else "—", 12, UI.DIM), UI.bold(status, 13, UI.GREEN if l.status == "sold" else (UI.YELLOW if l.status == "expired" else UI.TEXT))]
			for r in right: r.custom_minimum_size.x = 90
			var acts = UI.hb(6)
			if l.status == "active" and l.bid == 0: acts.add_child(UI.btn("Remove", func(): if Sys.remove_listing(l.id): UI.toast("Returned to club"); R.draw.call(), "Small"))
			if l.status == "expired":
				acts.add_child(UI.btn("Relist", func(): Sys.remove_listing(l.id); await UI.modules[1].list_dialog(l.uid); R.draw.call(), "Small"))
				acts.add_child(UI.btn("To club", func(): Sys.remove_listing(l.id); R.draw.call(), "Small"))
			var r = UI.hb(10, [UI.label("%d %s · %s" % [pl.ovr, pl.name, pl.pos], 14)] + [UI.spacer()] + right + [acts])
			list.add_child(UI.panel(r, "Glass"))
	body.add_child(UI.hb(10, [UI.wrapl(UI.label("Your listings. AI managers buy and bid in real time while the game is open. 5% tax on every sale.", 13, UI.DIM), 700), UI.spacer(),
		UI.btn("+ List a player", func():
			var u = await UI.pick_player("List a player", "", null, false)
			if u != null and await UI.modules[1].list_dialog(u): R.draw.call(), "Primary"),
		UI.btn("Clear sold", func(): Save.data.market.mine = Save.data.market.mine.filter(func(l): return l.status != "sold"); Save.dirty(); R.draw.call(), "Small")]))
	body.add_child(UI.scroll(list))
	R.draw.call()
	var tick = Timer.new(); tick.wait_time = 2.0; tick.autostart = true; body.add_child(tick)
	tick.timeout.connect(func():
		var fo = UI.get_viewport().gui_get_focus_owner()
		if fo == null or not list.is_ancestor_of(fo): R.draw.call())

func targets(body: VBoxContainer) -> void:
	var list = UI.vb(6)
	var R = {}
	R.draw = func():
		for c in list.get_children(): c.queue_free()
		var now = Sys.now(); var bids: Array = Save.data.market.bids
		if bids.is_empty(): list.add_child(UI.label("No bids yet", 14, UI.DIM))
		for b in bids:
			var pl = Data.P(b.pid)
			var col = UI.GREEN if b.status in ["won", "winning"] else (UI.RED if b.status == "outbid" else UI.DIM)
			var row = UI.hb(12, [UI.label("%d %s · %s" % [pl.ovr, pl.name, pl.pos], 14), UI.spacer(), UI.label("Your bid %s" % Sys.fmt(b.amt), 13), UI.label("Current %s" % Sys.fmt(b.listing.bid), 13, UI.DIM),
				UI.label(Sys.fmt_time(b.listing.ends - now) if b.status in ["winning", "outbid"] else "—", 13, UI.DIM), UI.bold(b.status.to_upper(), 13, col)])
			if b.status == "outbid" and b.listing.ends > now: row.add_child(UI.btn("Bid again", func(): await bid_dialog(b.listing); R.draw.call(), "Small"))
			list.add_child(UI.panel(row, "Glass"))
	body.add_child(UI.label("Coins are held while you are the highest bidder and refunded if you're outbid.", 13, UI.DIM))
	body.add_child(UI.scroll(list))
	R.draw.call()
	var tick = Timer.new(); tick.wait_time = 1.0; tick.autostart = true; body.add_child(tick)
	tick.timeout.connect(func():
		var fo = UI.get_viewport().gui_get_focus_owner()
		if fo == null or not list.is_ancestor_of(fo): R.draw.call())

# ------------------------------------------------------------------ PLAY
func s_play(_p) -> Dictionary:
	var f = UI.hub_shell("play")
	var m: Dictionary = Save.data.modes; var rv: Dictionary = m.rivals
	if m.sb.week != Sys.week_key(): m.sb.week = Sys.week_key(); m.sb.points = 0; m.sb.played = 0
	var sb_rank = sb_rank_for(m.sb.points)
	var sq = Sys.active_squad(); var inf = Sys.squad_info(sq)
	f.body.add_child(UI.hb(10, [page_title("Play"), UI.spacer(), UI.label("Active squad: %s · %d OVR · %d chem%s" % [sq.name, inf.rating, inf.chem.total, "" if Sys.squad_complete(sq) else " · INCOMPLETE"], 14, UI.DIM if Sys.squad_complete(sq) else UI.RED)]))
	var g = GridContainer.new(); g.columns = 3; g.add_theme_constant_override("h_separation", 18); g.add_theme_constant_override("v_separation", 18); UI.grow(g)
	var center = func(nodes: Array) -> Control: var c = CenterContainer.new(); c.size_flags_vertical = Control.SIZE_EXPAND_FILL; c.add_child(UI.vb(4, nodes)); return c
	var rivals = UI.tile([UI.bold("Division Rivals", 30), UI.wrapl(UI.bold("Climb from Division 10 to Elite. Promotion at 10 points (Win 3 · Draw 1 · Loss -1).", 13, UI.TEAL), 380),
		center.call([UI.head("ELITE" if rv.div == 1 else str(rv.div), 64, UI.TEAL), UI.bold(Data.division(int(rv.div)).name, 16), UI.bar(rv.pts, 10), UI.label("%d/10 points · %d wins" % [rv.pts, rv.wins], 13, UI.DIM)])], func(): UI.go("rivals"), Vector2(0, 0), true)
	var champs: Dictionary = m.champs
	var tiles = [
		rivals,
		UI.tile([UI.bold("Squad Battles", 24), UI.wrapl(UI.bold("Play AI squads. Earn points by difficulty & performance.", 13, UI.TEAL), 300), center.call([UI.head(Sys.fmt(m.sb.points), 28), UI.label("pts this week · " + sb_rank.name, 13, UI.DIM)])], func(): UI.go("squadbattles")),
		UI.tile([UI.bold("Champions", 24), UI.wrapl(UI.bold("10-match elite tournament. Requires a ticket (Rivals).", 13, UI.TEAL), 300), center.call([UI.head(("%d-%d" % [champs.active.w, champs.active.l]) if champs.active else str(champs.tickets), 28), UI.label("%d/10 played" % champs.active.played if champs.active else "ticket(s)", 13, UI.DIM)])], func(): UI.go("champions")),
		UI.tile([UI.bold("Draft", 24), UI.wrapl(UI.bold("Build a temporary squad from random choices. Win 4 straight.", 13, UI.TEAL), 300), center.call([UI.bold("In progress · %d wins" % m.draft.active.wins if m.draft.active else "● %s or ◆ %d" % [Sys.fmt(Data.draft_cost.coins), Data.draft_cost.points], 15)])], func(): UI.go("draft")),
		UI.tile([UI.bold("Friendlies", 24), UI.wrapl(UI.bold("Casual matches with custom rules. No stakes.", 13, UI.TEAL), 300), center.call([UI.head("⚽", 40)])], func(): UI.go("friendlies"))]
	for t in tiles: UI.grow(t); g.add_child(t)
	g.add_child(Control.new())
	f.body.add_child(g)
	return _hub(f, "play")

func sb_rank_for(pts: int) -> Dictionary:
	for r in Data.sb_ranks: if pts >= r.pts: return r
	return Data.sb_ranks[-1]

func require_squad() -> bool:
	if not Sys.squad_complete(Sys.active_squad()):
		(func():
			if await UI.modal("Squad incomplete", "Your active squad needs 11 players before you can play. Use Auto-build in the Squad Builder.", [["Open Squad Builder", true, "Primary"], ["Cancel", null, ""]]): UI.go("squad")).call()
		return false
	return true

func choose_difficulty(name: String):
	var body = UI.vb(6)
	for k in Data.difficulty_order:
		var d: Dictionary = Data.difficulties[k]
		var b = UI.btn("%s      %d pts · %s coins" % [d.name, d.sbPts, Sys.fmt(d.coins)], func(): UI.close_top(k), "Row", k == "professional")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT; body.add_child(b)
	return await UI.modal("vs %s — choose difficulty" % name, body, [["Cancel", null, ""]])

# ------------------------------------------------------------------ SQUAD BATTLES
func s_squadbattles(_p) -> Dictionary:
	var f = UI.sub_shell("Squad Battles", "Play")
	var sb: Dictionary = Save.data.modes.sb
	if sb.opps.is_empty() or sb.opps_week != Sys.week_key():
		sb.opps_week = Sys.week_key()
		var names: Array = Sys.shuffled(Data.ai_squad_names).slice(0, 8)
		sb.opps = []
		for i in names.size(): sb.opps.append({"name": names[i], "str": 66 + i * 3 + Sys.rint(0, 2), "done": []})
		Save.dirty()
	var rank = sb_rank_for(sb.points)
	var row = UI.hb(20); UI.grow(row)
	var left = UI.vb(10, [UI.wrapl(UI.label("Choose an opponent and difficulty. Higher difficulty = more points; points also scale with goals and clean sheets.", 13, UI.DIM), 800)]); UI.grow(left)
	var flow = HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 14); flow.add_theme_constant_override("v_separation", 14)
	for i in sb.opps.size():
		var o: Dictionary = sb.opps[i]
		flow.add_child(UI.tile([UI.bold(o.name, 18), UI.bold("Squad rating ~%d" % o.str, 13, UI.TEAL), UI.label("Beaten on: " + (", ".join(o.done.map(func(d): return Data.difficulties[d].name)) if not o.done.is_empty() else "—"), 12, UI.DIM)],
			func(): sb_play(o), Vector2(240, 130), i == 0))
	left.add_child(UI.scroll(flow)); row.add_child(left)
	var right = UI.vb(14); right.custom_minimum_size.x = 340
	var week = UI.vb(6, [UI.caps("This week"), UI.head(Sys.fmt(sb.points), 34), UI.bold(rank.name, 16)])
	if rank.reward:
		week.add_child(UI.wrapl(UI.label("Current reward: " + Sys.reward_text(rank.reward), 13, UI.TEAL), 300))
		var cb = UI.btn("Claimed this week" if sb.claimed_week == Sys.week_key() else "Claim rank reward", func():
			if await UI.modal("Claim rank reward?", "Claiming locks in %s for this week: %s." % [rank.name, Sys.reward_text(rank.reward)], [["Cancel", null, ""], ["Claim", true, "Primary"]]):
				sb.claimed_week = Sys.week_key(); Sys.grant(rank.reward, "Squad Battles " + rank.name); UI.rerender(), "Primary")
		cb.disabled = sb.claimed_week == Sys.week_key(); week.add_child(cb)
	right.add_child(UI.panel(week))
	var lb = []
	var frac: float = clamp(fmod(Sys.now(), 604800.0) / 604800.0 + 0.15, 0.0, 1.0)
	for n in Data.ai_squad_names.slice(0, 9):
		lb.append({"n": "%sMgr%d" % [n.split(" ")[0], Gfx.hash_s(n + Sys.week_key()) % 900 + 100], "p": int((Gfx.hash_s(n + Sys.week_key()) % 3800) * frac), "me": false})
	lb.append({"n": Save.data.profile.name + " (you)", "p": sb.points, "me": true})
	lb.sort_custom(func(a, b): return a.p > b.p)
	var lbv = UI.vb(4, [UI.caps("Weekly leaderboard")])
	for i in lb.size(): lbv.add_child(UI.hb(8, [UI.label("%d" % (i + 1), 14, UI.DIM), UI.bold(lb[i].n, 14, UI.TEAL if lb[i].me else UI.TEXT), UI.spacer(), UI.bold(Sys.fmt(lb[i].p), 14)]))
	var lp = UI.panel(lbv); UI.grow(lp, true, false); right.add_child(lp)
	row.add_child(right)
	f.body.add_child(row)
	return {"node": f.node, "bg": "hub"}

func sb_play(o: Dictionary) -> void:
	if not require_squad(): return
	var d = await choose_difficulty(o.name)
	if d == null: return
	var D: Dictionary = Data.difficulties[d]
	var ut = Sys.user_team(); var opp = Sys.ai_team(o.name, round((o.str + D.ovr) / 2.0))
	Sys.league3_check(ut)
	run_match({"home": ut, "away": opp, "user_side": "home", "difficulty": d, "half_len": int(Save.data.settings.half_len), "mode": "sb", "title": "Squad Battles"}, func(res):
		var sb: Dictionary = Save.data.modes.sb
		var r = Sys.record_ut_match(res)
		var pts = int(round(D.sbPts * (1.0 if r == "W" else (0.5 if r == "D" else 0.2)) + res.hg * 10 + (20 if res.ag == 0 else 0)))
		sb.points += pts; sb.played += 1
		if r == "W":
			Sys.track("sb_win")
			if not o.done.has(d): o.done.append(d)
		var coins: int = D.coins * (2 if r == "W" else 1)
		Sys.add("coins", coins, "Squad Battles vs " + o.name)
		Sys.log_match(res, "Squad Battles", r)
		show_results(res, "Squad Battles", "+%d SB points · +%s coins" % [pts, Sys.fmt(coins)], func(): UI.replace("squadbattles")))

# ------------------------------------------------------------------ RIVALS
func s_rivals(_p) -> Dictionary:
	var f = UI.sub_shell("Division Rivals", "Play")
	var rv: Dictionary = Save.data.modes.rivals
	var div = int(rv.div)
	var dots = UI.hb(6)
	for i in 10:
		var c = ColorRect.new(); c.custom_minimum_size = Vector2(28, 10); c.color = UI.TEAL if i < rv.pts else Color(1, 1, 1, 0.12); dots.add_child(c)
	var main = UI.vb(14, [UI.head("ELITE" if div == 1 else str(div), 90, UI.TEAL), UI.head(Data.division(div).name.to_upper(), 24), dots,
		UI.label("%d/10 points to promotion · falling below 0 relegates" % rv.pts, 14, UI.DIM),
		UI.label("Opponent strength ~%d · Difficulty %s" % [int(Sys.rivals_strength(div)), Data.difficulties[Sys.rivals_difficulty(div)].name], 14, UI.DIM),
		UI.btn("Ⓐ  Find match", func(): rivals_play(), "Primary", true)])
	main.alignment = BoxContainer.ALIGNMENT_CENTER
	for c in main.get_children(): c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var mp = UI.panel(main); UI.grow(mp)
	var g = GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 18); g.add_theme_constant_override("v_separation", 6)
	for kv in [["Win", "%s coins · +3 pts" % Sys.fmt(900 + (11 - div) * 60)], ["Draw", "%s coins · +1 pt" % Sys.fmt(450 + (11 - div) * 60)], ["Loss", "%s coins · -1 pt" % Sys.fmt(200 + (11 - div) * 60)], ["Promotion", "Premium/Jumbo pack + 50 Prime Points"], ["Champions ticket", "Every 3 weekly wins in Div 5+"],
		["Played", str(rv.played)], ["Wins", str(rv.wins)], ["Best division", Data.division(int(rv.best)).name], ["Champions tickets", str(Save.data.modes.champs.tickets)]]:
		g.add_child(UI.label(kv[0], 14, UI.DIM)); g.add_child(UI.wrapl(UI.label(kv[1], 14), 220))
	var sp = UI.panel(UI.vb(10, [UI.caps("Rewards & record"), g])); sp.custom_minimum_size.x = 420
	f.body.add_child(UI.hb(24, [mp, sp]))
	f.body.get_child(-1).size_flags_vertical = Control.SIZE_EXPAND_FILL
	return {"node": f.node, "bg": "hub"}

func rivals_play() -> void:
	if not require_squad(): return
	var rv: Dictionary = Save.data.modes.rivals; var div = int(rv.div)
	var ut = Sys.user_team()
	var name: String = Sys.pick(["Ace", "Pro", "King", "Volt", "Nova", "Zed", "Kai", "Rex"]) + Sys.pick(["_FC", "Gaming", "99", "Utd", "XI", "_27"])
	var opp = Sys.ai_team(name, round(Sys.rivals_strength(div)))
	Sys.league3_check(ut)
	run_match({"home": ut, "away": opp, "user_side": "home", "difficulty": Sys.rivals_difficulty(div), "half_len": int(Save.data.settings.half_len), "mode": "rivals", "title": "Division Rivals"}, func(res):
		var r = Sys.record_ut_match(res); var out = Sys.rivals_record(r)
		Sys.log_match(res, "Rivals", r)
		show_results(res, "Division Rivals", "+%s coins%s" % [Sys.fmt(out.coins), (" · " + out.msg) if out.msg != "" else ""], func(): UI.replace("rivals")))

# ------------------------------------------------------------------ CHAMPIONS
func s_champions(_p) -> Dictionary:
	var f = UI.sub_shell("Champions", "Play")
	var c: Dictionary = Save.data.modes.champs; var a = c.active
	var main = UI.vb(14); main.alignment = BoxContainer.ALIGNMENT_CENTER
	if a:
		main.add_child(UI.caps("Champions · in progress")); main.add_child(UI.head("%d - %d" % [a.w, a.l], 90))
		var dots = UI.hb(6)
		for i in Sys.CHAMPS_MATCHES: var d = ColorRect.new(); d.custom_minimum_size = Vector2(22, 22); d.color = UI.TEAL if i < a.played else Color(1, 1, 1, 0.1); dots.add_child(d)
		main.add_child(dots)
		main.add_child(UI.label("Next reward tier: " + Sys.reward_text(Sys.champs_reward(a.w + 1)), 14, UI.DIM))
		if a.played < Sys.CHAMPS_MATCHES: main.add_child(UI.btn("Ⓐ  Play next match", champs_play, "Primary", true))
		else: main.add_child(UI.btn("Claim rewards", champs_finish, "Primary", true))
		main.add_child(UI.btn("Finish early & claim", func():
			if await UI.modal("Finish now?", "You'll receive the %d-win rewards." % a.w, [["Cancel", null, ""], ["Finish", true, "Primary"]]): champs_finish(), "Danger"))
	else:
		main.add_child(UI.icon("badge", {"shape": "crest", "c1": "#e8b631", "c2": "#14161c", "icon": "crown"}, Vector2(110, 110)))
		main.add_child(UI.head("CHAMPIONS", 30))
		main.add_child(UI.wrapl(UI.label("A 10-match tournament against elite opposition (~88 OVR, Legendary). Rewards scale with wins. Earn tickets in Division Rivals.", 14, UI.DIM), 460))
		main.add_child(UI.bold("Tickets: %d" % c.tickets, 16))
		var sb = UI.btn("Ⓐ  Use ticket & start", func():
			if c.tickets >= 1: c.tickets -= 1; c.active = {"w": 0, "l": 0, "played": 0}; Save.dirty(); UI.rerender(), "Primary", true)
		sb.disabled = c.tickets < 1
		main.add_child(UI.hb(10, [sb, UI.btn("Buy ticket (◆ 600)", func():
			if Sys.spend("points", 600, "Champions ticket"): c.tickets += 1; Save.dirty(); UI.rerender())]))
	for ch in main.get_children(): ch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var mp = UI.panel(main); UI.grow(mp)
	var tiers = UI.vb(6, [UI.caps("Reward tiers")])
	for w in [9, 7, 5, 3, 0]: tiers.add_child(UI.hb(10, [UI.bold("%d+ wins" % w, 14), UI.wrapl(UI.label(Sys.reward_text(Sys.champs_reward(w)), 13, UI.DIM), 260)]))
	tiers.add_child(UI.caps("History"))
	for x in c.history.slice(0, 8): tiers.add_child(UI.label("%s · %d-%d" % [Time.get_date_string_from_unix_time(int(x.t)), x.w, x.l], 13, UI.DIM))
	var tp = UI.panel(tiers); tp.custom_minimum_size.x = 400
	var row = UI.hb(24, [mp, tp]); UI.grow(row); f.body.add_child(row)
	return {"node": f.node, "bg": "hub"}

func champs_finish() -> void:
	var c: Dictionary = Save.data.modes.champs; var a = c.active
	if a == null: return
	var rw = Sys.champs_reward(a.w)
	Sys.grant(rw, "Champions: %d-%d" % [a.w, a.l]); c.history.push_front({"t": Sys.now(), "w": a.w, "l": a.l}); Sys.history("Champions finished %d-%d" % [a.w, a.l])
	c.active = null; Save.dirty(); Sfx.play("bigreveal")
	await UI.modal("Champions rewards", Sys.reward_text(rw)); UI.rerender()

func champs_play() -> void:
	if not require_squad(): return
	var c: Dictionary = Save.data.modes.champs; var a: Dictionary = c.active
	var ut = Sys.user_team(); var opp = Sys.ai_team("%s %s %d" % [Sys.pick(["Elite", "Prime", "Apex", "Legend"]), Sys.pick(["Gamer", "Squad", "FC", "XI"]), Sys.rint(1, 99)], Sys.rint(85, 90))
	Sys.league3_check(ut)
	run_match({"home": ut, "away": opp, "user_side": "home", "difficulty": "legendary", "half_len": int(Save.data.settings.half_len), "mode": "champs", "title": "Champions · Match %d" % (a.played + 1), "knockout": true}, func(res):
		var r0 = Sys.record_ut_match(res); var r = r0
		if r0 == "D": r = "W" if res.winner == "home" else "L"
		a.played += 1
		if r == "W": a.w += 1; Sys.track("champs_win")
		else: a.l += 1
		Sys.add("coins", 1500 if r == "W" else 400, "Champions match"); Sys.log_match(res, "Champions", r); Save.dirty()
		show_results(res, "Champions", "+1,500 coins" if r == "W" else "+400 coins", func(): UI.replace("champions")))

# ------------------------------------------------------------------ DRAFT
func s_draft(_p) -> Dictionary:
	var f = UI.sub_shell("Draft", "Play")
	var d: Dictionary = Save.data.modes.draft
	if d.active == null:
		var tiers = UI.vb(4)
		for w in 5: tiers.add_child(UI.hb(10, [UI.bold("%d wins" % w, 14), UI.label(Sys.reward_text(Sys.draft_reward(w)), 13, UI.DIM)]))
		var start = func(cur: String):
			if not Sys.spend(cur, Data.draft_cost[cur], "Draft entry"): return
			d.active = {"formation": "", "slots": ["", "", "", "", "", "", "", "", "", "", ""], "captain": "", "wins": 0, "stage": "formation", "opp": null}; Save.dirty(); UI.rerender()
		var v = UI.vb(14, [UI.head("START A DRAFT", 24), UI.wrapl(UI.label("Choose a formation, then pick a captain and one player for each position from five random choices — including Team of the Week, Nightfall, Heroes and Icons. Your draft squad is temporary. Win up to 4 knockout matches for rewards.", 14, UI.DIM), 620), tiers,
			UI.hb(10, [UI.btn("Enter (● %s)" % Sys.fmt(Data.draft_cost.coins), func(): start.call("coins"), "Primary", true), UI.btn("Enter (◆ %d)" % Data.draft_cost.points, func(): start.call("points"))])])
		var cc = CenterContainer.new(); UI.grow(cc); cc.add_child(UI.panel(v)); f.body.add_child(cc)
		return {"node": f.node, "bg": "hub"}
	var A: Dictionary = d.active
	if A.stage == "formation":
		f.body.add_child(UI.head("CHOOSE YOUR FORMATION", 28))
		var h = UI.hb(16)
		for fm in Sys.shuffled(Data.formation_names).slice(0, 5):
			h.add_child(UI.tile([UI.bold(fm, 22), UI.icon("minipitch", {"formation": fm, "players": []}, Vector2(180, 200))], func(): A.formation = fm; A.stage = "pick"; Save.dirty(); UI.rerender(), Vector2(220, 280)))
		f.body.add_child(h)
		return {"node": f.node, "bg": "hub"}
	var players: Array = A.slots.map(func(id): return {} if id == "" else Data.P(id))
	var chem = Sys.chemistry(A.formation, players)
	var cap_idx: int = A.slots.find(A.captain) if A.captain != "" else -1
	var row = UI.hb(22); UI.grow(row)
	var side = UI.vb(12); side.custom_minimum_size.x = 320
	side.add_child(UI.hb(10, [UI.panel(UI.vb(0, [UI.head(str(Sys.squad_rating(players)), 30), UI.caps("Rating", 10)]), "Glass"), UI.panel(UI.vb(0, [UI.head(str(chem.total), 30), UI.caps("Chem", 10)]), "Glass")]))
	var pitch = PitchView.new().setup(A.formation, players, chem, cap_idx)
	if A.stage == "pick":
		side.add_child(UI.wrapl(UI.label("Select each position on the pitch to pick from 5 players. " + ("" if A.captain != "" else "Start with your captain (any position)."), 14, UI.DIM), 300))
		if not A.slots.has(""): side.add_child(UI.btn("Start tournament", func(): A.stage = "play"; Save.dirty(); UI.rerender(), "Primary", true))
		side.add_child(UI.btn("Abandon draft", func():
			if await UI.modal("Abandon draft?", "Your entry fee is not refunded.", [["Cancel", null, ""], ["Abandon", true, "Danger"]]): d.active = null; Save.dirty(); UI.rerender(), "Danger"))
		pitch.slot_pressed.connect(func(i): draft_pick(A, i))
	else:
		if A.opp == null: A.opp = {"name": Sys.pick(Data.ai_squad_names), "str": 80 + A.wins * 2.5}
		side.add_child(UI.head(Sys.DRAFT_ROUNDS[A.wins].to_upper(), 24))
		side.add_child(UI.label("vs %s (~%d OVR)" % [A.opp.name, int(A.opp.str)], 14, UI.DIM))
		var prog = UI.hb(6)
		for i in 4: prog.add_child(UI.pill(["R16", "QF", "SF", "F"][i], UI.GREEN if i < A.wins else UI.TEXT))
		side.add_child(prog)
		side.add_child(UI.wrapl(UI.label("Current reward: " + Sys.reward_text(Sys.draft_reward(A.wins)), 13, UI.TEAL), 300))
		side.add_child(UI.btn("Ⓐ  Play " + Sys.DRAFT_ROUNDS[A.wins], func(): draft_play(A, players, chem), "Primary", true))
		side.add_child(UI.btn("Quit & claim rewards", func(): draft_end(A), "Small"))
	row.add_child(side); row.add_child(pitch)
	f.body.add_child(row)
	return {"node": f.node, "bg": "hub"}

func draft_pick(A: Dictionary, i: int) -> void:
	if A.slots[i] != "": UI.toast("Already picked"); return
	var pos: String = Data.formations[A.formation][i][0]
	var excl = {}
	for id in A.slots: if id != "": excl[id] = true
	var choices = Sys.draft_choices(pos, excl, A.captain == "")
	var h = UI.hb(12); h.alignment = BoxContainer.ALIGNMENT_CENTER
	for p in choices:
		var c = UI.card(p, 10.5, false, func(): UI.close_top(p.id))
		h.add_child(UI.vb(4, [c, UI.label(Data.rarity_name(p), 12, UI.DIM)]))
	var pick = await UI.modal(("Pick your captain · " if A.captain == "" else "Pick · ") + pos, h, [["Cancel", null, ""]], true)
	if pick != null:
		A.slots[i] = pick
		if A.captain == "": A.captain = pick
		Sfx.play("reveal"); Save.dirty(); UI.rerender()

func draft_end(A: Dictionary) -> void:
	var d: Dictionary = Save.data.modes.draft
	var rw = Sys.draft_reward(A.wins)
	Sys.grant(rw, "Draft: %d wins" % A.wins); d.history.push_front({"t": Sys.now(), "w": A.wins}); d.active = null; Save.dirty(); Sfx.play("bigreveal")
	await UI.modal("Draft over — %d win%s" % [A.wins, "" if A.wins == 1 else "s"], "Rewards: " + Sys.reward_text(rw))
	UI.replace("draft")

func draft_play(A: Dictionary, players: Array, chem: Dictionary) -> void:
	var pr: Dictionary = Save.data.profile
	var team = {"name": pr.club_name + " Draft", "short": "DRF", "kit": pr.kit.home, "formation": A.formation, "players": players, "subs": [], "badge": pr.badge, "chem": chem, "is_user": true}
	var o = Sys.ai_team(A.opp.name, round(A.opp.str))
	run_match({"home": team, "away": o, "user_side": "home", "difficulty": "worldclass" if A.wins >= 2 else "professional", "half_len": int(Save.data.settings.half_len), "mode": "draft", "title": "Draft · " + Sys.DRAFT_ROUNDS[A.wins], "knockout": true}, func(res):
		Sys.record_ut_match(res)
		var won: bool = res.winner == "home"
		Sys.log_match(res, "Draft", "W" if won else "L")
		if won: A.wins += 1; A.opp = null; Sys.track("draft_win")
		Save.dirty()
		show_results(res, "Draft", ("Draft champion!" if A.wins >= 4 else "Through to the next round") if won else "Eliminated", func():
			if not won or A.wins >= 4: draft_end(A)
			else: UI.replace("draft")))

# ------------------------------------------------------------------ FRIENDLIES
const RULES := {"classic": ["Classic Match", "Standard rules."], "golden": ["Golden Goal", "Draw after 90 minutes? Next goal wins."], "longshot": ["Long Shots", "Goals from outside the box count double."],
	"headers": ["Headers & Volleys", "Only goals from headers or volleys count."], "nofouls": ["No Rules", "No fouls, no cards. Anything goes."]}

func s_friendlies(_p) -> Dictionary:
	var f = UI.sub_shell("Friendlies", "Play")
	var st = {"str": 80, "diff": Save.data.settings.difficulty}
	var list = UI.vb(10); UI.grow(list)
	var first = true
	for k in RULES:
		var t = UI.tile([UI.hb(10, [UI.vb(2, [UI.bold(RULES[k][0], 20), UI.bold(RULES[k][1], 13, UI.TEAL)]), UI.spacer(), UI.pill("Play")])], func():
			if not require_squad(): return
			var ut = Sys.user_team(); var opp = Sys.ai_team(Sys.pick(Data.ai_squad_names), st.str)
			run_match({"home": ut, "away": opp, "user_side": "home", "difficulty": st.diff, "half_len": int(Save.data.settings.half_len), "mode": "friendly", "rules": k, "title": RULES[k][0]}, func(res):
				var r = Sys.record_ut_match(res); Sys.log_match(res, "Friendly", r)
				show_results(res, "Friendly · " + RULES[k][0], "", func(): UI.replace("friendlies"))), Vector2.ZERO, first)
		first = false
		list.add_child(t)
	var side = UI.vb(12, [UI.caps("Opponent"), UI.field("Opponent strength", UI.option([70, 75, 80, 84, 88].map(func(v): return [v, "~%d OVR" % v]), 80, func(v): st.str = v)),
		UI.field("Difficulty", UI.option(Data.difficulty_order.map(func(k): return [k, Data.difficulties[k].name]), st.diff, func(v): st.diff = v)),
		UI.wrapl(UI.label("Friendlies count toward objectives but give no coins.", 12, UI.DIM), 260)])
	var sp = UI.panel(side); sp.custom_minimum_size.x = 320
	var row = UI.hb(22, [list, sp]); UI.grow(row); f.body.add_child(row)
	return {"node": f.node, "bg": "hub"}

# ------------------------------------------------------------------ match glue & results
func kit_clash(a: String, b: String) -> bool:
	var x = Color(a); var y = Color(b)
	return Vector3(x.r - y.r, x.g - y.g, x.b - y.b).length() < 0.47

func run_match(cfg: Dictionary, on_done: Callable) -> void:
	if kit_clash(cfg.home.kit.c1, cfg.away.kit.c1):
		var k: Dictionary = cfg.away
		if k.get("is_user", false): k.kit = Save.data.profile.kit.away
		else:
			var alt = "#ffffff" if not kit_clash("#ffffff", cfg.home.kit.c1) else "#111111"
			k.kit = {"c1": k.kit.c2 if not kit_clash(k.kit.c2, cfg.home.kit.c1) else alt, "c2": k.kit.c1}
	var start = func(sim: bool):
		if sim: on_done.call(Sys.simulate_match(cfg))
		else:
			var scene = preload("res://scripts/match/match_scene.gd").new()
			scene.setup(cfg, on_done)
			UI.root.add_child(scene)
	if cfg.has("sim"): start.call(cfg.sim); return
	var badge_for = func(t: Dictionary) -> Control:
		if t.has("badge"): return UI.icon("badge", t.badge, Vector2(70, 70))
		if t.has("crest"): return UI.icon("crest", t.crest, Vector2(70, 70))
		return UI.icon("badge", {"shape": "round", "c1": t.kit.c2, "c2": t.kit.c1, "icon": "ball"}, Vector2(70, 70))
	var side = func(t: Dictionary) -> Control:
		var v = UI.vb(6, [badge_for.call(t), UI.bold(t.name, 16), UI.label("%d OVR" % Sys.squad_rating(t.players), 13, UI.DIM)])
		for c in v.get_children(): c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.custom_minimum_size.x = 200; return v
	var info = "%s · %d-minute halves%s" % [Data.difficulties.get(cfg.get("difficulty", "professional"), {"name": ""}).name, int(cfg.get("half_len", 3)), (" · " + RULES[cfg.rules][0]) if cfg.get("rules", "classic") != "classic" else ""]
	var body = UI.vb(10, [UI.hb(20, [side.call(cfg.home), UI.head("VS", 30), side.call(cfg.away)]), UI.label(info, 14, UI.DIM)])
	body.get_child(0).alignment = BoxContainer.ALIGNMENT_CENTER
	var v = await UI.modal(cfg.get("title", "Match"), body, [["Cancel", null, ""], ["Simulate", "sim", ""], ["Play Match", "play", "Primary"]])
	if v != null: start.call(v == "sim")

func show_results(res: Dictionary, title: String, rewards: String, on_continue: Callable) -> void:
	var f = UI.sub_shell("Full Time", title)
	var row = UI.hb(24); UI.grow(row)
	var main = UI.vb(14); main.alignment = BoxContainer.ALIGNMENT_BEGIN
	var hn = UI.bold(res.home.name, 20); hn.custom_minimum_size.x = 240; hn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var an = UI.bold(res.away.name, 20); an.custom_minimum_size.x = 240
	main.add_child(UI.hb(30, [hn, UI.head("%d - %d" % [res.hg, res.ag], 76), an]))
	if res.get("pens") != null: main.add_child(UI.bold("Penalties %d - %d" % [res.pens[0], res.pens[1]], 16))
	if res.get("simulated", false): main.add_child(UI.pill("Simulated"))
	var gl = UI.vb(4); gl.custom_minimum_size.x = 280; var gr = UI.vb(4); gr.custom_minimum_size.x = 280
	for g in res.goals:
		var txt = "⚽ %s %d'%s%s" % [Data.short_name(g.name), g.min, " (OG)" if g.get("og", false) else "", (" (" + Data.short_name(g.assist) + ")") if g.get("assist", "") != "" else ""]
		var l = UI.label(txt, 14)
		if g.side == "home": l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; gl.add_child(l)
		else: gr.add_child(l)
	main.add_child(UI.hb(40, [gl, gr]))
	if rewards != "": main.add_child(UI.pill(rewards, UI.GREEN))
	main.add_child(UI.btn("Ⓐ  Continue", on_continue, "Primary", true))
	for c in main.get_children(): c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var mp = UI.panel(main); UI.grow(mp); row.add_child(mp)
	var S: Dictionary = res.stats
	var sv = UI.vb(10, [UI.caps("Match stats")])
	for kv in [["Possession %", "poss"], ["Shots", "shots"], ["Shots on target", "sot"], ["Passes", "passes"], ["Tackles", "tackles"], ["Fouls", "fouls"], ["Corners", "corners"]]:
		var a: int = S[kv[1]][0]; var b: int = S[kv[1]][1]; var tot: float = max(1, a + b)
		var bar = HBoxContainer.new(); bar.add_theme_constant_override("separation", 0)
		var l1 = ColorRect.new(); l1.color = UI.TEAL; l1.custom_minimum_size = Vector2(360.0 * a / tot, 6)
		var l2 = ColorRect.new(); l2.color = Color("#ff6a8a"); l2.custom_minimum_size = Vector2(360.0 * b / tot, 6)
		bar.add_child(l1); bar.add_child(l2)
		var lab = UI.caps(kv[0], 11); lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; UI.grow(lab, false, true)
		sv.add_child(UI.hb(8, [UI.bold(str(a), 15), lab, UI.bold(str(b), 15)])); sv.add_child(bar)
	var sp = UI.panel(sv); sp.custom_minimum_size.x = 420; row.add_child(sp)
	f.body.add_child(row)
	# show as a screen without pushing to the history stack
	if UI.cur and is_instance_valid(UI.cur): UI.cur.queue_free()
	UI.cur = f.node; UI.cur_name = "results"; UI.cur_tab = ""; UI.cur_back = on_continue
	UI.bg.set_mode("hub")
	f.node.set_anchors_preset(Control.PRESET_FULL_RECT)
	UI.host.add_child(f.node)
	Sfx.music_on()
	await UI.get_tree().process_frame
	UI.focus_first(f.node)
