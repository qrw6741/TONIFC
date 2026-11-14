class_name PlayerCard
extends Button
## A player card drawn entirely in code. Rarity-specific design, focus glow,
## chemistry diamonds, and drag & drop support for the squad builder.

var p: Dictionary = {}
var cs = 10.0            # card unit size (card is 12 x 16.8 units, mini 7.4 x 10.4)
var mini = false
var item_uid = ""
var untr = false
var chem = -1
var empty_pos = ""        # draws an empty slot when p is empty
var tag = ""              # small label under/over card (e.g. DUPLICATE)
var brackets = false      # draw FC-style selection brackets when focused
var drag_id = null         # payload for drag & drop
var drop_cb: Callable      # func(from_payload, to_payload)
var _t = 0.0

static func make(player: Dictionary, size := 10.0, is_mini := false) -> PlayerCard:
	var c = PlayerCard.new()
	c.p = player; c.cs = size; c.mini = is_mini
	c._fit()
	return c

func _fit() -> void:
	var w = (7.4 if mini else 12.0) * cs
	var h = (10.4 if mini else 16.8) * cs + (cs * 1.6 if chem >= 0 else 0.0)
	custom_minimum_size = Vector2(w, h)
	pivot_offset = Vector2(w, h) / 2

func set_chem(v: int) -> void: chem = v; _fit(); queue_redraw()

func _ready() -> void:
	flat = true; focus_mode = Control.FOCUS_ALL
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	mouse_entered.connect(func(): if UI.mouse_recent() and not has_focus(): grab_focus())
	focus_entered.connect(func():
		Sfx.play("move"); _t = 0.0
		create_tween().tween_property(self, "scale", Vector2(1.06, 1.06), 0.12)
		queue_redraw())
	focus_exited.connect(func(): create_tween().tween_property(self, "scale", Vector2.ONE, 0.12); queue_redraw())
	_fit()

func _process(delta: float) -> void:
	if has_focus():
		_t += delta; queue_redraw()

func _draw() -> void:
	var w = (7.4 if mini else 12.0) * cs
	var h = (10.4 if mini else 16.8) * cs
	var r = Rect2(Vector2.ZERO, Vector2(w, h))
	var font_h: Font = UI.font_head; var font_b: Font = UI.font_bold
	if p.is_empty():
		var sh = Gfx.shield(r)
		draw_colored_polygon(sh, Color(1, 1, 1, 0.08))
		var o = sh.duplicate(); o.append(sh[0]); draw_polyline(o, Color(1, 1, 1, 0.3) if not has_focus() else UI.TEAL, 1.5 if not has_focus() else 3.0, true)
		Gfx.text_c(self, font_b, w / 2, h * 0.52, "+", int(cs * 3), Color(1, 1, 1, 0.45))
		Gfx.text_c(self, font_h, w / 2, h * 0.86, empty_pos, int(cs * 1.1), Color(1, 1, 1, 0.75))
		return
	var st: Dictionary = Data.rarity_style(Data.rarity_key(p))
	var sh = Gfx.shield(r)
	# shadow & focus glow
	draw_colored_polygon(Gfx.shield(Rect2(r.position + Vector2(0, cs * 0.5), r.size)), Color(0, 0, 0, 0.35))
	if has_focus():
		var g: Color = st.glow; g.a = 0.45 + 0.2 * sin(_t * 5.0)
		var gl = Gfx.shield(r.grow(cs * 0.45)); draw_colored_polygon(gl, g)
	Gfx.grad_poly(self, sh, r, st.top, st.mid, st.bot)
	if st.get("shards", false):
		var sc: Color = st.get("shard_col", Color(1, 1, 1, 0.3))
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.25, h * 0.08), Vector2(w * 0.42, h * 0.08), Vector2(w * 0.08, h * 0.62), Vector2(w * 0.0, h * 0.62)]), sc)
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.75, h * 0.45), Vector2(w * 0.95, h * 0.3), Vector2(w * 0.95, h * 0.42), Vector2(w * 0.78, h * 0.62)]), sc)
	# shine sweep when focused
	if has_focus():
		var sx = fmod(_t * 1.2, 2.0) * w * 1.5 - w * 0.3
		var shine = PackedVector2Array()
		for q in [Vector2(sx, 0), Vector2(sx + w * 0.12, 0), Vector2(sx - w * 0.25, h), Vector2(sx - w * 0.37, h)]: shine.append(Vector2(clamp(q.x, 0, w), q.y))
		draw_colored_polygon(shine, Color(1, 1, 1, 0.22))
	var trim = Gfx.shield(r, cs * 0.35); trim.append(trim[0])
	draw_polyline(trim, st.trim, max(1.0, cs * 0.14), true)
	var tc: Color = st.text
	if p.type == "rising" and not mini:
		# star sparkles
		for sp in [[0.1, 0.56, 0.5], [0.9, 0.5, 0.42], [0.86, 0.62, 0.3], [0.14, 0.66, 0.32]]:
			var sc = Vector2(w * sp[0], h * sp[1]); var sr: float = cs * sp[2]
			draw_colored_polygon(PackedVector2Array([sc + Vector2(0, -sr), sc + Vector2(sr * 0.28, -sr * 0.28), sc + Vector2(sr, 0), sc + Vector2(sr * 0.28, sr * 0.28), sc + Vector2(0, sr), sc + Vector2(-sr * 0.28, sr * 0.28), sc + Vector2(-sr, 0), sc + Vector2(-sr * 0.28, -sr * 0.28)]), Color(0.75, 0.98, 1, 0.75))
	if p.type == "gallery":
		# museum frame: inner gilt-pink frame, corner gems and a light wash from the top
		var inner = Gfx.shield(r, cs * 0.95); inner.append(inner[0])
		draw_polyline(inner, Color(1, 0.44, 0.85, 0.55), max(1.0, cs * 0.1), true)
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.3, 0), Vector2(w * 0.7, 0), Vector2(w * 0.95, h * 0.55), Vector2(w * 0.05, h * 0.55)]), Color(1, 0.6, 0.95, 0.06))
		for gp in [Vector2(w * 0.1, h * 0.14), Vector2(w * 0.9, h * 0.14), Vector2(w * 0.5, h * 0.93)]:
			var gr: float = cs * (0.42 if mini else 0.5)
			draw_colored_polygon(PackedVector2Array([gp + Vector2(0, -gr), gp + Vector2(gr * 0.8, 0), gp + Vector2(0, gr), gp + Vector2(-gr * 0.8, 0)]), Color("#ff9be6"))
			draw_colored_polygon(PackedVector2Array([gp + Vector2(0, -gr * 0.5), gp + Vector2(gr * 0.35, 0), gp + Vector2(0, gr * 0.15), gp + Vector2(-gr * 0.35, 0)]), Color(1, 1, 1, 0.8))
	if p.type == "pass" and not mini:
		# Ascension chevrons on both flanks
		for k in 3:
			var cy = h * (0.6 - k * 0.04); var a = 0.65 - k * 0.18
			for sx in [w * 0.075, w * 0.925]:
				draw_polyline(PackedVector2Array([Vector2(sx - cs * 0.45, cy + cs * 0.4), Vector2(sx, cy), Vector2(sx + cs * 0.45, cy + cs * 0.4)]), Color(1, 0.78, 0.42, a), max(1.0, cs * 0.16), true)
	if p.type != "base" and not mini:
		Gfx.text_c(self, font_b, w / 2, cs * 1.25, Data.card_types[p.type].name.to_upper(), int(cs * 0.6), Color(tc, 0.85))
	if mini:
		Gfx.portrait(self, Rect2(Vector2(w - cs * 5.2, cs * 0.6), Vector2(cs * 4.9, cs * 5.6)), p)
		Gfx.text(self, font_h, Vector2(cs * 0.75, cs * 2.75), str(p.ovr), int(cs * 1.95), tc)
		Gfx.text(self, font_b, Vector2(cs * 0.85, cs * 3.85), p.pos, int(cs * 0.82), tc)
		Gfx.text_c(self, font_b, w / 2, cs * 7.3, _fit_name(Data.short_name(p.name), font_b, int(cs * 0.95), w - cs * 1.2), int(cs * 0.95), tc)
		Gfx.flag(self, Rect2(Vector2(w / 2 - cs * 2.2, cs * 7.85), Vector2(cs * 1.3, cs * 0.85)), p.nat)
		Gfx.league(self, Vector2(w / 2, cs * 8.3), cs * 1.25, p.lg)
		Gfx.crest(self, Vector2(w / 2 + cs * 1.6, cs * 8.3), cs * 1.15, p.club)
	else:
		Gfx.portrait(self, Rect2(Vector2(w - cs * 8.2, cs * 1.15), Vector2(cs * 7.6, cs * 8.0)), p)
		Gfx.text(self, font_h, Vector2(cs * 1.3, cs * 3.9), str(p.ovr), int(cs * 2.6), tc)
		Gfx.text(self, font_b, Vector2(cs * 1.42, cs * 5.4), p.pos, int(cs * 1.1), tc)
		Gfx.flag(self, Rect2(Vector2(cs * 1.4, cs * 6.0), Vector2(cs * 1.85, cs * 1.2)), p.nat)
		Gfx.crest(self, Vector2(cs * 2.32, cs * 8.25), cs * 1.85, p.club)
		Gfx.text_c(self, font_b, w / 2, cs * 10.4, _fit_name(Data.short_name(p.name), font_b, int(cs * 1.15), w - cs * 2.4), int(cs * 1.15), tc)
		var lab: Array = Data.GK_LABELS if p.pos == "GK" else Data.STAT_LABELS
		var cw = (w - cs * 2.2) / 6.0
		for i in 6:
			var cx = cs * 1.1 + cw * (i + 0.5)
			Gfx.text_c(self, font_h, cx, cs * 12.05, str(p.stats[i]), int(cs * 1.05), tc)
			Gfx.text_c(self, font_b, cx, cs * 12.85, lab[i], int(cs * 0.6), Color(tc, 0.78))
		Gfx.flag(self, Rect2(Vector2(w / 2 - cs * 2.6, cs * 13.75), Vector2(cs * 1.65, cs * 1.1)), p.nat)
		Gfx.league(self, Vector2(w / 2, cs * 14.3), cs * 1.6, p.lg)
		Gfx.crest(self, Vector2(w / 2 + cs * 1.85, cs * 14.3), cs * 1.5, p.club)
	if untr: draw_circle(Vector2(w - cs * 1.4, cs * 1.6), cs * 0.32, Color("#ff6464"))
	if tag != "": Gfx.text_c(self, font_b, w / 2, h - cs * 0.9, tag, int(cs * 0.8), Color.WHITE)
	if brackets and has_focus():
		var bc = Color(1, 1, 1, 0.85); var L = cs * 2.2; var o = cs * 0.7; var bw = max(2.0, cs * 0.22)
		for cx in [[-o, 1], [w + o, -1]]:
			for cy in [[-o, 1], [h + o, -1]]:
				draw_line(Vector2(cx[0], cy[0]), Vector2(cx[0] + L * cx[1], cy[0]), bc, bw)
				draw_line(Vector2(cx[0], cy[0]), Vector2(cx[0], cy[0] + L * cy[1]), bc, bw)
	if chem >= 0:
		for i in 3:
			var c = Vector2(w / 2 + (i - 1) * cs * 1.15, h + cs * 0.8)
			var on = i < chem
			var col = UI.TEAL if on else (Color(1, 0.3, 0.37, 0.5) if chem == 0 else Color(1, 1, 1, 0.18))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -cs * 0.45), c + Vector2(cs * 0.45, 0), c + Vector2(0, cs * 0.45), c + Vector2(-cs * 0.45, 0)]), col)

func _fit_name(s: String, font: Font, size: int, maxw: float) -> String:
	var t = s
	while t.length() > 3 and font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > maxw:
		t = t.substr(0, t.length() - 2) + "…"
		t = t.substr(0, t.length() - 1) if t.ends_with("……") else t
	return t

# ---------------- drag & drop ----------------
func _get_drag_data(_pos: Vector2):
	if drag_id == null or p.is_empty(): return null
	var prev = PlayerCard.make(p, cs * 0.9, mini)
	prev.modulate.a = 0.85
	set_drag_preview(prev)
	return {"card_drag": drag_id}

func _can_drop_data(_pos: Vector2, data) -> bool:
	return drop_cb.is_valid() and typeof(data) == TYPE_DICTIONARY and data.has("card_drag") and drag_id != null

func _drop_data(_pos: Vector2, data) -> void:
	drop_cb.call(data.card_drag, drag_id)
