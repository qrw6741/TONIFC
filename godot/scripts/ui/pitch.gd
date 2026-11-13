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

func _layout() -> void:
	var r = _rect()
	var F: Array = Data.formations[formation]
	for i in cards.size():
		var c: PlayerCard = cards[i]
		var pos = r.position + Vector2(F[i][1] / 100.0 * r.size.x, F[i][2] / 100.0 * r.size.y)
		c.position = pos - c.custom_minimum_size / 2
	queue_redraw()

func _draw() -> void:
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
