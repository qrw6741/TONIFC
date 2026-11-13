class_name MatchSim
extends RefCounted
## 11v11 football simulation on a 105×68 m pitch.
## Ball physics with height/bounce/curl, dribbling, passes, through balls, lobs, crosses,
## power & finesse shots, headers, volleys, skill moves, standing & slide tackles,
## fouls & cards, kick-offs, throw-ins, corners, goal kicks, free kicks with walls,
## penalties, goalkeeping (positioning, dives, catches, parries), stamina, substitutions,
## team shape / pressing / support-run AI, and friendly rule variants.

const PW := 105.0
const PH := 68.0
const GOAL_W := 7.32
const GOAL_H := 2.44
const G := 9.81
const GY0 := PH / 2 - GOAL_W / 2
const GY1 := PH / 2 + GOAL_W / 2

signal ended

## a player on the pitch (object, so comparisons are by identity)
class MP extends RefCounted:
	var p: Dictionary; var side = ""; var slot = 0; var team: Dictionary; var slot_pos = ""; var fx = 0.0; var fy = 0.0; var gk = false
	var x = 0.0; var y = 0.0; var vx = 0.0; var vy = 0.0; var face = 0.0
	var pac = 50.0; var sho = 50.0; var pas = 50.0; var dri = 50.0; var defn = 50.0; var phy = 50.0; var gkr = 0.0
	var stamina = 1.0; var cool = 0.0; var tackle_cool = 0.0; var stun = 0.0; var dive = null; var decide_t = 0.0; var run = null; var ph = 0.0
	var skill_t = 0.0; var yellow = 0; var label = ""; var label_t = 0.0; var sliding = 0.0; var target = null; var sp_move = false
	var recv_t = -9.0; var hold_t = 0.0; var sprinting = false; var jockey = false
	var touch_t = 0.0; var lead = 0.6; var lead_side = 0.0; var burst = 0.0; var invuln = 0.0; var spin_t = 0.0

var cfg: Dictionary
var t = 0.0
var clock = 0.0
var half = 1
var half_secs = 180.0
var state = "setpiece"
var state_t = 0.0
var paused = false
var rules = "classic"
var ai = 0.7
var user_side = ""
var msgs = []
var banner = null
var ball = {}
var stats = {"poss": [0.0, 0.0], "shots": [0, 0], "sot": [0, 0], "passes": [0, 0], "tackles": [0, 0], "fouls": [0, 0], "corners": [0, 0]}
var goals = []
var score = {"home": 0, "away": 0}
var subs_used = {"home": 0, "away": 0}
var sp = null
var pending_sp = null
var ctrl = null
var charge = 0.0
var charge_kind = ""
var fx = []
var ref = {"x": PW / 2, "y": PH / 2 + 8, "vx": 0.0, "vy": 0.0, "ph": 0.0}
var golden = false
var teams = {}
var all = []
var inp = {}
var edge = {}
var rel = {}
var last_goal_side = ""
var celebrant = null
var pending_save = null
var pen_kick = false
var last_auto_sw = 0.0
var finished = false

func _init(c: Dictionary) -> void:
	cfg = c
	ai = Data.difficulties[c.get("difficulty", "professional")].ai
	if c.has("ai"): ai = clamp(float(c.ai), 0.2, 1.3)
	elite = c.get("elite", false)   # dynamic difficulty (Rivals divisions, win streaks, Champions)
	half_secs = float(c.get("half_len", 3)) * 60.0
	rules = c.get("rules", "classic")
	user_side = c.get("user_side", "")
	ball = {"x": PW / 2, "y": PH / 2, "z": 0.0, "vx": 0.0, "vy": 0.0, "vz": 0.0, "spin": 0.0, "owner": null, "last": null, "prev": null, "shot": null, "shot_eval": false, "kind": "", "target": null, "pass_t": 0.0}
	for side in ["home", "away"]:
		var T: Dictionary = c[side]
		var team = {"side": side, "name": T.name, "short": T.short, "kit": T.kit, "formation": T.formation, "dir": 1 if side == "home" else -1, "players": [], "bench": T.get("subs", []).slice(0, 7), "user": user_side == side, "chem": T.get("chem"), "ai": ai}
		teams[side] = team
		for i in T.players.size():
			team.players.append(make_mp(T.players[i], side, i, team, T.chem.per[i] if T.get("chem") else 3))
	all = teams.home.players + teams.away.players
	if user_side != "":
		for m in teams[user_side].players: if m.slot_pos == "ST" or m.slot_pos == "CF": ctrl = m
		if ctrl == null: ctrl = teams[user_side].players[10]
	begin_kickoff("home")
	show_banner("%s vs %s" % [teams.home.short, teams.away.short], c.get("title", "Kick-off"), 1.8)

func make_mp(p: Dictionary, side: String, slot: int, team: Dictionary, chem: int) -> MP:
	var pos: Array = Data.formations[team.formation][slot]
	var st: Array = p.stats; var gk: bool = pos[0] == "GK"
	var fit = 0 if Data.fits_pos(p, pos[0]) else -6
	var cb = (chem - 1.5) * 1.5 + fit
	var m = MP.new()
	m.p = p; m.side = side; m.slot = slot; m.team = team; m.slot_pos = pos[0]; m.fx = float(pos[1]); m.fy = float(pos[2]); m.gk = gk
	m.face = 0.0 if side == "home" else PI
	m.pac = 55.0 if gk else clamp(st[0] + cb, 20, 99); m.sho = 30.0 if gk else clamp(st[1] + cb, 20, 99)
	m.pas = max(50.0, st[2]) if gk else clamp(st[2] + cb, 20, 99); m.dri = 40.0 if gk else clamp(st[3] + cb, 20, 99)
	m.defn = 40.0 if gk else clamp(st[4] + cb, 20, 99); m.phy = 60.0 if gk else clamp(st[5] + cb, 20, 99)
	m.gkr = clamp(p.ovr + cb, 30, 99) if gk else 0.0
	m.decide_t = randf() * 0.5; m.ph = randf() * 6
	return m

func enemy(side: String) -> Dictionary: return teams["away" if side == "home" else "home"]
func other(side: String) -> String: return "away" if side == "home" else "home"
func goal_x(team: Dictionary) -> float: return PW if team.dir > 0 else 0.0
func own_goal_x(team: Dictionary) -> float: return 0.0 if team.dir > 0 else PW
func si(side: String) -> int: return 0 if side == "home" else 1
func msg(text: String, dur := 2.0) -> void: msgs.append({"text": text, "t": dur})
func show_banner(big: String, small := "", dur := 2.2) -> void: banner = {"big": big, "small": small, "t": dur}
func d2(ax, ay, bx, by) -> float: return Vector2(ax - bx, ay - by).length()

func max_speed(m: MP, sprint: bool) -> float:
	var base = 5.2 + m.pac / 100.0 * 3.6
	var v = base if sprint else base * 0.66
	v *= 0.72 + 0.28 * m.stamina
	if not m.team.user: v *= 0.93 + m.team.ai * 0.09
	if m.burst > 0: v *= 1.2
	return v

# ------------------------------------------------------------------ positioning
func home_spot(m: MP) -> Vector2:
	var tm: Dictionary = m.team; var b = ball
	var in_poss: bool = b.owner != null and b.owner.side == m.side
	var depth = (100.0 - m.fy) / 100.0
	var span = 70.0 if in_poss else 52.0
	var prog: float = b.x if tm.dir > 0 else PW - b.x
	var shift: float = clamp((prog - 52.5) * 0.45 + (10.0 if in_poss else -2.0), -14.0, 28.0)
	var along: float = 4.0 + depth * span + shift
	if not m.gk and not in_poss: along = max(along, 7.0 if Data.pos_group[m.slot_pos] == "DEF" else 11.0)
	if m.gk: along = clamp(3.0 + max(0.0, prog - 60.0) * 0.06, 2.0, 9.0)
	along = clamp(along, 2.0, 100.0)
	var width = 30.0 if in_poss else 23.0
	var y: float = PH / 2 + (1.0 if tm.dir > 0 else -1.0) * ((m.fx - 50.0) / 50.0) * width
	y += (b.y - PH / 2) * (0.08 if m.gk else 0.22)
	var x: float = along if tm.dir > 0 else PW - along
	return Vector2(clamp(x, 1.0, PW - 1.0), clamp(y, 2.0, PH - 2.0))

func nearest(list: Array, x: float, y: float, excl = null):
	var best = null; var bd = 1e9
	for m in list:
		if m == excl or m.stun > 0: continue
		var d: float = (m.x - x) * (m.x - x) + (m.y - y) * (m.y - y)
		if d < bd: bd = d; best = m
	return best

func place_formation(kick_side: String) -> Array:
	for side in ["home", "away"]:
		var tm: Dictionary = teams[side]
		for m in tm.players:
			var depth: float = (100.0 - m.fy) / 100.0
			var along: float = min(3.0 + depth * 46.0, 50.5)
			if m.gk: along = 3.0
			m.x = along if tm.dir > 0 else PW - along
			m.y = clamp(PH / 2 + (1.0 if tm.dir > 0 else -1.0) * ((m.fx - 50.0) / 50.0) * 26.0, 3.0, PH - 3.0)
			m.vx = 0.0; m.vy = 0.0; m.dive = null; m.stun = 0.0; m.run = null; m.sliding = 0.0
			m.face = 0.0 if tm.dir > 0 else PI
	var tm: Dictionary = teams[kick_side]
	var fwds: Array = tm.players.filter(func(m): return not m.gk)
	fwds.sort_custom(func(a, b): return abs(a.x - PW / 2) < abs(b.x - PW / 2))
	var k: MP = fwds[0]; var p2: MP = fwds[1]
	k.x = PW / 2 - tm.dir * 0.4; k.y = PH / 2
	p2.x = PW / 2 - tm.dir * 2.5; p2.y = PH / 2 + 6
	var foe = enemy(kick_side)
	for m in foe.players:
		if d2(m.x, m.y, PW / 2, PH / 2) < 9.5: m.x = PW / 2 - foe.dir * 10.0
	return [k, p2]

func begin_kickoff(side: String) -> void:
	var r = place_formation(side)
	ball.merge({"x": PW / 2, "y": PH / 2, "z": 0.0, "vx": 0.0, "vy": 0.0, "vz": 0.0, "owner": null, "shot": null, "spin": 0.0}, true)
	state = "setpiece"; state_t = 0.0
	sp = {"type": "kickoff", "side": side, "taker": r[0], "x": PW / 2, "y": PH / 2, "aim": null, "user_dive": 0}
	give_ball(r[0])
	if teams[side].user: switch_to(r[0])

# ------------------------------------------------------------------ ball control
func give_ball(m: MP) -> void:
	var b = ball
	if b.owner == m: return
	if b.last != null and b.last != m: b.prev = b.last
	b.owner = m; b.last = m; b.shot = null; b.shot_eval = false; b.z = 0.0; b.vz = 0.0; b.spin = 0.0; b.kind = ""; b.reserve = null
	m.touch_t = 0.0; m.lead = 0.55
	m.run = null; m.recv_t = t
	if m.team.user: switch_to(m)

func switch_to(m: MP) -> void:
	if ctrl != m:
		if ctrl != null: ctrl.jockey = false
		ctrl = m; charge = 0.0; charge_kind = ""

func kick(m: MP, vx: float, vy: float, vz: float, kind: String, spin := 0.0) -> void:
	var b = ball
	b.owner = null; b.vx = vx; b.vy = vy; b.vz = vz; b.spin = spin; b.last = m; b.kind = kind
	b.z = max(b.z, 0.11)
	m.cool = 0.35
	b.shot = {"side": m.side, "m": m, "air": b.z > 0.5 or kind == "header", "outside": false} if kind == "shot" else null
	if kind == "shot": stats.shots[si(m.side)] += 1; b.shot_eval = false
	if kind == "pass": b.pass_t = t
	Sfx.play("kick")

func pass_to(m: MP, target: MP, kind: String, power := 0.45) -> void:
	var b = ball
	var tx: float = target.x; var ty: float = target.y
	var err: float = max(0.01, (1.0 - m.pas / 100.0) * (0.2 if m.team.user else 0.16) + (0.0 if m.team.user else (1.0 - m.team.ai) * 0.08) + (0.1 if m.stun > 0 else 0.0))
	if kind == "through" or kind == "lobthrough":
		tx = clamp(target.x + m.team.dir * (6.0 + m.pas / 20.0 + power * 8.0), 2.0, PW - 2.0); ty = target.y + (PH / 2 - target.y) * 0.15
		target.run = {"x": tx, "y": ty, "t": 2.6}
	else:
		tx += target.vx * 0.45; ty += target.vy * 0.45
	var dx: float = tx - b.x; var dy: float = ty - b.y; var d: float = max(0.1, Vector2(dx, dy).length())
	var ang = atan2(dy, dx) + (randf() - 0.5) * 2.0 * err * (0.6 + d / 40.0)
	var pw: float = 0.8 + power * 0.45 if m.team.user else 1.0
	if kind == "lob" or kind == "cross" or kind == "lobthrough":
		var vh: float = clamp(9.0 + d * 0.42, 11.0, 25.0); var T = d / vh
		kick(m, cos(ang) * vh, sin(ang) * vh, G * T / 2.0 * (0.92 if kind == "cross" else (1.1 if kind == "lobthrough" else 1.0)), "pass")
	elif kind == "driven":
		var v: float = clamp(10.0 + d * 0.55, 13.0, 27.0) * pw
		kick(m, cos(ang) * v, sin(ang) * v, 0.25, "pass")
	else:
		var v: float = clamp(6.0 + d * 0.5, 8.0, 22.0 if kind == "through" else 20.0) * pw
		kick(m, cos(ang) * v, sin(ang) * v, 0.4 if kind == "through" else 0.2, "pass")
	b.target = target
	stats.passes[si(m.side)] += 1

func shoot(m: MP, power: float, aim_y, finesse := false, kind := "shot", err_mult := 1.0) -> void:
	var tm: Dictionary = m.team; var b = ball; var gx = goal_x(tm)
	var d: float = d2(gx, PH / 2, b.x, b.y)
	var ty: float = aim_y if aim_y != null else (GY0 + 0.9 if randf() < 0.5 else GY1 - 0.9)
	var quality: float = (m.sho / 100.0) * (1.08 if finesse else 1.0) * (0.7 if m.stun > 0 else 1.0)
	var err_base: float = (1.1 - quality) * (0.35 + d / 30.0) * (1.0 if tm.user else 1.25 - tm.ai * 0.4) * err_mult
	var pressure = 1.0
	for o in enemy(m.side).players: if d2(o.x, o.y, m.x, m.y) < 2.2: pressure = 1.35
	ty += (randf() - 0.5) * 2.0 * err_base * 2.2 * pressure
	var chip: bool = kind == "chip"
	var spd: float = (11.0 + power * 6.0) if chip else ((15.0 + power * 9.0) if finesse else (17.0 + power * 15.0 + m.sho / 25.0))
	var tz: float = (1.5 + power * 0.9 + (randf() - 0.4) * err_base * 1.4) if chip else (0.3 + power * 1.4 + (randf() - 0.3) * err_base * 1.6 * pressure)
	if power > 0.85 and not chip: tz += (power - 0.85) * 10.0 * (1.05 - quality)
	if finesse: tz = min(tz, 1.9)
	var dx: float = gx - b.x; var dy: float = ty - b.y; var dd: float = max(0.1, Vector2(dx, dy).length())
	var T = dd / spd
	var vz: float = min(12.0 if chip else 9.0, (tz - b.z + 0.5 * G * T * T) / T)
	var spin = (-1.0 if dy > 0 else 1.0) * 5.5 if finesse else 0.0
	var ang = atan2(dy, dx)
	if finesse: ang -= spin * 0.018
	kick(m, cos(ang) * spd, sin(ang) * spd, vz, "shot", spin)
	if chip: b.shot.chip = true
	b.shot.air = kind == "header" or kind == "volley" or b.shot.air
	b.shot.outside = d > 17.5
	if m.label_t <= 0 or not m.team.user: m.label = "Chip" if chip else ("Finesse" if finesse else ("Header" if kind == "header" else ("Volley" if kind == "volley" else ""))); m.label_t = 1.2

# ------------------------------------------------------------------ main update
func update(dt: float) -> void:
	if finished: return
	t += dt; state_t += dt
	for side in ["home", "away"]: teams[side].ai = 0.75 if teams[side].user else ai
	for m in msgs: m.t -= dt
	msgs = msgs.filter(func(m): return m.t > 0)
	if banner != null:
		banner.t -= dt
		if banner.t <= 0: banner = null
	for f in fx: f.t -= dt
	fx = fx.filter(func(f): return f.t > 0)
	if state == "play":
		clock += dt
		if ball.owner != null: stats.poss[si(ball.owner.side)] += dt
		if clock >= half_secs and not golden:
			if half == 1:
				state = "halftime"; state_t = 0.0; Sfx.play("whistle3"); show_banner("Half Time", "%s %d - %d %s" % [teams.home.short, score.home, score.away, teams.away.short], 3.0); return
			if rules == "golden" and score.home == score.away:
				golden = true; show_banner("Golden Goal", "Next goal wins", 2.2); msg("Golden goal — next goal wins!", 3.0)
			else:
				state = "fulltime"; state_t = 0.0; Sfx.play("whistle3"); show_banner("Full Time", "%s %d - %d %s" % [teams.home.short, score.home, score.away, teams.away.short], 3.2); return
		if golden and clock > half_secs * 1.67:
			state = "fulltime"; state_t = 0.0; Sfx.play("whistle3"); show_banner("Full Time", "", 3.0); return
	match state:
		"halftime":
			if state_t > 3.2:
				half = 2; clock = 0.0
				for side in ["home", "away"]:
					teams[side].dir *= -1
					for m in teams[side].players: m.stamina = min(1.0, m.stamina + 0.25)
				begin_kickoff("away"); Sfx.play("whistle")
			sim_players(dt, true); return
		"fulltime":
			sim_players(dt, true)
			if state_t > 3.4: finished = true; ended.emit()
			return
		"goal":
			celebrate(dt); physics_ball(dt)
			if state_t > 4.2 + replay_len:
				if golden: state = "fulltime"; state_t = 0.0; Sfx.play("whistle3"); show_banner("Full Time", "Golden goal!", 3.0); return
				begin_kickoff(other(last_goal_side)); Sfx.play("whistle")
			return
		"setpiece": update_set_piece(dt); sim_players(dt, true); return
		"out":
			physics_ball(dt); sim_players(dt, true)
			if state_t > 1.0: start_set_piece(pending_sp)
			return
	user_control(dt)
	team_ai(dt)
	sim_players(dt, false)
	physics_ball(dt)
	handle_contacts(dt)
	check_goal_and_out(dt)
	update_ref(dt)
	Sfx.crowd_level(excitement())

func excitement() -> float:
	var near: float = min(ball.x, PW - ball.x)
	return clamp(0.25 + ((25.0 - near) / 25.0 * 0.55 if near < 25 else 0.0) + (0.3 if ball.shot else 0.0), 0.2, 1.0)

# ------------------------------------------------------------------ user control
## buffered button presses: a pass pressed just before the ball arrives still fires
var buf = {}
var buf_pow = 0.35
var pcharge = 0.0            # pass power being charged (hold the pass button)
var pkey = ""
var aim_tgt = null           # who the charged pass is aimed at (drawn as a line)
var pending_shot = null      # timed finishing window
var replay_len = 0.0
var elite = false   # FUT Champions / Division Rivals: overpowered AI keepers & defenders
func want(k: String) -> bool: return buf.has(k) and t - buf[k] < 0.4

func pass_kind(m: MP, key: String) -> String:
	var r1: bool = inp.get("rmod", false)
	if key == "through": return "lobthrough" if r1 else "through"
	if key == "lob": return "cross" if in_cross_zone(m) else "lob"
	return "driven" if r1 else "ground"

func do_user_pass(m: MP, key: String, power: float, ax: float, ay: float) -> void:
	var kind = pass_kind(m, key)
	var tgt = pick_pass_target(m, ax, ay, kind, power)
	if tgt: pass_to(m, tgt, kind, power)
	else:
		var v = (14.0 + power * 10.0) if kind in ["lob", "lobthrough", "cross"] else (10.0 + power * 12.0) * (1.3 if kind == "driven" else 1.0)
		kick(m, ax * v, ay * v, (4.0 + power * 4.0) if kind in ["lob", "lobthrough", "cross"] else 0.2, "pass")
	if inp.get("lmod", false):
		# one-two: the passer bursts forward for the return ball
		var d = m.team.dir
		m.run = {"x": clamp(m.x + d * 15.0, 3.0, PW - 3.0), "y": lerpf(m.y, PH / 2, 0.2), "t": 2.8}
		m.label = "One-Two"; m.label_t = 1.0
	if kind == "driven": m.label = "Driven"; m.label_t = 0.8
	elif kind == "lobthrough": m.label = "Lobbed through"; m.label_t = 0.8

func fire_pending_shot(mult: float, lab: String) -> void:
	var ps = pending_shot; pending_shot = null
	if ps == null or ball.owner != ps.m: return
	shoot(ps.m, ps.power, ps.aim, ps.fin, "chip" if ps.chip else "shot", mult)
	if lab != "": ps.m.label = lab; ps.m.label_t = 1.2

func user_control(dt: float) -> void:
	if user_side == "" or ctrl == null: return
	var team: Dictionary = teams[user_side]; var b = ball; var m: MP = ctrl
	# timed finishing: tap shoot again just as the shot goes off for a perfect strike
	if pending_shot != null:
		var dtp: float = t - pending_shot.t0
		if edge.get("shoot", false) or edge.get("finesse", false) or edge.get("chip", false):
			if dtp >= 0.05 and dtp <= 0.13: fire_pending_shot(0.4, "Perfectly timed!")
			else: fire_pending_shot(1.35, "Mistimed")
			for k in ["shoot", "finesse", "chip"]: edge.erase(k)   # the re-tap must not also trigger a slide
		elif dtp > 0.16: fire_pending_shot(1.0, "")
	if edge.get("sw", false) and b.owner != m:
		var best = nearest(team.players.filter(func(x): return x != m and not x.gk), b.x + b.vx * 0.3, b.y + b.vy * 0.3)
		if best: switch_to(best); Sfx.play("move")
	if b.owner != null and b.owner.side != user_side and d2(m.x, m.y, b.x, b.y) > 16 and t - last_auto_sw > 1.2:
		var best = nearest(team.players.filter(func(x): return not x.gk), b.x, b.y)
		if best and best != m: switch_to(best); last_auto_sw = t
	elif b.owner == null and not (b.last != null and b.last.side == user_side and b.kind == "pass") and d2(m.x, m.y, b.x, b.y) > 14 and t - last_auto_sw > 1.5:
		var best = nearest(team.players.filter(func(x): return not x.gk), b.x, b.y)
		if best and best != ctrl and d2(best.x, best.y, b.x, b.y) < d2(m.x, m.y, b.x, b.y) - 4: switch_to(best); last_auto_sw = t
	m = ctrl
	var has: bool = b.owner == m
	var ix: float = inp.get("x", 0.0); var iy: float = inp.get("y", 0.0)
	var mag = Vector2(ix, iy).length()
	if mag > 0.1:
		var close: bool = has and inp.get("close", false)
		var v = max_speed(m, inp.get("sprint", false) and not close) * min(1.0, mag) * ((0.94 - (1.0 - m.dri / 100.0) * 0.12) if has else 1.0) * (0.6 if close else 1.0)
		var turn: float = ((6.0 + m.dri / 14.0) * (1.7 if close else 1.0)) if has else 12.0
		if m.skill_t > 0.15: turn *= 0.25   # let the skill move's motion play out
		m.vx = lerpf(m.vx, ix / max(mag, 1.0) * v, min(1.0, turn * dt)); m.vy = lerpf(m.vy, iy / max(mag, 1.0) * v, min(1.0, turn * dt))
	else:
		m.vx = lerpf(m.vx, 0.0, min(1.0, 8.0 * dt)); m.vy = lerpf(m.vy, 0.0, min(1.0, 8.0 * dt))
	m.sprinting = inp.get("sprint", false) and mag > 0.1
	m.jockey = inp.get("jockey", false) and not has
	if m.jockey:
		var cap: float = max_speed(m, false) * 0.62
		var sp = Vector2(m.vx, m.vy).length()
		if sp > cap: m.vx *= cap / sp; m.vy *= cap / sp
		m.face = atan2(b.y - m.y, b.x - m.x); m.sprinting = false
	var ax: float = ix / mag if mag > 0.1 else cos(m.face); var ay: float = iy / mag if mag > 0.1 else sin(m.face)
	var held_key = ""
	for k in ["pass", "through", "lob"]: if inp.get(k, false): held_key = k
	var rel_key = ""
	for k in ["pass", "through", "lob"]: if rel.get(k, false): rel_key = k
	if has:
		if pending_shot != null: return
		if (inp.get("shoot", false) or inp.get("finesse", false) or inp.get("chip", false)):
			charge = min(1.0, charge + dt * 1.15); charge_kind = "chip" if inp.get("chip", false) else ("finesse" if inp.get("finesse", false) else "shot")
		if (rel.get("shoot", false) or rel.get("finesse", false) or rel.get("chip", false)) and charge_kind != "":
			var aim: float
			if abs(iy) > 0.3: aim = GY0 + 0.8 if iy < 0 else GY1 - 0.8
			else: aim = GY1 - 1.0 if m.y < PH / 2 else GY0 + 1.0
			pending_shot = {"m": m, "power": max(charge, 0.35 if charge_kind == "chip" else charge), "aim": aim, "fin": charge_kind == "finesse", "chip": charge_kind == "chip", "t0": t}
			charge = 0.0; charge_kind = ""; return
		# hold to power the pass (aim line shows the target), release to play it
		if held_key != "":
			pcharge = min(1.0, pcharge + dt * 1.25); pkey = held_key
			aim_tgt = pick_pass_target(m, ax, ay, pass_kind(m, held_key), pcharge)
		var fire_key = rel_key
		var power: float = max(0.22, pcharge)
		if fire_key == "":
			for k in ["pass", "through", "lob"]:
				if want(k): fire_key = k; power = buf_pow
		if fire_key != "":
			buf.clear(); pcharge = 0.0; pkey = ""; aim_tgt = null
			do_user_pass(m, fire_key, power, ax, ay); return
		var gs = edge.get("gesture")
		if gs != null: gesture_move(m, gs)
		elif edge.get("skill", false): do_skill(m, ax, ay)
	else:
		aim_tgt = null
		if held_key != "": pcharge = min(1.0, pcharge + dt * 1.25)
		if rel_key != "":
			buf[rel_key] = t; buf_pow = max(0.22, pcharge); pcharge = 0.0
		var opp = b.owner if b.owner != null and b.owner.side != m.side else null
		var d = d2(b.x, b.y, m.x, m.y)
		var first_time: bool = b.owner == null and d < 1.6 and m.cool <= 0 and b.z > 0.35 and b.z < 2.7
		if edge.get("pass", false) and opp: try_tackle(m, opp, false); buf.erase("pass")
		if edge.get("shoot", false) and not first_time and (opp != null or b.owner == null): try_slide(m, ax, ay)
		if first_time and (edge.get("shoot", false) or want("pass")):
			if edge.get("shoot", false) and abs(goal_x(team) - m.x) < 30: shoot(m, 0.6, null, false, "header" if b.z > 1.3 else "volley")
			else:
				buf.clear()
				var tgt = pick_pass_target(m, ax, ay, "ground", buf_pow)
				if tgt: pass_to(m, tgt, "ground", buf_pow)
				else: kick(m, ax * 15.0, ay * 15.0, 2.0, "pass")

func in_cross_zone(m: MP) -> bool: return abs(goal_x(m.team) - m.x) < 30 and (m.y < 18 or m.y > PH - 18)

func pick_pass_target(m: MP, ax: float, ay: float, kind: String, power := -1.0):
	var best = null; var bs = -1e9
	var pref: float = (6.0 + power * 42.0) if power >= 0 else -1.0
	for tm in m.team.players:
		if tm == m: continue
		var dx: float = tm.x - m.x; var dy: float = tm.y - m.y; var d = Vector2(dx, dy).length()
		if d < 3 or d > (55.0 if kind in ["lob", "cross", "lobthrough"] else 45.0): continue
		var cs: float = (dx * ax + dy * ay) / d
		if cs < 0.35: continue
		var sc: float = cs * 30.0 - d * 0.35
		if kind == "cross": sc += 25.0 if abs(goal_x(m.team) - tm.x) < 16 and abs(tm.y - PH / 2) < 12 else -10.0
		if kind in ["through", "lobthrough"]: sc += (tm.x - m.x) * m.team.dir * 0.3
		if pref > 0: sc -= abs(d - pref) * 0.3
		if tm.gk: sc -= 12
		if sc > bs: bs = sc; best = tm
	return best

## skill moves: [stars needed, label]
const MOVES := {"drag_back": [1, "Drag Back"], "ball_roll": [1, "Ball Roll"], "knock_on": [2, "Knock On"], "stepover": [2, "Step Over"],
	"croqueta": [3, "La Croqueta"], "roulette": [3, "Roulette"], "mcgeady": [4, "McGeady Spin"], "elastico": [4, "Elastico"], "rainbow": [5, "Rainbow Flick"]}
var last_flick = {"cls": "", "side": 0.0, "t": -9.0}

## AI / legacy entry: pick a move the player can do
func do_skill(m: MP, ax: float, ay: float) -> void:
	var opts = ["ball_roll", "stepover", "croqueta", "roulette", "elastico"].filter(func(k): return MOVES[k][0] <= int(m.p.sm))
	if opts.is_empty(): opts = ["ball_roll"]
	do_move(m, opts[randi() % opts.size()], atan2(ay, ax))

## turn a right-stick gesture into a move (relative to where the player faces)
func gesture_move(m: MP, gs: Dictionary) -> void:
	if gs.kind == "rot":
		do_move(m, "mcgeady" if float(gs.deg) >= 300.0 else "roulette", float(gs.get("ang", m.face))); return
	var ang: float = float(gs.get("ang", m.face))
	var rel: float = wrapf(ang - m.face, -PI, PI)
	var cls = "fwd" if abs(rel) < 0.75 else ("back" if abs(rel) > 2.35 else "side")
	var side_sign = sign(rel)
	var combo = ""
	if t - last_flick.t < 0.5:
		if cls == "side" and last_flick.cls == "side": combo = "stepover" if side_sign == last_flick.side else "croqueta"
		elif cls == "fwd" and last_flick.cls == "back": combo = "rainbow"
		elif cls == "back" and last_flick.cls == "fwd": combo = "elastico"
	last_flick = {"cls": cls, "side": side_sign, "t": t}
	if combo != "": do_move(m, combo, ang, true); return
	do_move(m, {"fwd": "knock_on", "back": "drag_back", "side": "ball_roll"}[cls], ang)

func do_move(m: MP, name: String, ang: float, force := false) -> void:
	var b = ball
	if b.owner != m or (m.skill_t > 0 and not force): return
	var need: int = MOVES[name][0]; var stars: int = int(m.p.sm)
	if stars < need:
		m.label = "%s needs %d★" % [MOVES[name][1], need]; m.label_t = 1.0; return
	var near = 99.0; var foe = null
	for o in enemy(m.side).players:
		var dd = d2(o.x, o.y, m.x, m.y)
		if dd < near: near = dd; foe = o
	var success: bool = randf() < 0.42 + stars * 0.07 + m.dri / 320.0 + (stars - need) * 0.05 - (0.14 if near < 1.4 else 0.0)
	var f = Vector2(cos(m.face), sin(m.face)); var dir = Vector2(cos(ang), sin(ang))
	var lat = Vector2(-f.y, f.x) * (1.0 if f.cross(dir) >= 0 else -1.0)
	var stun_near = func(r: float, s: float):
		if not success: return
		for o in enemy(m.side).players:
			if not o.gk and d2(o.x, o.y, m.x, m.y) < r: o.stun = max(o.stun, s); o.tackle_cool = max(o.tackle_cool, s + 0.2)
	match name:
		"drag_back":
			m.vx = -f.x * 2.2; m.vy = -f.y * 2.2; m.face = wrapf(m.face + PI, -PI, PI); m.lead = 0.42; m.touch_t = 0.3
			m.skill_t = 0.45; m.invuln = 0.25; stun_near.call(2.2, 0.25)
		"ball_roll":
			m.vx = lat.x * 4.6; m.vy = lat.y * 4.6; m.lead = 0.4; m.touch_t = 0.3; m.skill_t = 0.42; m.invuln = 0.22
		"knock_on":
			var kd = dir if dir.dot(f) > 0.2 else f
			b.owner = null; b.vx = kd.x * 12.5; b.vy = kd.y * 12.5; b.vz = 0.5; b.z = 0.1; b.last = m
			b.reserve = {"m": m, "until": t + 0.75}; m.burst = 1.1; m.cool = 0.05; m.skill_t = 0.6; stun_near.call(2.0, 0.2)
		"stepover":
			m.vx = lat.x * 3.0 + f.x * 1.5; m.vy = lat.y * 3.0 + f.y * 1.5; m.skill_t = 0.5; m.invuln = 0.3; stun_near.call(3.0, 0.38)
		"croqueta":
			m.vx = lat.x * 6.2; m.vy = lat.y * 6.2; m.lead = 0.4; m.touch_t = 0.32; m.skill_t = 0.48; m.invuln = 0.38; stun_near.call(1.8, 0.25)
		"roulette":
			m.vx = lat.x * 5.0 + f.x * 1.2; m.vy = lat.y * 5.0 + f.y * 1.2; m.spin_t = 0.55; m.skill_t = 0.7; m.invuln = 0.55; m.touch_t = 0.5; stun_near.call(2.0, 0.3)
		"mcgeady":
			m.face = ang; m.vx = dir.x * 7.0; m.vy = dir.y * 7.0; m.burst = 0.8; m.spin_t = 0.35; m.skill_t = 0.6; m.invuln = 0.4; m.touch_t = 0.4; stun_near.call(2.2, 0.3)
		"elastico":
			m.vx = lat.x * 7.2; m.vy = lat.y * 7.2; m.skill_t = 0.62; m.invuln = 0.42; m.touch_t = 0.4; stun_near.call(2.4, 0.45)
		"rainbow":
			b.owner = null; b.vx = f.x * 8.5; b.vy = f.y * 8.5; b.vz = 6.4; b.z = 0.3; b.last = m
			b.reserve = {"m": m, "until": t + 1.1}; m.burst = 1.3; m.cool = 0.25; m.skill_t = 0.9; stun_near.call(2.6, 0.45)
	m.label = MOVES[name][1] + ("" if success else " ✗"); m.label_t = 1.0
	Sfx.play("whoosh")
	if not success and not name in ["knock_on", "rainbow"] and near < 1.6 and randf() < 0.45:
		b.owner = null; b.vx = m.vx * 1.3 + f.x * 2.5; b.vy = m.vy * 1.3 + f.y * 2.5; m.cool = 0.4

func try_tackle(m: MP, opp: MP, is_ai: bool) -> bool:
	if m.tackle_cool > 0: return false
	m.tackle_cool = 0.7
	var d = d2(opp.x, opp.y, m.x, m.y)
	if d > 2.0:
		m.vx += (opp.x - m.x) / d * 2; m.vy += (opp.y - m.y) / d * 2; return false
	stats.tackles[si(m.side)] += 1; Sfx.play("tackle")
	var p: float = clamp(0.3 + (m.defn - opp.dri) / 100.0 + ((m.team.ai - 0.6) * 0.25 if is_ai else 0.12) + (0.14 if m.jockey else 0.0) - (d - 1.0) * 0.15, 0.08, 0.85)
	if is_ai and elite: p = clamp(p + 0.28, 0.2, 0.95)
	if t - opp.recv_t < 0.5: p *= 0.5
	if opp.invuln > 0: p *= 0.25
	if opp == ctrl and opp.team.user and inp.get("close", false) and ball.owner == opp: p *= 0.7   # shielding
	if randf() < p:
		if randf() < 0.55: give_ball(m)
		else: ball.owner = null; ball.vx = (randf() - 0.5) * 8; ball.vy = (randf() - 0.5) * 8; opp.cool = 0.4
		opp.stun = 0.3; return true
	if randf() < 0.12 and rules != "nofouls": foul(m, opp, false); return false
	m.stun = 0.45; return false

func try_slide(m: MP, ax: float, ay: float) -> void:
	if m.tackle_cool > 0 or m.sliding > 0: return
	m.sliding = 0.6; m.tackle_cool = 1.4
	var s = max_speed(m, true) + 2.5
	m.vx = ax * s; m.vy = ay * s; m.label = "Slide"; m.label_t = 0.6

func foul(m: MP, victim: MP, slide: bool) -> void:
	if rules == "nofouls": return
	stats.fouls[si(m.side)] += 1; Sfx.play("whistle")
	if (slide and randf() < 0.35) or randf() < 0.08: m.yellow += 1; msg("Yellow card — " + Data.short_name(m.p.name), 2.6)
	else: msg("Foul by " + Data.short_name(m.p.name), 2.0)
	var og = own_goal_x(m.team)
	var in_box: bool = abs(victim.x - og) < 16.5 and abs(victim.y - PH / 2) < 20.16
	ball.owner = null; ball.vx = 0.0; ball.vy = 0.0; ball.vz = 0.0
	pending_sp = {"type": "penalty", "side": victim.side, "x": 11.0 if m.team.dir > 0 else PW - 11.0, "y": PH / 2} if in_box else {"type": "freekick", "side": victim.side, "x": victim.x, "y": victim.y}
	state = "out"; state_t = 0.4
	if in_box: show_banner("Penalty!", "", 1.6)

# ------------------------------------------------------------------ team AI
func team_ai(dt: float) -> void:
	var b = ball
	for side in ["home", "away"]:
		var team: Dictionary = teams[side]; var foe = enemy(side)
		var in_poss: bool = b.owner != null and b.owner.side == side
		var loose: bool = b.owner == null
		var recv = null
		if loose and b.target != null and b.target.side == side and b.last != null and b.last.side == side and t - b.pass_t < 3.0: recv = b.target
		if recv != null and not (team.user and recv == ctrl):
			var best = Vector2(b.x, b.y)
			var k = 0.15
			while k < 2.6:
				var f = (1.0 - exp(-0.6 * k)) / 0.6
				var px: float = b.x + b.vx * f; var py: float = b.y + b.vy * f
				best = Vector2(px, py)
				if d2(px, py, recv.x, recv.y) / max_speed(recv, true) <= k: break
				k += 0.15
			steer(recv, best.x, best.y, true, dt)
		var chaser = null; var chaser2 = null
		if not in_poss:
			var tx: float = b.x + b.vx * 0.35; var ty: float = b.y + b.vy * 0.35
			var outfield: Array = team.players.filter(func(m): return not m.gk and not (team.user and m == ctrl) and m != recv)
			chaser = nearest(outfield, tx, ty)
			if not loose: chaser2 = nearest(outfield.filter(func(m): return m != chaser), tx, ty)
		for m in team.players:
			if team.user and m == ctrl: continue
			if m.stun > 0 or m.sliding > 0: continue
			if m.gk: gk_ai(m, dt); continue
			if b.owner == m: carrier_ai(m, dt); continue
			if m == recv: continue
			var home = home_spot(m)
			var tx = home.x; var ty = home.y; var sprint = false
			if m == chaser:
				var d = d2(b.x, b.y, m.x, m.y)
				if loose:
					var lead: float = min(0.8, d / 14.0); tx = b.x + b.vx * lead; ty = b.y + b.vy * lead; sprint = d > 2
				else:
					var og = own_goal_x(team); var gv = Vector2(og - b.x, PH / 2 - b.y).normalized()
					var close = d < 3.2
					tx = b.x + gv.x * (0.9 if close else 1.6); ty = b.y + gv.y * (0.9 if close else 1.6); sprint = d > 6
					if d < 1.7 and b.owner != null:
						var agg: float = 0.7 if team.user else (0.35 + team.ai * 0.9) * (1.6 if elite else 1.0)
						if randf() < agg * dt: try_tackle(m, b.owner, true)
						elif not team.user and randf() < dt * 0.04 * team.ai and abs(b.owner.x - og) > 25: try_slide(m, (b.x - m.x) / max(d, 0.1), (b.y - m.y) / max(d, 0.1))
			elif m == chaser2:
				var og = own_goal_x(team)
				var double_press: bool = (team.user and inp.get("contain", false)) or (not team.user and team.ai >= 0.85 and abs(b.x - og) < 60)
				if double_press:
					tx = lerpf(b.x, og, 0.08); ty = lerpf(b.y, PH / 2, 0.08); sprint = true
					if team.user and d2(b.x, b.y, m.x, m.y) < 1.6 and b.owner != null and randf() < 0.5 * dt: try_tackle(m, b.owner, true)
				else: tx = lerpf(b.x, og, 0.4); ty = lerpf(b.y, PH / 2, 0.35)
			elif not in_poss:
				var mk = nearest(foe.players.filter(func(o): return not o.gk), home.x, home.y)
				if mk and d2(mk.x, mk.y, home.x, home.y) < 14:
					var og = own_goal_x(team)
					tx = lerpf(lerpf(mk.x, og, 0.12), home.x, 0.35); ty = lerpf(lerpf(mk.y, PH / 2, 0.08), home.y, 0.35)
			else:
				if m.run != null and m.run.t > 0:
					m.run.t -= dt; tx = m.run.x; ty = m.run.y; sprint = true
				elif Data.pos_group[m.slot_pos] == "ATT" and randf() < dt * 0.35:
					var gx = goal_x(team)
					m.run = {"x": clamp(m.x + team.dir * randf_range(8, 18), 3.0, PW - 3.0), "y": clamp(lerpf(m.y, PH / 2, 0.3) + randf_range(-6, 6), 4.0, PH - 4.0), "t": randf_range(1, 2.2)}
					if abs(gx - m.run.x) < 3: m.run.x = gx - team.dir * 6.0
				var mk = nearest(foe.players, m.x, m.y)
				if mk:
					var d = d2(mk.x, mk.y, m.x, m.y)
					if d < 4: ty += (m.y - mk.y) / max(d, 0.1) * 3.0
			steer(m, tx, ty, sprint, dt)

func steer(m: MP, tx: float, ty: float, sprint: bool, dt: float) -> void:
	var dx: float = tx - m.x; var dy: float = ty - m.y; var d = Vector2(dx, dy).length()
	var mx = max_speed(m, sprint)
	var want: float = 0.0 if d < 0.4 else min(mx, d * 1.8)
	var vx = dx / d * want if d > 0.01 else 0.0; var vy = dy / d * want if d > 0.01 else 0.0
	m.vx = lerpf(m.vx, vx, min(1.0, 6.0 * dt)); m.vy = lerpf(m.vy, vy, min(1.0, 6.0 * dt))
	m.sprinting = sprint and want > mx * 0.8

func carrier_ai(m: MP, dt: float) -> void:
	var team: Dictionary = m.team; var foe = enemy(m.side); var a: float = team.ai
	var gx = goal_x(team); var dist_goal = d2(gx, PH / 2, m.x, m.y)
	var nr = nearest(foe.players, m.x, m.y)
	var press = d2(nr.x, nr.y, m.x, m.y) if nr else 99.0
	m.decide_t -= dt
	var dv = Vector2(gx - m.x, (PH / 2 - m.y) * 0.6).normalized()
	if nr and press < 6:
		var ov = Vector2(m.x - nr.x, m.y - nr.y).normalized()
		dv += Vector2(ov.x * 0.9, ov.y * 1.2) * (6.0 - press) / 6.0
	dv = dv.normalized()
	var sprint: bool = press > 3.2 or (press > 2 and (nr.x - m.x) * team.dir < 0)
	steer(m, m.x + dv.x * 6, m.y + dv.y * 6, sprint, dt)
	if m.decide_t > 0 or m.cool > 0 or state != "play": return
	m.decide_t = 0.55 - a * 0.3 + randf() * 0.25
	var angle_ok: bool = abs(m.y - PH / 2) < 16 + (30.0 - min(30.0, dist_goal)) * 0.2
	if dist_goal < 27 and angle_ok and (press > 2.2 or dist_goal < 16 or randf() < 0.5):
		var p_shoot = 0.95 if dist_goal < 12 else (0.6 + a * 0.2 if dist_goal < 17 else (0.25 + a * 0.15 if dist_goal < 22 else 0.08 + a * 0.08))
		if randf() < p_shoot:
			var aim = GY0 + randf_range(0.5, 1.6) if randf() < 0.5 else GY1 - randf_range(0.5, 1.6)
			var kp = null
			for o in foe.players: if o.gk: kp = o
			if kp != null and randf() < clamp((a - 0.45) * 1.3, 0.0, 0.92):
				aim = GY1 - randf_range(0.45, 1.1) if kp.y < PH / 2 else GY0 + randf_range(0.45, 1.1)
			shoot(m, randf_range(0.45, 0.82), aim, dist_goal > 15 and dist_goal < 22 and randf() < 0.35); return
	if press < 2.6 and m.skill_t <= 0 and m.p.sm >= 3 and randf() < clamp((a - 0.55) * 0.6, 0.0, 0.35) and dist_goal < 45:
		var side = Vector2(-dv.y, dv.x) * (1.0 if randf() < 0.5 else -1.0)
		do_skill(m, dv.x * 0.6 + side.x * 0.4, dv.y * 0.6 + side.y * 0.4); return
	var best = null; var bs = -1e9
	for tm in team.players:
		if tm == m: continue
		var d = d2(tm.x, tm.y, m.x, m.y)
		if d < 5 or d > 40: continue
		var open = 99.0
		for o in foe.players: open = min(open, d2(o.x, o.y, tm.x, tm.y))
		var risk = 0.0
		for o in foe.players:
			var t2: float = clamp(((o.x - m.x) * (tm.x - m.x) + (o.y - m.y) * (tm.y - m.y)) / (d * d), 0.0, 1.0)
			var od = d2(o.x, o.y, m.x + (tm.x - m.x) * t2, m.y + (tm.y - m.y) * t2)
			if od < 2.2 and t2 > 0.1: risk += (2.2 - od) * 6.0
		var sc: float = (tm.x - m.x) * team.dir * 0.9 + min(open, 8.0) * 2.2 - risk - d * 0.15 - (30.0 if tm.gk else 0.0)
		if abs(gx - tm.x) < 20 and abs(tm.y - PH / 2) < 15 and open > 2.5: sc += 14
		if sc > bs: bs = sc; best = tm
	var dribble: float = (14.0 if press > 5 else (6.0 if press > 3 else (-2.0 if press > 2 else -10.0))) + (5.0 if dist_goal < 32 else 0.0) + (m.dri - 70.0) * 0.2
	if best and (bs > dribble or press < 1.8):
		var cross: bool = in_cross_zone(m) and abs(gx - best.x) < 16
		var through: bool = best.run != null and randf() < 0.6
		pass_to(m, best, "cross" if cross else ("through" if through else ("lob" if d2(best.x, best.y, m.x, m.y) > 30 and randf() < 0.5 else "ground")))

func gk_ai(m: MP, dt: float) -> void:
	var team: Dictionary = m.team; var b = ball; var og = own_goal_x(team)
	if m.dive != null:
		m.dive.t -= dt; m.x += m.dive.vx * dt; m.y += m.dive.vy * dt; m.vx = m.dive.vx; m.vy = m.dive.vy
		if m.dive.t <= 0: m.dive = null; m.stun = 0.5
		return
	if b.owner == m:
		steer(m, og + team.dir * 6, PH / 2, false, dt)
		m.hold_t += dt
		if m.hold_t > 1.3 and not (team.user and ctrl == m):
			m.hold_t = 0.0
			var mates: Array = team.players.filter(func(x): return not x.gk)
			var best = mates[0]; var bo = -1.0
			for x in mates:
				var o = 99.0
				for e in enemy(m.side).players: o = min(o, d2(e.x, e.y, x.x, x.y))
				if o > bo: bo = o; best = x
			if bo < 6: best = Sys.pick(mates.filter(func(x): return Data.pos_group[x.slot_pos] != "DEF"))
			pass_to(m, best, "lob" if d2(best.x, best.y, m.x, m.y) > 28 else "ground")
		return
	m.hold_t = 0.0
	var dg = d2(b.x, b.y, og, PH / 2)
	var off: float = clamp(1.0 + (40.0 - min(40.0, dg)) * 0.07, 1.0, 4.5)
	var tx: float = og + team.dir * off
	var ty: float = clamp(PH / 2 + (b.y - PH / 2) * clamp(off / max(dg, 1.0), 0.0, 0.5) * 2.2, GY0 + 0.4, GY1 - 0.4)
	var in_box: bool = abs(b.x - og) < 16.5 and abs(b.y - PH / 2) < 20
	if in_box and (b.owner == null or b.owner.side != m.side) and dg < 13 and b.shot == null:
		if b.owner == null or d2(b.x, b.y, m.x, m.y) < 6: tx = b.x; ty = b.y
	steer(m, tx, ty, in_box, dt)
	if b.owner == null and d2(b.x, b.y, m.x, m.y) < 1.8 and b.z < 2.6 and m.cool <= 0 and b.shot == null:
		give_ball(m); b.vx = 0.0; b.vy = 0.0

# ------------------------------------------------------------------ physics
func sim_players(dt: float, frozen: bool) -> void:
	for m in all:
		m.cool = max(0.0, m.cool - dt); m.tackle_cool = max(0.0, m.tackle_cool - dt); m.stun = max(0.0, m.stun - dt); m.skill_t = max(0.0, m.skill_t - dt); m.label_t = max(0.0, m.label_t - dt)
		m.burst = max(0.0, m.burst - dt); m.invuln = max(0.0, m.invuln - dt); m.spin_t = max(0.0, m.spin_t - dt)
		if m.sliding > 0:
			m.sliding -= dt; m.vx *= 0.94; m.vy *= 0.94
			if m.sliding <= 0: m.sliding = 0.0; m.stun = 0.35
		if frozen and not m.sp_move:
			if m.target != null: steer(m, m.target.x, m.target.y, false, dt)
			else: m.vx *= 0.9; m.vy *= 0.9
		m.x = clamp(m.x + m.vx * dt, -3.0, PW + 3.0); m.y = clamp(m.y + m.vy * dt, -3.0, PH + 3.0)
		var spd = Vector2(m.vx, m.vy).length()
		if spd > 0.3: m.face = atan2(m.vy, m.vx)
		m.ph += spd * dt * 1.7
		if m.sprinting and spd > 4: m.stamina = max(0.0, m.stamina - dt * (0.012 - m.phy / 100.0 * 0.006) * 1.6)
		else: m.stamina = min(1.0, m.stamina + dt * 0.003)
	for i in all.size():
		for j in range(i + 1, all.size()):
			var a: MP = all[i]; var c: MP = all[j]
			var dx: float = c.x - a.x; var dy: float = c.y - a.y; var d = Vector2(dx, dy).length()
			if d < 0.85 and d > 0.001:
				var push = (0.85 - d) / 2.0
				a.x -= dx / d * push; a.y -= dy / d * push; c.x += dx / d * push; c.y += dy / d * push

func physics_ball(dt: float) -> void:
	var b = ball
	if b.owner != null:
		# dribbling with touches: each touch pushes the ball ahead (further when sprinting / with poor
		# dribbling), the player catches up between touches; loose touches can be poked away
		var m: MP = b.owner
		var spd = Vector2(m.vx, m.vy).length()
		var close: bool = m.team.user and m == ctrl and inp.get("close", false)
		var dri: float = m.dri / 100.0
		m.touch_t -= dt
		if m.touch_t <= 0.0:
			m.touch_t = (0.44 - dri * 0.14) * (0.7 if close else 1.0)
			var knock: float = spd * (0.05 + (1.0 - dri) * 0.1) * (1.75 if m.sprinting else 1.0) * (0.45 if close else 1.0)
			m.lead = (0.42 if close else 0.55) + min(1.7, knock)
			m.lead_side = randf_range(-0.14, 0.14) * (1.15 - dri)
			if spd > 1.0 and randf() < 0.5: Sfx.play("touch")
		m.lead = lerpf(m.lead, 0.5 if not close else 0.42, min(1.0, dt * 2.4))
		var fxv = cos(m.face); var fyv = sin(m.face)
		var tx = m.x + fxv * m.lead - fyv * m.lead_side; var ty = m.y + fyv * m.lead + fxv * m.lead_side
		b.x = lerpf(b.x, tx, min(1.0, dt * 16.0)); b.y = lerpf(b.y, ty, min(1.0, dt * 16.0)); b.z = 0.0
		b.vx = m.vx; b.vy = m.vy; b.vz = 0.0
		if m.lead > 1.05 and m.invuln <= 0 and state == "play":
			for o in enemy(m.side).players:
				if o.gk or o.stun > 0 or o.tackle_cool > 0: continue
				if d2(o.x, o.y, b.x, b.y) < 0.95 and randf() < dt * 3.0 * (m.lead - 0.9) * (0.6 + o.defn / 160.0):
					b.owner = null; var a = atan2(b.y - o.y, b.x - o.x) + randf_range(-0.8, 0.8)
					b.vx = cos(a) * 6.0; b.vy = sin(a) * 6.0; b.last = o; m.cool = 0.35; o.tackle_cool = 0.5
					o.label = "Poked away"; o.label_t = 1.0; stats.tackles[si(o.side)] += 1; Sfx.play("tackle")
					break
		return
	if b.z > 0.02 or b.vz > 0:
		b.vz -= G * dt; b.z += b.vz * dt
		b.vx *= exp(-0.12 * dt); b.vy *= exp(-0.12 * dt)
		if b.z <= 0:
			b.z = 0.0
			if b.vz < -2: b.vz = -b.vz * 0.48; b.vx *= 0.82; b.vy *= 0.82
			else: b.vz = 0.0
	else:
		b.vx *= exp(-0.6 * dt); b.vy *= exp(-0.6 * dt)
		if Vector2(b.vx, b.vy).length() < 0.15: b.vx = 0.0; b.vy = 0.0
	if b.spin != 0:
		var v: float = max(0.1, Vector2(b.vx, b.vy).length())
		var px: float = -b.vy / v; var py: float = b.vx / v
		b.vx += px * b.spin * dt; b.vy += py * b.spin * dt; b.spin *= exp(-0.6 * dt)
	b.x += b.vx * dt; b.y += b.vy * dt

func handle_contacts(dt: float) -> void:
	var b = ball
	if b.owner != null:
		for m in all:
			if m.sliding <= 0 or m.side == b.owner.side: continue
			var d = d2(m.x, m.y, b.x, b.y); var dc = d2(m.x, m.y, b.owner.x, b.owner.y)
			if d < 1.4 or dc < 1.0:
				var carrier: MP = b.owner
				var behind: bool = (m.vx * cos(carrier.face) + m.vy * sin(carrier.face)) / max(0.1, Vector2(m.vx, m.vy).length()) > 0.5
				var clean: bool = d < 1.2 and randf() < 0.45 + (m.defn - carrier.dri) / 120.0 + (-0.3 if behind else 0.0)
				stats.tackles[si(m.side)] += 1; Sfx.play("tackle"); m.sliding = 0.0
				if clean: b.owner = null; b.vx = m.vx * 0.9; b.vy = m.vy * 0.9; carrier.stun = 0.6; carrier.cool = 0.5
				elif rules != "nofouls" and (behind or randf() < 0.5): carrier.stun = 0.8; foul(m, carrier, true)
				break
		return
	var best = null; var bd = 1e9
	for m in all:
		if m.cool > 0 or m.stun > 0 or m.dive != null: continue
		if b.shot != null and m.gk: continue
		if b.get("reserve") != null and t < b.reserve.until and m != b.reserve.m and d2(m.x, m.y, b.x, b.y) > 0.65: continue
		var d = d2(m.x, m.y, b.x, b.y)
		var reach: float = 1.4 if m.gk else 0.95 + m.dri / 500.0
		if elite and not m.team.user: reach += 0.55 if m.gk else (0.45 if Data.pos_group.get(m.slot_pos, "") == "DEF" else 0.2)
		if b.z < 1.0 and d < reach:
			var spd = Vector2(b.vx, b.vy).length()
			var c: float = 1.0 if spd < 13 else clamp(1.0 - (spd - 13.0) / 22.0 + m.dri / 250.0, 0.15, 1.0)
			var same: bool = b.last != null and m.side == b.last.side
			var cm: float = (1.0 if same else 0.7) * (1.35 if elite and not m.team.user else 1.0)
			if randf() < c * cm * min(1.0, dt * 60.0) and d < bd: bd = d; best = m
		elif b.z >= 1.0 and b.z < 2.7 and d < 1.15 and not m.gk and not (m.team.user and m == ctrl and (inp.get("shoot", false) or inp.get("pass", false))):
			ai_header(m); return
	if best != null: give_ball(best)
	if b.shot != null and not b.shot_eval: gk_save_check()

func ai_header(m: MP) -> void:
	var team: Dictionary = m.team
	if abs(goal_x(team) - m.x) < 16 and abs(m.y - PH / 2) < 14: shoot(m, 0.5, null, false, "header")
	else:
		var ang = atan2((PH / 2 - m.y) * 0.3, float(team.dir)) + randf_range(-0.6, 0.6)
		kick(m, cos(ang) * 13.0, sin(ang) * 13.0, 4.5, "pass")

func gk_save_check() -> void:
	var b = ball; var sh: Dictionary = b.shot
	var def_t = enemy(sh.side)
	var gk = null
	for x in def_t.players: if x.gk: gk = x
	var gl = own_goal_x(def_t)
	if gk == null or abs(b.vx) < 1 or sign(b.vx) != (1.0 if gl > PW / 2 else -1.0):
		if abs(b.vx) < 1: b.shot_eval = true
		return
	var tt: float = (gl - b.x) / b.vx
	if tt > 0.75 or tt < 0: return
	b.shot_eval = true
	var cy: float = b.y + b.vy * tt; var cz: float = max(0.0, b.z + b.vz * tt - 0.5 * G * tt * tt)
	var on_target: bool = cy > GY0 and cy < GY1 and cz < GOAL_H
	if on_target: stats.sot[si(sh.side)] += 1
	else:
		if randf() < 0.6: Sfx.play("ooh")
		return
	var committed: bool = gk.dive != null and pen_kick
	var gky: float = gk.y + gk.dive.vy * min(tt, gk.dive.t) if committed else gk.y
	var reach = Vector2(abs(cy - gky), max(0.0, cz - 1.6)).length()
	var gkr: float = gk.gkr * (1.0 if def_t.user else 0.95 + ai * 0.1)
	if elite and not def_t.user: gkr = max(gkr, 92.0) * 1.12
	var speed = Vector2(b.vx, b.vy).length()
	var p: float = gkr / 100.0 * 1.15 - reach * 0.17 - (speed - 18.0) * 0.012 + max(0.12, tt) * 0.35
	if reach < 0.8: p += 0.25
	if elite and not def_t.user: p += 0.18 - (0.1 if reach > 2.6 else 0.0)
	if sh.get("chip", false) and abs(gk.x - gl) > 2.5: p *= 0.35
	p = clamp(p, 0.04, 0.95)
	var save = randf() < p
	var dy: float = cy - gk.y
	if committed: pen_kick = false
	elif abs(dy) > 0.6: gk.dive = {"vx": -0.5 if gl > PW / 2 else 0.5, "vy": clamp(dy / max(tt, 0.12), -9.0, 9.0) * (1.0 if save else 0.7), "t": min(0.55, tt + 0.15)}
	else: gk.dive = {"vx": 0.0, "vy": 0.0, "t": 0.35}
	if save: pending_save = {"gk": gk, "t": max(0.12, tt), "catch": speed < 21 and randf() < 0.5 + gkr / 300.0}

func resolve_save(dt: float) -> void:
	if pending_save == null: return
	pending_save.t -= dt
	if pending_save.t > 0.02: return
	var ps: Dictionary = pending_save; pending_save = null
	var b = ball; var gk: MP = ps.gk
	if b.owner != null or b.shot == null: return
	if ps.catch: gk.dive = null; give_ball(gk); msg("Save! " + Data.short_name(gk.p.name), 1.6)
	else:
		b.vx = gk.team.dir * randf_range(4, 10); b.vy = (-1.0 if b.y < PH / 2 else 1.0) * randf_range(4, 11); b.vz = randf_range(1, 4); b.last = gk; b.shot = null; b.spin = 0.0
		msg("Great save by %s!" % Data.short_name(gk.p.name), 1.8)
	Sfx.play("ooh")

func check_goal_and_out(dt: float) -> void:
	resolve_save(dt)
	var b = ball
	for gx in [0.0, PW]:
		if (gx == 0.0 and b.x < 0.3 and b.vx < 0) or (gx == PW and b.x > PW - 0.3 and b.vx > 0):
			var near_post: bool = min(abs(b.y - GY0), abs(b.y - GY1)) < 0.18 and b.z < GOAL_H
			var bar: bool = b.y > GY0 and b.y < GY1 and abs(b.z - GOAL_H) < 0.14
			if near_post or bar:
				b.vx = -b.vx * 0.6
				if bar: b.vz = -abs(b.vz) * 0.5
				b.x = 0.35 if gx == 0.0 else PW - 0.35
				Sfx.play("post"); msg("Off the crossbar!" if bar else "Off the post!", 1.6); b.shot = null; return
	if b.x < 0 or b.x > PW:
		var gx = 0.0 if b.x < 0 else PW
		if b.y > GY0 and b.y < GY1 and b.z < GOAL_H: score_goal(gx); return
		var def_t: Dictionary = teams.home if own_goal_x(teams.home) == gx else teams.away
		var last_side: String = b.last.side if b.last != null else ""
		if last_side == def_t.side:
			pending_sp = {"type": "corner", "side": other(def_t.side), "x": 0.5 if gx == 0.0 else PW - 0.5, "y": 0.5 if b.y < PH / 2 else PH - 0.5}
			stats.corners[si(other(def_t.side))] += 1; msg("Corner", 1.2)
		else:
			pending_sp = {"type": "goalkick", "side": def_t.side, "x": 5.5 if gx == 0.0 else PW - 5.5, "y": PH / 2 - 9 if b.y < PH / 2 else PH / 2 + 9}; msg("Goal kick", 1.2)
		b.shot = null; state = "out"; state_t = 0.0; b.owner = null
		return
	if b.y < 0 or b.y > PH:
		var side: String = other(b.last.side) if b.last != null else "home"
		pending_sp = {"type": "throwin", "side": side, "x": clamp(b.x, 1.0, PW - 1.0), "y": 0.0 if b.y < 0 else PH}
		b.shot = null; state = "out"; state_t = 0.3; b.owner = null; msg("Throw-in", 1.1)

func score_goal(gx: float) -> void:
	var b = ball
	var scoring: Dictionary = teams.home if goal_x(teams.home) == gx else teams.away
	var scorer = b.last
	var og: bool = scorer != null and scorer.side != scoring.side
	if rules == "headers" and not (b.shot != null and b.shot.air) and not og:
		msg("Goal disallowed — headers & volleys only!", 2.4); Sfx.play("whistle")
		pending_sp = {"type": "goalkick", "side": other(scoring.side), "x": 5.5 if gx == 0.0 else PW - 5.5, "y": PH / 2}; state = "out"; state_t = 0.0; b.owner = null; return
	var value = 2 if rules == "longshot" and b.shot != null and b.shot.outside and not og else 1
	score[scoring.side] += value
	var assist = b.prev if not og and b.prev != null and b.prev.side == scoring.side and b.prev != scorer else null
	var mn: int = min(45, int(clock / half_secs * 45.0)) + (half - 1) * 45 + 1
	for i in value:
		goals.append({"side": scoring.side, "pid": scorer.p.id if scorer else "", "name": scorer.p.name if scorer else "Unknown", "pos": scorer.slot_pos if scorer else "", "min": mn, "assist": assist.p.name if assist else "", "og": og})
	last_goal_side = scoring.side; state = "goal"; state_t = 0.0; celebrant = null if og else scorer
	b.vx *= 0.15; b.vy *= 0.15; b.shot = null
	Sfx.play("net"); Sfx.play("goalcrowd"); Sfx.play("whistle"); Sfx.crowd_level(1.0)
	show_banner("Double!" if value == 2 else "Goal!", "%s %d'%s%s" % [Data.short_name(scorer.p.name) if scorer else "", mn, " (OG)" if og else "", (" · assist " + Data.short_name(assist.p.name)) if assist else ""], 3.6)
	fx.append({"type": "confetti", "t": 3.5, "p": null})

func celebrate(dt: float) -> void:
	var c = celebrant
	var corner = Vector2((PW - 2.0 if c.team.dir > 0 else 2.0) if c else PW / 2, 3.0 if c and c.y < PH / 2 else PH - 3.0)
	for m in all:
		m.stun = 0.0
		if c and m == c: steer(m, corner.x, corner.y, true, dt)
		elif c and m.side == c.side and not m.gk: steer(m, corner.x - c.team.dir * (2 + m.slot % 4), corner.y + ((m.slot % 3) - 1) * 2.0, state_t > 0.6, dt)
		else: steer(m, m.x, m.y, false, dt)
	sim_players(dt, false)

func update_ref(dt: float) -> void:
	var b = ball
	var tx: float = b.x - 6.0; var ty: float = b.y + (9.0 if b.y < PH / 2 else -9.0)
	var dv = Vector2(tx - ref.x, ty - ref.y); var d = dv.length()
	var v: float = min(6.0, d * 0.9)
	ref.vx = lerpf(ref.vx, dv.x / d * v if d > 0.1 else 0.0, 0.05); ref.vy = lerpf(ref.vy, dv.y / d * v if d > 0.1 else 0.0, 0.05)
	ref.x += ref.vx * dt; ref.y += ref.vy * dt; ref.ph += Vector2(ref.vx, ref.vy).length() * dt * 1.7

# ------------------------------------------------------------------ set pieces
func start_set_piece(spd: Dictionary) -> void:
	var b = ball; var team: Dictionary = teams[spd.side]; var foe = enemy(spd.side)
	state = "setpiece"; state_t = 0.0; sp = spd; sp.aim = null; sp.user_dive = 0
	b.merge({"x": spd.x, "y": spd.y, "z": 0.0, "vx": 0.0, "vy": 0.0, "vz": 0.0, "owner": null, "shot": null, "spin": 0.0}, true)
	for m in all: m.target = null; m.run = null; m.dive = null; m.sliding = 0.0
	var taker
	if spd.type == "goalkick":
		for x in team.players: if x.gk: taker = x
	elif spd.type == "penalty":
		var srt: Array = team.players.duplicate(); srt.sort_custom(func(a, c): return a.sho > c.sho); taker = srt[0]
	else: taker = nearest(team.players.filter(func(x): return not x.gk), spd.x, spd.y)
	sp.taker = taker
	taker.x = spd.x - (0.0 if spd.type == "throwin" else team.dir * 0.6)
	taker.y = spd.y + ((-0.4 if spd.y < 1 else 0.4) if spd.type == "throwin" else 0.0)
	taker.vx = 0.0; taker.vy = 0.0
	var gx = goal_x(team)
	if spd.type == "corner" or (spd.type == "freekick" and abs(gx - spd.x) < 35):
		var atk: Array = team.players.filter(func(x): return x != taker and not x.gk)
		atk.sort_custom(func(a, c): return a.p.height > c.p.height)
		for i in atk.size():
			var m: MP = atk[i]
			if i < 5:
				m.target = {"x": gx - team.dir * randf_range(4, 12), "y": PH / 2 + (i - 2) * 3.2 + randf_range(-1, 1)}
				m.x = m.target.x; m.y = m.target.y
			else: var h = home_spot(m); m.target = {"x": h.x, "y": h.y}
		var def: Array = foe.players.filter(func(x): return not x.gk)
		for i in def.size():
			var m: MP = def[i]; var mk: MP = atk[i % min(5, atk.size())]
			m.target = {"x": mk.x + team.dir * 0.8, "y": mk.y + 0.6}; m.x = m.target.x; m.y = m.target.y
		if spd.type == "freekick":
			var dv = Vector2(gx - spd.x, PH / 2 - spd.y).normalized()
			for i in 3:
				var m: MP = def[i]
				m.x = spd.x + dv.x * 9.15 + (-dv.y) * (i - 1) * 0.8; m.y = spd.y + dv.y * 9.15 + dv.x * (i - 1) * 0.8
				m.target = {"x": m.x, "y": m.y}
	elif spd.type == "penalty":
		for m in all:
			if m == taker or m.gk: continue
			m.x = clamp(gx - team.dir * randf_range(18, 24), 1.0, PW - 1.0); m.y = PH / 2 + randf_range(-18, 18); m.target = {"x": m.x, "y": m.y}
		for x in foe.players: if x.gk: x.x = gx - team.dir * 0.3; x.y = PH / 2
		taker.x = spd.x - team.dir * 1.2; taker.y = PH / 2
	else:
		for m in all:
			if m != taker: var h = home_spot(m); m.target = {"x": h.x, "y": h.y}
		if spd.type == "throwin" or spd.type == "freekick":
			var near: Array = team.players.filter(func(x): return x != taker and not x.gk)
			near.sort_custom(func(a, c): return d2(a.x, a.y, spd.x, spd.y) < d2(c.x, c.y, spd.x, spd.y))
			for i in min(2, near.size()):
				near[i].target = {"x": clamp(spd.x + (-1 if i else 1) * 7.0 + team.dir * 3.0, 2.0, PW - 2.0), "y": clamp(spd.y + (1.0 if spd.y < PH / 2 else -1.0) * (6.0 + i * 5.0), 2.0, PH - 2.0)}
	b.x = spd.x; b.y = spd.y
	if team.user: switch_to(taker)
	if spd.type == "goalkick": give_ball(taker)
	var names = {"corner": "Corner kick", "throwin": "Throw-in", "goalkick": "Goal kick", "freekick": "Free kick", "penalty": "Penalty kick"}
	if team.user and spd.type != "goalkick":
		var hint = "aim with ↑/↓, hold K to shoot" if spd.type == "penalty" else ("J pass · L cross · K shoot" if spd.type == "freekick" and abs(gx - spd.x) < 32 else ("aim, then L to cross or J short" if spd.type == "corner" else "aim and press J / L"))
		msg("%s — %s" % [names[spd.type], hint], 3.2)
	elif foe.user and spd.type == "penalty": msg("Penalty against you — hold ↑ or ↓ to choose your dive", 3.0)

func update_set_piece(dt: float) -> void:
	var b = ball; var team: Dictionary = teams[sp.side]; var taker: MP = sp.taker
	if sp.type != "goalkick": b.owner = null; b.x = sp.x; b.y = sp.y; b.z = 0.0; b.vx = 0.0; b.vy = 0.0
	taker.vx = 0.0; taker.vy = 0.0; taker.sp_move = true
	var gx = goal_x(team)
	taker.face = atan2(PH / 2 - taker.y, gx - taker.x)
	if sp.type == "throwin": taker.face = atan2(PH / 2 - sp.y, team.dir * 2.0)
	ref.x = lerpf(ref.x, sp.x - 8.0, 0.02); ref.y = lerpf(ref.y, clamp(sp.y, 8.0, PH - 8.0), 0.02)
	var user_taking: bool = team.user and ctrl == taker
	var user_def_pen: bool = sp.type == "penalty" and enemy(sp.side).user
	if state_t < 0.8: return
	var ix: float = inp.get("x", 0.0); var iy: float = inp.get("y", 0.0)
	if user_taking:
		var mag = Vector2(ix, iy).length()
		var ax: float = ix / mag if mag > 0.2 else cos(taker.face); var ay: float = iy / mag if mag > 0.2 else sin(taker.face)
		sp.aim = {"x": ax, "y": ay}
		if sp.type == "penalty" or (sp.type == "freekick" and abs(gx - sp.x) < 32):
			if inp.get("shoot", false) or inp.get("finesse", false): charge = min(1.0, charge + dt * 1.1); charge_kind = "finesse" if inp.get("finesse", false) else "shot"
			if rel.get("shoot", false) or rel.get("finesse", false):
				var aim: float
				if abs(iy) > 0.3: aim = GY0 + 0.7 if iy < 0 else GY1 - 0.7
				elif sp.type == "penalty": aim = PH / 2 + randf_range(-0.8, 0.8)
				else: aim = GY0 + 1.0 if sp.y < PH / 2 else GY1 - 1.0
				var pw = charge; var fin = charge_kind == "finesse"; charge = 0.0; charge_kind = ""
				var is_pen: bool = sp.type == "penalty"
				b.owner = taker; shoot(taker, min(pw, 0.85) if is_pen else pw, aim, fin)
				if is_pen: penalty_keeper()
				finish_sp(); return
		if edge.get("pass", false) or edge.get("lob", false) or edge.get("through", false):
			var kind = ("cross" if sp.type == "corner" or in_cross_zone(taker) else "lob") if edge.get("lob", false) else ("through" if edge.get("through", false) else "ground")
			var tgt = pick_pass_target(taker, ax, ay, kind)
			if tgt == null: tgt = nearest(team.players.filter(func(x): return x != taker and not x.gk), sp.x, sp.y)
			b.owner = taker
			if sp.type == "throwin": throw_in(taker, tgt, kind)
			else: pass_to(taker, tgt, kind)
			finish_sp(); return
		if sp.type == "goalkick" and state_t > 6:
			var tgt = nearest(team.players.filter(func(x): return not x.gk), taker.x + team.dir * 30, PH / 2)
			pass_to(taker, tgt, "lob"); finish_sp()
		return
	if user_def_pen: sp.user_dive = sign(iy) if abs(iy) > 0.3 else 0
	if state_t < (2.2 if sp.type == "penalty" else 1.4): return
	b.owner = taker
	var mates: Array = team.players.filter(func(x): return x != taker and not x.gk)
	match sp.type:
		"goalkick":
			var tgt = nearest(mates, taker.x + team.dir * 18, Sys.pick([12.0, PH - 12])) if randf() < 0.5 else nearest(mates, taker.x + team.dir * 40, PH / 2)
			pass_to(taker, tgt, "lob" if d2(tgt.x, tgt.y, taker.x, taker.y) > 26 else "ground")
		"penalty":
			var s: int = Sys.pick([-1, 0, 1])
			var aim = PH / 2 + randf_range(-0.6, 0.6) if s == 0 else (GY0 + randf_range(0.5, 1.2) if s < 0 else GY1 - randf_range(0.5, 1.2))
			shoot(taker, randf_range(0.5, 0.78), aim, false); penalty_keeper()
		"corner":
			var srt: Array = mates.duplicate(); srt.sort_custom(func(a, c): return d2(a.x, a.y, gx, PH / 2) < d2(c.x, c.y, gx, PH / 2))
			pass_to(taker, srt[Sys.rint(0, min(2, srt.size() - 1))], "cross" if randf() < 0.85 else "ground")
		_:
			if sp.type == "freekick" and abs(gx - sp.x) < 28 and randf() < 0.6:
				shoot(taker, randf_range(0.55, 0.8), GY0 + 0.8 if randf() < 0.5 else GY1 - 0.8, true)
			else:
				var tgt = nearest(mates, sp.x + team.dir * 8, sp.y)
				if sp.type == "throwin": throw_in(taker, tgt, "ground")
				else: pass_to(taker, tgt, "lob" if d2(tgt.x, tgt.y, taker.x, taker.y) > 26 else "ground")
	finish_sp()

func finish_sp() -> void:
	sp.taker.sp_move = false
	for m in all: m.target = null
	state = "play"; state_t = 0.0; sp = null

func throw_in(m: MP, tgt: MP, kind: String) -> void:
	var b = ball; var dv = Vector2(tgt.x - b.x, tgt.y - b.y); var d: float = max(0.1, dv.length())
	var v: float = clamp(6.0 + d * 0.5, 7.0, 17.0 if kind == "lob" else 13.0)
	b.z = 1.8; kick(m, dv.x / d * v, dv.y / d * v, 2.5, "pass"); stats.passes[si(m.side)] += 1

func penalty_keeper() -> void:
	var def_t = enemy(sp.side); var gk = null
	for x in def_t.players: if x.gk: gk = x
	if gk == null: return
	var dir: int = sp.user_dive if def_t.user else Sys.weighted([[4, -1], [2, 0], [4, 1]])
	gk.dive = {"vx": 0.0, "vy": dir * 7.5, "t": 0.42}
	pen_kick = true; ball.shot_eval = false

# ------------------------------------------------------------------ result
func result() -> Dictionary:
	var tot: float = max(0.01, stats.poss[0] + stats.poss[1])
	var hp = int(round(stats.poss[0] / tot * 100.0))
	var st = stats.duplicate(true); st.poss = [hp, 100 - hp]
	var winner = "home" if score.home > score.away else ("away" if score.away > score.home else "")
	var pens = null
	if winner == "" and cfg.get("knockout", false):
		var H = _shooters(teams.home); var A = _shooters(teams.away)
		var gh = _gk_of(teams.home); var ga = _gk_of(teams.away)
		var h = 0; var a = 0; var i = 0
		while i < 5: h += int(_take(H, ga)); a += int(_take(A, gh)); i += 1
		while h == a and i < 20: h += int(_take(H, ga)); a += int(_take(A, gh)); i += 1
		if h == a: h += 1
		pens = [h, a]; winner = "home" if h > a else "away"
	return {"home": cfg.home, "away": cfg.away, "hg": score.home, "ag": score.away, "goals": goals, "stats": st, "winner": winner, "pens": pens, "user_side": user_side, "mode": cfg.get("mode", "")}

func _gk_of(tm: Dictionary) -> MP:
	for x in tm.players: if x.gk: return x
	return tm.players[0]
func _shooters(tm: Dictionary) -> Array:
	var a: Array = tm.players.filter(func(x): return not x.gk)
	a.sort_custom(func(p, q): return p.sho > q.sho)
	return a.slice(0, 5)
func _take(sh: Array, gk: MP) -> bool:
	var s: MP = Sys.pick(sh)
	return randf() < clamp(0.72 + (s.sho - max(40.0, gk.gkr)) / 200.0, 0.5, 0.92)

func simulate_rest() -> void:
	var remain: float = (1.0 + (1.0 - clock / half_secs)) if half == 1 else max(0.0, 1.0 - clock / half_secs)
	var frac = remain / 2.0
	var H = Sys.team_strength(teams.home.formation, teams.home.players.map(func(m): return m.p))
	var A = Sys.team_strength(teams.away.formation, teams.away.players.map(func(m): return m.p))
	var diff: float = ((H.att * 0.4 + H.mid * 0.35 + H.def * 0.25) - (A.att * 0.4 + A.mid * 0.35 + A.def * 0.25)) / 10.0
	var base_min = int((half - 1) * 45 + clock / half_secs * 45)
	for side in ["home", "away"]:
		var l: float = clamp((1.35 + diff * 0.9) if side == "home" else (1.15 - diff * 0.9), 0.2, 4.0) * frac
		var n = Sys._pois(l)
		for i in n:
			var m: MP = Sys.weighted(teams[side].players.map(func(x): return [{"ATT": 6.0, "MID": 3.0, "DEF": 1.0, "GK": 0.01}[Data.pos_group[x.slot_pos]], x]))
			goals.append({"side": side, "pid": m.p.id, "name": m.p.name, "pos": m.slot_pos, "min": Sys.rint(min(90, base_min + 1), 90), "assist": "", "og": false})
			score[side] += 1
		stats.shots[si(side)] += n * 2 + Sys.rint(0, 3); stats.sot[si(side)] += n
	goals.sort_custom(func(a, b): return a.min < b.min)
	finished = true; ended.emit()
