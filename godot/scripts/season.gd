extends Node
## Season Pass — 50 levels with a Free and a Premium track. Earn Season XP from
## matches, objectives and SBCs. Season 2 "Fright Night": exclusive Phantom Pass cards only come from here.
## Premium is unlocked with Prime Points (free in-game credits, no real money).

signal changed

const NAME := "Season 2 · Fright Night"
const TITLE := "SEASON 2: FRIGHT NIGHT"
const TAGLINE := "Halloween is here — climb 50 levels of Phantom Pass rewards"
const ID := "s2"
const LEVELS := 50
const XP_PER := 1000    # FC 27: every level costs 1,000 Season Points (SP)
const MATCH_CAP := 850  # FC 27: match play earns at most 850 SP per day
const PREMIUM_COST := 1000
const LEVEL_COST := 200
const OVERFLOW_COINS := 3000

func asc(base_id: String) -> Dictionary: return {"player": "asc_" + base_id}
func ph(base_id: String) -> Dictionary: return {"player": "ph_" + base_id}
func pk(id: String) -> Dictionary: return {"pack": id}
func co(n: int) -> Dictionary: return {"coins": n}
func pt(n: int) -> Dictionary: return {"points": n}

var FREE = {}
var PREM = {}

func _ready() -> void:
	FREE = {
		1: co(1000), 2: pk("frightsmall"), 3: co(1500), 4: pt(50), 5: pk("pp83x2"), 6: co(2000), 7: pk("premium"), 8: pt(100), 9: co(2500), 10: ph("p15"),
		11: co(3000), 12: pk("pp82x5"), 13: pk("frightsmall"), 14: co(3500), 15: pk("pick84"), 16: pt(150), 17: pk("jumbo"), 18: pk("pp83x2"), 19: co(5000), 20: pk("rare"),
		21: co(5000), 22: pt(200), 23: pk("pp82x5"), 24: pk("mega"), 25: ph("p131"), 26: co(7500), 27: pk("pp83x2"), 28: pt(250), 29: pk("frightsmall"), 30: pk("pick86"),
		31: co(10000), 32: pk("pp82x5"), 33: pk("jumbo"), 34: pt(300), 35: pk("pp83x2"), 36: co(12500), 37: pk("mega"), 38: pk("pp82x5"), 39: pt(400), 40: ph("p294"),
		41: co(15000), 42: pk("pp83x2"), 43: pk("rare"), 44: pk("pp82x5"), 45: pk("pick84"), 46: co(20000), 47: pk("pp83x2"), 48: pk("frightpack"), 49: pk("pp83x2"), 50: ph("p231")}
	PREM = {
		1: ph("p313"), 2: pk("pp82x5"), 3: co(5000), 4: pk("pp83x2"), 5: pk("frightsmall"), 6: pt(200), 7: pk("pp82x5"), 8: pk("pick84"), 9: co(10000), 10: pk("pp83x2"),
		11: pk("mega"), 12: pk("pp82x5"), 13: pt(300), 14: pk("pp83x2"), 15: ph("p221"), 16: pk("pp82x5"), 17: co(15000), 18: pk("pick86"), 19: pk("pp83x2"), 20: ph("p430"),
		21: pk("pp82x5"), 22: pk("rare"), 23: pk("pp83x2"), 24: co(20000), 25: pk("frightpack"), 26: pk("pp82x5"), 27: pk("pp85x1"), 28: pt(500), 29: pk("pp83x2"), 30: ph("p234"),
		31: pk("pp82x5"), 32: pk("totwpack"), 33: pk("pp83x2"), 34: co(25000), 35: pk("pick86"), 36: pk("pp82x5"), 37: pk("pp83x2"), 38: pk("pp83x2"), 39: pt(750), 40: ph("p19"),
		41: pk("pp82x5"), 42: pk("pp83x2"), 43: pk("rare"), 44: pk("pp82x5"), 45: pk("pick86"), 46: pk("pp82x5"), 47: pk("pp83x2"), 48: pk("frightpack"), 49: pk("pp85x1"), 50: pk("pickph")}
	# drop any reward that references content missing from this build
	for tr in [FREE, PREM]:
		for lv in tr.keys():
			var r: Dictionary = tr[lv]
			if (r.has("pack") and not Data.packs.has(r.pack)) or (r.has("player") and Data.P(r.player).is_empty()): tr[lv] = co(5000)

func st() -> Dictionary:
	var d = Save.data
	if d == null: return {}
	if typeof(d.get("season")) != TYPE_DICTIONARY or d.season.get("id", "") != ID:
		d.season = {"id": ID, "xp": 0, "premium": false, "free": {}, "prem": {}, "bonus": 0}
	if not d.season.has("ends"): d.season.ends = int(Time.get_unix_time_from_system()) + 30 * 86400
	return d.season

func days_left() -> int: return max(0, int(ceil((float(st().get("ends", 0)) - Time.get_unix_time_from_system()) / 86400.0)))

func level() -> int: return min(LEVELS, int(st().xp) / XP_PER)
func level_xp() -> int: return int(st().xp) - level() * XP_PER if level() < LEVELS else int(st().xp) - LEVELS * XP_PER
func premium() -> bool: return bool(st().get("premium", false))
func reward(lv: int, track: String) -> Dictionary: return (FREE if track == "free" else PREM).get(lv, {})
func claimed(lv: int, track: String) -> bool: return st()[track].has(str(lv))
func can_claim(lv: int, track: String) -> bool:
	return lv <= level() and not claimed(lv, track) and (track == "free" or premium()) and not reward(lv, track).is_empty()
func claim_count() -> int:
	if Save.data == null: return 0
	var n = 0
	for lv in range(1, level() + 1):
		if can_claim(lv, "free"): n += 1
		if can_claim(lv, "prem"): n += 1
	return n

## SP from a match: 15–100 depending on result and mode, capped at 850 SP a day (like FC 27)
func match_sp(result: String, mode: String) -> int:
	if result == "W": return 70 if mode in ["rivals", "champs"] else (60 if mode in ["draft", "event"] else 50)
	if result == "D": return 30
	return 15
func add_match_sp(n: int, why: String) -> void:
	if Save.data == null: return
	var s = st()
	if str(s.get("cap_day", "")) != Sys.day_key(): s.cap_day = Sys.day_key(); s.cap_n = 0
	var room: int = max(0, MATCH_CAP - int(s.get("cap_n", 0)))
	var g: int = min(n, room)
	if g <= 0: Sys.toast.emit("Daily match SP cap reached (850) — objectives still give SP", "info"); return
	s.cap_n = int(s.get("cap_n", 0)) + g
	add_xp(g, why)

func add_xp(n: int, why := "") -> void:
	if Save.data == null or n <= 0: return
	if why != "Bought level": n = Sys.xp_scaled(n, "season")
	if n <= 0: return
	var s = st(); var before = level(); var before_total: int = int(s.xp)
	if why != "" and why != "test": Sys.toast.emit("+%d SP · %s" % [n, why], "info")
	s.xp = before_total + n
	var after = level()
	if after > before:
		Sfx.play("reveal")
		Sys.toast.emit("Season Pass Level %d reached! Claim your rewards" % after, "good")
		Sys.history("Reached Season Pass Level %d" % after)
	# overflow levels past 50 pay coins automatically
	if int(s.xp) > LEVELS * XP_PER:
		var over_now = (int(s.xp) - LEVELS * XP_PER) / XP_PER
		var paid: int = int(s.get("bonus", 0))
		if over_now > paid:
			s.bonus = over_now
			Sys.add("coins", (over_now - paid) * OVERFLOW_COINS, "Season Pass bonus level")
	Save.dirty(); changed.emit()

func claim(lv: int, track: String) -> bool:
	if not can_claim(lv, track): return false
	st()[track][str(lv)] = true
	Sys.grant(reward(lv, track), "Season Pass Level %d" % lv)
	Save.dirty(); changed.emit(); return true

func claim_all() -> int:
	var n = 0; var players = 0; var packs = 0
	Sys.quiet = true
	for lv in range(1, level() + 1):
		for tr in ["free", "prem"]:
			var r = reward(lv, tr)
			if claim(lv, tr):
				n += 1
				if r.has("player"): players += 1
				if r.has("pack"): packs += 1
	Sys.quiet = false
	if n: Sys.toast.emit("Claimed %d rewards — %d packs sent to My Packs%s" % [n, packs, (", %d Phantom Pass card%s to your club" % [players, "s" if players > 1 else ""]) if players else ""], "good")
	return n

func unlock_premium() -> bool:
	if premium(): return false
	if not Sys.spend("points", PREMIUM_COST, "Season Pass Premium", "store"): return false
	st().premium = true; Save.dirty(); changed.emit()
	Sys.toast.emit("Premium Season Pass unlocked!", "good")
	return true

func buy_level() -> bool:
	if level() >= LEVELS: return false
	if not Sys.spend("points", LEVEL_COST, "Season Pass level", "store"): return false
	add_xp(XP_PER - level_xp(), "Bought level")
	return true

func reward_label(r: Dictionary) -> String:
	if r.has("player"):
		var p = Data.P(r.player); return "%d %s" % [p.ovr, Data.short_name(p.name)]
	if r.has("pack"): return Data.packs[r.pack].name
	if r.get("coins", 0): return Sys.fmt(r.coins) + " Coins"
	if r.get("points", 0): return Sys.fmt(r.points) + " Prime Points"
	return ""
