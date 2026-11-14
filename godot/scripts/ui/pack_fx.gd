extends Control
## Cinematic pack opening: floating pack, stadium light beams, sparks, walkout
## sequence for big pulls (nation → position → club → rating) and final card reveal.

signal finished

var pack_id = ""
var best: Dictionary
var walkout = false
var lvl = 0
var beams = 0.0
var flash = 0.0
var t = 0.0
var sparks = []
var stage: CenterContainer
var timers = []
var revealed = false
var finished_called = false
var colors = []
var art: Control = null

func setup(id: String, b: Dictionary, w: bool, l: int) -> void:
	pack_id = id; best = b; walkout = w; lvl = l
	colors = [[Color("#cfd6de"), Color("#7f8a99")], [Color("#ffd34a"), Color("#c3901c")], [Color("#ffd34a"), Color("#ff8a00")], [Color("#ff4fa3"), Color("#7a2ff5")], [Color("#fff3c4"), Color("#e8b631")]][l]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_STOP
	stage = CenterContainer.new(); stage.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(stage)
	var skip_b = UI.btn("Skip ▸▸", skip, "Small"); skip_b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT); skip_b.position = Vector2(-120, -60); skip_b.name = "skip"
	add_child(skip_b)
	# take focus away from the menu underneath, so ✕ / Enter can't press "Open" on another pack
	skip_b.focus_mode = Control.FOCUS_ALL
	skip_b.grab_focus.call_deferred()
	art = UI.icon("pack", pack_id, Vector2(200, 284))
	var v = UI.vb(20, [art, UI.bold("Opening %s…" % Data.packs[pack_id].name, 16, UI.DIM)])
	v.alignment = BoxContainer.ALIGNMENT_CENTER; art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_set_stage(v)
	art.pivot_offset = Vector2(100, 142)
	Sfx.play("riser")
	create_tween().tween_property(self, "beams", 0.4 + lvl * 0.15, 1.4)
	_at(1.5, func():
		flash = 0.9; Sfx.play("whoosh")
		if is_instance_valid(art):
			var t2 = art.create_tween(); t2.tween_property(art, "scale", Vector2(1.4, 1.4), 0.3); t2.parallel().tween_property(art, "modulate:a", 0.0, 0.3))
	if walkout:
		var steps = [
			func(): return UI.vb(10, [UI.icon("flag", best.nat, Vector2(240, 160)), _center(UI.head(Data.nations[best.nat].name.to_upper(), 34))]),
			func(): return UI.head(best.pos, 90),
			func(): return UI.vb(10, [UI.icon("crest", best.club, Vector2(200, 200)), _center(UI.head(Data.clubs[best.club].name.to_upper(), 30))]),
			func(): return UI.head(str(best.ovr), 160, colors[0])]
		for i in steps.size():
			_at(2.0 + i * 1.3, func():
				var n: Control = steps[i].call()
				_set_stage(n); n.pivot_offset = n.get_combined_minimum_size() / 2; n.scale = Vector2(1.6, 1.6); n.modulate.a = 0
				var t3 = n.create_tween().set_parallel(); t3.tween_property(n, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT); t3.tween_property(n, "modulate:a", 1.0, 0.3)
				Sfx.play("boom" if i == 3 else "reveal")
				create_tween().tween_property(self, "beams", 0.6 + lvl * 0.1 + i * 0.1, 0.4)
				if i == 3: burst(120); flash = 0.4)
		_at(2.0 + 4 * 1.3, reveal)
	else: _at(2.0, reveal)

func _center(l: Label) -> Label: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; return l

func _at(sec: float, cb: Callable) -> void:
	var tm = get_tree().create_timer(sec)
	timers.append(tm)
	tm.timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree() and not revealed and not finished_called: cb.call())

func _set_stage(n: Control) -> void:
	for c in stage.get_children(): c.queue_free()
	stage.add_child(n)

func skip() -> void:
	if revealed:
		if t - revealed_at > 0.35: done()   # ignore a double-tap right after the reveal
		return
	reveal()

var revealed_at = 0.0
## the overlay owns every confirm press while it's open (nothing reaches the menu behind it)
func _input(e: InputEvent) -> void:
	if finished_called: return
	if e.is_action_pressed("ui_accept") and not e.is_echo():
		get_viewport().set_input_as_handled()
		skip()
	elif (e is InputEventJoypadButton or e is InputEventKey) and e.is_pressed() and not e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()

func reveal() -> void:
	if revealed: return
	revealed = true; revealed_at = t
	flash = 0.7; burst(220 if lvl > 0 else 60); create_tween().tween_property(self, "beams", 1.0, 0.3)
	Sfx.play("bigreveal" if lvl >= 2 else "reveal")
	var c = UI.card(best, 22.0); c.focus_mode = Control.FOCUS_NONE; c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.pivot_offset = c.custom_minimum_size / 2; c.scale = Vector2(0.3, 0.3); c.modulate.a = 0
	var cont = UI.btn("Ⓐ  Continue", done, "Primary", true); cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var v = UI.vb(16, [c, _center(UI.bold("%s · %s" % [best.name, Data.rarity_name(best)], 20)), cont]); v.alignment = BoxContainer.ALIGNMENT_CENTER
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_set_stage(v)
	art = null
	var tw = c.create_tween().set_parallel(); tw.tween_property(c, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT); tw.tween_property(c, "modulate:a", 1.0, 0.4)
	var sk = get_node_or_null("skip")
	if sk: sk.visible = false
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(cont) and cont.is_inside_tree(): cont.grab_focus()

func done() -> void:
	if finished_called: return
	finished_called = true
	finished.emit()

func burst(n: int) -> void:
	var c = size / 2 - Vector2(0, size.y * 0.05)
	for i in n:
		var a = randf() * TAU; var v = randf_range(2, 9)
		sparks.append({"p": c, "v": Vector2(cos(a), sin(a)) * v - Vector2(0, 3), "l": 1.0, "c": colors[randi() % 2]})

func _process(delta: float) -> void:
	t += delta
	if is_instance_valid(art) and art.is_inside_tree() and art.modulate.a > 0.99: art.position.y = sin(t * 2.6) * 8.0
	flash = max(0.0, flash - delta * 2.4)
	for s in sparks: s.p += s.v; s.v.y += 0.06; s.l -= 0.012
	sparks = sparks.filter(func(s): return s.l > 0)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var c = Vector2(size.x / 2, size.y * 0.55)
	for k in 8: draw_circle(c, size.y * (1.0 - k * 0.11), Color(0.16, 0.24, 0.31, 0.06 + beams * 0.03))
	var nb = 6 + lvl * 3
	var base = Vector2(size.x / 2, size.y * 1.05)
	for i in nb:
		var a = -PI / 2 + (i - nb / 2.0) * 0.16 + sin(t * 0.8 + i) * 0.05
		var dir = Vector2(cos(a), sin(a)); var perp = Vector2(-dir.y, dir.x)
		var far = base + dir * size.y * 1.3
		var col: Color = colors[i % 2]; col.a = 0.22 * beams
		var ce = col; ce.a = 0
		draw_polygon(PackedVector2Array([base - perp * 8, base + perp * 8, far + perp * 90, far - perp * 90]), PackedColorArray([col, col, ce, ce]))
	for s in sparks:
		var sc: Color = s.c; sc.a = s.l
		draw_rect(Rect2(s.p, Vector2(3, 3)), sc)
	if flash > 0: draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, flash))
