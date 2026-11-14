class_name PitchView
extends Control
## Vertical pitch with 11 card slots positioned by formation, chemistry link lines,
## captain marker and out-of-position flags. Slots emit slot_pressed(i).

signal slot_pressed(i: int)
signal slot_drop(from_id, to_id)

var formation = "4-3-3"
var players = []      # Array of Dictionary ({} = empty)
var chem = null
var captain_idx = -1
var selected = -1
var show_links = true
var cards = []
var card_cs = 8.6
var persp = false     # FC-style angled pitch (squad screen): narrower far end, position pills under cards

func setup(f: String, ps: Array, c = null, cap := -1, sel := -1) -> PitchView:
	formation = f; players = ps; chem = c; captain_idx = cap; selected = sel
	show_links = Save.data.settings.get("show_links", true) if Save.data else true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL; size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(560, 640)
	_build()
	return self

func _build() -> void:
	for c in cards: c.queue_free()
	cards.clear()
	var F: Array = Data.formations[formation]
	for i in 11:
		var p: Dictionary = players[i] if i < players.size() else {}
		var c = PlayerCard.make(p, card_cs, true)
		c.empty_pos = F[i][0]
		if chem and not p.is_empty(): c.set_chem(chem.per[i])
		c.drag_id = i
		c.drop_cb = func(a, b): slot_drop.emit(a, b)
		c.pressed.connect(func(): Sfx.play("select"); slot_pressed.emit(i))
		add_child(c); cards.append(c)
	resized.connect(_layout)
	_layout.call_deferred()

func _rect() -> Rect2:
	var h = size.y; var w: float = min(size.x, h * 0.82)
	return Rect2(Vector2((size.x - w) / 2, 0), Vector2(w, h))

## perspective mapping of pitch coords (0–100) to pixels
func _pp(x: float, y: float) -> Vector2:
	var w = size.x; var h = size.y
	var wy = lerp(0.66, 1.0, clamp(y / 100.0, 0.0, 1.0)) * w
	return Vector2(w / 2 + (x - 50.0) / 100.0 * wy, y / 100.0 * h)

## where a slot's card centre goes (keeps the GK and strikers + pills inside the pitch)
func slot_pos(x: float, y: float) -> Vector2:
	if not persp:
		var r = _rect(); return r.position + Vector2(x / 100.0 * r.size.x, y / 100.0 * r.size.y)
	var ch: float = cards[0].custom_minimum_size.y if not cards.is_empty() else 100.0
	var top = ch / 2 + 6; var bot = size.y - ch / 2 - 30
	var py = top + (y - 18.0) / (92.0 - 18.0) * (bot - top)
	var yy = py / max(1.0, size.y) * 100.0
	return Vector2(_pp(x, yy).x, py)

func _layout() -> void:
	var F: Array = Data.formations[formation]
	for i in cards.size():
		var c: PlayerCard = cards[i]
		c.position = slot_pos(F[i][1], F[i][2]) - c.custom_minimum_size / 2
	queue_redraw()

func _draw() -> void:
	if persp: _draw_persp(); return
	var r = _rect()
	var stripes = 12
	for i in stripes:
		draw_rect(Rect2(r.position + Vector2(0, r.size.y * i / stripes), Vector2(r.size.x, r.size.y / stripes + 1)), Color("#1c5e33") if i % 2 == 0 else Color("#1a5630"))
	var lc = Color(1, 1, 1, 0.32)
	var P = func(x, y): return r.position + Vector2(x / 100.0 * r.size.x, y / 100.0 * r.size.y)
	draw_rect(Rect2(P.call(3, 3), P.call(97, 97) - P.call(3, 3)), lc, false, 1.5)
	draw_line(P.call(3, 50), P.call(97, 50), lc, 1.2)
	Gfx.ellipse_line(self, P.call(50, 50), r.size.x * 0.11, r.size.y * 0.09, lc, 1.2)
	draw_rect(Rect2(P.call(25, 3), P.call(75, 17) - P.call(25, 3)), lc, false, 1.2)
	draw_rect(Rect2(P.call(25, 83), P.call(75, 97) - P.call(25, 83)), lc, false, 1.2)
	if show_links:
		var F: Array = Data.formations[formation]
		var links: Array = chem.links if chem else Sys.formation_links(formation).map(func(l): return {"a": l[0], "b": l[1], "q": "none"})
		for l in links:
			var col: Color = {"green": UI.GREEN, "yellow": UI.YELLOW, "red": UI.RED, "none": Color(1, 1, 1, 0.25)}[l.q]
			draw_line(P.call(F[l.a][1], F[l.a][2]), P.call(F[l.b][1], F[l.b][2]), col, 3.0 if l.q != "none" else 1.5, true)
	# captain + out-of-position markers drawn over the links but under cards (cards are children)

func _draw_persp() -> void:
	var w = size.x; var h = size.y
	var P = func(x, y): return _pp(x, y)
	# grass with mowing stripes
	var n = 10
	for i in n:
		var y0 = 100.0 * i / n; var y1 = 100.0 * (i + 1) / n
		var poly = PackedVector2Array([P.call(0, y0), P.call(100, y0), P.call(100, y1), P.call(0, y1)])
		var c = Color("#2f6b3a") if i % 2 == 0 else Color("#2a6235")
		draw_colored_polygon(poly, c.lerp(Color("#3a7d45"), float(i) / n * 0.5))
	var lc = Color(1, 1, 1, 0.38)
	var L = func(a, b): draw_line(P.call(a.x, a.y), P.call(b.x, b.y), lc, 2.0, true)
	var box = func(x0, y0, x1, y1):
		L.call(Vector2(x0, y0), Vector2(x1, y0)); L.call(Vector2(x1, y0), Vector2(x1, y1)); L.call(Vector2(x1, y1), Vector2(x0, y1)); L.call(Vector2(x0, y1), Vector2(x0, y0))
	box.call(3, 2, 97, 98)
	L.call(Vector2(3, 40), Vector2(97, 40))
	var pts = PackedVector2Array()
	for k in 33:
		var a = TAU * k / 32.0
		pts.append(P.call(50 + cos(a) * 12, 40 + sin(a) * 10))
	draw_polyline(pts, lc, 2.0, true)
	box.call(25, 2, 75, 14); box.call(25, 84, 75, 98); box.call(38, 92, 62, 98)
	# chemistry links between card centres
	if show_links and chem:
		var F: Array = Data.formations[formation]
		for l in chem.links:
			var col: Color = {"green": UI.GREEN, "yellow": UI.YELLOW, "red": UI.RED, "none": Color(1, 1, 1, 0.2)}[l.q]
			col.a = 0.55
			draw_line(slot_pos(F[l.a][1], F[l.a][2]), slot_pos(F[l.b][1], F[l.b][2]), col, 2.0, true)
	# formation watermark
	draw_string(UI.font_head, Vector2(26, h - 22), formation, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color(1, 1, 1, 0.22))
	# position pills under every card
	var Fm: Array = Data.formations[formation]
	for i in cards.size():
		var c: PlayerCard = cards[i]
		var p: Dictionary = players[i] if i < players.size() else {}
		var pos: String = Fm[i][0]
		var fits: bool = p.is_empty() or Data.fits_pos(p, pos)
		var txt = pos + ("+" if not p.is_empty() and fits and chem and int(chem.per[i]) >= 3 else "")
		var cx = c.position.x + c.custom_minimum_size.x / 2; var cy = c.position.y + c.custom_minimum_size.y + 4
		var fw = UI.font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var pr = Rect2(cx - max(36.0, fw + 22) / 2, cy, max(36.0, fw + 22), 20)
		var sb = StyleBoxFlat.new(); sb.set_corner_radius_all(10)
		sb.bg_color = Color("#123d55") if fits else Color("#5a1d1d"); sb.border_color = Color("#3fb6e0") if fits else UI.RED; sb.set_border_width_all(1)
		if i == selected: sb.border_color = Color.WHITE; sb.set_border_width_all(2)
		draw_style_box(sb, pr)
		draw_string(UI.font_bold, Vector2(pr.position.x + (pr.size.x - fw) / 2, cy + 15), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#bfeaff") if fits else Color("#ffb3b3"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW: pass

func _process(_d: float) -> void:
	# overlay markers (captain, OOP, selection) are drawn by a small overlay pass
	for i in cards.size():
		var c: PlayerCard = cards[i]
		var want = Color(1.25, 1.25, 1.25) if i == selected else Color.WHITE
		if c.modulate != want: c.modulate = want
		var p: Dictionary = players[i] if i < players.size() else {}
		var tag = ""
		if not p.is_empty() and not Data.fits_pos(p, Data.formations[formation][i][0]): tag = "⚠ " + Data.formations[formation][i][0]
		if i == captain_idx and not p.is_empty(): tag = ("Ⓒ " + tag) if tag != "" else "Ⓒ CAPTAIN"
		if c.tag != tag: c.tag = tag; c.queue_redraw()
