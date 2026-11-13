extends RefCounted
## SBC menu as a carousel of tall glass tiles (FC-style), the Gem SBC builder
## ("select & submit pre-filtered players until you reach the score") and its intro.

const GEM := Color("#5fe3c8")
const CATS := ["Exchanges", "POTM", "Foundations", "Upgrades", "Challenges", "Players", "Rising Stars"]

func gem_text(n: int) -> String: return "◆ " + Sys.fmt(n)

func _glass(focused := false) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.62, 0.68, 0.76, 0.32) if focused else Color(0.22, 0.27, 0.34, 0.62)
	sb.set_corner_radius_all(8); sb.border_color = Color(1, 1, 1, 0.85) if focused else Color(1, 1, 1, 0.06); sb.set_border_width_all(2 if focused else 1)
	sb.content_margin_left = 18; sb.content_margin_right = 18; sb.content_margin_top = 18; sb.content_margin_bottom = 14
	return sb

func _reward_art(r: Dictionary, big := true) -> Control:
	if r.has("player"):
		var c = UI.card(Data.P(r.player), 9.5 if big else 6.0); c.focus_mode = Control.FOCUS_NONE; return c
	if r.has("pack"):
		var i = UI.icon("pack", r.pack, Vector2(112, 158) if big else Vector2(70, 98)); i.animate = false; i.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; return i
	var coin = Control.new(); coin.custom_minimum_size = Vector2(120, 120)
	coin.draw.connect(func():
		var ctr = coin.size / 2
		coin.draw_circle(ctr, 52, Color("#c3901c")); coin.draw_circle(ctr, 44, Color("#1b1b1b")); coin.draw_arc(ctr, 48, 0, TAU, 40, Color("#ffe08a"), 4)
		Gfx.text_c(coin, UI.font_head, ctr.x, ctr.y + 10, "PF", 30, Color("#f3d88a"))
		coin.draw_colored_polygon(PackedVector2Array([ctr + Vector2(40, -30), ctr + Vector2(58, -52), ctr + Vector2(64, -24)]), Color("#3fe0a0")))
	return coin

func _reward_name(r: Dictionary) -> String:
	if r.has("player"): var p = Data.P(r.player); return "%d %s (%s)" % [p.ovr, p.name, Data.rarity_name(p)]
	var parts = []
	if r.has("pack"): parts.append(Data.packs[r.pack].name + " (Untradeable)")
	if r.get("coins", 0): parts.append("%s Coins" % Sys.fmt(r.coins))
	if r.get("tokens", 0): parts.append("%d Star Tokens" % r.tokens)
	return " + ".join(parts)

func s_sbc(p) -> Dictionary:
	var f = UI.hub_shell("sbc")
	var cat: String = p.get("cat", "Exchanges")
	if cat == "Exchanges" and not Save.data.sbc.get("intro_seen", false):
		Save.data.sbc.intro_seen = true; Save.dirty()
		UI.go.call_deferred("sbcintro")
	var segs = CATS.map(func(c): return [c, c + (" ◆" if c == "Exchanges" else "")])
	f.body.add_child(UI.hb(10, [UI.head("SBC", 38), UI.label("Exchange players to upgrade your squad", 15, UI.DIM), UI.spacer(), UI.btn("How it works", func(): UI.go("sbcintro"), "Small"), UI.seg(segs, cat, func(v): UI.replace("sbc", {"cat": v}))]))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 14)
	var first = true
	var list: Array = Data.sbcs.filter(func(x): return x.cat == cat)
	list.sort_custom(func(a, b): return int(Sys.sbc_available(a)) > int(Sys.sbc_available(b)))
	for s in list: row.add_child(_tile(s, cat, first)); first = false
	if list.is_empty(): row.add_child(UI.label("No SBCs in this category right now.", 15, UI.DIM))
	var sc = UI.scroll(row, true); sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	f.body.add_child(sc)
	return {"node": f.node, "bg": "hub", "tab": "sbc", "back": func(): UI.reset("main")}

func _tile(s: Dictionary, cat: String, focus: bool) -> Control:
	var n: int = Sys.sbc_count(s.id); var av: bool = Sys.sbc_available(s)
	var rep: int = int(s.repeat)
	var b = Button.new(); b.focus_mode = Control.FOCUS_ALL; b.custom_minimum_size = Vector2(300, 470)
	for st in ["normal", "hover", "pressed", "disabled", "hover_pressed"]: b.add_theme_stylebox_override(st, _glass(false))
	b.add_theme_stylebox_override("focus", _glass(true))
	var v = UI.vb(10)
	var title = UI.wrapl(UI.bold(s.name, 19), 250); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.custom_minimum_size.y = 52
	v.add_child(title)
	var art = CenterContainer.new(); art.custom_minimum_size.y = 190; art.add_child(_reward_art(s.reward)); v.add_child(art)
	var rn = UI.wrapl(UI.label(_reward_name(s.reward), 14), 250); rn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(rn)
	var sub = UI.wrapl(UI.label(GemSBC.filter_text(s) if s.get("gem", false) else s.desc, 12, UI.DIM), 250); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(sub)
	v.add_child(UI.vspacer())
	var bottom = UI.vb(4)
	if rep >= 2: var rl = UI.label(("↻ Repeatable" if rep >= 99 else "↻ %d / %d" % [n, rep]), 14); rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bottom.add_child(rl)
	var main_l: Label
	if not av: main_l = UI.bold("✓ Completed", 18, UI.GREEN)
	elif s.get("gem", false): main_l = UI.bold(gem_text(int(s.target)), 20, GEM)
	else: main_l = UI.bold("%d/%d Completed" % [n, max(1, min(rep, 3) if rep < 99 else 1)] if rep < 99 else "%d Completed" % n, 18)
	main_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bottom.add_child(main_l)
	var bar = UI.bar(n, max(1, rep if rep < 99 else 1)); bar.custom_minimum_size.y = 6; bottom.add_child(bar)
	v.add_child(bottom)
	var m = MarginContainer.new(); m.set_anchors_preset(Control.PRESET_FULL_RECT); m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + k, 16)
	m.add_child(v); b.add_child(m); UI._ignore_mouse(m)
	if not av: b.modulate = Color(1, 1, 1, 0.55)
	b.pressed.connect(func():
		Sfx.play("select")
		if not Sys.sbc_available(s): UI.toast("Already completed"); return
		if s.get("gem", false): UI.go("gemsbc", {"id": s.id, "cat": cat})
		else: UI.go("sbcbuild", {"id": s.id, "cat": cat}))
	b.mouse_entered.connect(func(): if UI.mouse_recent() and not b.has_focus(): b.grab_focus())
	b.focus_entered.connect(func(): Sfx.play("move"); b.pivot_offset = b.size / 2; b.create_tween().tween_property(b, "scale", Vector2(1.03, 1.03), 0.12))
	b.focus_exited.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))
	if focus: b.set_meta("autofocus", true)
	return b

# ------------------------------------------------------------------ Gem SBC builder
func s_gemsbc(p) -> Dictionary:
	var sbc: Dictionary = {}
	for x in Data.sbcs: if x.id == p.id: sbc = x
	var f = UI.sub_shell(sbc.name, "SBC · " + p.get("cat", "Exchanges"))
	var sel: Array = p.get("sel", [])
	var inc_sq: bool = p.get("sq", false)
	var only_dupes: bool = p.get("dupes", false)
	var target: int = int(sbc.target)
	var tot: int = GemSBC.score(sel)
	var reload = func(extra := {}):
		var q = {"id": sbc.id, "cat": p.get("cat", "Exchanges"), "sel": sel, "sq": inc_sq, "dupes": only_dupes}
		q.merge(extra, true); UI.replace("gemsbc", q)
	# header: progress to target + reward
	var bar = UI.bar(min(tot, target), target, "GoldBar"); bar.custom_minimum_size = Vector2(520, 12)
	var done_col = UI.GREEN if tot >= target else GEM
	var head = UI.vb(6, [UI.hb(10, [UI.bold("Score", 15, UI.DIM), UI.head(Sys.fmt(tot), 34, done_col), UI.label("/ " + gem_text(target), 20, UI.DIM), UI.spacer(), UI.label("%d items selected · no item limit" % sel.size(), 14, UI.DIM)]), bar,
		UI.label(sbc.desc + "  ·  Eligible: " + GemSBC.filter_text(sbc), 13, UI.DIM)])
	head.custom_minimum_size.x = 560
	var submit = UI.btn("Submit (%s)" % ("ready" if tot >= target else "need %s more" % gem_text(target - tot)), func():
		if GemSBC.submit(sbc, sel):
			Sfx.play("bigreveal"); UI.toast("SBC complete! " + _reward_name(sbc.reward), "good")
			UI.replace("sbc", {"cat": p.get("cat", "Exchanges")}), "Primary", tot >= target)
	submit.disabled = tot < target
	f.body.add_child(UI.hb(20, [head, UI.spacer(), UI.vb(4, [_reward_art(sbc.reward, false), UI.wrapl(UI.label(_reward_name(sbc.reward), 12), 200)]), UI.vb(8, [submit,
		UI.hb(8, [UI.btn("Auto-fill (cheapest)", func(): sel = GemSBC.autofill(sbc, inc_sq); reload.call({"sel": sel}), "Small", tot < target), UI.btn("Clear", func(): reload.call({"sel": []}), "Small")])])]))
	# selected items (no limit — the row scrolls)
	var srow = HBoxContainer.new(); srow.add_theme_constant_override("separation", 8)
	for u0 in sel:
		var it = Sys.item(u0); var pl = Data.P(it.pid); var u: String = u0
		var c = UI.card(pl, 5.6, false, func(): sel.erase(u); reload.call({"sel": sel}))
		srow.add_child(UI.vb(1, [c, _gem_lab(pl)]))
	var e = PlayerCard.make({}, 5.6); e.empty_pos = "add"; e.focus_mode = Control.FOCUS_NONE
	srow.add_child(UI.vb(1, [e, UI.label(" ", 11)]))
	var ssc = UI.scroll(srow, true); ssc.custom_minimum_size.y = 118; ssc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	f.body.add_child(UI.panel(ssc))
	# pre-filtered club players
	var dupes = {}
	for it in Sys.duplicates(): dupes[it.uid] = true
	var items: Array = Save.data.club.filter(func(it): return GemSBC.eligible(sbc, it, inc_sq) and not sel.has(it.uid) and (not only_dupes or dupes.has(it.uid)))
	items.sort_custom(func(a, b): return Gallery.gems(Data.P(a.pid)) < Gallery.gems(Data.P(b.pid)))
	var ck = CheckBox.new(); ck.text = "Include players in my active squad"; ck.button_pressed = inc_sq; ck.toggled.connect(func(v): reload.call({"sq": v, "sel": sel}))
	var dk = CheckBox.new(); dk.text = "Duplicates only"; dk.button_pressed = only_dupes; dk.toggled.connect(func(v): reload.call({"dupes": v, "sel": sel}))
	f.body.add_child(UI.hb(14, [UI.bold("Pre-filtered players · %d eligible" % items.size(), 16), UI.label("Select to add · lowest gems first", 13, UI.DIM), UI.spacer(), dk, ck]))
	var grid = HFlowContainer.new(); grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 10)
	var add_all = UI.btn("Add all shown", func():
		for it in items.slice(0, 120): if not sel.has(it.uid): sel.append(it.uid)
		reload.call({"sel": sel}), "Small")
	f.body.get_child(f.body.get_child_count() - 1).add_child(add_all)
	for it in items.slice(0, 120):
		var pl = Data.P(it.pid); var u: String = it.uid
		var c = UI.card(pl, 5.2, false, func():
			if GemSBC.full(sel.size()): UI.toast("Max %d items" % GemSBC.MAX_ITEMS, "bad"); return
			sel.append(u); reload.call({"sel": sel}))
		c.untr = it.untr
		if dupes.has(u): c.tag = "DUPLICATE"
		grid.add_child(UI.vb(1, [c, _gem_lab(pl)]))
	if items.is_empty(): grid.add_child(UI.label("No eligible players in your club for this SBC.", 14, UI.DIM))
	f.body.add_child(UI.scroll(grid))
	return {"node": f.node, "bg": "hub", "back": func(): UI.replace("sbc", {"cat": p.get("cat", "Exchanges")})}

func _gem_lab(pl: Dictionary) -> Label:
	var l = UI.bold("◆ %d" % Gallery.gems(pl), 12, GEM); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; return l

# ------------------------------------------------------------------ intro (3 steps)
func s_sbcintro(_p) -> Dictionary:
	var page = Control.new(); page.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bgc = ColorRect.new(); bgc.set_anchors_preset(Control.PRESET_FULL_RECT); bgc.color = Color("#0d3550"); page.add_child(bgc)
	var glow = Control.new(); glow.set_anchors_preset(Control.PRESET_FULL_RECT); page.add_child(glow)
	glow.draw.connect(func():
		var W = glow.size.x; var H = glow.size.y
		for i in 30: glow.draw_rect(Rect2(W * i / 30.0, 0, W / 30.0 + 1, H), Color(0.05, 0.18 + 0.12 * i / 30.0, 0.32 + 0.05 * sin(i * 0.2), 1.0))
		glow.draw_colored_polygon(PackedVector2Array([Vector2(W * 0.6, H), Vector2(W, H * 0.3), Vector2(W, H * 0.5), Vector2(W * 0.75, H)]), Color(0.3, 0.9, 0.8, 0.12)))
	var v = UI.vb(18); v.set_anchors_preset(Control.PRESET_FULL_RECT); v.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(v)
	var t = UI.head("SBC", 44); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var st = UI.label("Exchange players to upgrade your Squad", 19); st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(st)
	var row = UI.hb(70); row.alignment = BoxContainer.ALIGNMENT_CENTER
	var silhouette = func(col: Color, w := 56.0) -> Control:
		var c = Control.new(); c.custom_minimum_size = Vector2(w, w * 1.4)
		c.draw.connect(func(): var r = Rect2(Vector2(2, 2), c.size - Vector2(4, 4)); c.draw_colored_polygon(Gfx.shield(r), col)); return c
	# step 1: items with scores
	var s1 = UI.hb(-18)
	var vals = [["silver", Color("#cfd6de"), 240], ["gold", Color("#f0c94e"), 360], ["special", Color("#2a2a2a"), 860]]
	var s1v = UI.vb(8, [s1]); var s1n = UI.hb(30)
	for x in vals: s1.add_child(silhouette.call(x[1], 92.0)); s1n.add_child(UI.bold("◆ %d" % x[2], 18, GEM))
	s1v.add_child(s1n)
	# step 2: select & submit
	var g2 = GridContainer.new(); g2.columns = 5; g2.add_theme_constant_override("h_separation", 6); g2.add_theme_constant_override("v_separation", 6)
	for c in [Color("#e2a06a"), Color("#e2a06a"), Color("#e2a06a"), Color("#cfd6de"), Color("#cfd6de"), Color("#cfd6de"), Color("#cfd6de"), Color("#f0c94e"), Color("#f0c94e"), Color("#2a2a2a")]: g2.add_child(silhouette.call(c, 44.0))
	var b2 = UI.bar(55, 100, "GoldBar"); b2.custom_minimum_size = Vector2(240, 8)
	# step 3: reward
	var g3 = GridContainer.new(); g3.columns = 3; g3.add_theme_constant_override("h_separation", 6); g3.add_theme_constant_override("v_separation", 6)
	for c in [Color("#efe7dd"), Color("#efe7dd"), Color("#efe7dd"), Color("#efe7dd"), Color("#f0c94e"), Color("#f0c94e")]: g3.add_child(silhouette.call(c, 44.0))
	var pk = UI.icon("pack", "rare", Vector2(84, 130)); pk.animate = false
	var b3 = UI.bar(100, 100, "GoldBar"); b3.custom_minimum_size = Vector2(240, 8)
	row.add_child(UI.vb(10, [UI.label(" ", 8), s1v]))
	row.add_child(UI.vb(10, [b2, g2]))
	row.add_child(UI.vb(10, [b3, UI.hb(10, [g3, pk])]))
	v.add_child(row)
	var line = ColorRect.new(); line.custom_minimum_size = Vector2(0, 2); line.color = Color(0.4, 1, 0.85, 0.5); v.add_child(line)
	var steps = UI.hb(120); steps.alignment = BoxContainer.ALIGNMENT_CENTER
	for s in [["Review Players", "Items have an assigned Score."], ["Select & Submit Players", "Select and submit pre-filtered players\nfrom your Club."], ["Get Your Reward", "Reach the score to complete the SBC\nand get your reward."]]:
		var col = UI.vb(6, [UI.label("◉", 26, Color("#3fe0a0")), UI.bold(s[0], 20), UI.label(s[1], 14, UI.DIM)])
		for c in col.get_children(): c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.custom_minimum_size.x = 300
		steps.add_child(col)
	v.add_child(steps)
	var adv = UI.btn("%s  Advance" % Pad.glyph("A"), func(): UI.replace("sbc", {"cat": "Exchanges"}), "Primary", true)
	adv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(adv)
	return {"node": page, "bg": "off", "back": func(): UI.replace("sbc", {"cat": "Exchanges"})}
