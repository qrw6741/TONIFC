extends RefCounted
## Season Pass screen (Free + Premium tracks) and the Player Pick screen.

const COL_W := 150

func page_title(t: String) -> Label: return UI.head(t.to_upper(), 38)

# ------------------------------------------------------------------ SEASON PASS
## FC-style layout: big featured reward over hero art (left), season info panel (top right),
## purple level bars over a row of slanted reward tiles (bottom). Focusing a tile features it.
const TW := 170
const TH := 204
const SKEW := 16.0
const PURPLE := Color("#9b6bff")

func s_season(p) -> Dictionary:
	var f = UI.hub_shell("season")
	var lv: int = Season.level()
	var maxed: bool = lv >= Season.LEVELS
	var focus_lv: int = int(p.get("focus", 0))
	var focus_tr: String = str(p.get("track", ""))
	if focus_lv == 0:
		focus_lv = clamp(lv + 1, 1, Season.LEVELS)
		for l in range(1, lv + 1):
			if Season.can_claim(l, "prem"): focus_lv = l; focus_tr = "prem"; break
			if Season.can_claim(l, "free"): focus_lv = l; focus_tr = "free"; break
	if focus_tr == "": focus_tr = "prem"
	# ---- top: hero (left) + info panel (right)
	var hero = HeroArt.new(); UI.grow(hero)
	var feat = {"box": null}
	var hm = MarginContainer.new(); hm.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: hm.add_theme_constant_override("margin_" + side, 18)
	hm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fb = UI.hb(30); fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hm.add_child(fb); hero.add_child(hm); feat.box = fb
	var info = _info_panel(lv, maxed)
	var top = UI.hb(14, [hero, info]); UI.grow(top)
	f.body.add_child(top)
	# ---- bottom: the level track
	var row = UI.hb(22)
	var tiles = {}
	for l in range(1, Season.LEVELS + 1):
		var grp = UI.vb(8)
		var hdr = UI.hb(8, [UI.bold(str(l), 20, UI.TEXT if l <= lv else UI.DIM)])
		var fill: float = 1.0 if l <= lv else (float(Season.level_xp()) / Season.XP_PER if l == lv + 1 else 0.0)
		var lb = LevelBar.new(); lb.v = fill; lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hdr.add_child(lb)
		grp.add_child(hdr)
		var pair = UI.hb(6)
		for tr in ["prem", "free"]:
			var t = _pass_tile(l, tr, func(): _feature(feat, l, tr))
			if l == focus_lv and tr == focus_tr: t.set_meta("autofocus", true)
			tiles["%d%s" % [l, tr]] = t
			pair.add_child(t)
		grp.add_child(pair)
		row.add_child(grp)
	var end_cap = UI.vb(8, [UI.bold(" ", 20), SpBadge.new()])
	row.add_child(end_cap)
	var sc = UI.scroll(row, true); sc.custom_minimum_size.y = TH + 52; sc.size_flags_vertical = Control.SIZE_FILL
	f.body.add_child(sc)
	f.body.add_child(UI.label("1,000 XP per level (the same XP levels your club) · matches 60–300 XP (Rivals/Champs win 300, other wins 200, draw 120, loss 60) up to 3,000 XP a day · objectives: easy 100 · medium 250 · hard 600 · SBCs 50.   %s Claim all" % (Pad.glyph("Y") if Pad.style != "" else "[C]"), 12, UI.DIM))
	_feature(feat, focus_lv, focus_tr)
	UI.keyhook(f.node, {"j3": func(): _claim_all(), "k%d" % KEY_C: func(): _claim_all()})
	var jump = func():
		await UI.get_tree().process_frame
		if is_instance_valid(sc): sc.scroll_horizontal = max(0, (focus_lv - 2) * (TW * 2 + 28))
		await UI.get_tree().process_frame
		var ft = tiles.get("%d%s" % [focus_lv, focus_tr])
		if p.has("focus") and is_instance_valid(ft): ft.grab_focus()
	jump.call()
	return {"node": f.node, "bg": "hub", "tab": "season", "back": func(): UI.reset("main")}

func _claim_all() -> void:
	if Season.claim_count() == 0: UI.toast("Nothing to claim yet", "bad"); return
	var n = Season.claim_all()
	if n: Sfx.play("reveal"); UI.toast("Claimed %d Season Pass rewards" % n, "good")
	UI.replace("season")

func _info_panel(lv: int, maxed: bool) -> Control:
	var v = UI.vb(10)
	v.add_child(UI.head(Season.TITLE, 32))
	v.add_child(UI.label(Season.TAGLINE, 14, UI.DIM))
	var pill = PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UI._sb(Color("#1f8f4e"), Color(0, 0, 0, 0), 0, 6, Vector4(10, 4, 12, 4)))
	pill.add_child(UI.hb(6, [ClockIco.new(), UI.bold("%d Days" % Season.days_left(), 14, Color.WHITE)]))
	v.add_child(UI.hb(8, [pill, UI.spacer()]))
	if Season.premium(): v.add_child(UI.bold("✓  Acquired", 15, UI.GREEN))
	else: v.add_child(UI.bold("Premium track not acquired", 15, Color("#ffc76b")))
	v.add_child(UI.wrapl(UI.label("Earn XP and redeem rewards across the season. The Premium track adds 83+ and 82+ upgrade packs, Player Picks, Fright Night packs and exclusive Phantom Pass cards (83–86).", 13, UI.DIM), 400))
	var xpl = UI.hb(8, [UI.bold("Level %d / %d" % [lv, Season.LEVELS], 15), UI.spacer(),
		UI.label((("%s XP to next" % Sys.fmt(Season.XP_PER - Season.level_xp())) if not maxed else "Max level") + " · match XP today %d / %d" % [Season.today_match_sp(), Season.MATCH_CAP], 13, UI.DIM)])
	v.add_child(xpl)
	var lb = LevelBar.new(); lb.v = 1.0 if maxed else float(Season.level_xp()) / Season.XP_PER; lb.custom_minimum_size = Vector2(0, 10)
	v.add_child(lb)
	var acts = UI.hb(8)
	var n_claim: int = Season.claim_count()
	var cb = UI.btn("Claim all (%d)" % n_claim, func(): _claim_all(), "Primary" if n_claim else "Small")
	cb.disabled = n_claim == 0; acts.add_child(cb)
	if not Season.premium(): acts.add_child(UI.btn("Unlock Premium ◆ %s" % Sys.fmt(Season.PREMIUM_COST), func(): _unlock_dialog(), "Small"))
	if not maxed: acts.add_child(UI.btn("Level ◆ %s" % Sys.fmt(Season.LEVEL_COST), func():
		if Season.buy_level(): UI.replace("season", {"focus": Season.level()}), "Small"))
	v.add_child(acts)
	var pn = PanelContainer.new()
	pn.add_theme_stylebox_override("panel", UI._sb(Color(0.03, 0.04, 0.07, 0.92), Color(1, 1, 1, 0.08), 1, 4, Vector4(24, 20, 24, 20)))
	pn.add_child(v); pn.custom_minimum_size.x = 460; pn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return pn

func _big_visual(r: Dictionary) -> Control:
	if r.has("player"):
		var c = UI.card(Data.P(r.player), 13.0 if UI.mobile else 22.0); c.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.focus_mode = Control.FOCUS_NONE
		return c
	if r.has("pack"):
		var ic = UI.icon("pack", r.pack, Vector2(150, 210) if UI.mobile else Vector2(230, 320)); return ic
	var co = CoinArt.new(); co.gem = not r.get("coins", 0); co.custom_minimum_size = Vector2(260, 260)
	return co

func _feature(feat: Dictionary, l: int, track: String) -> void:
	var box: HBoxContainer = feat.box
	if not is_instance_valid(box): return
	for c in box.get_children(): box.remove_child(c); c.queue_free()
	var r: Dictionary = Season.reward(l, track)
	var vis = _big_visual(r)
	var hold = CenterContainer.new(); hold.custom_minimum_size.x = 300; hold.add_child(vis); hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hold)
	var txt = UI.vb(8)
	txt.add_child(UI.caps("LEVEL %d · %s" % [l, "PREMIUM" if track == "prem" else "FREE"], 13, Color("#ffd27a") if track == "prem" else Color(1, 1, 1, 0.8)))
	txt.add_child(UI.wrapl(UI.head(Season.reward_label(r).to_upper(), 34, Color.WHITE), 360))
	var desc = ""
	if r.has("player"):
		var pl = Data.P(r.player)
		desc = "%s · %s — Season Pass exclusive. +1 skill move." % [pl.pos, Data.rarity_name(pl)]
	elif r.has("pack"): desc = Data.packs[r.pack].desc
	elif r.get("coins", 0): desc = "Coins credited instantly to your club."
	else: desc = "Prime Points — free in-game credits for packs and the Season Pass."
	txt.add_child(UI.wrapl(UI.label(desc, 14, Color(1, 1, 1, 0.82)), 360))
	var st = ""; var sc = Color.WHITE
	if Season.claimed(l, track): st = "✓  CLAIMED"; sc = UI.GREEN
	elif Season.can_claim(l, track): st = "READY TO CLAIM — press %s" % ("Ⓐ" if Pad.style == "xbox" else ("✕" if Pad.style == "ps" else "Enter")); sc = UI.GREEN
	elif track == "prem" and not Season.premium(): st = "UNLOCK PREMIUM TO CLAIM"; sc = Color("#ffd27a")
	else: st = "REACH LEVEL %d" % l; sc = Color(1, 1, 1, 0.7)
	txt.add_child(UI.bold(st, 15, sc))
	var tc = CenterContainer.new(); tc.add_child(txt); tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tc)
	box.modulate.a = 0.0
	box.create_tween().tween_property(box, "modulate:a", 1.0, 0.15)

func _pass_tile(l: int, track: String, on_focus: Callable) -> Button:
	var r: Dictionary = Season.reward(l, track)
	var t = PassTile.new()
	t.prem = track == "prem"; t.done = Season.claimed(l, track); t.claimable = Season.can_claim(l, track)
	t.locked = (t.prem and not Season.premium()) or l > Season.level()
	t.custom_minimum_size = Vector2(TW, TH); t.focus_mode = Control.FOCUS_ALL
	for k in ["normal", "hover", "pressed", "focus", "disabled"]: t.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	var vis: Control
	if r.has("player"):
		vis = UI.card(Data.P(r.player), 7.6); vis.mouse_filter = Control.MOUSE_FILTER_IGNORE; vis.focus_mode = Control.FOCUS_NONE
	elif r.has("pack"):
		vis = UI.icon("pack", r.pack, Vector2(84, 118)); vis.animate = false
	else:
		vis = CoinArt.new(); vis.gem = not r.get("coins", 0); vis.custom_minimum_size = Vector2(80, 80); vis.still = true
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hold = CenterContainer.new(); hold.custom_minimum_size = Vector2(TW - 30, 136); hold.add_child(vis); hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nm = UI.wrapl(UI.bold(Season.reward_label(r), 12), TW - 44); nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; nm.custom_minimum_size.y = 32
	var v = UI.vb(2, [hold, nm]); v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_preset(Control.PRESET_FULL_RECT); v.offset_left = 14; v.offset_right = -14; v.offset_top = 10; v.offset_bottom = -8
	t.add_child(v)
	var fx = TileFx.new(); fx.tile = t; fx.set_anchors_preset(Control.PRESET_FULL_RECT); fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(fx)
	if t.locked and not t.done and not t.claimable: v.modulate = Color(1, 1, 1, 0.6)
	t.pressed.connect(func(): Sfx.play("select"); _tile_pressed(l, track))
	t.mouse_entered.connect(func(): if UI.mouse_recent() and not t.has_focus(): t.grab_focus())
	t.focus_entered.connect(func(): Sfx.play("move"); on_focus.call(); t.queue_redraw(); fx.queue_redraw())
	t.focus_exited.connect(func(): t.queue_redraw(); fx.queue_redraw())
	return t

class PassTile extends Button:
	var prem = false
	var done = false
	var claimable = false
	var locked = false
	func shape(g := 0.0) -> PackedVector2Array:
		var w = size.x; var h = size.y; var k = 16.0
		return PackedVector2Array([Vector2(k - g, -g), Vector2(w + g, -g), Vector2(w - k + g, h + g), Vector2(-g, h + g)])
	func _draw() -> void:
		var f = has_focus()
		if f:
			draw_colored_polygon(shape(7), Color(1, 0.86, 0.45, 0.16))
			draw_colored_polygon(shape(3.5), Color(1, 0.9, 0.55, 0.35))
		var top = Color("#2b3550") if not prem else Color("#3a2f52")
		var bot = Color("#141a28") if not prem else Color("#1b1530")
		if claimable: top = Color("#1f5a45"); bot = Color("#10261f")
		var pts = shape()
		draw_polygon(pts, PackedColorArray([top, top.lerp(bot, 0.3), bot, bot]))
		var ln = pts.duplicate(); ln.append(pts[0])
		var bc = Color(1, 0.92, 0.65) if f else (UI.GREEN if claimable else Color(1, 1, 1, 0.16))
		draw_polyline(ln, bc, 3.0 if f else 1.5, true)

class TileFx extends Control:
	var tile
	func _ready() -> void:
		if tile.claimable:
			var tw = create_tween().set_loops(); tw.tween_property(self, "modulate:a", 0.55, 0.7); tw.tween_property(self, "modulate:a", 1.0, 0.7)
	func _draw() -> void:
		var w = size.x; var h = size.y; var k = 16.0
		var sx = func(y): return k * (1.0 - y / h)
		if tile.prem:
			var a = 30.0; var b = 52.0
			var band = PackedVector2Array([Vector2(sx.call(0.0) + a, 0), Vector2(sx.call(0.0) + b, 0), Vector2(sx.call(b), b), Vector2(sx.call(a), a)])
			draw_colored_polygon(band, Color("#e8b631"))
			var fnt = UI.font_bold
			var cx = (sx.call(0.0) + (a + b) / 2.0 + sx.call((a + b) / 2.0)) / 2.0
			draw_set_transform(Vector2(cx, (a + b) / 4.0), -PI / 4.0)
			var tw = fnt.get_string_size("PREMIUM", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			draw_string(fnt, Vector2(-tw / 2.0, 3.5), "PREMIUM", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#2a1a00"))
			draw_set_transform(Vector2.ZERO)
		if tile.done:
			var c = Vector2(w - 24, 20)
			draw_circle(c, 12, UI.GREEN)
			draw_polyline(PackedVector2Array([c + Vector2(-5.5, 0), c + Vector2(-1.5, 4.5), c + Vector2(6, -4.5)]), Color.WHITE, 2.6, true)
		elif tile.claimable:
			var c2 = Vector2(w - 24, 20)
			draw_circle(c2, 8, UI.GREEN)
		elif tile.locked:
			var c3 = Vector2(w - 26, 20)
			draw_rect(Rect2(c3 + Vector2(-6, -1), Vector2(12, 9)), Color(1, 1, 1, 0.55))
			draw_arc(c3 + Vector2(0, -1), 4.5, PI, TAU, 10, Color(1, 1, 1, 0.55), 2.0)

class LevelBar extends Control:
	var v = 0.0
	func _init() -> void: custom_minimum_size = Vector2(60, 8); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r = Rect2(Vector2(0, (size.y - 8) / 2), Vector2(size.x, 8))
		draw_rect(r, Color(0.35, 0.25, 0.6, 0.35))
		if v > 0: draw_rect(Rect2(r.position, Vector2(r.size.x * clamp(v, 0.0, 1.0), 8)), Color("#9b6bff"))

class ClockIco extends Control:
	func _init() -> void: custom_minimum_size = Vector2(16, 16); size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		var c = size / 2
		draw_arc(c, 6.5, 0, TAU, 20, Color.WHITE, 1.8, true)
		draw_line(c, c + Vector2(0, -4), Color.WHITE, 1.6); draw_line(c, c + Vector2(3, 1), Color.WHITE, 1.6)

class SpBadge extends Control:
	func _init() -> void: custom_minimum_size = Vector2(110, 204); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c = Vector2(size.x / 2, size.y / 2 - 8)
		draw_circle(c, 34, Color("#2a2140"))
		draw_arc(c, 34, 0, TAU, 40, Color("#9b6bff"), 3.0, true)
		var fnt = UI.font_head
		var tw = fnt.get_string_size("XP", HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(fnt, c + Vector2(-tw / 2, 11), "XP", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
		var t2 = UI.font_bold.get_string_size("SEASON END", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(UI.font_bold, Vector2(size.x / 2 - t2 / 2, c.y + 58), "SEASON END", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.DIM)

class CoinArt extends Control:
	var gem = false
	var still = false
	var t = 0.0
	func _process(d: float) -> void:
		if still: return
		t += d; queue_redraw()
	func _draw() -> void:
		var r = min(size.x, size.y) * 0.4
		if gem: UI.paint_gem(self, size / 2, r, t)
		else: UI.paint_coin(self, size / 2, r, t)

## warm gold hero art behind the featured reward
class HeroArt extends Control:
	var t = 0.0
	func _init() -> void: clip_contents = true; mouse_filter = Control.MOUSE_FILTER_IGNORE; custom_minimum_size = Vector2(500, 380)
	func _process(d: float) -> void:
		if UI.mobile: return
		t += d; queue_redraw()
	func _draw() -> void:
		var w = size.x; var h = size.y
		var n = 18
		for i in n:
			var y0 = h * i / n; var y1 = h * (i + 1) / n
			var c = Color("#1c0b2e").lerp(Color("#d4620f"), clamp(1.0 - abs(float(i) / n - 0.55) * 1.7, 0.0, 1.0))
			draw_rect(Rect2(0, y0, w, y1 - y0 + 1), c)
		var o = Vector2(w * 0.26, h * 0.5)
		for i in 14:
			var a = t * 0.06 + i * TAU / 14
			var p1 = o + Vector2(cos(a - 0.07), sin(a - 0.07)) * w * 1.3
			var p2 = o + Vector2(cos(a + 0.07), sin(a + 0.07)) * w * 1.3
			draw_colored_polygon(PackedVector2Array([o, p1, p2]), Color(1, 0.86, 0.5, 0.07))
		for i in 6: draw_circle(o, 260 - i * 38, Color(1, 0.8, 0.4, 0.035))
		# diagonal streaks like the stadium-light art
		for i in 7:
			var x = fmod(i * 173.0 + t * 12.0, w + 300) - 150
			draw_colored_polygon(PackedVector2Array([Vector2(x, h), Vector2(x + 26, h), Vector2(x + 26 + h * 0.6, 0), Vector2(x + h * 0.6, 0)]), Color(1, 0.95, 0.75, 0.035))
		# full moon, bats and pumpkins
		var mc = Vector2(w * 0.86, h * 0.2)
		for k in 5: draw_circle(mc, 52 + k * 14, Color(1, 0.75, 0.35, 0.05))
		draw_circle(mc, 46, Color("#ffe3a3")); draw_circle(mc + Vector2(-12, -8), 9, Color(0.85, 0.7, 0.45, 0.5)); draw_circle(mc + Vector2(14, 12), 6, Color(0.85, 0.7, 0.45, 0.5))
		for k in 5:
			var bp = Vector2(fmod(w * 0.5 + k * 157.0 + t * (22 + k * 4), w + 80) - 40, h * (0.12 + 0.07 * k) + sin(t * 3 + k) * 8)
			Gfx.bat(self, bp, 9 + k % 3 * 3, t * 9 + k)
		for k in 3: Gfx.pumpkin(self, Vector2(w * (0.58 + k * 0.14), h - 24), 20 - k * 3, t)
		draw_rect(Rect2(0, h - 60, w, 60), Color(0, 0, 0, 0.18))
		draw_rect(Rect2(0, 0, w, h), Color(1, 0.85, 0.5, 0.25), false, 1.0)

func _tile_pressed(l: int, track: String) -> void:
	var r: Dictionary = Season.reward(l, track)
	if Season.can_claim(l, track):
		Season.claim(l, track); Sfx.play("reveal")
		UI.replace("season", {"focus": l, "track": track})
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
	var body = UI.vb(8, [UI.wrapl(UI.label("Unlock the Premium track for %s Prime Points. You instantly get every Premium reward up to your current level, including 82+ x5 and 83+ x2 packs, Player Picks and 5 exclusive Phantom Pass cards (83–86)." % Sys.fmt(Season.PREMIUM_COST), 15), 520),
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

## FC-style ITEM PICK: face-down covers. Tap a cover (or Reveal All) — it charges up and shines; the stronger the shine,
## the better the player. Once revealed, tap a card to pick it.
func s_pick(_p) -> Dictionary:
	var cur = Save.data.get("pick_cur")
	var f = UI.sub_shell("Item Pick", "Player Pick", true)
	if cur == null:
		f.body.add_child(UI.label("No player pick in progress.", 16, UI.DIM))
		return {"node": f.node, "bg": "hub", "back": func(): UI.replace("store", {"tab": "mine"})}
	if not cur.has("rev"): cur.rev = []
	var n: int = cur.pids.size()
	var title = UI.head("ITEM PICK", 40 if not UI.mobile else 30, Color("#3dff8a")); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub = UI.label(Data.packs[cur.pack].name, 16); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cnt = UI.label("Pick 0/1 · tap a pack to reveal it", 13, UI.DIM); cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.body.add_child(UI.vb(4, [title, sub, cnt]))
	var holder: Container
	var cs: float = 6.6 if UI.mobile else 11.0
	if UI.mobile:
		var g = GridContainer.new(); g.columns = 3; g.add_theme_constant_override("h_separation", 10); g.add_theme_constant_override("v_separation", 14); holder = g
	else:
		var h = UI.hb(28); h.alignment = BoxContainer.ALIGNMENT_CENTER; holder = h
	var covers = []
	var update = func():
		var left = n - cur.rev.size()
		cnt.text = ("Pick 0/1 · tap a pack to reveal it · %d hidden" % left) if left > 0 else "Pick 0/1 · tap the player you want"
	for k in n:
		var pl: Dictionary = Data.P(cur.pids[k])
		var cv = PickCover.new(); cv.pl = pl; cv.cs = cs; cv.idx = k
		cv.revealed = cur.rev.has(k)
		cv.on_reveal = func(): if not cur.rev.has(k): cur.rev.append(k); Save.dirty(); update.call()
		cv.on_pick = func(): _choose(pl)
		holder.add_child(cv); covers.append(cv)
	var cc = CenterContainer.new(); UI.grow(cc); cc.add_child(holder); f.body.add_child(cc)
	var reveal_all = UI.btn("Reveal All", func():
		var d = 0.0
		for cv in covers:
			if not cv.revealed and not cv.busy: cv.reveal_after(d); d += 0.45, "Primary")
	var bar = UI.hb(10, [reveal_all]); bar.alignment = BoxContainer.ALIGNMENT_CENTER
	f.body.add_child(bar)
	update.call()
	return {"node": f.node, "bg": "hub", "back": func(): UI.toast("Choose a player first — your pick is saved", "bad")}

class PickCover extends Button:
	var pl: Dictionary
	var cs = 11.0
	var idx = 0
	var revealed = false
	var busy = false
	var charge = 0.0     # 0..1 while revealing
	var flash = 0.0
	var t = 0.0
	var lvl = 0
	var on_reveal: Callable
	var on_pick: Callable
	var card: Control = null
	func _ready() -> void:
		flat = true; focus_mode = Control.FOCUS_ALL
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]: add_theme_stylebox_override(st, StyleBoxEmpty.new())
		custom_minimum_size = Vector2(12.0 * cs, 16.8 * cs + 26)
		lvl = _level(pl)
		if revealed: _show_card()
		pressed.connect(func():
			if revealed: Sfx.play("select"); on_pick.call()
			elif not busy: reveal_after(0.0))
	static func _level(p: Dictionary) -> int:
		var o: int = int(p.get("ovr", 0)); var ty: String = str(p.get("type", "base"))
		if ty in ["icon", "hero"] or o >= 90: return 4
		if ty != "base" or o >= 88: return 3
		if o >= 86: return 2
		if o >= 84: return 1
		return 0
	func reveal_after(delay: float) -> void:
		busy = true
		if delay > 0: await get_tree().create_timer(delay).timeout
		if not is_inside_tree(): return
		Sfx.play("riser")
		var dur: float = 0.7 + lvl * 0.35
		var tw = create_tween(); tw.tween_property(self, "charge", 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		flash = 1.0
		Sfx.play("bigreveal" if lvl >= 3 else "reveal")
		if lvl >= 3: Pad.rumble(0.3 + lvl * 0.1, 0.5, 0.35)
		revealed = true; busy = false
		_show_card()
		on_reveal.call()
	func _show_card() -> void:
		if card: return
		card = UI.card(pl, cs); card.focus_mode = Control.FOCUS_NONE; card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = Vector2(0, 0); add_child(card)
		var nm = UI.bold(Data.short_name(pl.name), 13); nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nm.position = Vector2(0, 16.8 * cs + 4); nm.size = Vector2(12.0 * cs, 20); add_child(nm)
		card.pivot_offset = Vector2(6.0 * cs, 8.4 * cs); card.scale = Vector2(0.6, 0.6)
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	func _process(d: float) -> void:
		t += d
		if flash > 0.0: flash = max(0.0, flash - d * 1.6)
		if busy or flash > 0.0 or (revealed and lvl >= 3) or has_focus(): queue_redraw()
	func _draw() -> void:
		var w = 12.0 * cs; var h = 16.8 * cs
		var ctr = Vector2(w / 2, h * 0.48)
		var gcol: Color = Data.rarity_style(Data.rarity_key(pl)).glow if revealed or busy else Color(1, 0.85, 0.4)
		# the shine: rays + glow, size and brightness grow with the level while charging, then linger for the best cards
		var power: float = charge * (0.35 + lvl * 0.2) if busy else (flash + (0.25 + 0.1 * sin(t * 3.0) if revealed and lvl >= 3 else 0.0))
		if busy or revealed and (lvl >= 3 or flash > 0):
			var rays = 6 + lvl * 3; var rl: float = w * (0.5 + lvl * 0.25) * clamp(power + 0.2, 0.0, 1.6)
			for k in rays:
				var a = t * (0.4 + lvl * 0.15) + TAU * k / rays
				var tip = ctr + Vector2(cos(a), sin(a)) * rl
				var side = Vector2(-sin(a), cos(a)) * w * 0.05
				draw_colored_polygon(PackedVector2Array([ctr + side, tip, ctr - side]), Color(gcol, clamp(power, 0.0, 1.0) * 0.35))
			Gfx.glow(self, ctr, w * (0.6 + lvl * 0.35) * (0.4 + power), Color(gcol, clamp(power, 0.0, 1.0) * 0.8))
		if flash > 0.0: Gfx.glow(self, ctr, w * (1.0 + lvl * 0.4), Color(1, 1, 1, flash * 0.9))
		if revealed: 
			if has_focus(): draw_rect(Rect2(-6, -6, w + 12, h + 12), Color("#3dff8a"), false, 3.0)
			return
		# face-down cover: white card with a gold medallion of three silhouettes (shakes while charging)
		var shake = Vector2(sin(t * 60.0), cos(t * 47.0)) * cs * 0.12 * charge * (1 + lvl) if busy else Vector2.ZERO
		draw_set_transform(shake)
		var r = Rect2(Vector2.ZERO, Vector2(w, h))
		var sh = Gfx.shield(r)
		draw_colored_polygon(Gfx.shield(Rect2(Vector2(0, cs * 0.5), r.size)), Color(0, 0, 0, 0.35))
		Gfx.grad_poly(self, sh, r, Color("#ffffff"), Color("#f1efe9"), Color("#e3dfd4"))
		var tr = sh.duplicate(); tr.append(tr[0]); draw_polyline(tr, Color("#d9b25c"), max(1.0, cs * 0.18), true)
		var mc = Vector2(w / 2, h * 0.45); var mr: float = w * 0.28
		draw_circle(mc, mr * 1.12, Color("#e8c46a")); draw_circle(mc, mr, Color("#f7f3ea")); draw_arc(mc, mr * 0.98, 0, TAU, 40, Color("#c99a3a"), max(1.0, cs * 0.18))
		for k in 3:
			var px = mc.x + (k - 1) * mr * 0.55; var py = mc.y + (0.08 if k == 1 else 0.18) * mr; var s2: float = mr * (0.42 if k == 1 else 0.34)
			draw_circle(Vector2(px, py - s2 * 0.55), s2 * 0.42, Color("#b8892e"))
			draw_rect(Rect2(px - s2 * 0.6, py, s2 * 1.2, s2 * 0.9), Color("#b8892e"))
		for k in 9: draw_circle(mc + Vector2.from_angle(-PI / 2 + TAU * k / 9.0) * mr * 1.3, cs * 0.12, Color("#e8c46a"))
		if busy:
			var pulse = Color(gcol, 0.25 * charge * (1 + lvl * 0.4)); Gfx.glow(self, mc, mr * (1.6 + lvl * 0.6) * charge, pulse)
		if has_focus(): 
			var c = Color("#3dff8a"); var L = w * 0.18
			for q in [[Vector2(-8, -8), 1, 1], [Vector2(w + 8, -8), -1, 1], [Vector2(-8, h + 8), 1, -1], [Vector2(w + 8, h + 8), -1, -1]]:
				draw_line(q[0], q[0] + Vector2(L * q[1], 0), c, 4.0); draw_line(q[0], q[0] + Vector2(0, L * q[2]), c, 4.0)
		draw_set_transform(Vector2.ZERO)

func _choose(pl: Dictionary) -> void:
	var v = await UI.inspect(pl, [["Choose %s" % Data.short_name(pl.name), "pick", "Primary"]])
	if v != "pick": return
	var cur = Save.data.get("pick_cur")
	if cur == null: return
	Save.data.pick_cur = null
	Sys.club_add(pl.id, false, "pick")
	Sys.history("Picked %d %s from %s" % [pl.ovr, pl.name, Data.packs[cur.pack].name])
	Save.write_now()
	Sfx.play("bigreveal"); UI.toast("%d %s joined your club" % [pl.ovr, pl.name], "good")
	UI.reset("store", {"tab": "mine" if not Save.data.unopened.is_empty() else "packs"})
