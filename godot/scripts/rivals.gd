extends Node
## DIVISION RIVALS (FC-style)
## • Each division has 12 ranks (I–XII). Win = +1 rank (+2 on a 3+ win streak), draw = 0, loss = −1.
## • Checkpoints at ranks IV and VIII: once reached, losses can't drop you below them.
## • Reach XII to be promoted. Losing at rank 0 relegates — except in safe divisions (10, 7, 4).
## • Rivals rewards every 15 minutes: earn points in the current window (win 3 · draw 1),
##   reach reward level 1 / 2 / 3 (1 / 3 / 6 pts). Better division = better rewards.
## • Every result also earns Champions Qualification Points.

signal changed

const STEPS := 12
const CHECKPOINTS := [4, 8]
const SAFE_DIVS := [10, 7, 4]
const CYCLE := 900.0
const LEVEL_PTS := [1, 3, 6]
const ROMAN := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]

var _t = 0.0

func st() -> Dictionary:
	var d = Save.data
	if d == null: return {}
	var r: Dictionary = d.modes.rivals
	for kv in [["step", 0], ["cp", 0], ["streak", 0], ["cycle", {"id": cycle_id(), "pts": 0, "div": int(r.get("div", 10))}], ["unclaimed", []], ["draws", 0], ["losses", 0]]:
		if not r.has(kv[0]): r[kv[0]] = kv[1]
	return r

func cycle_id() -> int: return int(floor(Sys.now() / CYCLE))
func cycle_left() -> float: return (cycle_id() + 1) * CYCLE - Sys.now()
func div() -> int: return int(st().div)
func div_name(d: int) -> String: return "Elite" if d == 1 else "Division %d" % d
## every division has its own colour: bronze → copper → silver → green → teal → blue → purple → pink → red → Elite gold
const DIV_COLORS := {10: "#b07a4a", 9: "#d8743a", 8: "#b8c2cc", 7: "#3fcf6a", 6: "#20c9b8", 5: "#2f8dff", 4: "#8f5bff", 3: "#e04fc8", 2: "#ff3d4f", 1: "#ffc93c"}
func div_color(d: int) -> Color: return Color(DIV_COLORS.get(clamp(d, 1, 10), "#ff7a1a"))
func safe(d: int) -> bool: return SAFE_DIVS.has(d)

func level_for(pts: int) -> int:
	var l = 0
	for i in LEVEL_PTS.size(): if pts >= LEVEL_PTS[i]: l = i + 1
	return l

## reward for a division (10 … 1=Elite) and level (1–3)
func reward(d: int, lvl: int) -> Dictionary:
	var t: int = 11 - d   # 1 (Div 10) … 10 (Elite)
	if lvl <= 0: return {}
	var r = {"coins": 150 * t * lvl}
	if lvl >= 2: r.pack = "gold" if t <= 3 else ("premium" if t <= 6 else ("rare" if t <= 9 else "mega"))
	if lvl >= 3:
		r.packs = ["premium" if t <= 3 else ("rare" if t <= 6 else ("mega" if t <= 9 else "pp83x2"))]
		r.points = 10 * t
	return r

func reward_text(r: Dictionary) -> String:
	var parts = []
	if r.get("coins", 0): parts.append("%s Coins" % Sys.fmt(r.coins))
	if r.has("pack"): parts.append("1x " + Data.packs[r.pack].name)
	for p in r.get("packs", []): parts.append("1x " + Data.packs[p].name)
	if r.get("points", 0): parts.append("%d Prime Points" % r.points)
	return "\n".join(parts) if not parts.is_empty() else "—"

func _process(delta: float) -> void:
	if Save.data == null: return
	_t += delta
	if _t < 1.0: return
	_t = 0.0
	tick()

## close the 15-minute window: bank its rewards
func tick() -> void:
	var r = st()
	if int(r.cycle.id) == cycle_id(): return
	var lvl = level_for(int(r.cycle.pts))
	if lvl > 0:
		r.unclaimed.append({"div": int(r.cycle.div), "lvl": lvl, "pts": int(r.cycle.pts), "reward": reward(int(r.cycle.div), lvl)})
		Sys.toast.emit("Division Rivals rewards are ready! (Level %d)" % lvl, "good")
	r.cycle = {"id": cycle_id(), "pts": 0, "div": div()}
	Save.dirty(); changed.emit()

func claim_all() -> int:
	var r = st(); var n = 0
	for u in r.unclaimed:
		var rw: Dictionary = u.reward.duplicate(true)
		if rw.has("packs"):
			for p in rw.packs: Save.data.unopened.append(p)
			rw.erase("packs")
		Sys.grant(rw, "Rivals rewards (%s · level %d)" % [div_name(int(u.div)), int(u.lvl)])
		n += 1
	r.unclaimed = []
	Save.dirty(); changed.emit(); return n

func record(result: String) -> Dictionary:
	var r = st(); tick()
	r.played += 1
	var d = div()
	var msg = []
	var coins: int = {"W": 900, "D": 450, "L": 200}[result] + (11 - d) * 60
	Sys.add("coins", coins, "Division Rivals match")
	var moved = 0
	match result:
		"W":
			r.wins += 1; r.streak = int(r.streak) + 1; r.week_wins = int(r.get("week_wins", 0)) + 1
			moved = 2 if int(r.streak) >= 3 else 1
			r.step = int(r.step) + moved; r.cycle.pts = int(r.cycle.pts) + 3
			Sys.track("rivals_win")
			if moved == 2: msg.append("Win streak bonus: +2 ranks")
		"D":
			r.streak = 0; r.draws = int(r.draws) + 1; r.cycle.pts = int(r.cycle.pts) + 1
		_:
			r.streak = 0; r.losses = int(r.losses) + 1
			if int(r.step) == 0 and int(r.cp) == 0 and not safe(d) and d < 10:
				r.div = d + 1; r.step = 8; r.cp = 8
				msg.append("Relegated to " + div_name(d + 1))
			else:
				var before = int(r.step)
				r.step = max(int(r.cp), before - 1); moved = r.step - before
				if before > 0 and r.step == before: msg.append("Checkpoint saved your rank")
	for c in CHECKPOINTS:
		if int(r.step) >= c and int(r.cp) < c: r.cp = c; msg.append("Checkpoint reached (%s)" % ROMAN[c - 1])
	if int(r.step) >= STEPS:
		if d > 1:
			r.div = d - 1; r.step = 0; r.cp = 0
			msg.append("Promoted to " + div_name(d - 1) + "!")
			Sys.grant({"pack": "jumbo" if d - 1 <= 3 else "premium", "points": 50}, "Rivals promotion")
			r.best = min(int(r.best), d - 1); Sys.history("Promoted to " + div_name(d - 1))
		else:
			r.step = STEPS; msg.append("Elite rank maxed")
	var qp = Champs.add_qp(result)
	if qp > 0: msg.append("+%d Champions Qual. Points (%d/%d)" % [qp, int(Champs.st().qp), Champs.QP_NEED])
	Save.dirty(); changed.emit()
	return {"coins": coins, "msg": " · ".join(msg), "moved": moved}
