extends RefCounted
## Rising Stars event hub: overview, objectives, Next Gen Evolution, Star Token store.

const CYAN := Color("#8af4ff")
const TOK := Color("#ffd86b")

func s_event(p) -> Dictionary:
	var f = UI.sub_shell("Rising Stars", "Ultimate XI · Live event")
	var tab: String = p.get("tab", "overview")
	var claim_o = Event.objectives().filter(func(o): return Sys.obj_done(o) and not Sys.obj_claimed(o)).size()
	f.body.add_child(UI.hb(14, [UI.vb(0, [UI.head("RISING STARS", 40, CYAN), UI.label("The best young players in the top 5 leagues — boosted. Event live now.", 13, UI.DIM)]), UI.spacer(),
		UI.seg([["overview", "Overview"], ["objectives", "Objectives" + (" •" if claim_o or (Event.all_objectives_done() and not Event.st().final) else "")], ["evo", "Next Gen Evolution"], ["store", "Star Token Store"]], tab, func(v): UI.replace("event", {"tab": v})),
		UI.panel(UI.vb(0, [UI.caps("Star Tokens", 10), UI.head("★ " + Sys.fmt(Event.tokens()), 24, TOK)]), "Glass")]))
	match tab:
		"objectives": _objectives(f.body)
		"evo": _evo(f.body)
		"store": _store(f.body)
		_: _overview(f.body)
	return {"node": f.node, "bg": "hub", "back": func(): UI.reset("home")}

# ------------------------------------------------------------------ overview
func _overview(body: VBoxContainer) -> void:
	var row = UI.hb(10)
	var first = true
	for pl in Event.stars:
		var c = UI.card(pl, 8.2, false, func(): UI.inspect(pl))
		if first: c.set_meta("autofocus", true); first = false
		row.add_child(c)
	var sc = UI.scroll(row, true); sc.custom_minimum_size.y = 160
	body.add_child(UI.panel(UI.vb(6, [UI.caps("%d Rising Stars cards · in packs, SBCs, objectives and the Star Token store" % Event.stars.size(), 10), sc])))
	var g = UI.hb(14)
	var pk: Dictionary = Data.packs["rspack"]
	g.add_child(UI.tile([UI.icon("pack", "rspack", Vector2(84, 118)), UI.bold(pk.name, 16), UI.wrapl(UI.label(pk.desc, 12, UI.DIM), 200), UI.bold("◆ %s" % Sys.fmt(pk.points), 14, UI.TEAL)], func(): UI.modules[1].buy_pack("rspack"), Vector2(250, 280)))
	var done_o = Event.objectives().filter(func(o): return Sys.obj_claimed(o)).size()
	var final_p = Data.P(Event.final_reward())
	g.add_child(UI.tile([UI.caps("Event objectives", 10), UI.bold("%d / %d completed" % [done_o, Event.objectives().size()], 18), UI.bar(done_o, Event.objectives().size(), "GoldBar"), UI.label("Complete them all for:", 12, UI.DIM), UI.card(final_p, 5.4)], func(): UI.replace("event", {"tab": "objectives"}), Vector2(250, 280)))
	var ev_n: int = Event.st().evos.size()
	g.add_child(UI.tile([UI.caps("Next Gen Evolution", 10), UI.bold("%d / %d slots in use" % [ev_n, Event.MAX_EVOS], 18), UI.wrapl(UI.label("Put a young star into an Evolution and level him up to +%d OVR by playing matches." % Event.EVO_LEVELS, 13, UI.DIM), 210)], func(): UI.replace("event", {"tab": "evo"}), Vector2(250, 280)))
	var sb = Data.sbcs.filter(func(s): return s.cat == "Rising Stars")
	var sbv = UI.vb(4, [UI.caps("Event SBCs", 10)])
	for s in sb: sbv.add_child(UI.label(("✓ " if not Sys.sbc_available(s) else "• ") + s.name, 14, UI.DIM if not Sys.sbc_available(s) else UI.TEXT))
	g.add_child(UI.tile([sbv], func(): UI.replace("sbc", {"cat": "Rising Stars"}), Vector2(250, 280)))
	g.add_child(UI.tile([UI.caps("Star Token Store", 10), UI.head("★ " + Sys.fmt(Event.tokens()), 30, TOK), UI.wrapl(UI.label("Earn Star Tokens from event objectives and SBCs. Spend them on Rising Stars packs, a Player Pick and RS Endrick.", 13, UI.DIM), 210)], func(): UI.replace("event", {"tab": "store"}), Vector2(250, 280)))
	body.add_child(UI.scroll(g, true))

# ------------------------------------------------------------------ objectives
func _objectives(body: VBoxContainer) -> void:
	var list = UI.vb(10)
	var first = true
	for o in Event.objectives():
		var done: bool = Sys.obj_done(o); var cl: bool = Sys.obj_claimed(o)
		var right = UI.btn("Claimed" if cl else ("Claim" if done else "%d / %d" % [Sys.obj_progress(o), int(o.target)]), func():
			if Sys.obj_claim(o): Sfx.play("reveal"); UI.replace("event", {"tab": "objectives"}), "Primary" if done and not cl else "", first and done and not cl)
		right.disabled = cl or not done; right.custom_minimum_size.x = 140
		var info = UI.vb(3, [UI.bold(o.title, 17), UI.label(o.desc, 13, UI.DIM), UI.bar(Sys.obj_progress(o), int(o.target)), UI.label("Reward: " + Sys.reward_text(o.reward), 12, TOK)]); UI.grow(info, false, true)
		var pn = UI.panel(UI.hb(14, [info, right]))
		if cl: pn.modulate.a = 0.55
		list.add_child(pn)
	var fp = Data.P(Event.final_reward())
	var can: bool = Event.all_objectives_done() and not Event.st().final
	var fb = UI.btn("Claimed" if Event.st().final else ("Claim %s" % Data.short_name(fp.name) if can else "Complete all objectives"), func():
		if Event.claim_final(): Sfx.play("bigreveal"); UI.replace("event", {"tab": "objectives"}), "Primary" if can else "")
	fb.disabled = not can
	var side = UI.panel(UI.vb(10, [UI.caps("Group reward", 10), UI.card(fp, 11.0, false, func(): UI.inspect(fp)), UI.bold("Rising Stars " + fp.name, 15), fb]))
	body.add_child(UI.hb(18, [UI.grow(UI.scroll(list)), side]))
	UI.grow(body.get_child(-1))

# ------------------------------------------------------------------ evolution
func _evo(body: VBoxContainer) -> void:
	body.add_child(UI.wrapl(UI.label("Next Gen Evolution: choose a Rising Stars card or one of the real young stars (Yamal, Cubarsí, Güler, Mainoo, Estêvão, Endrick and more). Play Ultimate XI matches with him in your starting XI: 100 XP per match, +60 for a win, +40 per goal he scores. Every %d XP = +1 OVR and key stats. Level %d also adds a skill-move and weak-foot star. Evolved players become untradeable." % [Event.EVO_XP, Event.EVO_LEVELS], 13, UI.DIM), 1300))
	var row = UI.hb(18)
	var evos: Array = Event.st().evos
	for i in Event.MAX_EVOS:
		if i < evos.size():
			var e: Dictionary = evos[i]
			var it = Sys.item(e.uid)
			var cur = Data.P(it.get("pid", e.src))
			var nxt = Event.ensure_evo(Event.evo_id(e.src, min(Event.EVO_LEVELS, int(e.lvl) + 1)))
			var inxi: bool = Sys.active_squad().slots.has(e.uid)
			var v = UI.vb(10, [UI.caps("Evolution slot %d" % (i + 1), 10), UI.hb(16, [UI.card(cur, 10.0, false, func(): UI.inspect(cur)), UI.label("→", 40, CYAN), UI.card(nxt, 8.0, false, func(): UI.inspect(nxt))]),
				UI.bold("Level %d / %d · %d / %d XP" % [int(e.lvl), Event.EVO_LEVELS, int(e.xp), Event.EVO_XP], 15), UI.bar(int(e.xp), Event.EVO_XP, "GoldBar"),
				UI.label("In your starting XI ✓" if inxi else "Not in your active starting XI — he only earns XP when he starts", 13, UI.GREEN if inxi else UI.YELLOW)])
			if not inxi: v.add_child(UI.btn("Open Squad", func(): UI.go("squad"), "Small"))
			row.add_child(UI.panel(v))
		else:
			var t = UI.tile([UI.caps("Evolution slot %d" % (i + 1), 10), UI.head("+", 70, CYAN), UI.bold("Start an Evolution", 17), UI.label("Pick an eligible young star from your club", 13, UI.DIM)], func(): _start(), Vector2(330, 360), i == evos.size())
			row.add_child(t)
	var done: Array = Event.st().evolved.keys()
	var dv = UI.vb(6, [UI.caps("Completed", 10)])
	if done.is_empty(): dv.add_child(UI.label("None yet", 13, UI.DIM))
	for src in done:
		var fin = Data.P(Event.evo_id(src, Event.EVO_LEVELS)); dv.add_child(UI.label("%d %s" % [fin.ovr, fin.name], 14))
	row.add_child(UI.panel(dv))
	body.add_child(row)

func _start() -> void:
	var u = await UI.pick_player("Choose a player for Next Gen Evolution", "", func(it): return Event.evo_eligible(it))
	if u == null: return
	var pl = Data.P(Sys.item(u).pid)
	var fin = Event.ensure_evo(Event.evo_id(pl.id, Event.EVO_LEVELS))
	var ok = await UI.modal("Start Evolution?", UI.hb(20, [UI.card(pl, 9.0), UI.label("→", 40, CYAN), UI.card(fin, 9.0), UI.wrapl(UI.label("%s can reach %d OVR. The player becomes untradeable." % [pl.name, fin.ovr], 14), 240)]), [["Start Evolution", true, "Primary"], ["Cancel", null, ""]])
	if ok and Event.start_evo(u): Sfx.play("reveal"); UI.replace("event", {"tab": "evo"})

# ------------------------------------------------------------------ store
func _store(body: VBoxContainer) -> void:
	var flow = HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 16); flow.add_theme_constant_override("v_separation", 16)
	var first = true
	for it in Event.STORE:
		var r: Dictionary = it.reward
		var vis: Control
		if r.has("pack"): vis = UI.icon("pack", r.pack, Vector2(90, 126)); vis.animate = false
		elif r.has("player"): vis = UI.card(Data.P(r.player), 7.0)
		else: vis = UI.head("●", 60, UI.GOLD2)
		var hold = CenterContainer.new(); hold.custom_minimum_size = Vector2(180, 130); hold.add_child(vis)
		var left = "" if int(it.limit) == 0 else "  ·  %d left" % (int(it.limit) - Event.bought(it.id))
		var ok: bool = Event.can_buy(it)
		var t = UI.tile([hold, UI.bold(it.name, 16), UI.bold("★ %s%s" % [Sys.fmt(it.cost), left], 14, TOK if ok else UI.DIM)],
			func():
				if int(it.limit) > 0 and Event.bought(it.id) >= int(it.limit): UI.toast("Sold out", "bad"); return
				if Event.tokens() < int(it.cost): UI.toast("Not enough Star Tokens — complete event objectives and SBCs", "bad"); Sfx.play("error"); return
				if await UI.modal("Buy %s?" % it.name, "Spend ★ %s Star Tokens?" % Sys.fmt(it.cost), [["Buy", true, "Primary"], ["Cancel", null, ""]]):
					if Event.buy(it): Sfx.play("coin"); UI.replace("event", {"tab": "store"}), Vector2(220, 240), first)
		if not ok: t.modulate = Color(1, 1, 1, 0.7)
		flow.add_child(t); first = false
	body.add_child(UI.scroll(flow))
