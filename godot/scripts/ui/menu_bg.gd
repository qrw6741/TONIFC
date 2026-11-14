extends Control
## Animated backgrounds: a 3D-projected floodlit stadium with players passing a ball
## and a drifting camera (main menu), or a dark clubhouse set (Ultimate XI hub).

var mode = "menu"
var t = 0.0
var players = []
var ball = {"x": 52.0, "z": 34.0, "vx": 0.0, "vz": 0.0, "owner": 0}
var parts = []
var crowd = []
var bats = []

func _ready() -> void:
	var kits = [[Color("#e8b631"), Color("#14161c")], [Color("#f2f2f2"), Color("#2a6fdb")]]
	for i in 12:
		players.append({"x": randf_range(20, 85), "z": randf_range(8, 60), "vx": 0.0, "vz": 0.0, "team": i % 2, "kit": kits[i % 2], "ph": randf() * 6, "tx": 50.0, "tz": 34.0, "re": 0.0})
	for i in 70: parts.append({"x": randf(), "y": randf(), "s": randf_range(0.6, 2.2), "v": randf_range(0.002, 0.01), "a": randf_range(0.1, 0.5)})
	var cols = [Color("#ff7a1a"), Color("#8a3fd1"), Color("#2b1340"), Color("#ffb35a"), Color("#3fd17a"), Color("#dddddd")] if Fright.THEME else [Color("#e8b631"), Color("#ffffff"), Color("#2a6fdb"), Color("#cf3b3b"), Color("#88aaaa"), Color("#dddddd")]
	for i in 8: bats.append({"x": randf(), "y": randf_range(0.05, 0.4), "v": randf_range(0.015, 0.04), "s": randf_range(7, 14), "ph": randf() * 6})
	for i in 1200: crowd.append({"u": randf(), "v": randf(), "c": cols[randi() % cols.size()], "ph": randf() * 6})

func set_mode(m: String) -> void:
	mode = m; visible = m != "off"

var _since = 0.0
func _process(delta: float) -> void:
	if mode == "off": return
	t += delta
	if mode == "menu": _update(delta)
	# backgrounds don't need 60+ fps: redraw at ~30 fps (menu) / ~15 fps (hub), or almost never in performance mode
	var perf: bool = (Save.data != null and Save.data.settings.get("perf_mode", false)) or Cloud.companion()
	var hz: float = (30.0 if mode == "menu" else 15.0) if not perf else (10.0 if mode == "menu" else 0.5)
	_since += delta
	if _since >= 1.0 / hz: _since = 0.0; queue_redraw()

func _update(dt: float) -> void:
	var b = ball
	var owner = players[b.owner] if b.owner >= 0 else null
	if owner:
		b.x = lerpf(b.x, owner.x + 0.9, 0.3); b.z = lerpf(b.z, owner.z, 0.3)
		if randf() < dt * 0.6:
			var mates = players.filter(func(p): return p.team == owner.team and p != owner)
			var tg: Dictionary = mates[randi() % mates.size()]
			var d: float = max(0.1, Vector2(tg.x - b.x, tg.z - b.z).length())
			b.vx = (tg.x - b.x) / d * 22.0; b.vz = (tg.z - b.z) / d * 22.0; b.owner = -1
	else:
		b.x += b.vx * dt; b.z += b.vz * dt; b.vx *= 0.985; b.vz *= 0.985
	for i in players.size():
		var p: Dictionary = players[i]
		p.re -= dt
		var dist = Vector2(b.x - p.x, b.z - p.z).length()
		if b.owner == -1 and dist < 1.4: b.owner = i
		if p.re <= 0: p.tx = clamp(b.x + randf_range(-22, 22), 6, 99); p.tz = clamp(b.z + randf_range(-16, 16), 4, 64); p.re = randf_range(1, 3)
		var chase: bool = b.owner == -1 and dist < 12
		var tx: float = b.x if chase else (p.x + (-6 if p.team else 6) if i == b.owner else p.tx)
		var tz: float = b.z if chase else (p.z + sin(t + i) * 4 if i == b.owner else p.tz)
		var dv = Vector2(tx - p.x, tz - p.z); var dl: float = max(0.01, dv.length())
		var sp: float = min(dl, 6.0 if i == b.owner else 5.5)
		p.vx = lerpf(p.vx, dv.x / dl * sp, 0.08); p.vz = lerpf(p.vz, dv.y / dl * sp, 0.08)
		p.x = clamp(p.x + p.vx * dt, 2, 103); p.z = clamp(p.z + p.vz * dt, 2, 66)
		p.ph += Vector2(p.vx, p.vz).length() * dt * 1.6
	if b.x < 2 or b.x > 103 or b.z < 2 or b.z > 66:
		b.x = clamp(b.x, 3, 102); b.z = clamp(b.z, 3, 65); b.vx = -b.vx; b.vz = -b.vz

func proj(x: float, z: float, y := 0.0) -> Vector3:
	var W = size.x; var H = size.y
	var cx = 52.0 + sin(t * 0.07) * 18.0; var cz = -26.0 + sin(t * 0.05) * 4.0; var cy = 17.0 + sin(t * 0.09) * 3.0
	var f = W * 0.9; var s: float = f / max(1.0, z - cz)
	return Vector3(W / 2 + (x - cx) * s, H * 0.36 + (cy - y) * s, s)

func _quad(pts: Array, col: Color) -> void:
	var pv = PackedVector2Array()
	for p in pts: var q = proj(p[0], p[1], p[2] if p.size() > 2 else 0.0); pv.append(Vector2(q.x, q.y))
	draw_colored_polygon(pv, col)

func _draw() -> void:
	if mode == "hub": _draw_hub(); return
	var W = size.x; var H = size.y
	draw_rect(Rect2(0, 0, W, H), Color("#070a10") if not Fright.THEME else Color("#0b0612"))
	draw_rect(Rect2(0, 0, W, H * 0.5), Color("#0b111a") if not Fright.THEME else Color("#1a0b2a"))
	if Fright.THEME: _moon(Vector2(W * 0.8, H * 0.13), 60.0)
	_quad([[-10, 72, 0], [115, 72, 0], [115, 72, 22], [-10, 72, 22]], Color("#0c1018"))
	var qp = PackedVector2Array(); var qc = PackedColorArray()
	for s in crowd:
		var x: float = lerpf(-10.0, 115.0, s.u); var y: float = 1.0 + s.v * 20.0
		var q = proj(x, 72.0 + s.v * 6.0, y)
		var jump: float = max(0.0, sin(t * 3.0 + s.ph)) * 1.2 * q.z * 0.05
		var c: Color = s.c; c.a = 0.35 + s.v * 0.25
		Gfx.add_quad(qp, qc, Rect2(q.x, q.y - jump, max(1.0, q.z * 0.35), max(1.0, q.z * 0.5)), c)
	Gfx.flush_quads(self, qp, qc)
	var sh = fmod(t * 0.15, 1.0)
	var a0 = proj(-2, 70); var a1 = proj(107, 70)
	_quad([[-2, 70, 0], [107, 70, 0], [107, 70, 1.2], [-2, 70, 1.2]], Color("#0f2b3d"))
	var hx: float = lerpf(a0.x, a1.x, sh)
	draw_rect(Rect2(hx - 30, proj(52, 70, 1.2).y, 60, max(2.0, proj(52, 70).y - proj(52, 70, 1.2).y)), Color(0.91, 0.71, 0.19, 0.8))
	for i in 14:
		var x0 = i * 105.0 / 14.0; var x1 = (i + 1) * 105.0 / 14.0
		_quad([[x0, 0], [x1, 0], [x1, 68], [x0, 68]], Color("#1d6b37") if i % 2 else Color("#1a6232"))
	var lc = Color(1, 1, 1, 0.55)
	_line([[0, 0], [105, 0], [105, 68], [0, 68], [0, 0]], lc); _line([[52.5, 0], [52.5, 68]], lc)
	_line([[0, 13.8], [16.5, 13.8], [16.5, 54.2], [0, 54.2]], lc); _line([[105, 13.8], [88.5, 13.8], [88.5, 54.2], [105, 54.2]], lc)
	var circ = []
	for k in 33: var an = TAU * k / 32; circ.append([52.5 + cos(an) * 9.15, 34 + sin(an) * 9.15])
	_line(circ, lc)
	for gx in [0.0, 105.0]:
		var p1 = proj(gx, 30.3); var p2 = proj(gx, 37.7); var p3 = proj(gx, 30.3, 2.44); var p4 = proj(gx, 37.7, 2.44)
		draw_polyline(PackedVector2Array([Vector2(p1.x, p1.y), Vector2(p3.x, p3.y), Vector2(p4.x, p4.y), Vector2(p2.x, p2.y)]), Color.WHITE, 2)
	var ents = players.duplicate(); ents.sort_custom(func(a, b): return a.z > b.z)
	for p in ents: _runner(p)
	var bp = proj(ball.x, ball.z, 0.3)
	draw_circle(Vector2(bp.x, bp.y), max(1.5, bp.z * 0.22), Color.WHITE)
	for L in [[-8, 74, 30], [113, 74, 30], [20, 76, 34], [85, 76, 34]]:
		var q = proj(L[0], L[1], L[2])
		Gfx.glow(self, Vector2(q.x, q.y), 230.0, Color(1, 0.97, 0.85, 0.3) if not Fright.THEME else Color(1, 0.55, 0.15, 0.3))
		draw_circle(Vector2(q.x, q.y), 6, Color(1, 1, 0.95, 0.9))
	for pt in parts:
		pt.y -= pt.v * 0.3
		if pt.y < 0: pt.y = 1.0; pt.x = randf()
		draw_circle(Vector2(pt.x * W, pt.y * H), pt.s, Color(1, 0.9, 0.67, pt.a * 0.5) if not Fright.THEME else Color(1, 0.5, 0.1, pt.a * 0.6))
	if Fright.THEME:
		_bats(W, H)
		for k in 4: Gfx.pumpkin(self, Vector2(W * (0.06 + k * 0.07), H - 28 - (k % 2) * 8), 26 - k * 3, t + k)
	# broadcast overlay (main menu identity) — gold, or orange & purple for Halloween
	var o1 = Color(0.31, 0.23, 0.05, 0.55) if not Fright.THEME else Color(0.3, 0.1, 0.38, 0.55)
	var o2 = Color(0.59, 0.45, 0.14, 0.32) if not Fright.THEME else Color(0.75, 0.33, 0.05, 0.32)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W * 0.55, 0), Vector2(W * 0.3, H), Vector2(0, H)]), o1)
	draw_colored_polygon(PackedVector2Array([Vector2(W * 0.55, 0), Vector2(W * 0.75, 0), Vector2(W * 0.5, H), Vector2(W * 0.3, H)]), o2)
	draw_colored_polygon(PackedVector2Array([Vector2(W * 0.75, 0), Vector2(W, 0), Vector2(W, H), Vector2(W * 0.5, H)]), Color(0.04, 0.03, 0.02, 0.55))

func _moon(c: Vector2, r: float) -> void:
	for k in 6: draw_circle(c, r + 16 + k * 18, Color(1, 0.7, 0.3, 0.045))
	draw_circle(c, r, Color("#ffe1a0"))
	draw_circle(c + Vector2(-r * 0.3, -r * 0.2), r * 0.18, Color(0.85, 0.68, 0.42, 0.5)); draw_circle(c + Vector2(r * 0.35, r * 0.25), r * 0.12, Color(0.85, 0.68, 0.42, 0.5))

func _bats(W: float, H: float) -> void:
	for b in bats:
		b.x += b.v * 0.016
		if b.x > 1.1: b.x = -0.1; b.y = randf_range(0.05, 0.4)
		Gfx.bat(self, Vector2(b.x * W, b.y * H + sin(t * 2.0 + b.ph) * 10), b.s, t * 10.0 + b.ph)

func _line(pts: Array, c: Color) -> void:
	var pv = PackedVector2Array()
	for p in pts: var q = proj(p[0], p[1]); pv.append(Vector2(q.x, q.y))
	draw_polyline(pv, c, 1.4, true)

func _runner(p: Dictionary) -> void:
	var base = proj(p.x, p.z, 0); var top = proj(p.x, p.z, 1.8)
	var h: float = base.y - top.y; var w: float = h * 0.28
	var b = Vector2(base.x, base.y)
	Gfx.ellipse(self, b, w * 0.9, w * 0.25, Color(0, 0, 0, 0.35), 12)
	var sw = sin(p.ph * 2.2)
	draw_line(b + Vector2(0, -h * 0.48), b + Vector2(sw * w * 0.7, 0), Color("#111111"), max(1.0, w * 0.32))
	draw_line(b + Vector2(0, -h * 0.48), b + Vector2(-sw * w * 0.7, 0), Color("#111111"), max(1.0, w * 0.32))
	draw_rect(Rect2(b + Vector2(-w * 0.5, -h * 0.55), Vector2(w, h * 0.14)), p.kit[1])
	draw_rect(Rect2(b + Vector2(-w * 0.55, -h * 0.86), Vector2(w * 1.1, h * 0.34)), p.kit[0])
	draw_circle(b + Vector2(0, -h * 0.93), w * 0.32, Color("#c48a5c"))

func _draw_hub() -> void:
	var W = size.x; var H = size.y
	draw_rect(Rect2(0, 0, W, H), Color("#0c1116") if not Fright.THEME else Color("#120a1c"))
	draw_rect(Rect2(0, H * 0.55, W, H * 0.45), Color("#080b0f") if not Fright.THEME else Color("#0a0610"))
	var vx = W * 0.55 + sin(t * 0.08) * 40.0; var vy = H * 0.42
	for i in range(-20, 21): draw_line(Vector2(vx + i * 8, vy - 70), Vector2(vx + i * 160, -20), Color(1, 1, 1, 0.04), 2)
	for i in 5:
		var y = H * 0.08 + i * 26; var w = W * (0.5 - i * 0.06)
		for k in 8:
			var a = (0.18 - i * 0.025) * (1.0 - k / 8.0)
			draw_rect(Rect2(vx - w / 2 * (1.0 - k / 8.0), y, w * (1.0 - k / 8.0), 3), Color(0.78, 1, 0.96, a * 0.35))
	for i in 9: draw_rect(Rect2(vx - 380 + i * 95, vy - 40, 70, 210), Color(1, 1, 1, 0.025))
	var dp = PackedVector2Array(); var dc = PackedColorArray()
	for y in range(0, int(H), 12):
		for x in range(0, 70, 12):
			if (x + y) % 24 == 0:
				Gfx.add_quad(dp, dc, Rect2(x + 4.5, y + 4.5, 3, 3), Color(0.25, 0.88, 0.77, 0.12)); Gfx.add_quad(dp, dc, Rect2(W - x - 7.5, y + 4.5, 3, 3), Color(0.25, 0.88, 0.77, 0.12))
	Gfx.flush_quads(self, dp, dc)
	for pt in parts:
		pt.y -= pt.v * 0.15
		if pt.y < 0: pt.y = 1.0; pt.x = randf()
		draw_circle(Vector2(pt.x * W, pt.y * H), pt.s, Color(0.47, 1, 0.9, pt.a * 0.25) if not Fright.THEME else Color(1, 0.5, 0.12, pt.a * 0.35))
	if Fright.THEME: _bats(W, H)
