extends RefCounted
## FUT Champions screen (rank ladder, entry requirements, rank rewards, performance)
## and the Champions Token Store.

const GOLD := Color("#e8c46a")
const CYAN := Color("#4fd1ff")

class ChampsBG extends Control:
	func _draw() -> void:
		var W = size.x; var H = size.y
		var g = Gradient.new(); g.colors = PackedColorArray([Color("#1b0608"), Color("#3a0b10"), Color("#120405")]); g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		var steps = 24
		for i in steps:
			draw_rect(Rect2(W * i / steps, 0, W / steps + 1, H), g.sample(float(i) / steps))
		# big golden "C" crest outlines
		var cx = W * 0.78; var cy = H * 0.5
		for k in 3:
			var r = H * (0.55 - k * 0.12); var a = 0.10 - k * 0.025
			var pts = PackedVector2Array()
			for i in 7:
				var an = -PI / 2 + i * TAU / 6.0
				pts.append(Vector2(cx + cos(an) * r * 0.95, cy + sin(an) * r))
			draw_polyline(pts, Color(0.91, 0.72, 0.3, a), 10.0 - k * 2.0, true)
		draw_arc(Vector2(cx, cy), H * 0.24, PI * 0.25, PI * 1.75, 40, Color(0.91, 0.72, 0.3, 0.08), 26.0)
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.0))

class RankShield extends Button:
	var idx = 0; var state = "locked"; var tier = 0; var numeral = ""
	func _ready() -> void:
		flat = true; focus_mode = Control.FOCUS_ALL; custom_minimum_size = Vector2(62, 76)
		for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]: add_theme_stylebox_override(s, StyleBoxEmpty.new())
		focus_entered.connect(func(): queue_redraw(); Sfx.play("move"))
		focus_exited.connect(queue_redraw)
		mouse_entered.connect(func(): if UI.mouse_recent(): grab_focus())
	func _draw() -> void:
		var r = Rect2(Vector2(6, 4), size - Vector2(12, 8))
		var sh = Gfx.shield(r)
		var fill = Color("#1a1c22") if state == "locked" else (Color("#c79a3a") if state == "done" else Color("#262a33"))
		var edge = Color("#8a8f99") if state == "locked" else (Color("#ffe39a") if state == "done" else Color.WHITE)
		if has_focus(): draw_colored_polygon(Gfx.shield(r.grow(5)), Color(0.31, 0.82, 1.0, 0.55))
		# tier decorations: wings (Elite), laurels (Champion)
		if tier >= 1:
			for s in [-1, 1]:
				var bx = r.get_center().x + s * r.size.x * 0.5
				draw_colored_polygon(PackedVector2Array([Vector2(bx, r.position.y + r.size.y * 0.3), Vector2(bx + s * 8, r.position.y + r.size.y * 0.42), Vector2(bx, r.position.y + r.size.y * 0.62)]), edge.darkened(0.2))
		if tier >= 2:
			for s in [-1, 1]:
				for k in 4:
					var p = Vector2(r.get_center().x + s * (r.size.x * 0.32 + k * 2), r.end.y - 6 - k * 7)
					draw_circle(p, 2.6, edge.darkened(0.15))
		draw_colored_polygon(sh, fill)
		var o = sh.duplicate(); o.append(sh[0]); draw_polyline(o, edge, 2.4, true)
		Gfx.text_c(self, UI.font_head, r.get_center().x, r.get_center().y + 9, numeral, 24, Color.WHITE if state != "done" else Color("#2a1d02"))

## the Champions Token: gold-rimmed medallion, crimson field, laurel arcs, crest with a "C" and a star
class Token extends Control:
	static func paint(ci: CanvasItem, c: Vector2, r: float, t := 0.0) -> void:
		ci.draw_circle(c + Vector2(0, r * 0.08), r * 1.02, Color(0, 0, 0, 0.35))
		for i in 10: ci.draw_circle(c, r * (1.0 - i * 0.012), Color("#f8d77a").lerp(Color("#9a6a12"), float(i) / 9.0))
		var teeth = PackedVector2Array()
		for i in 48:
			var a = TAU * i / 48.0; var rr = r * (0.9 if i % 2 == 0 else 0.86)
			teeth.append(c + Vector2(cos(a), sin(a)) * rr)
		ci.draw_colored_polygon(teeth, Color("#c3901c"))
		ci.draw_circle(c, r * 0.8, Color("#5a0d14"))
		for i in 18: ci.draw_circle(c, r * (0.8 - i * 0.02), Color("#8e1622").lerp(Color("#3a0509"), float(i) / 17.0))
		for s in [-1, 1]:
			for k in 7:
				var a = PI / 2 + s * (0.55 + k * 0.28)
				var p = c + Vector2(cos(a), sin(a)) * r * 0.66
				var leaf = PackedVector2Array([p + Vector2(0, -r * 0.05), p + Vector2(s * r * 0.05, 0), p + Vector2(0, r * 0.05), p + Vector2(-s * r * 0.05, 0)])
				ci.draw_colored_polygon(leaf, Color("#e8c46a"))
		var sh = Gfx.shield(Rect2(c - Vector2(r * 0.34, r * 0.4), Vector2(r * 0.68, r * 0.8)))
		ci.draw_colored_polygon(sh, Color("#f0c94e"))
		var o = sh.duplicate(); o.append(sh[0]); ci.draw_polyline(o, Color("#fff1c4"), max(1.5, r * 0.03), true)
		Gfx.text_c(ci, UI.font_head, c.x, c.y + r * 0.2, "C", int(r * 0.55), Color("#5a0d14"))
		var st = PackedVector2Array()
		for i in 10:
			var a = -PI / 2 + i * TAU / 10.0; var rr = r * (0.13 if i % 2 == 0 else 0.055)
			st.append(c + Vector2(0, -r * 0.6) + Vector2(cos(a), sin(a)) * rr)
		ci.draw_colored_polygon(st, Color("#fff1c4"))
		var sx = c.x - r + fmod(t * 0.6, 2.4) * r
		ci.draw_arc(c, r * 0.95, -2.4, -1.6, 12, Color(1, 1, 1, 0.35), max(1.0, r * 0.05))
	var t = 0.0
	func _process(d: float) -> void: t += d; queue_redraw()
	func _draw() -> void: Token.paint(self, size / 2, min(size.x, size.y) * 0.48, t)
	static func make(px: float) -> Token:
		var k = Token.new(); k.custom_minimum_size = Vector2(px, px); k.mouse_filter = Control.MOUSE_FILTER_IGNORE; return k

class Emblem extends Control:
	var big = true
	func _draw() -> void:
		var r = Rect2(Vector2(4, 4), size - Vector2(8, 8))
		var sh = Gfx.shield(r)
		Gfx.grad_poly(self, sh, r, Color("#f8d77a"), Color("#c3901c"), Color("#7a1010"))
		var o = sh.duplicate(); o.append(sh[0]); draw_polyline(o, Color("#ffe8a8"), 3.0, true)
		Gfx.text_c(self, UI.font_head, r.get_center().x, r.get_center().y + r.size.y * 0.2, "C", int(r.size.y * 0.55), Color("#5a0d10"))

func _fmt_long(sec: float) -> String:
	var s = int(sec); var d = s / 86400; var h = (s % 86400) / 3600; var m = (s % 3600) / 60
	if d > 0: return "%d Days %d Hours" % [d, h]
	return "%d Hours %d Mins" % [h, m]

func s_champions(_p) -> Dictionary:
	var fin = Champs.check_week()
	var C = Champs.st(); var run = C.run
	var page = Control.new(); page.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bgc = ChampsBG.new(); bgc.set_anchors_preset(Control.PRESET_FULL_RECT); page.add_child(bgc)
	var mg = MarginContainer.new(); mg.set_anchors_preset(Control.PRESET_FULL_RECT)
	for kv in [["left", 56], ["right", 56], ["top", 22], ["bottom", 14]]: mg.add_theme_constant_override("margin_" + kv[0], kv[1])
	page.add_child(mg)
	var v = UI.vb(12); mg.add_child(v)
	v.add_child(UI.hb(14, [UI.icon("badge", Save.data.profile.badge, Vector2(46, 50)), UI.bold("Play", 26), UI._sepline(), UI.spacer(), UI.currency_bar()]))
	var countdown = UI.bold("", 18)
	var cd_txt = func(): countdown.text = "⏱  " + _fmt_long(Champs.event_left())
	cd_txt.call()
	v.add_child(UI.vb(4, [UI.head("CHAMPIONS", 46), UI.hb(10, [UI.label("Event ends in" if run != null else "Weekly event · resets in", 17), countdown]),
		UI.label("Play in Champions to earn points to reach higher ranks and better rewards.", 17, UI.DIM)]))
	# ---- rank ladder
	var pts: int = int(run.pts) if run != null else 0
	var reached: int = Champs.rank_for(pts)
	var ladder = HBoxContainer.new(); ladder.add_theme_constant_override("separation", 0); ladder.alignment = BoxContainer.ALIGNMENT_CENTER
	var em = Emblem.new(); em.custom_minimum_size = Vector2(74, 90); ladder.add_child(em)
	var R = {"sel": max(0, reached if reached < 14 else 14)}
	var rank_name = UI.bold("", 22); var rank_pts = UI.head("", 30, CYAN); var rank_rw = UI.wrapl(UI.label("", 15), 300)
	var show_rank = func(i: int):
		R.sel = i
		rank_name.text = Champs.rank_name(i)
		rank_pts.text = "%d/%d pts" % [min(pts, Champs.RANK_PTS[i]), Champs.RANK_PTS[i]]
		rank_pts.add_theme_color_override("font_color", UI.GREEN if pts >= Champs.RANK_PTS[i] else CYAN)
		rank_rw.text = Champs.reward_text(Champs.REWARDS[i]).replace(" · ", "\n")
	var marker_row = HBoxContainer.new(); marker_row.add_theme_constant_override("separation", 0); marker_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var mk_sp = Control.new(); mk_sp.custom_minimum_size.x = 74; marker_row.add_child(mk_sp)
	var marker_at: int = max(0, reached)
	for i in 15:
		var con = ColorRect.new(); con.custom_minimum_size = Vector2(18, 5); con.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		con.color = GOLD if pts >= Champs.RANK_PTS[i] else Color(1, 1, 1, 0.25)
		ladder.add_child(con)
		var sh = RankShield.new(); sh.idx = i; sh.tier = i / 5; sh.numeral = Champs.NUM[i % 5]
		sh.state = "done" if pts >= Champs.RANK_PTS[i] else ("next" if i == reached + 1 else "locked")
		var ii = i
		sh.focus_entered.connect(func(): show_rank.call(ii))
		sh.pressed.connect(func(): _preview_all(pts))
		ladder.add_child(sh)
		var ms = Control.new(); ms.custom_minimum_size.x = 18; marker_row.add_child(ms)
		var mk = Label.new(); mk.custom_minimum_size.x = 62; mk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mk.text = "▼" if i == marker_at else ""; mk.add_theme_color_override("font_color", Color("#3fe0a0")); mk.add_theme_font_size_override("font_size", 22)
		marker_row.add_child(mk)
	v.add_child(UI.vb(0, [marker_row, ladder]))
	show_rank.call(R.sel)
	# ---- bottom: requirements + play | rank rewards | performance
	var req = UI.vb(8, [UI.bold("Entry Requirements", 19, Color("#3fe0a0"))])
	var qp: int = int(C.qp)
	var req_row = func(icon: String, txt: String, val: String, ok: bool) -> Control:
		return UI.panel(UI.hb(10, [UI.label(icon, 18, GOLD), UI.label(txt, 16), UI.spacer(), UI.label(val, 16, UI.DIM), UI.bold("✓" if ok else "✗", 20, UI.GREEN if ok else UI.RED)]), "Glass")
	if run == null:
		req.add_child(req_row.call("★", "Champions Qual. Points", "%s/%s" % [Sys.fmt(qp), Sys.fmt(Champs.QP_NEED)], Champs.qualified()))
		req.add_child(req_row.call("■", "Min. Rivals Division %d" % Champs.MIN_DIV, "", Champs.div_ok()))
	else:
		req.add_child(req_row.call("★", "Qualified for this week's event", "", true))
		req.add_child(req_row.call("■", "Match %d of %d" % [min(Champs.MATCHES, int(run.played) + 1), Champs.MATCHES], "", true))
	var play = UI.btn("", func(): _play_pressed(), "Primary", true)
	play.custom_minimum_size = Vector2(330, 54)
	var upd_play = func():
		var r = Champs.run()
		var glyph = Pad.glyph("A") if Pad.style != "" else "Ⓐ"
		play.disabled = false
		if r == null:
			if Champs.cooldown_left() > 0: play.text = "Next run in %s" % Sys.fmt_time(Champs.cooldown_left()); play.disabled = true
			elif Champs.qualified() and Champs.div_ok(): play.text = glyph + "  Play FUT Champions"
			else: play.text = "Qualify in Division Rivals"; play.disabled = false
		elif r.done: play.text = glyph + "  Claim Rewards"
		else: play.text = glyph + "  Play FUT Champions"
	upd_play.call()
	req.add_child(play)
	var row2 = UI.hb(10, [Token.make(34), UI.btn("Token Store  ·  %d" % Champs.tokens(), func(): UI.go("champsstore"), "Small")])
	if run != null and not run.done:
		row2.add_child(UI.btn("Finish run now", func():
			if await UI.modal("Finish FUT Champions now?", "You'll get the rewards for %s and can't play the remaining %d matches. A new run can start after a 5-minute cooldown." % [Champs.rank_name(Champs.rank_for(int(run.pts))), Champs.remaining()], [["Keep playing", null, ""], ["Finish & claim", true, "Danger"]]):
				_show_claim(Champs.claim()), "Small"))
	req.add_child(row2)
	req.custom_minimum_size.x = 400
	var rr = UI.panel(UI.vb(12, [UI.bold("Rank Rewards", 20), UI.label("Earn points to unlock better rewards", 15, UI.DIM),
		UI.hb(18, [Token.make(130), UI.vb(4, [rank_name, rank_pts, rank_rw])])]))
	rr.custom_minimum_size = Vector2(400, 250)
	var perf_n = func(n, lab: String) -> Control:
		var b = UI.vb(0, [UI.label(lab, 17), UI.head(str(n), 32, CYAN)])
		for c in b.get_children(): c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UI.grow(b, false, true); return b
	var big = UI.vb(0, [UI.head(str(pts), 64), UI.label("Points", 18)])
	for c in big.get_children(): c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var perf = UI.panel(UI.vb(10, [UI.bold("Performance", 20), big, UI.hb(10, [perf_n.call(run.w if run else 0, "Wins"), perf_n.call(run.l if run else 0, "Losses"), perf_n.call(Champs.remaining(), "Remaining")])]))
	perf.custom_minimum_size = Vector2(350, 250)
	var bottom = UI.hb(18, [req, UI.spacer(), rr, perf]); bottom.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(UI.vspacer()); v.add_child(bottom)
	var g = func(ps: String, xb: String, kb: String) -> String: return ps if Pad.style == "ps" else (xb if Pad.style == "xbox" else kb)
	v.add_child(UI.hb(22, [UI._key_hint(g.call("✕", "A", "Enter"), "Select"), UI._key_hint(g.call("○", "B", "Esc"), "Back"), UI._key_hint(g.call("□", "X", "R"), "Preview Reward(s)"), UI._key_hint(g.call("◀ L ▶", "◀ L ▶", "◀ ▶"), "Navigate"), UI._key_hint(g.call("△", "Y", "T"), "Token Store")]))
	UI.keyhook(page, {"j%d" % JOY_BUTTON_X: func(): _preview_all(pts), "k%d" % KEY_R: func(): _preview_all(pts),
		"j%d" % JOY_BUTTON_Y: func(): UI.go("champsstore"), "k%d" % KEY_T: func(): UI.go("champsstore")})
	var t = Timer.new(); t.wait_time = 1.0; t.autostart = true; page.add_child(t)
	t.timeout.connect(func(): cd_txt.call(); upd_play.call())
	if not fin.is_empty(): UI.go.call_deferred("champsreward", {"res": fin})
	# Back always works, even when the history was cleared (e.g. after the rewards reveal)
	return {"node": page, "bg": "off", "back": _back_or_play}

func _emblem_circle() -> Control:
	var c = Control.new(); c.custom_minimum_size = Vector2(130, 130)
	c.draw.connect(func():
		var ctr = c.size / 2
		c.draw_circle(ctr, 62, Color("#15171c")); c.draw_arc(ctr, 62, 0, TAU, 48, Color(1, 1, 1, 0.35), 3)
		var r = Rect2(ctr - Vector2(30, 36), Vector2(60, 72)); var sh = Gfx.shield(r)
		c.draw_colored_polygon(sh, Color("#2a2e36")); var o = sh.duplicate(); o.append(sh[0]); c.draw_polyline(o, Color.WHITE, 2.5, true)
		Gfx.text_c(c, UI.font_head, ctr.x, ctr.y + 9, "PF", 22, Color.WHITE))
	return c

func _preview_all(pts: int) -> void:
	var g = GridContainer.new(); g.columns = 3; g.add_theme_constant_override("h_separation", 22); g.add_theme_constant_override("v_separation", 8)
	for hdr in ["Rank", "Points", "Rewards"]: g.add_child(UI.caps(hdr, 10))
	for i in range(14, -1, -1):
		var got = pts >= Champs.RANK_PTS[i]
		g.add_child(UI.bold(Champs.rank_name(i), 14, GOLD if i >= 10 else (UI.TEAL if i >= 5 else UI.TEXT)))
		g.add_child(UI.label("%d pts%s" % [Champs.RANK_PTS[i], "  ✓" if got else ""], 13, UI.GREEN if got else UI.DIM))
		g.add_child(UI.label(Champs.reward_text(Champs.REWARDS[i]), 13))
	var body = UI.vb(10, [UI.label("Win = %d pts · Loss = %d pt · %d matches · you receive the rewards of the highest rank you reach." % [Champs.WIN_PTS, Champs.LOSS_PTS, Champs.MATCHES], 14, UI.DIM), g])
	await UI.modal("Champions Rank Rewards", body, [["Close", null, "Primary"]], true)

func _show_claim(res: Dictionary) -> void:
	if res.is_empty(): return
	UI.go("champsreward", {"res": res})

# ------------------------------------------------------------------ rewards reveal (end of a Champions run)
class Trophy extends Control:
	func _draw() -> void:
		var c = size / 2; var r = min(size.x, size.y) * 0.46
		draw_circle(c + Vector2(0, r * 0.06), r * 1.02, Color(0, 0, 0, 0.35))
		for i in 8: draw_circle(c, r * (1.0 - i * 0.015), Color("#f8d77a").lerp(Color("#9a6a12"), i / 7.0))
		draw_circle(c, r * 0.84, Color("#6e0f18"))
		for k in 7:
			var a = -PI / 2 + (k - 3) * 0.32
			Champs_star(self, c + Vector2(cos(a), sin(a)) * r * 0.68, r * 0.07)
		var cup = PackedVector2Array([c + Vector2(-r * 0.32, -r * 0.34), c + Vector2(r * 0.32, -r * 0.34), c + Vector2(r * 0.22, r * 0.02), c + Vector2(r * 0.06, r * 0.12), c + Vector2(-r * 0.06, r * 0.12), c + Vector2(-r * 0.22, r * 0.02)])
		draw_colored_polygon(cup, Color("#f0c94e"))
		for s in [-1, 1]: draw_arc(c + Vector2(s * r * 0.3, -r * 0.2), r * 0.11, PI / 2 * (1 - s), PI / 2 * (1 - s) + PI, 12, Color("#f0c94e"), r * 0.05)
		draw_rect(Rect2(c + Vector2(-r * 0.05, r * 0.1), Vector2(r * 0.1, r * 0.16)), Color("#e0b23e"))
		draw_rect(Rect2(c + Vector2(-r * 0.2, r * 0.26), Vector2(r * 0.4, r * 0.1)), Color("#f0c94e"))
		for s in [-1, 1]:
			for k in 5:
				var a = PI / 2 + s * (0.7 + k * 0.3)
				draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.7, r * 0.045, Color("#e8c46a"))
	static func Champs_star(ci: CanvasItem, p: Vector2, r: float) -> void:
		var st = PackedVector2Array()
		for i in 10:
			var a = -PI / 2 + i * TAU / 10.0; var rr = r if i % 2 == 0 else r * 0.45
			st.append(p + Vector2(cos(a), sin(a)) * rr)
		ci.draw_colored_polygon(st, Color("#f8d77a"))

class CoinPile extends Control:
	var t = 0.0
	func _process(d: float) -> void: t += d; queue_redraw()
	func _draw() -> void:
		var W = size.x; var H = size.y
		var cw = W * 0.2; var ch = cw * 0.32
		var stacks = [[0.18, 7], [0.38, 10], [0.62, 9], [0.82, 6], [0.28, 4], [0.72, 4]]
		for st in stacks:
			var x = W * st[0]; var base = H * (0.86 if st[1] > 5 else 0.95)
			for k in st[1]:
				var y = base - k * ch * 0.55
				Gfx.ellipse(self, Vector2(x, y + ch * 0.25), cw * 0.5, ch * 0.5, Color("#9a6a12"), 18)
				Gfx.ellipse(self, Vector2(x, y), cw * 0.5, ch * 0.5, Color("#f5d36a").lerp(Color("#c99a2a"), float(k % 3) / 3.0), 18)
		var fc = Vector2(W * 0.5, H * 0.66); var fr = W * 0.17
		draw_circle(fc, fr, Color("#b8861d")); draw_circle(fc, fr * 0.86, Color("#1c1a14")); draw_arc(fc, fr * 0.93, 0, TAU, 40, Color("#f8d77a"), fr * 0.1)
		Gfx.text_c(self, UI.font_head, fc.x, fc.y + fr * 0.25, "PF", int(fr * 0.7), Color("#f3d88a"))
		for k in 5:
			var a = t * 2.0 + k * 1.3; var sp = Vector2(W * (0.2 + 0.15 * k), H * (0.2 + 0.1 * (k % 3)))
			var s = (sin(a) + 1.0) * 0.5 * W * 0.025
			draw_line(sp - Vector2(s, 0), sp + Vector2(s, 0), Color(1, 1, 0.9, 0.9), 2.0); draw_line(sp - Vector2(0, s), sp + Vector2(0, s), Color(1, 1, 0.9, 0.9), 2.0)

class Sparks extends Control:
	var parts = []
	func burst(at: Vector2, n := 40, col := Color("#ffd36b")) -> void:
		for i in n:
			var a = randf() * TAU; var v = randf_range(120, 420)
			parts.append({"p": at, "v": Vector2(cos(a), sin(a)) * v, "life": randf_range(0.6, 1.3), "c": col, "s": randf_range(2, 5)})
	func _process(d: float) -> void:
		for p in parts: p.p += p.v * d; p.v *= 0.96; p.v.y += 260 * d; p.life -= d
		parts = parts.filter(func(p): return p.life > 0); queue_redraw()
	func _draw() -> void:
		for p in parts: draw_circle(p.p, p.s, Color(p.c, clamp(p.life, 0.0, 1.0)))

func s_champsreward(p) -> Dictionary:
	var res: Dictionary = p.get("res", {"rank": -1, "reward": {}})
	var rw: Dictionary = res.get("reward", {})
	var page = Control.new(); page.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bgc = ChampsBG.new(); bgc.set_anchors_preset(Control.PRESET_FULL_RECT); page.add_child(bgc)
	var dim = ColorRect.new(); dim.color = Color(0, 0, 0, 0.55); dim.set_anchors_preset(Control.PRESET_FULL_RECT); page.add_child(dim)
	var sparks = Sparks.new(); sparks.set_anchors_preset(Control.PRESET_FULL_RECT); sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mg = MarginContainer.new(); mg.set_anchors_preset(Control.PRESET_FULL_RECT)
	for kv in [["left", 52], ["right", 52], ["top", 20], ["bottom", 16]]: mg.add_theme_constant_override("margin_" + kv[0], kv[1])
	page.add_child(mg); page.add_child(sparks)
	var v = UI.vb(10); mg.add_child(v)
	v.add_child(UI.hb(14, [UI.icon("badge", Save.data.profile.badge, Vector2(44, 48)), UI.label("Play", 18, UI.DIM), UI.bold("Rivals", 22), UI._sepline(), UI.label("Rivals", 16, UI.DIM), UI.bold("Champions", 16), UI.spacer(), UI.currency_bar()]))
	var title = UI.head("CHAMPIONS", 64); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub = UI.label("Congratulations - here are your Champions Competition Rewards!", 20); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rk = UI.bold("You finished at %s" % Champs.rank_name(int(res.get("rank", -1))), 17, GOLD); rk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title); v.add_child(sub); v.add_child(rk)
	v.add_child(UI.vspacer())
	var row = UI.hb(70); row.alignment = BoxContainer.ALIGNMENT_CENTER
	var items = []
	if rw.get("tokens", 0): items.append([Token.make(230), int(rw.tokens), "Champions\nToken"])
	if rw.get("qp", 0): var tr = Trophy.new(); tr.custom_minimum_size = Vector2(160, 160); items.append([tr, int(rw.qp), "Champions Qualification\nPoints"])
	if rw.get("coins", 0): var cp = CoinPile.new(); cp.custom_minimum_size = Vector2(190, 160); items.append([cp, int(rw.coins), "Coins"])
	if items.is_empty(): row.add_child(UI.label("No rank reached this time — win a match to earn rewards.", 18, UI.DIM))
	var cols = []
	for it in items:
		var hold = CenterContainer.new(); hold.custom_minimum_size = Vector2(250, 250); hold.add_child(it[0])
		var num = UI.head("0", 46); num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var nm = UI.label(it[2], 24); nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var col = UI.vb(4, [hold, num, nm]); col.modulate.a = 0.0
		row.add_child(col); cols.append([col, num, it[1], hold])
	v.add_child(row)
	v.add_child(UI.vspacer())
	var g = func(ps: String, xb: String, kb: String) -> String: return ps if Pad.style == "ps" else (xb if Pad.style == "xbox" else kb)
	var adv = UI.btn("%s  Advance" % g.call("✕", "A", "Enter"), func(): _leave_reward(), "Primary", true); adv.custom_minimum_size.x = 200
	v.add_child(UI.hb(22, [adv, UI._key_hint(g.call("○", "B", "Esc"), "Back")]))
	# staggered reveal: pop in, count up, sparkle
	var start = func():
		Sfx.play("riser")
		title.pivot_offset = title.size / 2; title.scale = Vector2(1.6, 1.6); title.modulate.a = 0
		var tt = title.create_tween().set_parallel(); tt.tween_property(title, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT); tt.tween_property(title, "modulate:a", 1.0, 0.4)
		for i in cols.size():
			var c = cols[i]; var col: Control = c[0]; var num: Label = c[1]; var amount: int = c[2]; var hold: Control = c[3]
			var tw = col.create_tween()
			tw.tween_interval(0.6 + i * 0.75)
			tw.tween_callback(func():
				col.pivot_offset = col.size / 2; col.scale = Vector2(0.3, 0.3); Sfx.play("reveal")
				sparks.burst(hold.get_global_rect().get_center() - sparks.get_global_rect().position, 46))
			tw.tween_property(col, "modulate:a", 1.0, 0.15)
			tw.parallel().tween_property(col, "scale", Vector2(1.12, 1.12), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(col, "scale", Vector2.ONE, 0.15)
			tw.tween_method(func(x: float): num.text = Sys.fmt(int(x)), 0.0, float(amount), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func(): Sfx.play("coin"))
		var fin = page.create_tween(); fin.tween_interval(0.8 + cols.size() * 0.75 + 0.6)
		fin.tween_callback(func(): Sfx.play("bigreveal"); for k in 3: sparks.burst(Vector2(sparks.size.x * (0.25 + k * 0.25), sparks.size.y * 0.35), 60, [Color("#ffd36b"), Color("#ff4f5e"), Color.WHITE][k]))
	start.call_deferred()
	return {"node": page, "bg": "off", "back": func(): _leave_reward()}

## leave the rewards reveal → Champions screen, keeping Play underneath so Back still exits
func _leave_reward() -> void:
	UI.stack = [["play", {}, []]]
	UI._show("champions", {})

func _play_pressed() -> void:
	var r = Champs.run()
	if r == null:
		if Champs.cooldown_left() > 0: UI.toast("Next FUT Champions run available in " + Sys.fmt_time(Champs.cooldown_left()), "bad"); return
		if not Champs.qualified():
			UI.toast("Earn %s more Champions Qual. Points in Division Rivals (win +200 · draw +100 · loss +50)" % Sys.fmt(Champs.QP_NEED - int(Champs.st().qp)), "bad")
			UI.go("rivals"); return
		if not Champs.div_ok(): UI.toast("Reach Rivals Division %d first" % Champs.MIN_DIV, "bad"); return
		if not await UI.modal("Enter FUT Champions?", "This uses your 1,000 Qualification Points. You get %d matches this week; rewards are based on the highest rank you reach." % Champs.MATCHES, [["Cancel", null, ""], ["Enter", true, "Primary"]]): return
		Champs.start()
		_play_match(); return
	if r.done: _show_claim(Champs.claim()); return
	_play_match()

func _play_match() -> void:
	if not UI.modules[2].require_squad(): return
	var r = Champs.run()
	var ut = Sys.user_team()
	var nm = "%s%s" % [Sys.pick(["Elite", "Prime", "Apex", "Legend", "Volt", "Nova"]), Sys.pick(["_FC", "Gaming", "XI", "99", "Utd"])]
	var opp = Sys.ai_team(nm, min(93, 85 + int(r.w) * 0.45 + Sys.experience() * 20))
	Sys.league3_check(ut)
	UI.run_match({"home": ut, "away": opp, "user_side": "home", "difficulty": "ultimate", "ai": min(1.3, 1.12 + int(r.w) * 0.015 + Sys.experience()), "elite": true, "half_len": int(Save.data.settings.half_len), "mode": "champs", "title": "FUT Champions · Match %d/%d" % [int(r.played) + 1, Champs.MATCHES], "knockout": true}, func(res):
		var r0 = Sys.record_ut_match(res)
		var won: bool = r0 == "W" or (r0 == "D" and res.get("winner", "") == "home")
		var out = Champs.record(won, "%d-%d" % [res.hg, res.ag], nm)
		Sys.add("coins", 1200 if won else 400, "FUT Champions match")
		Sys.log_match(res, "Champions", "W" if won else "L")
		var rk = Champs.rank_name(out.rank)
		UI.show_results(res, "FUT Champions", "+%d pts · %s · +%s coins%s" % [out.pts, rk, Sys.fmt(1200 if won else 400), " · run complete — claim your rewards" if Champs.run().done else ""], func(): UI.replace("champions")))

# ------------------------------------------------------------------ token store
func s_champsstore(_p) -> Dictionary:
	var f = UI.sub_shell("Champions Token Store", "FUT Champions")
	f.body.add_child(UI.hb(14, [Token.make(84), UI.head("TOKEN STORE", 38), UI.spacer(), UI.panel(UI.hb(10, [Token.make(46), UI.vb(0, [UI.caps("Champions Tokens", 10), UI.head(Sys.fmt(Champs.tokens()), 26, GOLD)])]), "Glass")]))
	f.body.add_child(UI.label("Earn Champions Tokens from your FUT Champions rank rewards every week.", 13, UI.DIM))
	var flow = HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 16); flow.add_theme_constant_override("v_separation", 16)
	var first = true
	for it in Champs.STORE:
		var rwd: Dictionary = it.reward
		var vis: Control = UI.icon("pack", rwd.pack, Vector2(84, 118)) if rwd.has("pack") else UI.head("●", 56, UI.GOLD2)
		if vis is Icon: vis.animate = false
		var hold = CenterContainer.new(); hold.custom_minimum_size = Vector2(170, 124); hold.add_child(vis)
		var left = "" if int(it.limit) == 0 else "  ·  %d left" % (int(it.limit) - Champs.bought(it.id))
		var ok: bool = Champs.can_buy(it)
		var t = UI.tile([hold, UI.bold(it.name, 15), UI.hb(6, [Token.make(22), UI.bold("%s%s" % [Sys.fmt(it.cost), left], 14, GOLD if ok else UI.DIM)])],
			func():
				if int(it.limit) > 0 and Champs.bought(it.id) >= int(it.limit): UI.toast("Sold out", "bad"); return
				if Champs.tokens() < int(it.cost): UI.toast("Not enough Champions Tokens", "bad"); Sfx.play("error"); return
				if await UI.modal("Buy %s?" % it.name, "Spend ◉ %s Champions Tokens?" % Sys.fmt(it.cost), [["Buy", true, "Primary"], ["Cancel", null, ""]]):
					if Champs.buy(it): Sfx.play("coin"); UI.replace("champsstore"), Vector2(210, 230), first)
		if not ok: t.modulate = Color(1, 1, 1, 0.7)
		flow.add_child(t); first = false
	f.body.add_child(UI.scroll(flow))
	return {"node": f.node, "bg": "hub"}

func _back_or_play() -> void:
	if UI.stack.is_empty(): UI.reset("play")
	else: UI.back()
