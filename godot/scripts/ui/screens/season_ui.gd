extends RefCounted
## Season Pass screen (Free + Premium tracks) and the Player Pick screen.

const COL_W := 150

func page_title(t: String) -> Label: return UI.head(t.to_upper(), 38)

# ------------------------------------------------------------------ SEASON PASS
func s_season(p) -> Dictionary:
	var f = UI.hub_shell("season")
	var lv: int = Season.level()
	var maxed: bool = lv >= Season.LEVELS
	# ---- header: title, level & XP, actions
	var lvbox = UI.vb(4, [UI.hb(8, [UI.bold("Level %d / %d" % [lv, Season.LEVELS], 15), UI.spacer(),
		UI.label(("%s XP to next level" % Sys.fmt(Season.XP_PER - Season.level_xp())) if not maxed else "Max level · bonus levels pay %s coins" % Sys.fmt(Season.OVERFLOW_COINS), 13, UI.DIM)]),
		UI.bar(Season.level_xp() if not maxed else Season.XP_PER, Season.XP_PER, "GoldBar")])
	lvbox.custom_minimum_size.x = 340
	var acts = UI.hb(10)
	var n_claim: int = Season.claim_count()
	var cb = UI.btn("Claim all (%d)" % n_claim, func():
		var n = Season.claim_all()
		if n: Sfx.play("reveal")
		UI.replace("season"), "Primary")
	cb.disabled = n_claim == 0; acts.add_child(cb)
	if not Season.premium():
		acts.add_child(UI.btn("Unlock Premium  ◆ %s" % Sys.fmt(Season.PREMIUM_COST), func(): _unlock_dialog(), "" if n_claim else "Primary"))
	if not maxed:
		acts.add_child(UI.btn("Buy level  ◆ %d" % Season.LEVEL_COST, func():
			if Season.buy_level(): UI.replace("season", {"focus": Season.level()}), "Small"))
	f.body.add_child(UI.hb(16, [UI.vb(0, [page_title("Season Pass"), UI.bold(Season.NAME, 14, Color("#ff8a5c"))]), UI.spacer(), lvbox, acts]))
	# ---- Ascension showcase
	var show = UI.hb(10)
	var asc_lv = []
	for tr in [["free", Season.FREE], ["prem", Season.PREM]]:
		for l in tr[1]:
			if tr[1][l].has("player"): asc_lv.append([l, tr[0], Data.P(tr[1][l].player)])
	asc_lv.sort_custom(func(a, b): return a[0] < b[0])
	for a in asc_lv:
		var pl: Dictionary = a[2]
		var c = UI.card(pl, 5.6, false, func(): UI.inspect(pl))
		show.add_child(UI.vb(2, [c, UI.caps("LV %d · %s" % [a[0], "FREE" if a[1] == "free" else "PREMIUM"], 9, Color("#ffc76b") if a[1] == "prem" else UI.DIM)]))
	var fin = UI.vb(2)
	var fh = UI.hb(4)
	for pl in Data.ascension_finale: fh.add_child(UI.card(pl, 4.2, false, func(): UI.inspect(pl)))
	fin.add_child(fh); fin.add_child(UI.caps("LV 50 PREMIUM · PICK 1 OF 3", 9, Color("#ffc76b")))
	show.add_child(fin)
	var blurb = UI.vb(4, [UI.head("ASCENSION", 30, Color("#ff7a45")), UI.wrapl(UI.label("A brand-new rarity you can only earn from the Season Pass — boosted cards with +1 skill move and weak foot star. Not in packs, not on the market.", 13, UI.DIM), 230)])
	blurb.custom_minimum_size.x = 240
	var banner = UI.panel(UI.hb(18, [blurb, UI.scroll(show, true)]))
	banner.get_child(0).get_child(1).custom_minimum_size.y = 128
	f.body.add_child(banner)
	# ---- the track
	var row = UI.hb(10)
	var lab_col = UI.vb(10, [UI.caps(" ", 11), _track_label("FREE", UI.DIM), _track_label("PREMIUM", Color("#ffc76b"))])
	var focus_lv: int = int(p.get("focus", 0))
	if focus_lv == 0:
		focus_lv = clamp(lv + 1, 1, Season.LEVELS)
		for l in range(1, lv + 1):
			if Season.can_claim(l, "free") or Season.can_claim(l, "prem"): focus_lv = l; break
	for l in range(1, Season.LEVELS + 1):
		var col = UI.vb(10)
		var reached: bool = l <= lv
		var lc = UI.TEXT if reached else UI.DIM
		col.add_child(UI.hb(4, [UI.spacer(), UI.bold("LEVEL %d" % l, 12, lc if l != lv else UI.TEAL), UI.spacer()]))
		col.add_child(_reward_tile(l, "free", l == focus_lv))
		col.add_child(_reward_tile(l, "prem", false))
		row.add_child(col)
	var sc = UI.scroll(row, true)
	f.body.add_child(UI.hb(10, [lab_col, sc]))
	UI.grow(f.body.get_child(-1))
	f.body.add_child(UI.label("Earn Season XP: match win 450 · draw 300 · loss 200 · objectives 150–600 · SBCs 300. Prime Points are free in-game credits — no real money.", 12, UI.DIM))
	# jump the track to the focused level
	var jump = func():
		await UI.get_tree().process_frame
		if is_instance_valid(sc): sc.scroll_horizontal = max(0, (focus_lv - 3) * (COL_W + 10))
	jump.call()
	return {"node": f.node, "bg": "hub", "tab": "season", "back": func(): UI.reset("main")}

func _track_label(t: String, c: Color) -> Control:
	var l = UI.bold(t, 13, c); l.custom_minimum_size = Vector2(84, 186); l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _reward_tile(l: int, track: String, focus: bool) -> Control:
	var r: Dictionary = Season.reward(l, track)
	var claimable: bool = Season.can_claim(l, track)
	var done: bool = Season.claimed(l, track)
	var locked_prem: bool = track == "prem" and not Season.premium()
	var kids = []
	var vis: Control
	if r.has("player"):
		vis = UI.card(Data.P(r.player), 6.4)
	elif r.has("pack"):
		vis = UI.icon("pack", r.pack, Vector2(68, 96)); vis.animate = false
	elif r.get("coins", 0):
		vis = UI.head("●", 52, UI.GOLD2)
	else:
		vis = UI.head("◆", 52, UI.TEAL)
	var hold = CenterContainer.new(); hold.custom_minimum_size = Vector2(COL_W - 40, 110); hold.add_child(vis)
	kids.append(hold)
	var nm = UI.wrapl(UI.bold(Season.reward_label(r), 12), COL_W - 40); nm.custom_minimum_size.y = 34
	kids.append(nm)
	var status: String; var sc: Color
	if done: status = "✓ CLAIMED"; sc = UI.DIM
	elif claimable: status = "CLAIM"; sc = UI.GREEN
	elif locked_prem: status = "PREMIUM"; sc = Color("#ffc76b")
	else: status = "LEVEL %d" % l; sc = UI.DIM
	kids.append(UI.caps(status, 11, sc))
	var t = UI.tile(kids, func(): _tile_pressed(l, track), Vector2(COL_W, 186), focus)
	t.custom_minimum_size.x = COL_W
	if done: t.modulate = Color(1, 1, 1, 0.45)
	elif not claimable and (l > Season.level() or locked_prem): t.modulate = Color(1, 1, 1, 0.72)
	if claimable:
		var glow = StyleBoxFlat.new(); glow.bg_color = Color(0.18, 0.85, 0.5, 0.12); glow.border_color = UI.GREEN; glow.set_border_width_all(2); glow.set_corner_radius_all(10)
		t.add_theme_stylebox_override("normal", glow)
	elif r.has("player"):
		var asc = StyleBoxFlat.new(); asc.bg_color = Color(0.55, 0.06, 0.14, 0.25); asc.border_color = Color("#ff7a45"); asc.set_border_width_all(1); asc.set_corner_radius_all(10)
		t.add_theme_stylebox_override("normal", asc)
	return t

func _tile_pressed(l: int, track: String) -> void:
	var r: Dictionary = Season.reward(l, track)
	if Season.can_claim(l, track):
		Season.claim(l, track); Sfx.play("reveal")
		UI.replace("season", {"focus": l})
		return
	if track == "prem" and not Season.premium() and not Season.claimed(l, track):
		_unlock_dialog(); return
	if r.has("player"):
		await UI.inspect(Data.P(r.player))
	elif r.has("pack"):
		var pk: Dictionary = Data.packs[r.pack]
		await UI.modal(pk.name, UI.hb(20, [UI.icon("pack", r.pack, Vector2(100, 140)), UI.wrapl(UI.label(pk.desc + ("\n\nReach Season Pass Level %d to claim." % l if l > Season.level() else ""), 15), 320)]))
	elif l > Season.level():
		UI.toast("Reach Season Pass Level %d to claim this reward" % l)

func _unlock_dialog() -> void:
	var body = UI.vb(8, [UI.wrapl(UI.label("Unlock the Premium track for %s Prime Points. You instantly get every Premium reward up to your current level, including 82+ x5 and 83+ x2 packs, Player Picks and 6 exclusive Ascension cards." % Sys.fmt(Season.PREMIUM_COST), 15), 520),
		UI.label("Balance: ◆ %s  (Prime Points are free in-game credits)" % Sys.fmt(Save.data.points), 13, UI.DIM)])
	var v = await UI.modal("Unlock Premium Season Pass?", body, [["Unlock  ◆ %s" % Sys.fmt(Season.PREMIUM_COST), true, "Primary"], ["Cancel", null, ""]])
	if v and Season.unlock_premium(): Sfx.play("bigreveal"); UI.replace("season")

# ------------------------------------------------------------------ PLAYER PICK
func start_pick(id: String) -> void:
	if Save.data.get("pick_cur") != null:
		Save.data.unopened.append(id); Save.dirty()
		UI.toast("Finish your current Player Pick first", "bad"); UI.go("pick"); return
	var pk: Dictionary = Data.packs[id]
	var pool: Array = Sys.tier_pool(pk.pick.tier).duplicate()
	var pids = []
	var tries = 0
	while pids.size() < int(pk.pick.n) and tries < 200:
		tries += 1
		var pl: Dictionary = Sys.roll_tier(pk.pick.tier)
		if not pids.has(pl.id): pids.append(pl.id)
	Save.data.pick_cur = {"pack": id, "pids": pids}
	Save.data.stats.packs += 1; Sys.track("pack")
	Save.write_now()
	UI.go("pick")

func s_pick(_p) -> Dictionary:
	var cur = Save.data.get("pick_cur")
	var f = UI.sub_shell(Data.packs[cur.pack].name if cur else "Player Pick", "Season Pass reward", true)
	if cur == null:
		f.body.add_child(UI.label("No player pick in progress.", 16, UI.DIM))
		return {"node": f.node, "bg": "hub", "back": func(): UI.replace("store", {"tab": "mine"})}
	f.body.add_child(UI.vb(4, [UI.head("CHOOSE YOUR PLAYER", 36), UI.label("Pick 1 of %d — the others are released. The player you pick is untradeable." % cur.pids.size(), 15, UI.DIM)]))
	var row = UI.hb(46); row.alignment = BoxContainer.ALIGNMENT_CENTER
	var i = 0
	for pid in cur.pids:
		var pl: Dictionary = Data.P(pid)
		var c = UI.card(pl, 14.0, false, func(): _choose(pl))
		if i == 0: c.set_meta("autofocus", true)
		var col = UI.vb(10, [c, UI.hb(4, [UI.spacer(), UI.bold(pl.name, 16), UI.spacer()]), UI.hb(4, [UI.spacer(), UI.label(Data.rarity_name(pl) + " · " + pl.pos, 13, UI.DIM), UI.spacer()])])
		col.modulate.a = 0.0
		var tw = col.create_tween(); tw.tween_interval(0.25 + i * 0.35); tw.tween_property(col, "modulate:a", 1.0, 0.35)
		row.add_child(col); i += 1
	var cc = CenterContainer.new(); UI.grow(cc); cc.add_child(row)
	f.body.add_child(cc)
	Sfx.play("riser")
	return {"node": f.node, "bg": "hub", "back": func(): UI.toast("Choose a player first — your pick is saved", "bad")}

func _choose(pl: Dictionary) -> void:
	var v = await UI.inspect(pl, [["Choose %s" % Data.short_name(pl.name), "pick", "Primary"]])
	if v != "pick": return
	var cur = Save.data.get("pick_cur")
	if cur == null: return
	Save.data.pick_cur = null
	Sys.club_add(pl.id, true, "pick")
	Sys.history("Picked %d %s from %s" % [pl.ovr, pl.name, Data.packs[cur.pack].name])
	Save.write_now()
	Sfx.play("bigreveal"); UI.toast("%d %s joined your club" % [pl.ovr, pl.name], "good")
	UI.reset("store", {"tab": "mine" if not Save.data.unopened.is_empty() else "packs"})
