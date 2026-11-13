extends Node
## EVOLUTIONS — permanent player upgrades. Pick an Evolution, put an eligible player in it,
## then play Ultimate XI matches with him in your starting XI to level him up.
## Evolved players use ids "ev_<evo>_<level>_<source id>" and are generated on demand.

signal changed

const SLOTS := 3
const ATT := ["ST", "CF", "LW", "RW", "CAM", "LM", "RM"]
const MID := ["CM", "CAM", "CDM", "LM", "RM"]
const DEF := ["CB", "LB", "RB", "CDM", "LWB", "RWB"]

## stats order: PAC SHO PAS DRI DEF PHY (GK: DIV HAN KIC REF SPD POS)
const CATALOG := [
	{"id": "pace", "name": "Pace Merchant", "desc": "Turn a quick player into a rocket.", "cost": {}, "xp": 300, "cap": 83,
		"req": {"max_ovr": 80, "not_pos": ["GK"], "stat_max": [0, 86], "types": ["base"]},
		"levels": [{"ovr": 1, "s": [3, 0, 0, 1, 0, 0]}, {"ovr": 1, "s": [2, 0, 0, 2, 0, 0]}, {"ovr": 1, "s": [2, 1, 0, 1, 0, 1]}], "final": {"sm": 1}},
	{"id": "finisher", "name": "Clinical Finisher", "desc": "Sharpen an attacker's shooting.", "cost": {"coins": 8000}, "xp": 300, "cap": 85,
		"req": {"max_ovr": 82, "pos": ATT, "types": ["base"]},
		"levels": [{"ovr": 1, "s": [0, 3, 0, 1, 0, 0]}, {"ovr": 1, "s": [0, 2, 0, 1, 0, 1]}, {"ovr": 1, "s": [1, 2, 1, 0, 0, 0]}], "final": {"wf": 1}},
	{"id": "maestro", "name": "Midfield Maestro", "desc": "Better passing and ball control for a midfielder.", "cost": {"coins": 8000}, "xp": 300, "cap": 85,
		"req": {"max_ovr": 82, "pos": MID, "types": ["base"]},
		"levels": [{"ovr": 1, "s": [0, 0, 3, 1, 0, 0]}, {"ovr": 1, "s": [0, 1, 2, 2, 0, 0]}, {"ovr": 1, "s": [1, 0, 1, 1, 1, 1]}], "final": {"sm": 1}},
	{"id": "wall", "name": "The Wall", "desc": "A stronger, smarter defender.", "cost": {"coins": 8000}, "xp": 300, "cap": 85,
		"req": {"max_ovr": 82, "pos": DEF, "types": ["base"]},
		"levels": [{"ovr": 1, "s": [0, 0, 0, 0, 3, 1]}, {"ovr": 1, "s": [1, 0, 0, 0, 2, 2]}, {"ovr": 1, "s": [1, 0, 1, 0, 2, 1]}], "final": {}},
	{"id": "gk", "name": "Safe Hands", "desc": "Reflexes and positioning for a goalkeeper.", "cost": {}, "xp": 300, "cap": 85,
		"req": {"max_ovr": 83, "pos": ["GK"], "types": ["base"]},
		"levels": [{"ovr": 1, "s": [2, 1, 0, 2, 0, 1]}, {"ovr": 1, "s": [1, 1, 0, 2, 0, 2]}, {"ovr": 1, "s": [2, 1, 1, 1, 0, 1]}], "final": {}},
	{"id": "goldrush", "name": "Gold Rush", "desc": "Upgrade a bronze or silver player all the way to gold.", "cost": {"coins": 15000}, "xp": 250, "cap": 80,
		"req": {"max_ovr": 74, "types": ["base"]},
		"levels": [{"ovr": 2, "s": [2, 2, 2, 2, 2, 2]}, {"ovr": 2, "s": [2, 2, 2, 2, 2, 2]}, {"ovr": 2, "s": [2, 2, 2, 2, 2, 2]}], "final": {"rare": true}},
	{"id": "elite", "name": "Elite Upgrade", "desc": "Push a top player even higher. Long and expensive.", "cost": {"points": 1000}, "xp": 450, "cap": 90,
		"req": {"min_ovr": 84, "max_ovr": 87, "types": ["base"]},
		"levels": [{"ovr": 1, "key": 2}, {"ovr": 1, "key": 1}, {"ovr": 1, "key": 2}, {"ovr": 1, "key": 1}], "final": {"sm": 1, "wf": 1}}]

func spec(id: String) -> Dictionary:
	for e in CATALOG: if e.id == id: return e
	return {}

# ------------------------------------------------------------------ state
func st() -> Dictionary:
	var d = Save.data
	if d == null: return {}
	if typeof(d.get("evos")) != TYPE_DICTIONARY: d.evos = {"active": [], "done": []}
	return d.evos

func busy(uid: String) -> bool:
	if st().active.any(func(e): return e.uid == uid): return true
	return Event.st().evos.any(func(e): return e.uid == uid)

func used(evo_id: String, base: String) -> bool:
	return st().done.any(func(d): return d.evo == evo_id and d.base == base) or st().active.any(func(e): return e.evo == evo_id and e.base == base)

func eligible(evo: Dictionary, it: Dictionary) -> bool:
	var p = Data.P(it.pid)
	if p.is_empty() or busy(it.uid) or Sys.in_market(it.uid): return false
	var base: String = p.get("base", p.id)
	if used(evo.id, base): return false
	var r: Dictionary = evo.req
	if r.has("types") and not (r.types as Array).has(p.type): return false
	if r.has("max_ovr") and p.ovr > int(r.max_ovr): return false
	if r.has("min_ovr") and p.ovr < int(r.min_ovr): return false
	if r.has("pos") and not (r.pos as Array).has(p.pos): return false
	if r.has("not_pos") and (r.not_pos as Array).has(p.pos): return false
	if r.has("stat_max") and int(p.stats[int(r.stat_max[0])]) > int(r.stat_max[1]): return false
	return true

func eligible_items(evo: Dictionary) -> Array: return Save.data.club.filter(func(it): return eligible(evo, it))

func req_text(evo: Dictionary) -> Array:
	var r: Dictionary = evo.req; var out = []
	if r.has("min_ovr") and r.has("max_ovr"): out.append("Overall %d–%d" % [r.min_ovr, r.max_ovr])
	elif r.has("max_ovr"): out.append("Overall %d or lower" % r.max_ovr)
	if r.has("pos"): out.append("Position: " + ", ".join(r.pos))
	if r.has("not_pos"): out.append("Not a " + ", ".join(r.not_pos))
	if r.has("stat_max"): out.append("%s %d or lower" % [Data.STAT_LABELS[int(r.stat_max[0])], r.stat_max[1]])
	out.append("Regular (non-special) cards only")
	return out

func cost_text(evo: Dictionary) -> String:
	var c: Dictionary = evo.cost
	if c.get("coins", 0): return "● " + Sys.fmt(c.coins)
	if c.get("points", 0): return "◆ " + Sys.fmt(c.points)
	return "Free"

func total_ovr(evo: Dictionary) -> int:
	var t = 0
	for l in evo.levels: t += int(l.ovr)
	return t

# ------------------------------------------------------------------ evolved player generation
func ev_id(evo: String, lvl: int, src: String) -> String: return "ev_%s_%d_%s" % [evo, lvl, src]

func ensure(id: String) -> Dictionary:
	if Data.by_id.has(id): return Data.by_id[id]
	var parts = id.split("_", true, 3)
	if parts.size() < 4 or parts[0] != "ev": return {}
	var evo = spec(parts[1]); var lvl = int(parts[2]); var src: String = parts[3]
	var b: Dictionary = Data.P(src)
	if evo.is_empty() or b.is_empty(): return {}
	var p: Dictionary = b.duplicate(true)
	p.id = id; p.base = b.get("base", src); p.evo_name = evo.name
	var key = _key_stats(b)
	var add_ovr = 0; var adds = [0, 0, 0, 0, 0, 0]
	for i in min(lvl, evo.levels.size()):
		var L: Dictionary = evo.levels[i]
		add_ovr += int(L.ovr)
		if L.has("s"):
			for k in 6: adds[k] += int(L.s[k])
		if L.has("key"):
			for k in key: adds[k] += int(L.key)
	p.ovr = min(max(int(b.ovr), int(evo.cap)), int(b.ovr) + add_ovr)
	var stt = []
	for k in 6: stt.append(min(99, int(b.stats[k]) + adds[k]))
	p.stats = stt
	if lvl >= evo.levels.size():
		var fin: Dictionary = evo.final
		if fin.has("sm"): p.sm = min(5, int(b.sm) + int(fin.sm))
		if fin.has("wf"): p.wf = min(5, int(b.wf) + int(fin.wf))
		if fin.get("rare", false): p.rare = true
	Data.by_id[id] = p
	return p

func _key_stats(b: Dictionary) -> Array:
	if b.pos == "GK": return [0, 3, 5]
	if DEF.has(b.pos) and b.pos != "CDM": return [0, 4, 5]
	if MID.has(b.pos) and b.pos != "CAM": return [2, 3, 4]
	return [0, 1, 3]

func preview(evo: Dictionary, src: String, lvl: int) -> Dictionary: return ensure(ev_id(evo.id, lvl, src))

# ------------------------------------------------------------------ actions
func start(evo: Dictionary, uid: String) -> bool:
	var it = Sys.item(uid)
	if it.is_empty() or not eligible(evo, it): return false
	if st().active.size() >= SLOTS: Sys.toast.emit("All %d Evolution slots are in use" % SLOTS, "bad"); return false
	var c: Dictionary = evo.cost
	if c.get("coins", 0) and not Sys.spend("coins", int(c.coins), "Evolution: " + evo.name, "evo"): return false
	if c.get("points", 0) and not Sys.spend("points", int(c.points), "Evolution: " + evo.name, "evo"): return false
	var p = Data.P(it.pid)
	st().active.append({"uid": uid, "evo": evo.id, "src": it.pid, "base": p.get("base", p.id), "lvl": 0, "xp": 0})
	it.untr = true
	Sys.history("Started Evolution %s: %s" % [evo.name, p.name])
	Save.dirty(); changed.emit(); return true

func cancel(uid: String) -> void:
	st().active = st().active.filter(func(e): return e.uid != uid); Save.dirty(); changed.emit()

func in_xi(uid: String) -> bool:
	var sq = Sys.active_squad()
	return sq != null and not sq.is_empty() and (sq.slots as Array).has(uid)

func after_match(res: Dictionary, r: String, ga: int) -> void:
	if st().is_empty(): return
	var u_side: String = res.get("user_side", "home")
	if u_side == "": u_side = "home"
	var finished = []
	for e in st().active:
		if not in_xi(e.uid): continue
		var it = Sys.item(e.uid)
		if it.is_empty(): finished.append(e); continue
		var evo = spec(e.evo); var p = Data.P(it.pid)
		var gain = 100 + (60 if r == "W" else (25 if r == "D" else 0))
		for g in res.goals:
			if g.side != u_side: continue
			if g.get("pid", "") == it.pid: gain += 40
			if g.get("assist", "") == p.name: gain += 30
		if ga == 0 and (p.pos == "GK" or DEF.has(p.pos)): gain += 40
		e.xp = int(e.xp) + gain
		while int(e.xp) >= int(evo.xp) and int(e.lvl) < evo.levels.size():
			e.xp = int(e.xp) - int(evo.xp); e.lvl = int(e.lvl) + 1
			var np = ensure(ev_id(evo.id, e.lvl, e.src))
			it.pid = np.id
			Gallery.record(np.id, "reward", true)
			Sys.toast.emit("%s · %s reached Level %d — now %d OVR" % [evo.name, Data.short_name(np.name), e.lvl, np.ovr], "good")
		if int(e.lvl) >= evo.levels.size():
			finished.append(e)
			st().done.append({"evo": e.evo, "base": e.base, "pid": it.pid, "t": Sys.now()})
			Sys.history("Completed Evolution %s: %s" % [evo.name, Data.P(it.pid).name])
	for e in finished: st().active.erase(e)
	Save.dirty(); changed.emit()
