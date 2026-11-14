extends Node
## BLACK FRIDAY CONTENT DROP — "Blackout"
## • 15 Blackout cards that UPGRADE (+1 OVR, all stats +1) every time their club wins a result — results drop every 2 days, max +4
## • Blackout objective & gem-SBC exclusives · Flash packs (limited per hour) · Team of the Week 3 · neon Blackout theme

const THEME := true
const START := "2026-11-13T20:00:00"     # 14 Nov 2026, 00:00 in Dubai
const ROUND_SECS := 2 * 86400            # a new round of results every 2 days
const MAX_UP := 4

## [base id, starting ovr]
const BLACKOUT := [["p443", 91], ["p420", 92], ["p256", 92], ["p1194", 91], ["p1522", 91], ["p437", 90], ["p1188", 90], ["p415", 90], ["p402", 90], ["p130", 89], ["p217", 89], ["p812", 89], ["p1523", 89], ["p1185", 89], ["p834", 88]]
const BLACKOUT_OBJ := ["p485", 88]                                      # Nico Williams — objectives
const BLACKOUT_SBC := [["p421", 92, 900000], ["p1515", 90, 600000]]      # Vinícius, Hakimi — gem SBCs
## Team of the Week 3
const TOTW3 := [["p237", 90], ["p2", 89], ["p797", 88], ["p240", 87], ["p221", 84], ["p807", 88], ["p226", 86], ["p417", 90], ["p229", 89], ["p230", 90], ["p444", 90], ["p1189", 88], ["p215", 86]]

var cards = []          # pack-able Blackout cards
var all_cards = []      # every Blackout card (incl. objective & SBC ones)
var totw_latest = []
var _round_seen = -1

func _ready() -> void:
	Data.card_types["blackout"] = {"name": "Blackout", "order": 4}
	for f in BLACKOUT: cards.append(_make(f[0], f[1], "blackout", "bo_"))
	all_cards = cards.duplicate()
	all_cards.append(_make(BLACKOUT_OBJ[0], BLACKOUT_OBJ[1], "blackout", "bo_"))
	for f in BLACKOUT_SBC: all_cards.append(_make(f[0], f[1], "blackout", "bo_"))
	for f in TOTW3: totw_latest.append(Fright._make(f[0], f[1], "totw", "t3_"))
	_packs(); _objectives(); _sbcs()
	refresh(true)
	var tm = Timer.new(); tm.wait_time = 30.0; tm.autostart = true; add_child(tm); tm.timeout.connect(func(): refresh(false))

func _make(base_id: String, target: int, type: String, prefix: String) -> Dictionary:
	var p: Dictionary = Fright._make(base_id, target, type, prefix)
	if p.is_empty(): return p
	p.bo_start = target; p.bo_stats = p.stats.duplicate(); p.bo_up = 0
	p.wf = min(5, int(Data.P(base_id).wf) + 1)
	return p

func exclusive_card(id: String) -> bool:
	if id == "bo_" + BLACKOUT_OBJ[0]: return true
	for f in BLACKOUT_SBC: if id == "bo_" + f[0]: return true
	return false

# ------------------------------------------------------------------ live upgrades
var debug_round = -1    # tests only
func round_now() -> int:
	if debug_round >= 0: return debug_round
	var st: float = Time.get_unix_time_from_datetime_string(START)
	return max(0, int(floor((Sys.now() - st) / ROUND_SECS)))
func secs_to_next() -> float:
	var st: float = Time.get_unix_time_from_datetime_string(START)
	return (round_now() + 1) * ROUND_SECS - (Sys.now() - st)

## the simulated result of a club in a round: {win, gf, ga, opp}
func result(club: String, rnd: int) -> Dictionary:
	var h: int = Gfx.hash_s("%s#%d#blackout" % [club, rnd])
	var lg: String = str(Data.clubs.get(club, {}).get("lg", ""))
	var opps = Data.clubs.keys().filter(func(c): return c != club and str(Data.clubs[c].get("lg", "")) == lg)
	var opp: String = opps[h % opps.size()] if not opps.is_empty() else "ICN"
	var roll: int = (h >> 3) % 100
	var gf: int = 0; var ga: int = 0
	if roll < 55: gf = 1 + (h >> 9) % 3; ga = (h >> 12) % gf          # win
	elif roll < 78: gf = (h >> 9) % 3; ga = gf                          # draw
	else: ga = 1 + (h >> 9) % 3; gf = (h >> 12) % ga                    # loss
	return {"win": gf > ga, "gf": gf, "ga": ga, "opp": opp}

## rounds played so far (round 0 is the launch — no result yet)
func upgrades_for(p: Dictionary) -> int:
	var n = 0
	for r in range(1, round_now() + 1):
		if result(str(p.club), r).win: n += 1
	return min(MAX_UP, n)

func refresh(silent: bool) -> void:
	var rn = round_now()
	if rn == _round_seen and not silent: return
	_round_seen = rn
	var ups = []
	for p in all_cards:
		if p.is_empty(): continue
		var u: int = upgrades_for(p)
		if u != int(p.bo_up):
			if u > int(p.bo_up): ups.append(p)
			p.bo_up = u; p.ovr = int(p.bo_start) + u
			var st = []
			for i in 6: st.append(min(99, int(p.bo_stats[i]) + u))
			p.stats = st
	if not silent and not ups.is_empty() and Save.data != null:
		Sys.toast.emit("⚡ Blackout upgrades! %s" % ", ".join(ups.slice(0, 3).map(func(p): return "%s %d" % [Data.short_name(p.name), p.ovr])), "good")

# ------------------------------------------------------------------ content
func _packs() -> void:
	Data.packs["blackoutpack"] = {"name": "Blackout Pack", "items": 3, "coins": 250000, "points": 2500, "art": "blackout", "guar": [["blackout", 1], ["gold-rare", 2]], "w": {"gold-rare": 100}, "desc": "3 Rare Gold players. 1 Blackout card guaranteed — they upgrade every time their club wins.", "promo": true}
	Data.packs["flashpack"] = {"name": "Flash Pack", "items": 5, "coins": 90000, "points": 900, "art": "blackout", "guar": [["gold-rare", 5]], "w": {"gold-rare": 100, "blackout": 6, "totw": 4}, "desc": "⚡ FLASH: 5 Rare Gold players with a boosted Blackout chance. Only 3 per hour!", "promo": true, "flash": 3}
	Data.packs["doorbuster"] = {"name": "Doorbuster Pack", "items": 12, "coins": 25000, "points": 250, "art": "blackout", "guar": [["gold-rare", 3]], "w": {"gold": 70, "gold-rare": 30, "blackout": 0.8}, "desc": "⚡ FLASH: 12 gold players at a Black Friday price. Only 2 per hour!", "promo": true, "flash": 2}
	Data.packs["bosmall"] = {"name": "Power Cut Pack", "items": 6, "coins": 0, "points": 0, "art": "blackout", "guar": [["gold-rare", 2]], "w": {"gold-rare": 80, "gold": 18, "blackout": 2}, "desc": "6 gold players with a small chance of a Blackout card.", "reward": true}
	Data.tier_label["blackout"] = "Blackout"
	# Fright Night has left the store
	Data.pack_order.erase("frightpack")
	for id in ["doorbuster", "flashpack", "blackoutpack"]:
		Data.pack_order.erase(id); Data.pack_order.insert(0, id)
	for id in ["premium", "mega", "ultimate", "rare", "jumbo"]:
		if Data.packs.has(id): Data.packs[id].w["blackout"] = 0.6; Data.packs[id].w["fright"] = 0.15
	if Data.packs.has("totwpack"): Data.packs.totwpack.desc = "3 Rare Gold. 1 Team of the Week card guaranteed — TOTW 3 is live!"

func _objectives() -> void:
	var o = func(id, title, desc, ev, target, reward): return {"id": id, "cat": "blackout", "title": title, "desc": desc, "ev": ev, "target": target, "reward": reward}
	for x in [
		o.call("bo_play", "Lights Out", "Play 4 matches in any Ultimate XI mode", "match", 4, {"pack": "bosmall"}),
		o.call("bo_goals", "Power Surge", "Score 15 goals", "goal", 15, {"coins": 15000}),
		o.call("bo_wins", "Doorbuster Wins", "Win 6 matches", "win", 6, {"pack": "bosmall"}),
		o.call("bo_clean", "Total Blackout", "Keep 4 clean sheets", "cleansheet", 4, {"coins": 12000}),
		o.call("bo_rivals", "Rivals After Dark", "Win 5 Division Rivals matches", "rivals_win", 5, {"pack": "blackoutpack"}),
		o.call("bo_sbc", "Checkout", "Complete 4 SBCs", "sbc", 4, {"coins": 20000}),
		o.call("bo_packs", "Shopping Spree", "Open 15 packs", "pack", 15, {"pack": "bosmall"}),
		o.call("bo_nico", "Lightning Strikes", "Score 35 goals this Blackout to unlock 88 Blackout Nico Williams", "goal", 35, {"player": "bo_" + BLACKOUT_OBJ[0]})]:
		Data.objectives.append(x)

func _sbcs() -> void:
	var add = func(id, name, desc, target, reward, rep):
		Data.sbcs.append({"id": id, "cat": "Blackout", "name": name, "desc": desc, "gem": true, "target": target, "filter": {}, "reward": reward, "repeat": rep, "size": 0, "reqs": []})
	for f in BLACKOUT_SBC:
		var p = Data.P("bo_" + f[0])
		add.call("bo_sbc_" + f[0], "Blackout %s" % Data.short_name(p.name), "%d Blackout %s — upgrades when %s win. Submit players worth %s gems." % [p.ovr, p.name, Data.clubs[p.club].name, Sys.fmt(f[2])], f[2], {"player": p.id}, 1)
	add.call("bo_cut", "Power Cut Exchange", "Any players. Rewards a Power Cut Pack.", 3000, {"pack": "bosmall"}, 10)
	add.call("bo_upg", "Blackout Upgrade", "Any players. Rewards a Blackout Pack.", 12000, {"pack": "blackoutpack"}, 2)
	add.call("bo_totw3", "TOTW 3 Upgrade", "Any players. Rewards a Team of the Week Pack.", 9000, {"pack": "totwpack"}, 2)
