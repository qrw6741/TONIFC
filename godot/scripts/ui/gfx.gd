class_name Gfx
## Static drawing helpers used by cards, icons, pitch and match views.
## Everything is vector-drawn in code: flags, club badges (original colour-matched
## designs, not official crests), league marks, kits, pack art and player portraits.

## Draw many coloured rectangles in ONE draw call (crowds etc.).
## pts holds 4 corners per rect (TL, TR, BR, BL), cols one colour per corner.
static var _idx_cache = {}
static func flush_quads(ci: CanvasItem, pts: PackedVector2Array, cols: PackedColorArray) -> void:
	var n: int = pts.size() / 4
	if n == 0: return
	var idx: PackedInt32Array = _idx_cache.get(n, PackedInt32Array())
	if idx.is_empty():
		idx.resize(n * 6)
		for i in n:
			var b = i * 4; var o = i * 6
			idx[o] = b; idx[o + 1] = b + 1; idx[o + 2] = b + 2; idx[o + 3] = b; idx[o + 4] = b + 2; idx[o + 5] = b + 3
		if _idx_cache.size() > 8: _idx_cache.clear()
		_idx_cache[n] = idx
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)

static func add_quad(pts: PackedVector2Array, cols: PackedColorArray, r: Rect2, c: Color) -> void:
	pts.append(r.position); pts.append(Vector2(r.end.x, r.position.y)); pts.append(r.end); pts.append(Vector2(r.position.x, r.end.y))
	cols.append(c); cols.append(c); cols.append(c); cols.append(c)

## soft floodlight glow: one textured quad instead of many stacked translucent circles
static var _glow: Texture2D = null
static func glow(ci: CanvasItem, center: Vector2, radius: float, c: Color) -> void:
	if _glow == null:
		var g = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0)])
		var t = GradientTexture2D.new(); t.gradient = g; t.width = 128; t.height = 128
		t.fill = GradientTexture2D.FILL_RADIAL; t.fill_from = Vector2(0.5, 0.5); t.fill_to = Vector2(1.0, 0.5)
		_glow = t
	ci.draw_texture_rect(_glow, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2), false, c)

static func col(c) -> Color:
	return c if c is Color else Color(String(c))

static func text(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	ci.draw_string(font, pos, s, align, width, size, color)

static func text_c(ci: CanvasItem, font: Font, center_x: float, baseline: float, s: String, size: int, color: Color) -> void:
	var w = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, Vector2(center_x - w / 2.0, baseline), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

## polygon filled with a vertical gradient (top → mid → bottom)
static func grad_poly(ci: CanvasItem, pts: PackedVector2Array, r: Rect2, top: Color, mid: Color, bot: Color) -> void:
	var cols = PackedColorArray()
	for p in pts:
		var t: float = clamp((p.y - r.position.y) / max(1.0, r.size.y), 0.0, 1.0)
		cols.append(top.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(bot, (t - 0.5) * 2.0))
	ci.draw_polygon(pts, cols)

static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color, seg := 28) -> void:
	var pts = PackedVector2Array()
	for i in seg: var a = TAU * i / seg; pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, color)

static func ellipse_line(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color, w := 2.0, seg := 32) -> void:
	var pts = PackedVector2Array()
	for i in seg + 1: var a = TAU * i / seg; pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_polyline(pts, color, w, true)

## FUT-style card shield (relative 0..1 coords → rect)
static func shield(r: Rect2, inset := 0.0) -> PackedVector2Array:
	var rel = [[0.5, 0], [0.63, 0.032], [0.8, 0.012], [0.94, 0.06], [1, 0.09], [1, 0.84], [0.91, 0.895], [0.5, 1], [0.09, 0.895], [0, 0.84], [0, 0.09], [0.06, 0.06], [0.2, 0.012], [0.37, 0.032]]
	var rr = r.grow(-inset)
	var pts = PackedVector2Array()
	for p in rel: pts.append(rr.position + Vector2(p[0] * rr.size.x, p[1] * rr.size.y))
	return pts

# ------------------------------------------------------------------ flags
static func flag(ci: CanvasItem, r: Rect2, code: String) -> void:
	var n: Dictionary = Data.nations.get(code, {})
	var f: Dictionary = n.get("flag", {"t": "solid", "c": ["#888888"]})
	var c: Array = f.c.map(func(x): return Color(x))
	var t: String = f.t
	var stripes = func(cols: Array, vertical: bool, w: Array):
		var tot = 0.0
		for x in w: tot += x
		var o = 0.0
		for i in cols.size():
			var sz: float = (r.size.x if vertical else r.size.y) * w[i] / tot
			if vertical: ci.draw_rect(Rect2(r.position.x + o, r.position.y, sz + 0.5, r.size.y), cols[i])
			else: ci.draw_rect(Rect2(r.position.x, r.position.y + o, r.size.x, sz + 0.5), cols[i])
			o += sz
	var ones = c.map(func(_x): return 1.0)
	var C = r.get_center()
	match t:
		"v3", "v2": stripes.call(c, true, ones)
		"v3c": stripes.call(c, true, [1.0, 2.0, 1.0])
		"v2p": stripes.call(c, true, [2.0, 3.0])
		"h2", "h3", "h5": stripes.call(c, false, ones)
		"h3w": stripes.call(c, false, [1.0, 2.0, 1.0] if code == "ESP" else [2.0, 1.0, 1.0])
		"cross", "swiss":
			ci.draw_rect(r, c[0])
			var th = r.size.y * 0.2
			if t == "swiss":
				ci.draw_rect(Rect2(C.x - th / 2, r.position.y + r.size.y * 0.2, th, r.size.y * 0.6), c[1])
				ci.draw_rect(Rect2(C.x - r.size.y * 0.3, C.y - th / 2, r.size.y * 0.6, th), c[1])
			else:
				ci.draw_rect(Rect2(C.x - th / 2, r.position.y, th, r.size.y), c[1])
				ci.draw_rect(Rect2(r.position.x, C.y - th / 2, r.size.x, th), c[1])
		"saltire":
			ci.draw_rect(r, c[0])
			ci.draw_line(r.position, r.end, c[1], r.size.y * 0.2)
			ci.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), c[1], r.size.y * 0.2)
		"nordic":
			ci.draw_rect(r, c[0])
			var x0 = r.position.x + r.size.x * 0.3
			ci.draw_rect(Rect2(x0 - r.size.y * 0.15, r.position.y, r.size.y * 0.3, r.size.y), c[1])
			ci.draw_rect(Rect2(r.position.x, C.y - r.size.y * 0.15, r.size.x, r.size.y * 0.3), c[1])
			ci.draw_rect(Rect2(x0 - r.size.y * 0.075, r.position.y, r.size.y * 0.15, r.size.y), c[2])
			ci.draw_rect(Rect2(r.position.x, C.y - r.size.y * 0.075, r.size.x, r.size.y * 0.15), c[2])
		"diamond":
			ci.draw_rect(r, c[0])
			ci.draw_colored_polygon(PackedVector2Array([Vector2(C.x, r.position.y + 2), Vector2(r.end.x - 2, C.y), Vector2(C.x, r.end.y - 2), Vector2(r.position.x + 2, C.y)]), c[1])
			ci.draw_circle(C, r.size.y * 0.22, c[2])
		"circle":
			ci.draw_rect(r, c[0]); ci.draw_circle(C, r.size.y * 0.3, c[1])
		"crescent":
			ci.draw_rect(r, c[0]); ci.draw_circle(C - Vector2(r.size.x * 0.1, 0), r.size.y * 0.28, c[1]); ci.draw_circle(C - Vector2(r.size.x * 0.05, 0), r.size.y * 0.22, c[0])
		"star":
			ci.draw_rect(r, c[0]); ci.draw_circle(C, r.size.y * 0.22, c[1]); ci.draw_circle(C, r.size.y * 0.15, c[0])
		"czech":
			stripes.call([c[0], c[1]], false, [1.0, 1.0])
			ci.draw_colored_polygon(PackedVector2Array([r.position, Vector2(r.position.x + r.size.x * 0.47, C.y), Vector2(r.position.x, r.end.y)]), c[2])
		"usa":
			stripes.call([c[0], c[1], c[0], c[1], c[0], c[1], c[0]], false, [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
			ci.draw_rect(Rect2(r.position, r.size * Vector2(0.43, 0.54)), c[2])
		"uae":
			stripes.call([c[0], c[1], c[2]], false, [1.0, 1.0, 1.0]); ci.draw_rect(Rect2(r.position, Vector2(r.size.x * 0.27, r.size.y)), c[3])
		_: ci.draw_rect(r, c[0])
	ci.draw_rect(r, Color(0, 0, 0, 0.25), false, 1.0)

# ------------------------------------------------------------------ crests / league / badge
static func hash_s(s: String) -> int:
	var h = 7
	for ch in s.to_utf8_buffer(): h = (h * 31 + ch) % 1000003
	return h

static func crest(ci: CanvasItem, c: Vector2, size: float, code: String) -> void:
	var cl: Dictionary = Data.clubs.get(code, {"name": "?", "c": ["#444444", "#dddddd"]})
	var a = Color(cl.c[0]); var b = Color(cl.c[1])
	var s = size / 40.0
	var P = func(x, y): return c + Vector2((x - 20) * s, (y - 20) * s)
	var font: Font = UI.font_head
	if code == "ICN":
		ci.draw_circle(c, 18 * s, Color("#2b2416")); ci.draw_arc(c, 18 * s, 0, TAU, 32, Color("#e8d6a0"), 2.5 * s)
		text_c(ci, font, c.x, c.y + 5 * s, "I", int(14 * s), Color("#e8d6a0")); return
	if code == "HER":
		var hx = PackedVector2Array([P.call(20, 2), P.call(37, 12), P.call(37, 28), P.call(20, 38), P.call(3, 28), P.call(3, 12)])
		ci.draw_colored_polygon(hx, Color("#3a1666")); hx.append(hx[0]); ci.draw_polyline(hx, Color("#ffd23f"), 2.5 * s)
		text_c(ci, font, c.x, c.y + 5 * s, "H", int(14 * s), Color("#ffd23f")); return
	var style = hash_s(code) % 4
	var pts: PackedVector2Array
	match style:
		0: pts = PackedVector2Array([P.call(20, 2), P.call(36, 7), P.call(36, 20), P.call(32, 30), P.call(20, 38), P.call(8, 30), P.call(4, 20), P.call(4, 7)])
		1:
			pts = PackedVector2Array()
			for i in 28: var an = TAU * i / 28; pts.append(c + Vector2(cos(an), sin(an)) * 17 * s)
		2: pts = PackedVector2Array([P.call(6, 4), P.call(34, 4), P.call(34, 22), P.call(29, 32), P.call(20, 38), P.call(11, 32), P.call(6, 22)])
		_: pts = PackedVector2Array([P.call(20, 2), P.call(36, 10), P.call(36, 30), P.call(20, 38), P.call(4, 30), P.call(4, 10)])
	ci.draw_colored_polygon(pts, a if style != 2 else b)
	if style == 2: ci.draw_colored_polygon(PackedVector2Array([P.call(6, 4), P.call(34, 4), P.call(34, 14), P.call(6, 14)]), a)
	var outline = pts.duplicate(); outline.append(pts[0])
	ci.draw_polyline(outline, b if style != 2 else a, 2.5 * s, true)
	var name: String = cl.name
	var skip = ["FC", "CD", "AC", "AS", "SV", "US", "UD", "CF", "SC", "RC", "TSV", "AFC", "SSC", "RCD", "CA", "OGC", "AJ", "VfB", "VfL", "TSG", "SS", "RB", "LOSC", "Real", "Club", "Stade", "Olympique", "Borussia", "Bayer", "Eintracht", "Deportivo", "1.", "FSV", "04", "05", "29", "1907", "de", "United", "City"]
	var init = name.substr(0, 1)
	for w in name.split(" "):
		if not skip.has(w) and w.length() > 1: init = w.substr(0, 1).to_upper(); break
	text_c(ci, font, c.x, c.y + (8 if style == 2 else 5) * s, init, int(13 * s), (a if style == 2 else b))

static func league(ci: CanvasItem, c: Vector2, size: float, lg: String) -> void:
	var L: Dictionary = Data.leagues.get(lg, {})
	if L.is_empty(): return
	var r = Rect2(c - Vector2(size, size) * 0.42, Vector2(size, size) * 0.84)
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(L.color); sb.set_corner_radius_all(int(size * 0.22))
	ci.draw_style_box(sb, r)
	var fs = int(size * (0.3 if String(L.short).length() <= 3 else 0.24))
	text_c(ci, UI.font_head, c.x, c.y + fs * 0.36, L.short, fs, Color.WHITE)

static func badge(ci: CanvasItem, c: Vector2, size: float, b: Dictionary) -> void:
	var s = size / 80.0
	var P = func(x, y): return c + Vector2((x - 40) * s, (y - 40) * s)
	var c1 = Color(b.c1); var c2 = Color(b.c2)
	var pts: PackedVector2Array
	match b.get("shape", "shield"):
		"round":
			pts = PackedVector2Array()
			for i in 32: var a = TAU * i / 32; pts.append(c + Vector2(cos(a), sin(a)) * 36 * s)
		"hex": pts = PackedVector2Array([P.call(40, 4), P.call(72, 22), P.call(72, 58), P.call(40, 76), P.call(8, 58), P.call(8, 22)])
		"crest": pts = PackedVector2Array([P.call(12, 6), P.call(68, 6), P.call(68, 44), P.call(58, 64), P.call(40, 76), P.call(22, 64), P.call(12, 44)])
		_: pts = PackedVector2Array([P.call(40, 4), P.call(72, 14), P.call(72, 40), P.call(64, 60), P.call(40, 76), P.call(16, 60), P.call(8, 40), P.call(8, 14)])
	ci.draw_colored_polygon(pts, c2)
	var o = pts.duplicate(); o.append(pts[0]); ci.draw_polyline(o, c1, 4 * s, true)
	match b.get("icon", "star"):
		"ball": ci.draw_circle(c, 14 * s, c1); ci.draw_circle(c, 5 * s, c2)
		"crown": ci.draw_colored_polygon(PackedVector2Array([P.call(24, 50), P.call(26, 30), P.call(34, 40), P.call(40, 26), P.call(46, 40), P.call(54, 30), P.call(56, 50)]), c1)
		"bolt": ci.draw_colored_polygon(PackedVector2Array([P.call(44, 20), P.call(28, 44), P.call(39, 44), P.call(34, 62), P.call(52, 36), P.call(41, 36)]), c1)
		"bird": ci.draw_colored_polygon(PackedVector2Array([P.call(22, 46), P.call(34, 30), P.call(40, 40), P.call(46, 30), P.call(58, 46), P.call(40, 50)]), c1)
		"flame": ci.draw_colored_polygon(PackedVector2Array([P.call(40, 22), P.call(50, 36), P.call(48, 52), P.call(40, 60), P.call(31, 52), P.call(30, 42), P.call(38, 36), P.call(41, 46), P.call(45, 38)]), c1)
		_:
			var st = PackedVector2Array()
			for i in 10:
				var a = -PI / 2 + i * PI / 5; var rr = (17.0 if i % 2 == 0 else 7.0) * s
				st.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(st, c1)

static func kit(ci: CanvasItem, r: Rect2, k: Dictionary) -> void:
	var s = r.size.x / 80.0
	var P = func(x, y): return r.position + Vector2(x, y) * s
	var body = PackedVector2Array([P.call(22, 8), P.call(32, 4), P.call(40, 9), P.call(48, 4), P.call(58, 8), P.call(76, 22), P.call(68, 34), P.call(60, 28), P.call(60, 76), P.call(20, 76), P.call(20, 28), P.call(12, 34), P.call(4, 22)])
	var c1 = Color(k.c1); var c2 = Color(k.c2)
	ci.draw_colored_polygon(body, c1)
	match k.get("pattern", "plain"):
		"stripes":
			for i in 4: ci.draw_rect(Rect2(P.call(24 + i * 9, 6), Vector2(4.5, 70) * s), c2)
		"hoops":
			for i in 4: ci.draw_rect(Rect2(P.call(20, 22 + i * 14), Vector2(40, 7) * s), c2)
		"sash": ci.draw_colored_polygon(PackedVector2Array([P.call(22, 10), P.call(32, 10), P.call(60, 64), P.call(60, 76), P.call(52, 76), P.call(20, 22)]), c2)
		"half": ci.draw_colored_polygon(PackedVector2Array([P.call(40, 9), P.call(48, 4), P.call(58, 8), P.call(76, 22), P.call(68, 34), P.call(60, 28), P.call(60, 76), P.call(40, 76)]), c2)
	var o = body.duplicate(); o.append(body[0]); ci.draw_polyline(o, Color(0, 0, 0, 0.35), 1.5 * s, true)
	ci.draw_polyline(PackedVector2Array([P.call(32, 4), P.call(40, 9), P.call(48, 4)]), c2, 3 * s)

# ------------------------------------------------------------------ pack art
static func pack(ci: CanvasItem, r: Rect2, id: String, t := 0.0) -> void:
	var pk: Dictionary = Data.packs[id]
	var cols: Array = {"bronze": ["#e2b48c", "#b07a4f", "#7d4f2c"], "silver": ["#f1f3f6", "#b9c1cb", "#8b95a3"], "gold": ["#f8e4a6", "#e0be62", "#b88f2e"],
		"premium": ["#fff3c4", "#e8b631", "#8a6410"], "jumbo": ["#fff3c4", "#e8b631", "#4a3505"], "rare": ["#ffffff", "#f0c94e", "#c3901c"], "mega": ["#f4e7ff", "#9d6dff", "#3a1a7a"],
		"ultimate": ["#1a1a1a", "#000000", "#3a2a08"], "totw": ["#2a2a2a", "#111111", "#0b0b0b"], "promo": ["#ff4fa3", "#3a1268", "#08142e"], "icon": ["#fffaf0", "#eadcb8", "#c6aa6a"], "found": ["#6ff3dc", "#1d5d5a", "#0c2c32"], "pass": ["#ff6a3d", "#8c0f24", "#1c0410"], "pick": ["#ffc76b", "#c2401f", "#2a0610"], "gallery": ["#ffd1f3", "#b23ad1", "#1a0b33"], "fright": ["#ff8a1f", "#4a1260", "#0b0410"], "phantom": ["#c8f7ff", "#3b4a7a", "#0d1022"], "rising": ["#8af4ff", "#2140c9", "#0a0d3a"]}.get(pk.art, ["#f8e4a6", "#e0be62", "#b88f2e"])
	var pts = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	grad_poly(ci, pts, r, Color(cols[0]), Color(cols[1]), Color(cols[2]))
	# moving shine
	var sx = r.position.x + fmod(t * 0.35, 1.6) * r.size.x * 1.6 - r.size.x * 0.4
	ci.draw_colored_polygon(PackedVector2Array([Vector2(clamp(sx, r.position.x, r.end.x), r.position.y), Vector2(clamp(sx + r.size.x * 0.18, r.position.x, r.end.x), r.position.y), Vector2(clamp(sx - r.size.x * 0.1, r.position.x, r.end.x), r.end.y), Vector2(clamp(sx - r.size.x * 0.28, r.position.x, r.end.x), r.end.y)]), Color(1, 1, 1, 0.25))
	var dark: bool = ["ultimate", "totw", "promo", "mega", "found", "pass", "pick", "gallery", "rising", "fright", "phantom"].has(pk.art)
	var tc = Color("#f3d88a") if (pk.art == "ultimate" or pk.art == "totw") else (Color.WHITE if dark else Color(0, 0, 0, 0.7))
	var border = Color("#ffc76b") if pk.art == "pass" or pk.art == "pick" else Color("#e8b631") if pk.art == "ultimate" else (Color("#d9b25c") if pk.art == "totw" else Color(1, 1, 1, 0.35))
	ci.draw_rect(r, border, false, 2.0)
	var words: String = String(pk.name).replace(" Pack", "").to_upper()
	var fs = int(r.size.x * 0.13)
	var lines = words.split(" ")
	var y = r.get_center().y - (lines.size() - 1) * fs * 0.55
	for ln in lines:
		text_c(ci, UI.font_head, r.get_center().x, y + fs * 0.35, ln, fs, tc); y += fs * 1.1
	text_c(ci, UI.font_bold, r.get_center().x, r.end.y - r.size.y * 0.1, ("PICK 1 OF %d" % int(pk.pick.n)) if pk.has("pick") else ("PF27 · %d ITEMS" % int(pk.items)), int(r.size.x * 0.075), tc)

# ------------------------------------------------------------------ portrait
static func portrait(ci: CanvasItem, r: Rect2, p: Dictionary, kc1 = null, kc2 = null) -> void:
	var f: Dictionary = p.get("face", {"skin": 2, "hair": 0, "hairC": 0, "beard": 0, "brow": 0})
	var skin = Color(Data.SKINS[int(f.skin)]); var hair = Color(Data.HAIRC[int(f.hairC)])
	var cl: Dictionary = Data.clubs.get(p.club, {"c": ["#333333", "#dddddd"]})
	var A = col(kc1) if kc1 != null else Color(cl.c[0])
	var B = col(kc2) if kc2 != null else Color(cl.c[1])
	var s: float = min(r.size.x, r.size.y) / 100.0
	var o = r.position + Vector2((r.size.x - 100 * s) / 2, r.size.y - 100 * s)
	var P = func(x, y): return o + Vector2(x, y) * s
	var shade = Color(0, 0, 0, 0.18)
	# shirt
	ci.draw_colored_polygon(PackedVector2Array([P.call(8, 100), P.call(12, 82), P.call(32, 72), P.call(42, 68), P.call(58, 68), P.call(68, 72), P.call(88, 82), P.call(92, 100)]), A)
	ci.draw_colored_polygon(PackedVector2Array([P.call(42, 68), P.call(50, 80), P.call(58, 68)]), B)
	ci.draw_colored_polygon(PackedVector2Array([P.call(8, 100), P.call(12, 82), P.call(32, 72), P.call(36, 100)]), Color(B, 0.35))
	ci.draw_colored_polygon(PackedVector2Array([P.call(92, 100), P.call(88, 82), P.call(68, 72), P.call(64, 100)]), Color(B, 0.35))
	# neck & head
	ci.draw_rect(Rect2(P.call(43, 58), Vector2(14, 14) * s), skin)
	ci.draw_rect(Rect2(P.call(43, 62), Vector2(14, 6) * s), shade)
	ellipse(ci, P.call(32.5, 45), 3.2 * s, 5 * s, skin); ellipse(ci, P.call(67.5, 45), 3.2 * s, 5 * s, skin)
	ellipse(ci, P.call(50, 43), 18 * s, 22 * s, skin)
	ellipse(ci, P.call(56, 45), 11 * s, 19 * s, Color(0, 0, 0, 0.07))
	var by = 40.0 + f.get("brow", 0)
	ci.draw_line(P.call(40, by), P.call(47, by - 1), hair, 2.2 * s); ci.draw_line(P.call(53, by - 1), P.call(60, by), hair, 2.2 * s)
	ellipse(ci, P.call(43.5, 45), 3.2 * s, 2.0 * s, Color(1, 1, 1, 0.85)); ellipse(ci, P.call(56.5, 45), 3.2 * s, 2.0 * s, Color(1, 1, 1, 0.85))
	ellipse(ci, P.call(43.8, 45), 1.8 * s, 1.8 * s, Color("#1a1a1a")); ellipse(ci, P.call(56.2, 45), 1.8 * s, 1.8 * s, Color("#1a1a1a"))
	ellipse(ci, P.call(40, 53), 4 * s, 2.5 * s, Color(skin.darkened(0.12), 0.35)); ellipse(ci, P.call(60, 53), 4 * s, 2.5 * s, Color(skin.darkened(0.12), 0.35))
	ci.draw_polyline(PackedVector2Array([P.call(50, 46), P.call(48.5, 53), P.call(52, 54)]), shade, 1.4 * s)
	ci.draw_polyline(PackedVector2Array([P.call(45, 59), P.call(50, 61), P.call(55, 59)]), Color("#7a3d33"), 1.6 * s)
	# beard: 1 stubble · 2 full · 3 moustache · 4 goatee · 5 trimmed beard
	match int(f.get("beard", 0)):
		1: ci.draw_colored_polygon(PackedVector2Array([P.call(36, 50), P.call(40, 63), P.call(50, 68), P.call(60, 63), P.call(64, 50), P.call(58, 60), P.call(50, 62), P.call(42, 60)]), Color(hair, 0.32))
		2: ci.draw_colored_polygon(PackedVector2Array([P.call(34, 46), P.call(37, 66), P.call(50, 75), P.call(63, 66), P.call(66, 46), P.call(60, 61), P.call(50, 64), P.call(40, 61)]), Color(hair, 0.95))
		3: ci.draw_colored_polygon(PackedVector2Array([P.call(43, 58.5), P.call(50, 56), P.call(57, 58.5), P.call(50, 60)]), hair)
		4:
			ci.draw_colored_polygon(PackedVector2Array([P.call(44, 61), P.call(50, 60), P.call(56, 61), P.call(54, 68), P.call(50, 70), P.call(46, 68)]), Color(hair, 0.9))
			ci.draw_colored_polygon(PackedVector2Array([P.call(43, 58.5), P.call(50, 56.5), P.call(57, 58.5), P.call(50, 59.5)]), Color(hair, 0.9))
		5:
			ci.draw_colored_polygon(PackedVector2Array([P.call(35, 48), P.call(38, 63), P.call(50, 70), P.call(62, 63), P.call(65, 48), P.call(59, 60), P.call(50, 62.5), P.call(41, 60)]), Color(hair, 0.75))
			ci.draw_colored_polygon(PackedVector2Array([P.call(43, 58.5), P.call(50, 56.5), P.call(57, 58.5), P.call(50, 59.5)]), Color(hair, 0.8))
	# hair
	var hs: int = int(f.get("hair", 0))
	var hl = hair.lightened(0.18)
	match hs:
		0: ci.draw_colored_polygon(PackedVector2Array([P.call(30, 40), P.call(31, 26), P.call(40, 17), P.call(50, 15), P.call(60, 17), P.call(69, 26), P.call(70, 40), P.call(64, 29), P.call(50, 27), P.call(36, 29)]), hair)
		1:
			ci.draw_colored_polygon(PackedVector2Array([P.call(29, 42), P.call(29, 22), P.call(40, 13), P.call(50, 12), P.call(62, 13), P.call(71, 22), P.call(71, 42), P.call(68, 26), P.call(58, 22), P.call(50, 30), P.call(38, 23), P.call(32, 30)]), hair)
			ci.draw_polyline(PackedVector2Array([P.call(38, 18), P.call(48, 15), P.call(60, 17)]), Color(hl, 0.6), 1.4 * s)
		2: ci.draw_colored_polygon(PackedVector2Array([P.call(31, 36), P.call(34, 24), P.call(50, 19), P.call(66, 24), P.call(69, 36), P.call(60, 30), P.call(40, 30)]), Color(hair, 0.85))
		3: ci.draw_colored_polygon(PackedVector2Array([P.call(28, 60), P.call(26, 30), P.call(36, 14), P.call(50, 10), P.call(64, 14), P.call(74, 30), P.call(72, 60), P.call(68, 34), P.call(50, 22), P.call(32, 34)]), hair)
		4:
			ci.draw_circle(P.call(50, 24), 17 * s, hair); ci.draw_circle(P.call(36, 30), 9 * s, hair); ci.draw_circle(P.call(64, 30), 9 * s, hair)
		5: ci.draw_arc(P.call(50, 40), 17 * s, PI * 1.15, PI * 1.85, 12, Color(1, 1, 1, 0.18), 2.0 * s)   # bald: a little shine
		6: ci.draw_colored_polygon(PackedVector2Array([P.call(30, 40), P.call(32, 22), P.call(46, 12), P.call(66, 6), P.call(74, 18), P.call(70, 34), P.call(62, 22), P.call(46, 26), P.call(36, 30)]), hair)
		7:
			# curly top: short sides, a crown of curls
			ci.draw_colored_polygon(PackedVector2Array([P.call(31, 38), P.call(33, 27), P.call(67, 27), P.call(69, 38), P.call(62, 31), P.call(38, 31)]), Color(hair, 0.85))
			for c in [[38, 23, 6.5], [46, 18, 7.0], [55, 18, 7.0], [63, 23, 6.5], [42, 14, 5.5], [51, 12, 6.0], [59, 14, 5.5]]: ci.draw_circle(P.call(c[0], c[1]), c[2] * s, hair)
			for c in [[44, 15], [53, 13], [60, 19]]: ci.draw_arc(P.call(c[0], c[1]), 2.6 * s, 0, PI, 6, Color(hl, 0.5), 1.0 * s)
		9:
			# slicked back
			ci.draw_colored_polygon(PackedVector2Array([P.call(30, 38), P.call(30, 24), P.call(38, 14), P.call(50, 11), P.call(62, 14), P.call(70, 24), P.call(70, 38), P.call(66, 26), P.call(50, 22), P.call(34, 26)]), hair)
			for k in 4: ci.draw_line(P.call(40 + k * 6, 23), P.call(42 + k * 6, 13), Color(hl, 0.45), 1.0 * s)
		10:
			# dreadlocks / braids
			ci.draw_colored_polygon(PackedVector2Array([P.call(30, 36), P.call(33, 22), P.call(50, 16), P.call(67, 22), P.call(70, 36), P.call(60, 29), P.call(40, 29)]), hair)
			for k in 7:
				var x = 32.0 + k * 6.0
				ci.draw_line(P.call(x, 22), P.call(x - 2 + (k % 3), 46 + (k % 2) * 6), hair, 3.0 * s)
		11:
			# man bun
			ci.draw_colored_polygon(PackedVector2Array([P.call(30, 38), P.call(31, 25), P.call(40, 17), P.call(50, 15), P.call(60, 17), P.call(69, 25), P.call(70, 38), P.call(64, 28), P.call(50, 25), P.call(36, 28)]), hair)
			ci.draw_circle(P.call(50, 9), 7.5 * s, hair); ci.draw_line(P.call(44, 14), P.call(56, 14), hair.darkened(0.3), 1.5 * s)
		12:
			# short twists
			ci.draw_colored_polygon(PackedVector2Array([P.call(31, 37), P.call(33, 25), P.call(67, 25), P.call(69, 37), P.call(61, 30), P.call(39, 30)]), Color(hair, 0.9))
			for k in 6:
				for j in 2: ci.draw_circle(P.call(36 + k * 5.6, 20 - j * 4 + (k % 2) * 1.5), 3.0 * s, hair)
		_: ci.draw_colored_polygon(PackedVector2Array([P.call(31, 38), P.call(36, 22), P.call(44, 18), P.call(44, 10), P.call(56, 10), P.call(56, 18), P.call(64, 22), P.call(69, 38), P.call(62, 30), P.call(38, 30)]), hair)

# ---------- Halloween props
static func bat(ci: CanvasItem, p: Vector2, s: float, ph: float) -> void:
	# body + two convex wings (always valid polygons, even mid-flap)
	var f: float = sin(ph) * 0.6
	var col = Color(0.05, 0.02, 0.08, 0.9)
	for side in [-1.0, 1.0]:
		var tip = p + Vector2(side * s * 1.4, -s * (0.35 + f))
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(side * s * 0.15, -s * 0.15), tip, p + Vector2(side * s * 0.9, s * 0.25), p + Vector2(side * s * 0.15, s * 0.2)]) if side > 0 else PackedVector2Array([p + Vector2(side * s * 0.15, -s * 0.15), p + Vector2(side * s * 0.15, s * 0.2), p + Vector2(side * s * 0.9, s * 0.25), tip]), col)
	ci.draw_circle(p, s * 0.25, col)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.2, -s * 0.15), p + Vector2(-s * 0.12, -s * 0.42), p + Vector2(-s * 0.02, -s * 0.18)]), col)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(s * 0.02, -s * 0.18), p + Vector2(s * 0.12, -s * 0.42), p + Vector2(s * 0.2, -s * 0.15)]), col)
static func pumpkin(ci: CanvasItem, p: Vector2, r: float, t: float) -> void:
	for k in [-0.55, 0.55, 0.0]: ci.draw_circle(p + Vector2(r * k, 0), r * (0.62 if k != 0.0 else 0.7), Color("#e8730e") if k == 0.0 else Color("#c95e0a"))
	ci.draw_rect(Rect2(p + Vector2(-r * 0.1, -r * 0.95), Vector2(r * 0.2, r * 0.3)), Color("#3d6b1f"))
	var g = Color(1, 0.85, 0.3, 0.75 + 0.25 * sin(t * 4.0))
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.4, -r * 0.2), p + Vector2(-r * 0.15, -r * 0.2), p + Vector2(-r * 0.28, -r * 0.42)]), g)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(r * 0.4, -r * 0.2), p + Vector2(r * 0.15, -r * 0.2), p + Vector2(r * 0.28, -r * 0.42)]), g)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.45, r * 0.12), p + Vector2(r * 0.45, r * 0.12), p + Vector2(r * 0.25, r * 0.38), p + Vector2(-r * 0.25, r * 0.38)]), g)

