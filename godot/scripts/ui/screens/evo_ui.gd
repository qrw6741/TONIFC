extends RefCounted
## Evolutions hub tab: browse Evolutions, start one, track active upgrades.

const EVC := Color("#7dffb0")

func page_title(t: String) -> Label: return UI.head(t.to_upper(), 38)

func s_evolutions(p) -> Dictionary:
	var f = UI.hub_shell("evolutions")
	var tab: String = p.get("tab", "available")
	var act: Array = Evo.st().active
	f.body.add_child(UI.hb(12, [page_title("Evolutions"), UI.spacer(),
		UI.seg([["available", "Available"], ["active", "Active (%d/%d)" % [act.size(), Evo.SLOTS]], ["done", "Completed (%d)" % Evo.st().done.size()]], tab, func(v): UI.replace("evolutions", {"tab": v}))]))
	match tab:
		"active": _active(f.body)
		"done": _done(f.body)
		_: _available(f.body)
	return {"node": f.node, "bg": "hub", "tab": "evolutions", "back": func(): UI.reset("main")}

# ------------------------------------------------------------------ available
func _available(body: VBoxContainer) -> void:
	body.add_child(UI.wrapl(UI.label("Put a player into an Evolution, then play Ultimate XI matches with him in your starting XI. Each match: 100 XP, +60 win, +40 per goal, +30 per assist, +40 clean sheet for defenders & keepers. Upgrades are permanent; evolved players become untradeable.", 13, UI.DIM), 1300))
	var flow = HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 14); flow.add_theme_constant_override("v_separation", 14)
	var first = true
	for evo in Evo.CATALOG:
		var n_el: int = Evo.eligible_items(evo).size()
		var reqs = UI.vb(1)
		for r in Evo.req_text(evo): reqs.add_child(UI.label("• " + r, 12, UI.DIM))
		var boost = "Up to +%d OVR · %d levels" % [Evo.total_ovr(evo), evo.levels.size()]
		var fin: Dictionary = evo.final
		if fin.has("sm"): boost += " · +1★ skills"
		if fin.has("wf"): boost += " · +1★ weak foot"
		var t = UI.tile([UI.hb(6, [UI.bold(evo.name, 19, EVC), UI.spacer(), UI.pill(Evo.cost_text(evo), UI.GOLD2 if evo.cost.has("coins") else (UI.TEAL if evo.cost.has("points") else UI.GREEN))]),
			UI.wrapl(UI.label(evo.desc, 13), 270), reqs, UI.bold(boost, 13, UI.TEAL),
			UI.caps("%d eligible player%s in your club" % [n_el, "" if n_el == 1 else "s"], 10, UI.GREEN if n_el else UI.DIM)],
			func(): _choose(evo), Vector2(310, 250), first)
		if n_el == 0: t.modulate = Color(1, 1, 1, 0.7)
		flow.add_child(t); first = false
	# event evolution
	var ng = UI.tile([UI.hb(6, [UI.bold("Next Gen", 19, Color("#8af4ff")), UI.spacer(), UI.pill("EVENT", Color("#8af4ff"))]), UI.wrapl(UI.label("Rising Stars event Evolution for young stars — up to +5 OVR.", 13), 270), UI.caps("Open in the Rising Stars event", 10, UI.DIM)], func(): UI.go("event", {"tab": "evo"}), Vector2(310, 250))
	flow.add_child(ng)
	body.add_child(UI.scroll(flow))

func _choose(evo: Dictionary) -> void:
	if Evo.st().active.size() >= Evo.SLOTS: UI.toast("All %d Evolution slots are in use — finish one first" % Evo.SLOTS, "bad"); Sfx.play("error"); return
	if Evo.eligible_items(evo).is_empty(): UI.toast("No eligible players in your club for %s" % evo.name, "bad"); Sfx.play("error"); return
	var u = await UI.pick_player("Choose a player for %s" % evo.name, "", func(it): return Evo.eligible(evo, it))
	if u == null: return
	var src: String = Sys.item(u).pid
	var pl = Data.P(src)
	var cards = UI.hb(10, [UI.vb(4, [UI.card(pl, 8.0), UI.caps("Now", 10)])])
	for lv in range(1, evo.levels.size() + 1):
		cards.add_child(UI.label("→", 26, EVC))
		cards.add_child(UI.vb(4, [UI.card(Evo.preview(evo, src, lv), 6.6 if lv < evo.levels.size() else 8.0), UI.caps("Level %d" % lv, 10, EVC if lv == evo.levels.size() else UI.DIM)]))
	var body = UI.vb(12, [cards, UI.label("Cost: %s · %d XP per level · %s becomes untradeable" % [Evo.cost_text(evo), int(evo.xp), pl.name], 14, UI.DIM)])
	var ok = await UI.modal("Start %s?" % evo.name, body, [["Start Evolution (%s)" % Evo.cost_text(evo), true, "Primary"], ["Cancel", null, ""]], true)
	if ok and Evo.start(evo, u):
		Sfx.play("reveal"); UI.toast("%s started for %s" % [evo.name, pl.name], "good")
		UI.replace("evolutions", {"tab": "active"})

# ------------------------------------------------------------------ active
func _active(body: VBoxContainer) -> void:
	var act: Array = Evo.st().active
	var list = UI.vb(12)
	if act.is_empty():
		list.add_child(UI.label("No active Evolutions. Pick one from the Available tab.", 15, UI.DIM))
		list.add_child(UI.btn("Browse Evolutions", func(): UI.replace("evolutions"), "Primary", true))
	var first = true
	for e in act:
		var evo = Evo.spec(e.evo); var it = Sys.item(e.uid)
		var cur = Data.P(it.get("pid", e.src))
		var nl: int = min(evo.levels.size(), int(e.lvl) + 1)
		var nxt = Evo.preview(evo, e.src, nl); var fin = Evo.preview(evo, e.src, evo.levels.size())
		var inxi: bool = Evo.in_xi(e.uid)
		var info = UI.vb(6, [UI.bold(evo.name, 20, EVC), UI.bold(cur.name, 15),
			UI.label("Level %d / %d · %d / %d XP" % [int(e.lvl), evo.levels.size(), int(e.xp), int(evo.xp)], 14), UI.bar(int(e.xp), int(evo.xp), "GoldBar"),
			UI.label("In your starting XI ✓ — earning XP" if inxi else "Not in your active starting XI — he only earns XP when he starts", 13, UI.GREEN if inxi else UI.YELLOW)])
		info.custom_minimum_size.x = 380
		var btns = UI.vb(8)
		var sq_b = UI.btn("Open Squad", func(): UI.go("squad"), "Primary" if not inxi else "", first)
		btns.add_child(sq_b)
		btns.add_child(UI.btn("Cancel Evolution", func():
			if await UI.modal("Cancel this Evolution?", "%s keeps the upgrades earned so far. Any cost paid is not refunded." % cur.name, [["Keep going", null, ""], ["Cancel Evolution", true, "Danger"]]):
				Evo.cancel(e.uid); UI.replace("evolutions", {"tab": "active"}), "Small"))
		var row = UI.hb(16, [UI.card(cur, 8.6, false, func(): UI.inspect(cur)), UI.label("→", 34, EVC), UI.vb(2, [UI.card(nxt, 7.0, false, func(): UI.inspect(nxt)), UI.caps("Next", 10)]),
			UI.label("⇢", 30, UI.DIM), UI.vb(2, [UI.card(fin, 7.0, false, func(): UI.inspect(fin)), UI.caps("Final", 10, EVC)]), info, UI.spacer(), btns])
		list.add_child(UI.panel(row)); first = false
	body.add_child(UI.scroll(list))

# ------------------------------------------------------------------ completed
func _done(body: VBoxContainer) -> void:
	var flow = HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 12); flow.add_theme_constant_override("v_separation", 12)
	var arr: Array = Evo.st().done.duplicate(); arr.reverse()
	if arr.is_empty(): body.add_child(UI.label("No completed Evolutions yet.", 15, UI.DIM))
	var first = true
	for d in arr:
		var pl = Data.P(d.pid)
		if pl.is_empty(): continue
		var c = UI.card(pl, 8.0, false, func(): UI.inspect(pl))
		if first: c.set_meta("autofocus", true); first = false
		flow.add_child(UI.vb(2, [c, UI.caps(Evo.spec(d.evo).get("name", ""), 10, EVC)]))
	body.add_child(UI.scroll(flow))
