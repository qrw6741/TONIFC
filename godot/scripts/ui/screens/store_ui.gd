extends RefCounted
## Store (FC-style): Browse with a category sidebar, a pack details header and a row of big packs
## with prices; My Packs; Pack Probabilities; and a Preview Pack whose contents you can see before
## buying — it refreshes every 30 minutes (one purchase per preview).

const PROMO_LIMIT := 6
const PREVIEW_SECS := 1800.0

# ------------------------------------------------------------------ shared helpers
static func promo_state() -> Dictionary:
	var d = Save.data
	if typeof(d.get("store_lim")) != TYPE_DICTIONARY or d.store_lim.get("week", "") != Sys.week_key(): d.store_lim = {"week": Sys.week_key(), "n": {}}
	return d.store_lim
static func promo_left(id: String) -> int:
	if not Data.packs[id].get("promo", false): return -1
	return PROMO_LIMIT - int(promo_state().n.get(id, 0))
static func promo_bought(id: String) -> void:
	if Data.packs[id].get("promo", false): promo_state().n[id] = int(promo_state().n.get(id, 0)) + 1; Save.dirty()

static func preview_window() -> int: return int(floor(Sys.now() / PREVIEW_SECS))
static func preview_left() -> float: return (preview_window() + 1) * PREVIEW_SECS - Sys.now()
static func preview() -> Dictionary:
	var d = Save.data
	if not Data.packs.has("preview"):
		Data.packs["preview"] = {"name": "Preview Rare Players Pack", "items": 6, "coins": 30000, "points": 450, "art": "rare", "guar": [["gold-rare", 1]], "w": {"gold-rare": 1}, "desc": "See the 6 players inside before you buy. New preview every 30 minutes."}
	if typeof(d.get("preview")) != TYPE_DICTIONARY or int(d.preview.get("win", -1)) != preview_window():
		var items: Array = Sys.generate_pack("rare")
		items.shuffle(); items = items.slice(0, 6)
		items.sort_custom(func(a, b): return Data.card_value_score(a) > Data.card_value_score(b))
		d.preview = {"win": preview_window(), "items": items.map(func(x): return x.id), "bought": false}
		Save.dirty()
	return d.preview

func _price_text(pk: Dictionary) -> String:
	var parts = []
	if pk.coins: parts.append("● " + Sys.fmt(pk.coins))
	if pk.points: parts.append("◆ " + Sys.fmt(pk.points))
	return "  or  ".join(parts)

func _pack_stats(pk: Dictionary) -> String:
	var g = 0
	for x in pk.guar: g += int(x[1])
	return "%d items · %d guaranteed" % [int(pk.items), g]

# ------------------------------------------------------------------ screen
func s_store(p) -> Dictionary:
	var f = UI.hub_shell("store")
	var tab: String = p.get("tab", "mine" if (not Save.data.unopened.is_empty() or not Save.data.pending.is_empty()) else "browse")
	if tab == "packs": tab = "browse"
	var cat: String = p.get("cat", "promo" if tab == "promo" else "classic")
	if tab == "promo": tab = "browse"
	f.body.add_child(UI.hb(10, [UI.head("STORE", 38), UI.spacer(), UI.seg([["browse", "Browse"], ["mine", "My Packs (%d)" % Save.data.unopened.size()], ["odds", "Pack Probabilities"]], tab, func(v): UI.replace("store", {"tab": v}))]))
	match tab:
		"mine": _mine(f.body)
		"odds": _odds(f.body)
		_: _browse(f, cat)
	return {"node": f.node, "bg": "hub", "tab": "store", "back": func(): UI.reset("main")}

func _browse(f: Dictionary, cat: String) -> void:
	var row = UI.hb(22); UI.grow(row)
	# sidebar
	var side = UI.vb(6); side.custom_minimum_size.x = 250
	var pv = preview()
	for c in [["promo", "Promo Packs"], ["classic", "Classic Packs"], ["preview", "Preview Pack  ⏱ " + Sys.fmt_time(preview_left())], ["daily", "Daily Prime Points" + (" •" if Save.data.daily_pts != Sys.day_key() else "")]]:
		var b = UI.btn(c[1], func(): UI.replace("store", {"tab": "browse", "cat": c[0]}), "Row")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if c[0] == cat:
			var sb = StyleBoxFlat.new(); sb.bg_color = Color(1, 1, 1, 0.16); sb.set_corner_radius_all(8); sb.content_margin_left = 14; sb.content_margin_top = 10; sb.content_margin_bottom = 10
			b.add_theme_stylebox_override("normal", sb); b.add_theme_color_override("font_color", Color.WHITE)
		side.add_child(b)
	row.add_child(side)
	var main = UI.vb(12); UI.grow(main)
	match cat:
		"preview": _preview_view(main, pv)
		"daily": _daily(main)
		_: _pack_row(main, cat)
	row.add_child(main)
	f.body.add_child(row)

func _pack_row(main: VBoxContainer, cat: String) -> void:
	var ids: Array = Data.pack_order.filter(func(id): return Data.packs.has(id) and Data.packs[id].get("promo", false) == (cat == "promo"))
	var title = UI.head("", 36); var meta = UI.label("", 15, Color("#3fe0c8")); var desc = UI.wrapl(UI.label("", 15, UI.DIM), 900)
	var show = func(id: String):
		var pk: Dictionary = Data.packs[id]
		title.text = pk.name
		var m = []
		if pk.get("promo", false): m.append("⏱ Expires in %s" % Sys.fmt_time(Sys.secs_to_reset("weekly")))
		var left = promo_left(id)
		m.append(("Packs Remaining: %d" % left) if left >= 0 else "Packs Remaining: ∞")
		meta.text = "      ".join(m)
		desc.text = "Includes %d items. %s" % [int(pk.items), pk.desc]
	main.add_child(UI.vb(4, [title, meta, desc]))
	var packs = HBoxContainer.new(); packs.add_theme_constant_override("separation", 18)
	var first = true
	for id in ids:
		var pk: Dictionary = Data.packs[id]
		var b = Button.new(); b.flat = true; b.focus_mode = Control.FOCUS_ALL
		for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]: b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
		var art = UI.icon("pack", id, Vector2(160, 226)); art.animate = false; art.mouse_filter = Control.MOUSE_FILTER_IGNORE; art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var stats = UI.bold(_pack_stats(pk), 12); stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; stats.modulate.a = 0.0
		var price = UI.bold(_price_text(pk), 15, UI.GOLD2); price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var left = promo_left(id)
		if left == 0: price.text = "Sold out this week"; price.add_theme_color_override("font_color", UI.DIM)
		var v = UI.vb(8, [art, stats, price]); v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c in v.get_children(): c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.custom_minimum_size = Vector2(200, 0); b.add_child(v); b.custom_minimum_size = Vector2(200, 300)
		var pid: String = id
		b.focus_entered.connect(func():
			show.call(pid); Sfx.play("move"); stats.modulate.a = 1.0
			b.pivot_offset = Vector2(100, 120); b.create_tween().tween_property(b, "scale", Vector2(1.06, 1.06), 0.12)
			art.animate = true)
		b.focus_exited.connect(func(): stats.modulate.a = 0.0; b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12); art.animate = false)
		b.mouse_entered.connect(func(): if UI.mouse_recent() and not b.has_focus(): b.grab_focus())
		b.pressed.connect(func():
			Sfx.play("select")
			if promo_left(pid) == 0: UI.toast("You've bought the maximum of this pack this week", "bad"); return
			UI.modules[1].buy_pack(pid))
		if first: b.set_meta("autofocus", true); show.call(id); first = false
		packs.add_child(b)
	var sc = UI.scroll(packs, true); sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; sc.custom_minimum_size.y = 330
	main.add_child(sc)
	var focused = func() -> String:
		var fo = UI.get_viewport().gui_get_focus_owner()
		if fo != null and packs.is_ancestor_of(fo): return ids[fo.get_index()]
		return ""
	UI.keyhook(main, {"j%d" % JOY_BUTTON_X: func(): var id = focused.call(); if id != "": _details(id),
		"k%d" % KEY_V: func(): var id = focused.call(); if id != "": _details(id),
		"j%d" % JOY_BUTTON_Y: func(): UI.replace("store", {"tab": "odds"}), "k%d" % KEY_P: func(): UI.replace("store", {"tab": "odds"})})
	var g = func(ps: String, xb: String, kb: String) -> String: return ps if Pad.style == "ps" else (xb if Pad.style == "xbox" else kb)
	main.add_child(UI.hb(20, [UI._key_hint(g.call("✕", "A", "Enter"), "Buy"), UI._key_hint(g.call("□", "X", "V"), "View Pack Details"), UI._key_hint(g.call("△", "Y", "P"), "Show Pack Probabilities")]))

func _details(id: String) -> void:
	var pk: Dictionary = Data.packs[id]
	var t = GridContainer.new(); t.columns = 3; t.add_theme_constant_override("h_separation", 22)
	for hdr in ["Item", "Per slot", "≥1 in pack"]: t.add_child(UI.caps(hdr, 10))
	for o in Sys.pack_odds(id):
		t.add_child(UI.label(Data.tier_label.get(o.tier, o.tier), 13)); t.add_child(UI.label("%.2f%%" % (o.per * 100), 13)); t.add_child(UI.label("%.2f%%" % (o.least * 100), 13))
	var gtxt = ", ".join(pk.guar.map(func(x): return "%d× %s" % [int(x[1]), Data.tier_label.get(x[0], x[0])]))
	await UI.modal(pk.name, UI.hb(22, [UI.icon("pack", id, Vector2(120, 168)), UI.vb(8, [UI.bold(pk.desc, 15), UI.label("%d items · Guaranteed: %s" % [int(pk.items), gtxt], 13, UI.DIM), UI.label("Price: " + _price_text(pk), 14, UI.GOLD2), t])]), [["Close", null, "Primary"]])

func _daily(main: VBoxContainer) -> void:
	var today = Sys.day_key()
	var claimed: bool = Save.data.daily_pts == today
	main.add_child(UI.head("Daily Prime Points", 36))
	main.add_child(UI.wrapl(UI.label("Claim 100 free Prime Points every day. Prime Points are fictional credits — there are no real-money purchases in this game.", 15, UI.DIM), 800))
	var b = UI.btn("Claimed today" if claimed else "Claim 100 Prime Points", func(): Save.data.daily_pts = today; Sys.add("points", 100, "Daily Prime Points"); UI.replace("store", {"tab": "browse", "cat": "daily"}), "Primary", not claimed)
	b.disabled = claimed; b.custom_minimum_size = Vector2(300, 52); main.add_child(b)

func _preview_view(main: VBoxContainer, pv: Dictionary) -> void:
	var pk: Dictionary = Data.packs["preview"]
	var cd = UI.bold("", 16, Color("#3fe0c8"))
	var upd = func(): cd.text = "⏱ New preview in %s" % Sys.fmt_time(preview_left())
	upd.call()
	main.add_child(UI.vb(4, [UI.head(pk.name, 36), cd, UI.wrapl(UI.label("You can see exactly which players are inside before buying. The contents change every 30 minutes and each preview can be bought once.", 15, UI.DIM), 900)]))
	var cards = UI.hb(12)
	for pid in pv.items:
		var pl = Data.P(pid)
		var c = UI.card(pl, 8.4, false, func(): UI.inspect(pl))
		if pv.bought: c.modulate = Color(1, 1, 1, 0.45)
		cards.add_child(c)
	var buy = UI.vb(10, [UI.icon("pack", "preview", Vector2(110, 154))])
	if pv.bought:
		buy.add_child(UI.bold("Purchased ✓", 16, UI.GREEN))
	else:
		buy.add_child(UI.btn("Buy ● %s" % Sys.fmt(pk.coins), func(): _buy_preview("coins"), "Primary", true))
		buy.add_child(UI.btn("Buy ◆ %s" % Sys.fmt(pk.points), func(): _buy_preview("points"), ""))
	main.add_child(UI.hb(24, [cards, buy]))
	var tm = Timer.new(); tm.wait_time = 1.0; tm.autostart = true; main.add_child(tm)
	var w0 = {"w": preview_window()}
	tm.timeout.connect(func():
		upd.call()
		if preview_window() != w0.w and UI.modals.is_empty(): UI.replace("store", {"tab": "browse", "cat": "preview"}))

func _buy_preview(cur: String) -> void:
	var pv = preview(); var pk: Dictionary = Data.packs["preview"]
	if pv.bought: return
	if not Save.data.pending.is_empty(): UI.toast("Assign your previous pack items first", "bad"); UI.go("packresult"); return
	if not await UI.modal("Buy this preview pack?", "You'll get exactly these %d players for %s." % [pv.items.size(), ("● " + Sys.fmt(pk.coins)) if cur == "coins" else ("◆ " + Sys.fmt(pk.points))], [["Cancel", null, ""], ["Buy", true, "Primary"]]): return
	if not Sys.spend(cur, pk.coins if cur == "coins" else pk.points, "Bought " + pk.name, "store"): return
	pv.bought = true; Save.dirty()
	UI.modules[1].open_pack("preview", true, pv.items.map(func(x): return Data.P(x)))

# ------------------------------------------------------------------ my packs & probabilities
func _mine(body: VBoxContainer) -> void:
	var content = UI.vb(14)
	if Save.data.get("pick_cur") != null:
		var pinfo = UI.vb(2, [UI.bold("Player Pick in progress", 15), UI.label("Finish choosing your player from %s." % Data.packs[Save.data.pick_cur.pack].name, 13, UI.DIM)]); UI.grow(pinfo, false, true)
		content.add_child(UI.panel(UI.hb(14, [pinfo, UI.btn("Continue pick", func(): UI.go("pick"), "Primary")])))
	if not Save.data.pending.is_empty():
		var info = UI.vb(2, [UI.bold("%d unassigned items" % Save.data.pending.size(), 15), UI.label("From your last pack — keep, send to the Transfer List or quick sell.", 13, UI.DIM)]); UI.grow(info, false, true)
		content.add_child(UI.panel(UI.hb(14, [info, UI.btn("View items", func(): UI.go("packresult"), "Primary")])))
	if Save.data.unopened.is_empty(): content.add_child(UI.label("No unopened packs. Earn them from objectives, SBCs and competitions, or buy them in the Store.", 15, UI.DIM))
	var flow = HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 16); flow.add_theme_constant_override("v_separation", 16)
	var first = true
	for i in Save.data.unopened.size():
		var id: String = Save.data.unopened[i]
		var pk: Dictionary = Data.packs[id]
		var art = UI.icon("pack", id, Vector2(110, 154)); art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; art.animate = false
		var idx = i
		flow.add_child(UI.tile([art, UI.bold(pk.name, 15), UI.bold("Open now", 14, UI.GREEN)], func():
			Save.data.unopened.remove_at(idx); Save.dirty(); UI.modules[1].open_pack(id, false), Vector2(200, 250), first))
		first = false
	content.add_child(flow)
	body.add_child(UI.scroll(content))

func _odds(body: VBoxContainer) -> void:
	var content = UI.vb(12)
	content.add_child(UI.wrapl(UI.label("Every pack's contents are generated from these odds. Guaranteed slots are filled first; remaining slots roll the per-slot odds.", 13, UI.DIM), 1100))
	var g = HFlowContainer.new(); g.add_theme_constant_override("h_separation", 14); g.add_theme_constant_override("v_separation", 14)
	for id in Data.pack_order:
		var pk: Dictionary = Data.packs[id]
		var t = GridContainer.new(); t.columns = 3; t.add_theme_constant_override("h_separation", 18)
		for hdr in ["Item", "Per slot", "≥1 in pack"]: t.add_child(UI.caps(hdr, 10))
		for o in Sys.pack_odds(id):
			t.add_child(UI.label(Data.tier_label.get(o.tier, o.tier), 13)); t.add_child(UI.label("%.2f%%" % (o.per * 100), 13)); t.add_child(UI.label("%.2f%%" % (o.least * 100), 13))
		var gtxt = ", ".join(pk.guar.map(func(x): return "%d× %s" % [int(x[1]), Data.tier_label.get(x[0], x[0])]))
		var pn = UI.panel(UI.vb(6, [UI.bold(pk.name, 15), UI.wrapl(UI.label("%d items · Guaranteed: %s" % [int(pk.items), gtxt], 12, UI.DIM), 300), t])); pn.custom_minimum_size.x = 340
		g.add_child(pn)
	content.add_child(g)
	body.add_child(UI.scroll(content))
