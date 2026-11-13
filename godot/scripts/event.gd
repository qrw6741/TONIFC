extends Node
## RISING STARS event — boosted cards for the best real young players in the top 5 leagues,
## a Next Gen Evolution you level up by playing, event objectives & SBCs, and Star Tokens.

signal changed

const NAME := "Rising Stars"
const ID := "rs1"
const MAX_EVOS := 2
const EVO_LEVELS := 5
const EVO_XP := 300

## [base id, real age, boost]
const STARS := [
	["p443", 19, 4], ["p430", 19, 5], ["p1524", 21, 4], ["p850", 21, 5], ["p418", 21, 5], ["p1520", 20, 5],
	["p406", 21, 5], ["p272", 21, 6], ["p132", 19, 7], ["p426", 20, 9], ["p423", 19, 8], ["p21", 20, 7],
	["p20", 19, 9], ["p263", 20, 6], ["p1600", 21, 6], ["p1192", 18, 11]]
## extra real young players (eligible for the Next Gen Evolution) with corrected ages
const YOUNG := [["p245", 21], ["p353", 20], ["p1518", 22], ["p1228", 21], ["p122", 20], ["p1246", 20], ["p1528", 18], ["p1521", 20], ["p815", 21], ["p362", 20], ["p133", 22], ["p439", 22], ["p441", 23]]

var stars = []          # Rising Stars player dicts
var young_ids = {}      # base pid -> true (eligible for evolution)

func _ready() -> void:
	Data.card_types["rising"] = {"name": "Rising Stars", "order": 4}
	Data.tier_label["rising"] = "Rising Stars"
	for a in YOUNG:
		var b = Data.by_id.get(a[0], {})
		if not b.is_empty(): b.age = a[1]; young_ids[a[0]] = true
	for a in STARS:
		var b: Dictionary = Data.by_id.get(a[0], {})
		if b.is_empty(): continue
		b.age = a[1]; young_ids[a[0]] = true
		var p: Dictionary = b.duplicate(true)
		var boost: int = a[2]
		p.id = "rs_" + a[0]; p.base = a[0]; p.type = "rising"; p.rare = true
		p.ovr = min(95, int(b.ovr) + boost)
		var st = []
		for i in 6:
			var v: int = int(b.stats[i])
			st.append(min(99, v + boost + (1 if v >= 75 else -1)))
		p.stats = st; p.sm = min(5, int(b.sm) + 1)
		Data.players.append(p); Data.by_id[p.id] = p; Data.by_club[p.club].append(p)
		stars.append(p)
	stars.sort_custom(func(x, y): return x.ovr > y.ovr)
	# packs
	Data.packs["rspack"] = {"name": "Rising Stars Pack", "items": 6, "coins": 0, "points": 1500, "art": "rising", "guar": [["rising", 1], ["gold-rare", 5]], "w": {"gold-rare": 100}, "desc": "6 Rare Gold. 1 Rising Stars card guaranteed.", "promo": true}
	Data.packs["rspick"] = {"name": "Rising Stars Player Pick", "items": 1, "coins": 0, "points": 0, "art": "rising", "guar": [["rising", 1]], "w": {"rising": 1}, "desc": "Choose 1 of 3 Rising Stars cards.", "reward": true, "pick": {"n": 3, "tier": "rising"}}
	if not Data.pack_order.has("rspack"): Data.pack_order.insert(Data.pack_order.find("nightfall") + 1 if Data.pack_order.has("nightfall") else Data.pack_order.size(), "rspack")
	for id in ["premium", "jumbo", "rare", "mega", "ultimate"]:
		if Data.packs.has(id): Data.packs[id].w["rising"] = {"premium": 0.3, "jumbo": 0.3, "rare": 0.8, "mega": 0.35, "ultimate": 2.0}[id]
	# objectives (tracked by the normal objective system)
	var O = [
		["rs_o1", "Rising Up", "Play 3 Ultimate XI matches", "match", 3, {"coins": 2000, "tokens": 50}],
		["rs_o2", "Young Guns", "Win 5 Ultimate XI matches", "win", 5, {"tokens": 100}],
		["rs_o3", "Goal Machine", "Score 12 goals in Ultimate XI", "goal", 12, {"tokens": 100}],
		["rs_o4", "Next Gen XI", "Play 5 matches with a Rising Star or young star in your starting XI", "rs_play", 5, {"tokens": 150}],
		["rs_o5", "Evolve", "Level up a Next Gen Evolution 3 times", "rs_evo", 3, {"tokens": 150}],
		["rs_o6", "Building Blocks", "Complete 2 SBCs", "sbc", 2, {"tokens": 75}],
		["rs_o7", "Rivals Rising", "Win 3 Division Rivals matches", "rivals_win", 3, {"tokens": 150, "pack": "premium"}]]
	for o in O:
		Data.objectives.append({"id": o[0], "cat": "event", "title": o[1], "desc": o[2], "ev": o[3], "target": o[4], "reward": o[5]})
	# SBCs
	Data.sbcs.append({"id": "rs_s1", "cat": "Rising Stars", "name": "RS Estêvão", "desc": "Earn Rising Stars Estêvão.", "size": 11, "repeat": 1, "reqs": [{"t": "rating", "v": 82}, {"t": "chem", "v": 24}], "reward": {"player": "rs_p132"}})
	Data.sbcs.append({"id": "rs_s2", "cat": "Rising Stars", "name": "RS Arda Güler", "desc": "Earn Rising Stars Arda Güler.", "size": 11, "repeat": 1, "reqs": [{"t": "rating", "v": 84}, {"t": "chem", "v": 27}, {"t": "special", "n": 1}], "reward": {"player": "rs_p418"}})
	Data.sbcs.append({"id": "rs_s3", "cat": "Rising Stars", "name": "Rising Stars Upgrade", "desc": "A squad of 80+ for a Rising Stars Pack and 100 Star Tokens.", "size": 11, "repeat": 3, "reqs": [{"t": "rating", "v": 80}, {"t": "chem", "v": 20}], "reward": {"pack": "rspack", "tokens": 100}})

# ------------------------------------------------------------------ state
func st() -> Dictionary:
	var d = Save.data
	if d == null: return {}
	if typeof(d.get("event")) != TYPE_DICTIONARY or d.event.get("id", "") != ID:
		d.event = {"id": ID, "tokens": 0, "evos": [], "evolved": {}, "bought": {}, "final": false}
	return d.event
func tokens() -> int: return int(st().tokens)
func add_tokens(n: int, why := "") -> void:
	if n <= 0 or st().is_empty(): return
	st().tokens = tokens() + n
	Sys.toast.emit("+%d Star Tokens%s" % [n, (" · " + why) if why != "" else ""], "good")
	Save.dirty(); changed.emit()

func objectives() -> Array: return Data.objectives.filter(func(o): return o.cat == "event")
func all_objectives_done() -> bool: return objectives().all(func(o): return Sys.obj_claimed(o))
func final_reward() -> String: return "rs_p1192"
func claim_final() -> bool:
	if st().final or not all_objectives_done(): return false
	st().final = true; Sys.grant({"player": final_reward()}, "Rising Stars objectives")
	Save.dirty(); changed.emit(); return true

# ------------------------------------------------------------------ Next Gen Evolution
func is_young(p: Dictionary) -> bool:
	if p.is_empty(): return false
	if p.type == "rising": return true
	return p.type == "base" and young_ids.has(p.id)
func evo_eligible(it: Dictionary) -> bool:
	var p = Data.P(it.pid)
	if p.is_empty() or str(it.pid).begins_with("evo"): return false
	if st().evolved.has(it.pid): return false
	if st().evos.any(func(e): return e.uid == it.uid): return false
	if Evo.st().active.any(func(e): return e.uid == it.uid): return false
	return is_young(p) and p.ovr <= 90

## evolved player definition: evo<level>_<source id>
func evo_id(src: String, lvl: int) -> String: return "evo%d_%s" % [lvl, src]
func ensure_evo(id: String) -> Dictionary:
	if Data.by_id.has(id): return Data.by_id[id]
	if not id.begins_with("evo"): return {}
	var us = id.find("_")
	var lvl = int(id.substr(3, us - 3)); var src = id.substr(us + 1)
	var b: Dictionary = Data.by_id.get(src, {})
	if b.is_empty(): return {}
	var p: Dictionary = b.duplicate(true)
	p.id = id; p.base = b.get("base", src); p.type = "rising"; p.rare = true; p.evo = lvl
	p.ovr = min(96, int(b.ovr) + lvl)
	var st2 = []
	for i in 6:
		var v: int = int(b.stats[i])
		# pace / shooting / dribbling grow fastest for attackers, defending/physical for defenders
		var key: bool = (i in [0, 1, 3]) if not (b.pos in ["CB", "LB", "RB", "CDM", "GK"]) else (i in [0, 4, 5])
		st2.append(min(99, v + lvl * (2 if key else 1)))
	p.stats = st2
	if lvl >= EVO_LEVELS: p.sm = min(5, int(b.sm) + 1); p.wf = min(5, int(b.wf) + 1)
	Data.by_id[id] = p
	return p

func start_evo(uid: String) -> bool:
	var it = Sys.item(uid)
	if it.is_empty() or not evo_eligible(it): return false
	if st().evos.size() >= MAX_EVOS: Sys.toast.emit("Both Evolution slots are in use", "bad"); return false
	st().evos.append({"uid": uid, "src": it.pid, "lvl": 0, "xp": 0})
	it.untr = true
	Sys.history("Started Next Gen Evolution: " + Data.P(it.pid).name)
	Save.dirty(); changed.emit(); return true

func cancel_evo(uid: String) -> void:
	st().evos = st().evos.filter(func(e): return e.uid != uid); Save.dirty(); changed.emit()

## called after every Ultimate XI match
func after_match(res: Dictionary, r: String) -> void:
	if st().is_empty(): return
	var sq = Sys.active_squad()
	var xi: Array = sq.slots if sq else []
	var played_young = false
	for u in xi:
		if u == "": continue
		if is_young(Data.P(Sys.item(u).get("pid", ""))): played_young = true
	if played_young: Sys.track("rs_play")
	var u_side: String = res.get("user_side", "home")
	if u_side == "": u_side = "home"
	var done = []
	for e in st().evos:
		if not xi.has(e.uid): continue
		var it = Sys.item(e.uid)
		if it.is_empty(): done.append(e); continue
		var goals = 0
		for g in res.goals: if g.side == u_side and g.get("pid", "") == it.pid: goals += 1
		e.xp = int(e.xp) + 100 + (60 if r == "W" else (25 if r == "D" else 0)) + goals * 40
		while int(e.xp) >= EVO_XP and int(e.lvl) < EVO_LEVELS:
			e.xp = int(e.xp) - EVO_XP; e.lvl = int(e.lvl) + 1
			var np = ensure_evo(evo_id(e.src, e.lvl))
			it.pid = np.id
			Gallery.record(np.id, "reward", true)
			Sys.track("rs_evo")
			Sys.toast.emit("Evolution! %s is now %d OVR (Level %d)" % [Data.short_name(np.name), np.ovr, e.lvl], "good")
		if int(e.lvl) >= EVO_LEVELS:
			st().evolved[e.src] = true; done.append(e)
			Sys.history("Completed Next Gen Evolution: " + Data.P(it.pid).name)
	for e in done: st().evos.erase(e)
	Save.dirty(); changed.emit()

# ------------------------------------------------------------------ Star Token store
const STORE := [
	{"id": "coins", "name": "5,000 Coins", "cost": 50, "limit": 0, "reward": {"coins": 5000}},
	{"id": "rspack", "name": "Rising Stars Pack", "cost": 400, "limit": 3, "reward": {"pack": "rspack"}},
	{"id": "rspick", "name": "Rising Stars Player Pick", "cost": 900, "limit": 1, "reward": {"pack": "rspick"}},
	{"id": "endrick", "name": "Rising Stars Endrick", "cost": 700, "limit": 1, "reward": {"player": "rs_p426"}}]
func bought(i: String) -> int: return int(st().bought.get(i, 0))
func can_buy(it: Dictionary) -> bool: return tokens() >= int(it.cost) and (int(it.limit) == 0 or bought(it.id) < int(it.limit))
func buy(it: Dictionary) -> bool:
	if not can_buy(it): Sfx.play("error"); return false
	st().tokens = tokens() - int(it.cost); st().bought[it.id] = bought(it.id) + 1
	Sys.grant(it.reward, "Star Token Store"); Save.dirty(); changed.emit(); return true
