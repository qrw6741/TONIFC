extends RefCounted
## Gallery screens: overview (per league), set detail (album + grading) and Token Store.

const GEM := Color("#ff6fd8")
const TOKEN := Color("#9fe8ff")
const GRADE_COL := {"–": Color(1, 1, 1, 0.35), "D": Color("#b07a4f"), "C": Color("#b9c1cb"), "B": Color("#e0be62"), "A": Color("#3fe0c5"), "S": Color("#ff6fd8")}

func page_title(t: String) -> Label: return UI.head(t.to_upper(), 38)
func gem_text(n: int) -> String: return "✦ %s" % Sys.fmt(n)

func _back() -> Callable: return func(): UI.replace("club")

func _header(f: Dictionary, title: String) -> void:
	var lv: int = Gallery.level()
	var tot: int = Gallery.total_score()
	var into: int = tot - lv * Gallery.LEVEL_PTS
	var lvbox = UI.vb(4, [UI.hb(8, [UI.bold("Gallery Level %d / %d" % [lv, Gallery.MAX_LEVEL], 15), UI.spacer(), UI.label(("%s / %s gems to next" % [Sys.fmt(into), Sys.fmt(Gallery.LEVEL_PTS)]) if lv < Gallery.MAX_LEVEL else "Max level", 13, UI.DIM)]),
		UI.bar(into if lv < Gallery.MAX_LEVEL else 1, Gallery.LEVEL_PTS if lv < Gallery.MAX_LEVEL else 1, "GoldBar")])
	lvbox.custom_minimum_size.x = 330
	var nxt = lv + 1
	var nr = ("Next milestone: " + _milestone_text()) if lv < Gallery.MAX_LEVEL else ""
	f.body.add_child(UI.hb(16, [UI.vb(0, [page_title(title), UI.label(nr, 13, UI.DIM)]), UI.spacer(), lvbox,
		UI.panel(UI.vb(0, [UI.caps("Gallery Tokens", 10), UI.head("◈ " + Sys.fmt(Gallery.tokens()), 24, TOKEN)]), "Glass")]))

func _milestone_text() -> String:
	for l in range(Gallery.level() + 1, Gallery.MAX_LEVEL + 1):
		if l % 5 == 0: return "Level %d · %s" % [l, Sys.reward_text(Gallery.level_reward(l))]
	return ""

# ------------------------------------------------------------------ OVERVIEW
func s_gallery(p) -> Dictionary:
	Gallery.check_level()
	var f = UI.sub_shell("Gallery", "Ultimate XI · Club")
	var lg: String = p.get("lg", "ENG1")
	_header(f, "Gallery")
	var claim_n = Gallery.set_ids().filter(func(id): return Gallery.claimable(id)).size()
	var segs = Gallery.LEAGUES.map(func(l): return [l, Data.leagues[l].name + (" •" if Gallery.claimable("L:" + l) or Gallery.top_clubs[l].any(func(c): return Gallery.claimable("C:" + c)) else "")])
	var gb = UI.btn("Grade all (%d)" % claim_n, func():
		var r = Gallery.grade_all()
		if r.sets: Sfx.play("reveal"); UI.toast("Graded %d sets · +%s Gallery Tokens" % [r.sets, Sys.fmt(r.tokens)], "good")
		Gallery.check_level(); UI.replace("gallery", {"lg": lg}), "Primary")
	gb.disabled = claim_n == 0
	f.body.add_child(UI.hb(10, [UI.seg(segs, lg, func(v): UI.replace("gallery", {"lg": v})), UI.spacer(), gb, UI.btn("Token Store", func(): UI.go("gallerystore"), "" if claim_n else "Primary"), UI.btn("How it works", func(): _help(), "Small")]))
	var grid = GridContainer.new(); grid.columns = 4; grid.add_theme_constant_override("h_separation", 14); grid.add_theme_constant_override("v_separation", 14)
	var first = true
	for id in ["L:" + lg] + Gallery.top_clubs[lg].map(func(c): return "C:" + c):
		grid.add_child(_set_tile(id, first)); first = false
	f.body.add_child(UI.scroll(grid))
	return {"node": f.node, "bg": "hub", "back": _back()}

func _set_tile(id: String, focus: bool) -> Control:
	var sc = Gallery.score(id)
	var code = id.substr(2)
	var is_lg: bool = id.begins_with("L:")
	var g = Gallery.grade_letter(sc.grade)
	var em = UI.icon("league" if is_lg else "crest", code, Vector2(46, 46))
	var gl = UI.head(g, 46, GRADE_COL[g])
	var nslots = Gallery.set_slots(id)
	var bar_v: float; var bar_m: float; var sub: String
	if not sc.full:
		bar_v = sc.items.size(); bar_m = nslots; sub = "%d / %d players collected" % [sc.items.size(), nslots]
	elif sc.next > 0:
		bar_v = sc.total; bar_m = sc.next; sub = "%s / %s gems to %s" % [Sys.fmt(sc.total), Sys.fmt(sc.next), Gallery.GRADES[sc.grade + 1]]
	else:
		bar_v = 1; bar_m = 1; sub = "Top grade reached"
	var claim: bool = Gallery.claimable(id)
	var kids = [UI.hb(10, [em, UI.vb(0, [UI.caps("League set" if is_lg else "Club set", 10), UI.bold(Gallery.set_title(id), 18)]), UI.spacer(), gl]),
		UI.label(gem_text(sc.total) + " gems" + (("  ·  +%d%% bonus" % sc.pct) if sc.pct else ""), 14, GEM),
		UI.bar(bar_v, bar_m), UI.label(sub, 12, UI.DIM),
		UI.caps("GRADE TO CLAIM ◈ TOKENS" if claim else "%d slots · %d players in album" % [nslots, Gallery.album(id).size()], 10, UI.GREEN if claim else UI.DIM)]
	var t = UI.tile(kids, func(): UI.go("galleryset", {"id": id}), Vector2(300, 196), focus)
	if claim:
		var glow = StyleBoxFlat.new(); glow.bg_color = Color(0.18, 0.85, 0.5, 0.1); glow.border_color = UI.GREEN; glow.set_border_width_all(2); glow.set_corner_radius_all(10)
		t.add_theme_stylebox_override("normal", glow)
	return t

func _help() -> void:
	var txt = """Every player item you get from packs, rewards, picks or the market is recorded in your Gallery forever — even after you sell or quick sell it.

Each item is worth GEMS based on its rating and rarity (special cards are worth much more). Every set automatically uses your best recorded items: 15 for a league set, 11 for a club set.

Set score = gems + bonus tags (Special items, First Owner, Golden, Same Nation). Fill every slot for grade D, then climb C → B → A → S. Each new grade pays Gallery Tokens and coins once.

Your total score across all sets raises your Gallery Level — milestone rewards every 5 levels, up to an Icon Player Pick at Level 25. Spend tokens in the Token Store."""
	await UI.modal("How the Gallery works", UI.wrapl(UI.label(txt, 14), 620), [["Got it", true, "Primary"]])

# ------------------------------------------------------------------ SET DETAIL
func s_galleryset(p) -> Dictionary:
	var id: String = p.id
	var f = UI.sub_shell(Gallery.set_title(id), "Gallery · " + ("League set" if id.begins_with("L:") else "Club set"))
	var sc = Gallery.score(id)
	var g = Gallery.grade_letter(sc.grade)
	var claim: bool = Gallery.claimable(id)
	var gbtn = UI.btn("Grade set  ·  ◈ claim" if claim else "Graded %s" % g, func():
		var r = Gallery.grade(id)
		if r.tokens: Sfx.play("bigreveal"); UI.toast("Grade %s! +%s Gallery Tokens · +%s coins" % [Gallery.GRADES[r.grade], Sys.fmt(r.tokens), Sys.fmt(r.coins)], "good")
		UI.replace("galleryset", {"id": id}), "Primary", claim)
	gbtn.disabled = not claim
	# grade ladder
	var ladder = UI.hb(8)
	var mx = Gallery.max_score(id)
	for i in Gallery.GRADES.size():
		var gg = Gallery.GRADES[i]
		var need = "Fill all slots" if i == 0 else "%s gems" % Sys.fmt(int(Gallery.GRADE_FRAC[i] * mx))
		var got = Gallery.claimed_grade(id) >= i
		var pn = UI.panel(UI.vb(0, [UI.head(gg, 26, GRADE_COL[gg] if sc.grade >= i else Color(1, 1, 1, 0.3)), UI.label(need, 11, UI.DIM), UI.label(("✓ claimed" if got else "◈ %d" % Gallery.set_tokens(id)[i]), 11, UI.DIM if got else TOKEN)]), "Glass")
		pn.custom_minimum_size.x = 104; ladder.add_child(pn)
	var tagbox = UI.vb(3, [UI.caps("Bonus tags", 10)])
	for t in sc.tags: tagbox.add_child(UI.label(("✓ +%d%%  " % t[1] if t[2] else "·  ") + t[0], 12, UI.GREEN if t[2] else UI.DIM))
	var scorebox = UI.vb(2, [UI.caps("Set score", 10), UI.head(gem_text(sc.total), 30, GEM), UI.label("%s base + %d%% bonus" % [Sys.fmt(sc.base), sc.pct], 12, UI.DIM)])
	f.body.add_child(UI.hb(18, [UI.head(g, 64, GRADE_COL[g]), scorebox, ladder, tagbox, UI.spacer(), gbtn]))
	# slots (best recorded items)
	var slots = UI.hb(8)
	for i in Gallery.set_slots(id):
		if i < sc.items.size():
			var pl: Dictionary = sc.items[i]
			var c = UI.card(pl, 5.0, false, func(): UI.inspect(pl))
			slots.add_child(UI.vb(2, [c, _gem_lab(pl)]))
		else:
			var e = PlayerCard.make({}, 5.0); e.empty_pos = "?"; e.focus_mode = Control.FOCUS_NONE
			slots.add_child(UI.vb(2, [e, UI.label("empty", 11, UI.DIM)]))
	f.body.add_child(UI.vb(4, [UI.caps("Your best %d recorded items — used automatically" % Gallery.set_slots(id), 10), UI.scroll(slots, true)]))
	f.body.get_child(-1).get_child(1).custom_minimum_size.y = 112
	# album
	var alb: Array = Gallery.album(id)
	var owned = alb.filter(func(x): return Gallery.seen(x.id)).size()
	var grid = HFlowContainer.new(); grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 10)
	var show: Array = alb if alb.size() <= 120 else alb.filter(func(x): return Gallery.seen(x.id) or x.ovr >= 80)
	for pl in show:
		var have: bool = Gallery.seen(pl.id)
		var c = UI.card(pl, 4.6, true, func(): UI.inspect(pl))
		if not have: c.modulate = Color(0.35, 0.35, 0.4, 0.55)
		var lab = _gem_lab(pl) if have else UI.label("✦ " + Sys.fmt(Gallery.gems(pl)), 11, UI.DIM)
		grid.add_child(UI.vb(1, [c, lab]))
	f.body.add_child(UI.hb(10, [UI.caps("Album · %d / %d collected%s" % [owned, alb.size(), (" · showing collected + 80+ rated" if show.size() < alb.size() else "")], 10), UI.spacer(), UI.label("Greyed cards are not in your Gallery yet", 12, UI.DIM)]))
	f.body.add_child(UI.scroll(grid))
	return {"node": f.node, "bg": "hub", "back": func(): UI.replace("gallery", {"lg": Data.clubs[id.substr(2)].lg if id.begins_with("C:") else id.substr(2)})}

func _gem_lab(pl: Dictionary) -> Control:
	var l = UI.bold(("✦ " + Sys.fmt(Gallery.gems(pl))) + ("  1st" if Gallery.first_owner(pl.id) else ""), 11, GEM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

# ------------------------------------------------------------------ TOKEN STORE
func s_gallerystore(_p) -> Dictionary:
	var f = UI.sub_shell("Gallery Token Store", "Gallery")
	_header(f, "Token Store")
	var flow = HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 16); flow.add_theme_constant_override("v_separation", 16)
	var first = true
	for it in Gallery.STORE:
		var r: Dictionary = it.reward
		var vis: Control = UI.icon("pack", r.pack, Vector2(90, 126)) if r.has("pack") else UI.head("●", 60, UI.GOLD2)
		if vis is Icon: vis.animate = false
		var hold = CenterContainer.new(); hold.custom_minimum_size = Vector2(180, 130); hold.add_child(vis)
		var left = "" if int(it.limit) == 0 else "  ·  %d left" % (int(it.limit) - Gallery.bought(it.id))
		var ok: bool = Gallery.can_buy(it)
		var t = UI.tile([hold, UI.bold(it.name, 16), UI.label(Data.packs[r.pack].desc if r.has("pack") else "Coins for your club.", 12, UI.DIM), UI.bold("◈ %s%s" % [Sys.fmt(it.cost), left], 14, TOKEN if ok else UI.DIM)],
			func():
				if int(it.limit) > 0 and Gallery.bought(it.id) >= int(it.limit): UI.toast("Sold out", "bad"); return
				if Gallery.tokens() < int(it.cost): UI.toast("Not enough Gallery Tokens — grade more sets", "bad"); Sfx.play("error"); return
				if await UI.modal("Buy %s?" % it.name, "Spend ◈ %s Gallery Tokens?" % Sys.fmt(it.cost), [["Buy", true, "Primary"], ["Cancel", null, ""]]):
					if Gallery.buy(it): Sfx.play("coin"); UI.replace("gallerystore"), Vector2(220, 280), first)
		t.get_child(0).get_child(0).get_child(2).custom_minimum_size.x = 180
		(t.get_child(0).get_child(0).get_child(2) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not ok: t.modulate = Color(1, 1, 1, 0.7)
		flow.add_child(t); first = false
	f.body.add_child(UI.label("Earn Gallery Tokens by grading sets. Packs and picks go to My Packs in the Store.", 13, UI.DIM))
	f.body.add_child(UI.scroll(flow))
	return {"node": f.node, "bg": "hub", "back": func(): UI.replace("gallery")}
