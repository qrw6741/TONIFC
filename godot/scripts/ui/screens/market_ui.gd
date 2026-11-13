extends RefCounted
## Transfer Market: overview hub, live search with card grid & price filters, price checker
## with 24h trend, watchlist & bids (Transfer Targets), Transfer List with available items.

const PER_PAGE := 18

class Spark extends Control:
	var data: Array = []
	var col = Color("#3fe0c5")
	func _draw() -> void:
		if data.size() < 2: return
		var mn = data.min(); var mx = data.max()
		var span = max(1.0, float(mx - mn))
		var pts = PackedVector2Array()
		for i in data.size():
			pts.append(Vector2(size.x * i / float(data.size() - 1), size.y - 6 - (float(data[i]) - mn) / span * (size.y - 12)))
		var fill = pts.duplicate(); fill.append(Vector2(size.x, size.y)); fill.append(Vector2(0, size.y))
		draw_colored_polygon(fill, Color(col, 0.12))
		draw_polyline(pts, col, 2.0, true)
		draw_circle(pts[-1], 4.0, col)

func page_title(t: String) -> Label: return UI.head(t.to_upper(), 38)
func pct_label(v: float, size := 13) -> Label:
	return UI.bold(("▲ +%.1f%%" % v) if v >= 0 else ("▼ %.1f%%" % v), size, UI.GREEN if v >= 0 else UI.RED)

## timer that refreshes the screen when the market changes (keeps controller focus) and ticks labels
func _live(body: Control, tab: String, tick: Callable = Callable()) -> void:
	var ver = {"v": Sys.market_ver}
	var t = Timer.new(); t.wait_time = 1.0; t.autostart = true; body.add_child(t)
	t.timeout.connect(func():
		if tick.is_valid(): tick.call()
		if Sys.market_ver != ver.v and UI.modals.is_empty() and UI.cur_name == "transfers":
			ver.v = Sys.market_ver; UI.replace("transfers", {"tab": tab}))

func s_transfers(p) -> Dictionary:
	var f = UI.hub_shell("transfers")
	var tab: String = p.get("tab", "hub")
	var M = Sys.M()
	var active = M.mine.filter(func(l): return l.status == "active").size()
	var bids_n = M.bids.filter(func(b): return b.status in ["winning", "outbid"]).size() + M.watch.size()
	f.body.add_child(UI.hb(10, [page_title("Transfers"), UI.spacer(), UI.seg([["hub", "Overview"], ["search", "Search Market"], ["list", "Transfer List (%d)" % (M.tl.size() + M.mine.size())], ["targets", "Transfer Targets (%d)" % bids_n], ["history", "History"]], tab, func(v): UI.replace("transfers", {"tab": v}))]))
	var body = UI.vb(10); UI.grow(body); f.body.add_child(body)
	match tab:
		"search": _search(body, p.get("filter", M.get("last_filter", {})), int(p.get("page", 0)))
		"list": _tlist(body)
		"targets": _targets(body)
		"history": _history(body)
		_: _overview(body)
	return {"node": f.node, "bg": "hub", "tab": "transfers", "back": func(): UI.reset("main")}

# ------------------------------------------------------------------ overview
func _overview(body: VBoxContainer) -> void:
	var M = Sys.M()
	var row = UI.hb(16)
	var mine: Array = M.mine
	var cnt = func(s: String) -> int: return mine.filter(func(l): return l.status == s).size()
	var bcnt = func(s: String) -> int: return M.bids.filter(func(b): return b.status == s).size()
	var t1 = UI.tile([UI.head("⌕", 54, UI.TEAL), UI.bold("Search the Transfer Market", 22), UI.label("%d live listings · prices move every hour" % M.pool.filter(func(l): return not l.get("gone", false)).size(), 13, UI.DIM)], func(): UI.replace("transfers", {"tab": "search"}), Vector2(380, 230), true)
	var g1 = GridContainer.new(); g1.columns = 2; g1.add_theme_constant_override("h_separation", 26)
	for kv in [["Available", M.tl.size()], ["Active", cnt.call("active")], ["Unsold", cnt.call("expired")], ["Sold", cnt.call("sold")]]:
		g1.add_child(UI.label(kv[0], 14, UI.DIM)); g1.add_child(UI.bold(str(kv[1]), 16, UI.GREEN if kv[0] == "Sold" and kv[1] > 0 else UI.TEXT))
	var t2 = UI.tile([UI.bold("Transfer List", 22), UI.label("%d / %d items" % [M.tl.size() + mine.size(), Sys.TL_MAX], 13, UI.DIM), g1], func(): UI.replace("transfers", {"tab": "list"}), Vector2(320, 230))
	var g2 = GridContainer.new(); g2.columns = 2; g2.add_theme_constant_override("h_separation", 26)
	for kv in [["Winning", bcnt.call("winning")], ["Outbid", bcnt.call("outbid")], ["Watched", M.watch.size()], ["Won", bcnt.call("won")]]:
		g2.add_child(UI.label(kv[0], 14, UI.DIM)); g2.add_child(UI.bold(str(kv[1]), 16, UI.RED if kv[0] == "Outbid" and kv[1] > 0 else UI.TEXT))
	var t3 = UI.tile([UI.bold("Transfer Targets", 22), UI.label("Bids & watchlist", 13, UI.DIM), g2], func(): UI.replace("transfers", {"tab": "targets"}), Vector2(320, 230))
	row.add_child(t1); row.add_child(t2); row.add_child(t3)
	body.add_child(row)
	# market movers
	var cands: Array = Data.players.filter(func(x): return x.type == "base" and x.ovr >= 83)
	cands.sort_custom(func(a, b): return Sys.trend_pct(a) > Sys.trend_pct(b))
	var mv = UI.hb(12)
	for pl in cands.slice(0, 4) + cands.slice(cands.size() - 4):
		var c = UI.card(pl, 6.4, false, func(): compare_price(pl))
		mv.add_child(UI.vb(2, [c, UI.hb(4, [UI.spacer(), pct_label(Sys.trend_pct(pl), 12), UI.spacer()]), UI.hb(4, [UI.spacer(), UI.label("● " + Sys.fmt(Sys.value(pl)), 12, UI.GOLD2), UI.spacer()])]))
	var sc = UI.scroll(mv, true); sc.custom_minimum_size.y = 170
	body.add_child(UI.panel(UI.vb(8, [UI.hb(8, [UI.caps("Market movers · last 24h", 11), UI.spacer(), UI.label("Biggest risers and fallers among 83+ players — select one to check prices", 12, UI.DIM)]), sc])))
	body.add_child(UI.label("How it works: prices follow each player's own hourly swings plus supply & demand. Other managers snipe cheap Buy Now listings and bid in the last seconds. Sales are taxed 5%.", 12, UI.DIM))

# ------------------------------------------------------------------ search
const PRICES := [0, 200, 300, 500, 750, 1000, 1500, 2000, 3000, 5000, 7500, 10000, 15000, 20000, 30000, 50000, 75000, 100000, 150000, 250000, 500000, 1000000, 2500000]

func _stepper(st: Dictionary, key: String, caption: String) -> Control:
	var lab = UI.bold("", 14); lab.custom_minimum_size.x = 92; lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var upd = func(): lab.text = "Any" if int(st[key]) == 0 else "● " + Sys.fmt(st[key])
	var move = func(d: int):
		var i = 0
		for k in PRICES.size(): if PRICES[k] <= int(st[key]): i = k
		st[key] = PRICES[clamp(i + d, 0, PRICES.size() - 1)]; upd.call()
	upd.call()
	return UI.field(caption, UI.hb(4, [UI.btn("–", func(): move.call(-1), "Small"), lab, UI.btn("+", func(): move.call(1), "Small")]))

func _search(body: VBoxContainer, f0: Dictionary, page: int) -> void:
	var st = {"name": "", "pos": "", "lg": "", "nat": "", "club": "", "rar": "", "min": 0, "max": 0, "min_bid": 0, "max_bid": 0, "min_bin": 0, "max_bin": 0, "sort": "ends"}
	for k in f0: st[k] = f0[k]
	var opts = func(arr: Array, first: String) -> Array: return [["", first]] + arr
	var nat_items = Data.nations.keys().map(func(k): return [k, Data.nations[k].name]); nat_items.sort_custom(func(a, b): return a[1] < b[1])
	var club_items = Data.clubs.keys().filter(func(k): return not Data.clubs[k].get("special", false) and (st.lg == "" or Data.clubs[k].lg == st.lg)).map(func(k): return [k, Data.clubs[k].name]); club_items.sort_custom(func(a, b): return a[1] < b[1])
	var ovrs = [[0, "Any"]] + range(99, 44, -1).map(func(x): return [x, str(x)])
	var go_search = func(): Sys.M().last_filter = st.duplicate(); UI.replace("transfers", {"tab": "search", "filter": st.duplicate(), "page": 0, "run": true})
	var left = UI.vb(8)
	left.add_child(UI.caps("Search filters", 11))
	left.add_child(UI.field("Player name", UI.line(st.name, func(t): st.name = t, "Any player", 270)))
	left.add_child(UI.hb(8, [UI.field("Position", UI.option(opts.call(Data.positions.map(func(x): return [x, x]), "Any"), st.pos, func(v): st.pos = v)),
		UI.field("Rarity", UI.option(opts.call([["bronze", "Bronze"], ["silver", "Silver"], ["gold", "Gold"], ["gold-rare", "Rare Gold"], ["rare", "Any rare"], ["special", "Special"]], "Any"), st.rar, func(v): st.rar = v))]))
	left.add_child(UI.field("League", UI.option(opts.call(["ENG1", "ESP1", "ITA1", "GER1", "FRA1", "LEG"].map(func(k): return [k, Data.leagues[k].name]), "Any"), st.lg, func(v): st.lg = v; st.club = ""; UI.replace("transfers", {"tab": "search", "filter": st.duplicate()}))))
	left.add_child(UI.field("Club", UI.option(opts.call(club_items, "Any"), st.club, func(v): st.club = v)))
	left.add_child(UI.field("Nation", UI.option(opts.call(nat_items, "Any"), st.nat, func(v): st.nat = v)))
	left.add_child(UI.hb(8, [UI.field("Min OVR", UI.option(ovrs, st.min, func(v): st.min = int(v))), UI.field("Max OVR", UI.option(ovrs, st.max, func(v): st.max = int(v))),
		UI.field("Sort", UI.option([["ends", "Time left"], ["bin-asc", "Price ↑"], ["bin-desc", "Price ↓"], ["ovr", "Rating"]], st.sort, func(v): st.sort = v))]))
	left.add_child(UI.hb(6, [_stepper(st, "min_bid", "Bid min"), _stepper(st, "max_bid", "Bid max")]))
	left.add_child(UI.hb(6, [_stepper(st, "min_bin", "Buy Now min"), _stepper(st, "max_bin", "Buy Now max")]))
	left.add_child(UI.hb(8, [UI.btn("Reset", func(): UI.replace("transfers", {"tab": "search", "filter": {}}), "Small"), UI.spacer(), UI.btn("⌕  Search", go_search, "Primary", f0.is_empty() or not UI.cur_params.get("run", false))]))
	var lp = UI.panel(UI.scroll(left)); lp.custom_minimum_size.x = 330
	# results
	var res: Array = Sys.M().listings.filter(func(l): return l.ends > Sys.now() and not l.get("gone", false))
	if UI.cur_params.get("run", false) or res.is_empty(): res = Sys.market_search(st)
	var pages: int = max(1, int(ceil(res.size() / float(PER_PAGE))))
	page = clamp(page, 0, pages - 1)
	var grid = HFlowContainer.new(); grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 12)
	var labels = []
	var first = UI.cur_params.get("run", false)
	for l in res.slice(page * PER_PAGE, (page + 1) * PER_PAGE):
		var pl = Data.P(l.pid)
		var c = UI.card(pl, 6.6, false, func(): await listing_actions(l); UI.replace("transfers", {"tab": "search", "filter": st, "page": page}))
		if first: c.set_meta("autofocus", true); first = false
		var tl = UI.label("", 11, UI.DIM); var bl = UI.label("", 12); var nl = UI.bold("BIN ● " + Sys.fmt(l.bin), 13, UI.GOLD2)
		labels.append([l, tl, bl])
		var w = UI.label("★ watching" if Sys.is_watched(l) else "", 10, UI.TEAL)
		grid.add_child(UI.vb(1, [c, tl, bl, nl, w]))
	var tick = func():
		var now = Sys.now()
		for x in labels:
			var l: Dictionary = x[0]
			x[1].text = "Expired" if l.ends <= now or l.get("gone", false) else "⏱ " + Sys.fmt_time(l.ends - now)
			x[2].text = ("Bid %s%s" % [Sys.fmt(l.bid), " (you)" if l.bidder == "me" else ""]) if l.bid > 0 else "Start %s" % Sys.fmt(l.start)
			x[2].add_theme_color_override("font_color", UI.GREEN if l.bidder == "me" else UI.TEXT)
	tick.call()
	var head = UI.hb(10, [UI.bold("%d results" % res.size(), 16), UI.label("Page %d / %d" % [page + 1, pages], 13, UI.DIM), UI.spacer(),
		UI.btn("‹ Prev", func(): UI.replace("transfers", {"tab": "search", "filter": st, "page": page - 1}), "Small"),
		UI.btn("Next ›", func(): UI.replace("transfers", {"tab": "search", "filter": st, "page": page + 1}), "Small"),
		UI.btn("⟳ Refresh", go_search, "Small")])
	if res.is_empty(): grid.add_child(UI.label("No listings match. Widen your filters and search again.", 15, UI.DIM))
	var right = UI.vb(8, [head, UI.scroll(grid)]); UI.grow(right)
	var row = UI.hb(16, [lp, right]); UI.grow(row)
	body.add_child(row)
	var t = Timer.new(); t.wait_time = 1.0; t.autostart = true; body.add_child(t); t.timeout.connect(tick)

func listing_actions(l: Dictionary) -> void:
	var pl = Data.P(l.pid)
	if l.ends <= Sys.now() or l.get("gone", false): UI.toast("This item is no longer available", "bad"); return
	var acts = [["Buy Now ● %s" % Sys.fmt(l.bin), "buy", "Primary"], ["Make bid (min %s)" % Sys.fmt(Sys.min_bid(l)), "bid", ""], ["Unwatch" if Sys.is_watched(l) else "Watch", "watch", ""], ["Compare price", "cmp", ""]]
	var v = await UI.inspect(pl, acts)
	match v:
		"buy":
			if await UI.modal("Confirm purchase", "Buy %s (%d) for %s coins?\nBalance after: %s" % [pl.name, pl.ovr, Sys.fmt(l.bin), Sys.fmt(Save.data.coins - l.bin)], [["Cancel", null, ""], ["Buy Now", true, "Primary"]]):
				if l.get("gone", false): UI.toast("Too slow — another manager bought it first!", "bad"); Sfx.play("error")
				elif Sys.buy_now(l): Sfx.play("bigreveal"); UI.toast(pl.name + " added to your club!", "good")
		"bid": await bid_dialog(l)
		"watch": UI.toast("Added to Transfer Targets" if Sys.toggle_watch(l) else "Removed from watchlist")
		"cmp": await compare_price(pl)

func bid_dialog(l: Dictionary) -> void:
	var pl = Data.P(l.pid)
	var st = {"amt": Sys.min_bid(l)}
	var lab = UI.head("", 26, UI.GOLD2)
	var upd = func(): lab.text = "● " + Sys.fmt(st.amt)
	upd.call()
	var step = func(d: int):
		if d > 0: st.amt = min(l.bin, Sys.min_bid({"bid": st.amt, "start": 0}))
		else:
			var lo = Sys.min_bid(l); var x = lo
			while Sys.min_bid({"bid": x, "start": 0}) < st.amt: x = Sys.min_bid({"bid": x, "start": 0})
			st.amt = max(lo, x if x < st.amt else lo)
		upd.call()
	var body = UI.vb(12, [UI.player_row(pl, [], func(): pass), UI.label("Current: %s · Buy Now %s · ends in %s · market value ● %s" % [Sys.fmt(l.bid) if l.bid > 0 else "no bids", Sys.fmt(l.bin), Sys.fmt_time(l.ends - Sys.now()), Sys.fmt(Sys.value(pl))], 13, UI.DIM),
		UI.hb(10, [UI.btn("–", func(): step.call(-1), "Small"), lab, UI.btn("+", func(): step.call(1), "Small", true)])])
	if await UI.modal("Place bid", body, [["Cancel", null, ""], ["Place bid", true, "Primary"]]):
		if Sys.place_bid(l, st.amt): UI.toast("Bid placed — track it in Transfer Targets", "good")

## price checker: market value, 24h trend, cheapest Buy Now listings, recent sales
func compare_price(pl: Dictionary) -> void:
	var tr = Sys.trend(pl)
	var sp = Spark.new(); sp.data = tr; sp.custom_minimum_size = Vector2(420, 120); sp.col = UI.GREEN if tr[-1] >= tr[0] else UI.RED
	var lows = UI.vb(4, [UI.caps("Lowest Buy Now on the market", 10)])
	var R = {"pick": null}
	for l in Sys.lowest_bins(pl.id):
		var b = UI.btn("● %s   ·   %s left%s" % [Sys.fmt(l.bin), Sys.fmt_time(l.ends - Sys.now()), "   ·   bid %s" % Sys.fmt(l.bid) if l.bid > 0 else ""], func(): R.pick = l; UI.close_top("buy"), "Small")
		lows.add_child(b)
	var sales = UI.vb(2, [UI.caps("Recent sales", 10)])
	for s in Sys.recent_sales(pl): sales.add_child(UI.label("● %s   ·   %s ago" % [Sys.fmt(s.price), Sys.fmt_time(Sys.now() - s.t)], 12, UI.DIM))
	var rg = Sys.price_range(pl)
	var info = UI.vb(8, [UI.bold(pl.name, 20), UI.hb(10, [UI.head("● " + Sys.fmt(Sys.value(pl)), 26, UI.GOLD2), pct_label(Sys.trend_pct(pl), 14)]), UI.caps("Price · last 24 hours", 10), sp,
		UI.label("Listing range %s – %s · 24h low %s · high %s" % [Sys.fmt(rg.min), Sys.fmt(rg.max), Sys.fmt(tr.min()), Sys.fmt(tr.max())], 12, UI.DIM), UI.hb(30, [lows, sales])])
	var v = await UI.modal("Compare Price", UI.hb(24, [UI.card(pl, 11.0), info]), [["Search this player", "search", ""], ["Close", null, "Primary"]], true)
	if v == "buy" and R.pick != null: await listing_actions(R.pick)
	elif v == "search": UI.go("transfers", {"tab": "search", "filter": {"name": pl.name}, "run": true})

# ------------------------------------------------------------------ transfer list
func _section(title: String, sub: String, btns := []) -> Control:
	return UI.hb(10, [UI.bold(title, 18), UI.label(sub, 13, UI.DIM), UI.spacer()] + btns)

func _card_cell(pl: Dictionary, lines: Array, cb: Callable, dim := false) -> Control:
	var c = UI.card(pl, 6.4, false, cb)
	if dim: c.modulate.a = 0.55
	var v = UI.vb(1, [c])
	for l in lines: v.add_child(l)
	return v

func _tlist(body: VBoxContainer) -> void:
	var M = Sys.M()
	var mine: Array = M.mine
	var content = UI.vb(12)
	var labels = []
	var flow = func() -> HFlowContainer:
		var fl = HFlowContainer.new(); fl.add_theme_constant_override("h_separation", 12); fl.add_theme_constant_override("v_separation", 12); return fl
	# available (unlisted) items
	var av = flow.call()
	for it in M.tl:
		var pl = Data.P(it.pid)
		av.add_child(_card_cell(pl, [UI.label("Value ● " + Sys.fmt(Sys.value(pl)), 11, UI.GOLD2)], func(): await _avail_actions(it)))
	content.add_child(_section("Available items", "%d / %d · not listed yet" % [M.tl.size(), Sys.TL_MAX], [
		UI.btn("List all at market value", func(): _list_all(), "Small"), UI.btn("Send all to club", func():
			for it in M.tl.duplicate(): Sys.tl_to_club(it.uid)
			UI.replace("transfers", {"tab": "list"}), "Small"),
		UI.btn("+ List from club", func():
			var u = await UI.pick_player("List a player", "", null, false)
			if u != null and await UI.modules[1].list_dialog(u): UI.replace("transfers", {"tab": "list"}), "Small")]))
	if M.tl.is_empty(): av.add_child(UI.label("Empty — send items here from the New Items screen after opening packs.", 13, UI.DIM))
	content.add_child(av)
	# active
	var ac = flow.call()
	for l in mine.filter(func(x): return x.status == "active"):
		var pl = Data.P(l.pid)
		var tl = UI.label("", 11, UI.DIM); var bl = UI.label("", 12)
		labels.append([l, tl, bl])
		ac.add_child(_card_cell(pl, [tl, bl, UI.bold("BIN ● " + Sys.fmt(l.bin), 12, UI.GOLD2)], func():
			if l.bid > 0: UI.toast("This listing has bids and can't be removed", "bad"); return
			if await UI.modal("Remove listing?", "Take %s off the market and back to Available items?" % pl.name, [["Cancel", null, ""], ["Remove", true, "Primary"]]):
				if Sys.remove_listing(l.id):
					Sys.club_remove(l.uid); Sys.tl_add(l.pid, false, "market")
					UI.replace("transfers", {"tab": "list"})))
	content.add_child(_section("Active", "%d listed" % ac.get_child_count()))
	if ac.get_child_count() == 0: ac.add_child(UI.label("Nothing listed.", 13, UI.DIM))
	content.add_child(ac)
	# unsold
	var un = flow.call()
	for l in mine.filter(func(x): return x.status == "expired"):
		var pl = Data.P(l.pid)
		un.add_child(_card_cell(pl, [UI.label("Unsold · BIN %s" % Sys.fmt(l.bin), 11, UI.YELLOW)], func():
			var v = await UI.inspect(pl, [["Relist (same prices)", "relist", "Primary"], ["Relist with new prices", "new", ""], ["Send to club", "club", ""], ["Compare price", "cmp", ""]])
			match v:
				"relist": Sys.remove_listing(l.id); Sys.list_item(l.uid, l.start, l.bin, 60)
				"new": Sys.remove_listing(l.id); await UI.modules[1].list_dialog(l.uid)
				"club": Sys.remove_listing(l.id)
				"cmp": await compare_price(pl)
			UI.replace("transfers", {"tab": "list"})))
	var n_un = un.get_child_count()
	content.add_child(_section("Unsold", "%d expired" % n_un, [UI.btn("Relist all", func():
		var n = 0
		for l in mine.filter(func(x): return x.status == "expired"):
			Sys.remove_listing(l.id)
			if Sys.list_item(l.uid, l.start, l.bin, 60): n += 1
		UI.toast("Relisted %d items" % n, "good"); UI.replace("transfers", {"tab": "list"}), "Small")] if n_un else []))
	if n_un: content.add_child(un)
	# sold
	var so = flow.call()
	var sold: Array = mine.filter(func(x): return x.status == "sold")
	for l in sold: so.add_child(_card_cell(Data.P(l.pid), [UI.bold("Sold ● " + Sys.fmt(l.sold), 12, UI.GREEN)], func(): pass, true))
	var earned = 0
	for l in sold: earned += int(round(l.sold * (1.0 - Sys.MARKET_TAX)))
	content.add_child(_section("Sold", "%d items · +%s coins after tax" % [sold.size(), Sys.fmt(earned)], [UI.btn("Clear sold", func():
		M.mine = M.mine.filter(func(x): return x.status != "sold"); Save.dirty(); UI.replace("transfers", {"tab": "list"}), "Small")] if not sold.is_empty() else []))
	if not sold.is_empty(): content.add_child(so)
	body.add_child(UI.scroll(content))
	var tick = func():
		var now = Sys.now()
		for x in labels:
			x[1].text = "⏱ " + Sys.fmt_time(x[0].ends - now)
			x[2].text = ("Bid " + Sys.fmt(x[0].bid)) if x[0].bid > 0 else "Start " + Sys.fmt(x[0].start)
	tick.call()
	_live(body, "list", tick)

func _avail_actions(it: Dictionary) -> void:
	var pl = Data.P(it.pid)
	var v = await UI.inspect(pl, [["List on Transfer Market", "list", "Primary"], ["Send to club", "club", ""], ["Quick sell (%s)" % Sys.fmt(Data.quick_sell_value(pl)), "qs", "Danger"], ["Compare price", "cmp", ""]])
	match v:
		"list":
			var taken = Sys.tl_take(it.uid)
			Save.data.club.append(taken)
			if not await UI.modules[1].list_dialog(taken.uid):
				Sys.club_remove(taken.uid); Sys.M().tl.append(taken); Save.dirty()
		"club": Sys.tl_to_club(it.uid)
		"qs": Sys.tl_quick_sell(it.uid)
		"cmp": await compare_price(pl)
	UI.replace("transfers", {"tab": "list"})

func _list_all() -> void:
	var M = Sys.M()
	if M.tl.is_empty(): return
	if not await UI.modal("List all available items?", "Every available item is listed for 1 hour: start price 70% and Buy Now 100% of its current market value.", [["Cancel", null, ""], ["List all", true, "Primary"]]): return
	var n = 0
	for it in M.tl.duplicate():
		var taken = Sys.tl_take(it.uid); Save.data.club.append(taken)
		var v = Sys.value(Data.P(taken.pid)); var rg = Sys.price_range(Data.P(taken.pid))
		var bin = max(rg.min + 100, int(round(v / 50.0)) * 50); var start = max(rg.min, int(round(v * 0.7 / 50.0)) * 50)
		if start >= bin: start = bin - 50
		if Sys.list_item(taken.uid, start, bin, 60): n += 1
		else: Sys.club_remove(taken.uid); M.tl.append(taken)
	UI.toast("Listed %d items" % n, "good"); UI.replace("transfers", {"tab": "list"})

# ------------------------------------------------------------------ targets
func _targets(body: VBoxContainer) -> void:
	var M = Sys.M()
	var content = UI.vb(12)
	var labels = []
	var flow = func() -> HFlowContainer:
		var fl = HFlowContainer.new(); fl.add_theme_constant_override("h_separation", 12); fl.add_theme_constant_override("v_separation", 12); return fl
	var act = flow.call()
	for b in M.bids.filter(func(x): return x.status in ["winning", "outbid"]):
		var pl = Data.P(b.pid); var l: Dictionary = b.listing
		var tl = UI.label("", 11, UI.DIM)
		labels.append([l, tl])
		var st = UI.bold("WINNING · " + Sys.fmt(b.amt) if b.status == "winning" else "OUTBID · now " + Sys.fmt(l.bid), 12, UI.GREEN if b.status == "winning" else UI.RED)
		act.add_child(_card_cell(pl, [tl, st], func():
			if b.status == "outbid" and l.ends > Sys.now(): await bid_dialog(l)
			else: await compare_price(pl)
			UI.replace("transfers", {"tab": "targets"})))
	content.add_child(_section("Active bids", "Coins are held while you're winning and refunded if you're outbid"))
	if act.get_child_count() == 0: act.add_child(UI.label("No active bids.", 13, UI.DIM))
	content.add_child(act)
	var wa = flow.call()
	for l in M.watch:
		var pl = Data.P(l.pid)
		var tl = UI.label("", 11, UI.DIM)
		labels.append([l, tl])
		var gone: bool = l.get("gone", false) or l.ends <= Sys.now()
		wa.add_child(_card_cell(pl, [tl, UI.label(("Bid " + Sys.fmt(l.bid)) if l.bid > 0 else "Start " + Sys.fmt(l.start), 12), UI.bold(("SOLD" if l.get("sold_ai", false) else "EXPIRED") if gone else "BIN ● " + Sys.fmt(l.bin), 12, UI.DIM if gone else UI.GOLD2)], func():
			if gone: Sys.toggle_watch(l)
			else: await listing_actions(l)
			UI.replace("transfers", {"tab": "targets"}), gone))
	content.add_child(_section("Watched items", "%d watched" % M.watch.size(), [UI.btn("Clear expired", func():
		M.watch = M.watch.filter(func(l): return not l.get("gone", false) and l.ends > Sys.now()); Save.dirty(); UI.replace("transfers", {"tab": "targets"}), "Small")] if not M.watch.is_empty() else []))
	if M.watch.is_empty(): wa.add_child(UI.label("Watch listings from the search results to track them here.", 13, UI.DIM))
	content.add_child(wa)
	var won = flow.call()
	var won_b: Array = M.bids.filter(func(x): return x.status == "won")
	for b in won_b: won.add_child(_card_cell(Data.P(b.pid), [UI.bold("WON · " + Sys.fmt(b.amt), 12, UI.GREEN), UI.label("Sent to club", 11, UI.DIM)], func(): pass))
	content.add_child(_section("Won items", "%d" % won_b.size(), [UI.btn("Clear", func():
		M.bids = M.bids.filter(func(x): return x.status in ["winning", "outbid"]); Save.dirty(); UI.replace("transfers", {"tab": "targets"}), "Small")] if not won_b.is_empty() else []))
	if not won_b.is_empty(): content.add_child(won)
	body.add_child(UI.scroll(content))
	var tick = func():
		var now = Sys.now()
		for x in labels: x[1].text = "Ended" if x[0].ends <= now else "⏱ " + Sys.fmt_time(x[0].ends - now)
	tick.call()
	_live(body, "targets", tick)

func _history(body: VBoxContainer) -> void:
	var list = UI.vb(4)
	if Save.data.market.history.is_empty(): list.add_child(UI.label("No transfers yet", 14, UI.DIM))
	for x in Save.data.market.history:
		var pl = Data.P(x.pid)
		list.add_child(UI.panel(UI.hb(14, [UI.label(Time.get_datetime_string_from_unix_time(int(x.t)).replace("T", " "), 13, UI.DIM), UI.bold("Bought" if x.kind == "buy" else "Sold", 13, UI.TEXT if x.kind == "buy" else UI.GREEN), UI.label("%d %s" % [pl.ovr, pl.name], 14), UI.spacer(), UI.bold("● " + Sys.fmt(x.price), 14, UI.GOLD2)]), "Glass"))
	body.add_child(UI.scroll(list))
