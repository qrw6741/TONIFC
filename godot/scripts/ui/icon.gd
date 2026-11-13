class_name Icon
extends Control
## Small vector graphic: flag, crest, league, badge, kit, pack, portrait or mini-pitch.

var kind = ""
var arg = null
var t = 0.0
var animate = false

static func make(k: String, a, size: Vector2) -> Icon:
	var i = Icon.new(); i.kind = k; i.arg = a; i.custom_minimum_size = size
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	i.animate = (k == "pack")
	return i

var _since = 0.0
func _process(delta: float) -> void:
	if not animate: return
	t += delta; _since += delta
	if _since >= 1.0 / 30.0 and is_visible_in_tree(): _since = 0.0; queue_redraw()

func _draw() -> void:
	var r = Rect2(Vector2.ZERO, size)
	var c = r.get_center(); var m: float = min(size.x, size.y)
	match kind:
		"flag": Gfx.flag(self, r, arg)
		"crest": Gfx.crest(self, c, m, arg)
		"league": Gfx.league(self, c, m, arg)
		"badge": Gfx.badge(self, c, m, arg)
		"kit": Gfx.kit(self, Rect2(c - Vector2(m, m) / 2, Vector2(m, m)), arg)
		"pack": Gfx.pack(self, r, arg, t)
		"portrait": Gfx.portrait(self, r, arg)
		"minipitch": _mini_pitch(r)

func _mini_pitch(r: Rect2) -> void:
	var f: String = arg.formation; var ps: Array = arg.players
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(0.16, 0.55, 0.35, 0.18); sb.border_color = Color(0.63, 1, 0.93, 0.35); sb.set_border_width_all(1); sb.set_corner_radius_all(6)
	draw_style_box(sb, r)
	draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color(0.63, 1, 0.93, 0.3), 1)
	draw_arc(r.get_center(), r.size.x * 0.09, 0, TAU, 24, Color(0.63, 1, 0.93, 0.3), 1)
	var rad: float = min(r.size.x, r.size.y) * 0.055
	for i in Data.formations[f].size():
		var s: Array = Data.formations[f][i]
		var pos = r.position + Vector2(s[1] / 100.0 * r.size.x, (s[2] * 0.92 + 4) / 100.0 * r.size.y)
		var pl: Dictionary = ps[i] if i < ps.size() else {}
		draw_circle(pos, rad, Data.ovr_color(pl) if not pl.is_empty() else Color(1, 1, 1, 0.15))
		draw_arc(pos, rad, 0, TAU, 20, Color.WHITE, 1)
		if not pl.is_empty():
			Gfx.text_c(self, UI.font_head, pos.x, pos.y + rad * 0.4, str(pl.ovr), int(rad * 1.0), Color("#111111"))
			Gfx.text_c(self, UI.font_bold, pos.x, pos.y + rad * 2.2, Data.short_name(pl.name).substr(0, 12), int(rad * 0.75), Color.WHITE)
		else:
			Gfx.text_c(self, UI.font_bold, pos.x, pos.y + rad * 2.2, s[0], int(rad * 0.75), Color.WHITE)
