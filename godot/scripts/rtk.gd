extends Node
## UCL RTK 1 — Road to the Knockouts, part 1
## • 5 RTK cards of players from the European TOTW (Round 4) who are in the game: Douvikas, Nico Paz, Fabián Ruiz, Jacobo Ramón, Yann Sommer
## • they UPGRADE +1 (OVR & all stats) every time their club wins a European matchday — a matchday every 3 days, max +4
## • UCL RTK pack, an objective (Douvikas — he was Player of the Round, 9.8) and a gem SBC (Fabián Ruiz)

const NAME := "UCL RTK 1"
const START := "2026-11-18T20:00:00"     # 19 Nov 2026, 00:00 in Dubai
const ROUND_SECS := 3 * 86400
const MAX_UP := 4
const FIRST_MD := 5                       # Round 4 picked the team, matchday 5 is the first upgrade chance

## [base id, RTK ovr, match rating in Round 4]
const RTK := [["p993", 87, 9.8], ["p988", 87, 9.2], ["p1519", 88, 9.4], ["p981", 84, 8.4], ["p795", 88, 8.7]]
const RTK_OBJ := "p993"                  # Douvikas — objective
const RTK_SBC := ["p1519", 700000]       # Fabián Ruiz — gem SBC

var cards = []        # pack-able RTK cards
var all_cards = []
var _round_seen = -1
var debug_round = -1  # tests only

func _ready() -> void:
	Data.card_types["rtk"] = {"name": "UCL RTK", "order": 4}
	for f in RTK:
		var p: Dictionary = Fright._make(f[0], f[1], "rtk", "rtk_")
		if p.is_empty(): continue
		p.bo_start = int(f[1]); p.bo_stats = p.stats.duplicate(); p.bo_up = 0; p.rtk_rating = f[2]
		all_cards.append(p)
		if f[0] != RTK_OBJ and f[0] != RTK_SBC[0]: cards.append(p)
	_packs(); _objectives(); _sbcs()
	refresh(true)
	var tm = Timer.new(); tm.wait_time = 30.0; tm.autostart = true; add_child(tm); tm.timeout.connect(func(): refresh(false))

func exclusive_card(id: String) -> bool: return id == "rtk_" + RTK_OBJ or id == "rtk_" + RTK_SBC[0]

# ------------------------------------------------------------------ live upgrades (same engine as Blackout)
func round_now() -> int:
	if debug_round >= 0: return debug_round
	var st: float = Time.get_unix_time_from_datetime_string(START)
	return max(0, int(floor((Sys.now() - st) / ROUND_SECS)))
func secs_to_next() -> float:
	var st: float = Time.get_unix_time_from_datetime_string(START)
	return (round_now() + 1) * ROUND_SECS - (Sys.now() - st)
func round_label(r: int) -> String: return "MD%d" % (FIRST_MD + r - 1)

## a club's European result on a matchday — the opponent comes from another league
func result(club: String, rnd: int) -> Dictionary:
	var h: int = Gfx.hash_s("%s#%d#ucl" % [club, rnd])
	var lg: String = str(Data.clubs.get(club, {}).get("lg", ""))
	var opps = Data.clubs.keys().filter(func(c): return str(Data.clubs[c].get("lg", "")) != lg and not Data.clubs[c].get("special", false) and Data.leagues.has(str(Data.clubs[c].get("lg", ""))))
	var opp: String = opps[h % opps.size()] if not opps.is_empty() else "ICN"
	var roll: int = (h >> 3) % 100
	var gf: int = 0; var ga: int = 0
	if roll < 52: gf = 1 + (h >> 9) % 3; ga = (h >> 12) % gf
	elif roll < 76: gf = (h >> 9) % 3; ga = gf
	else: ga = 1 + (h >> 9) % 3; gf = (h >> 12) % ga
	return {"win": gf > ga, "gf": gf, "ga": ga, "opp": opp}

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
		var u: int = upgrades_for(p)
		if u != int(p.bo_up):
			if u > int(p.bo_up): ups.append(p)
			p.bo_up = u; p.ovr = int(p.bo_start) + u
			var st = []
			for i in 6: st.append(min(99, int(p.bo_stats[i]) + u))
			p.stats = st
	if not silent and not ups.is_empty() and Save.data != null:
		Sys.toast.emit("★ UCL RTK upgrades! %s" % ", ".join(ups.slice(0, 3).map(func(p): return "%s %d" % [Data.short_name(p.name), p.ovr])), "good")

# ------------------------------------------------------------------ content
func _packs() -> void:
	Data.packs["rtkpack"] = {"name": "UCL RTK Pack", "items": 3, "coins": 300000, "points": 3000, "art": "rtk", "guar": [["rtk", 1], ["gold-rare", 2]], "w": {"gold-rare": 100}, "desc": "3 Rare Gold players. 1 UCL RTK card guaranteed — they upgrade every time their club wins in Europe.", "promo": true}
	Data.packs["rtksmall"] = {"name": "Matchday Pack", "items": 6, "coins": 0, "points": 0, "art": "rtk", "guar": [["gold-rare", 2]], "w": {"gold-rare": 80, "gold": 18, "rtk": 2}, "desc": "6 gold players with a small chance of a UCL RTK card.", "reward": true}
	Data.tier_label["rtk"] = "UCL RTK"
	Data.pack_order.erase("rtkpack"); Data.pack_order.insert(0, "rtkpack")
	for id in ["premium", "mega", "ultimate", "rare", "jumbo"]:
		if Data.packs.has(id): Data.packs[id].w["rtk"] = 0.4

func _objectives() -> void:
	var o = func(id, title, desc, ev, target, reward): return {"id": id, "cat": "rtk", "title": title, "desc": desc, "ev": ev, "target": target, "reward": reward}
	for x in [
		o.call("rtk_play", "European Night", "Play 4 matches in any Ultimate XI mode", "match", 4, {"pack": "rtksmall"}),
		o.call("rtk_wins", "Group Winners", "Win 5 matches", "win", 5, {"pack": "rtksmall"}),
		o.call("rtk_goals", "Away Goals", "Score 12 goals", "goal", 12, {"coins": 10000}),
		o.call("rtk_rivals", "Knockout Ready", "Win 4 Division Rivals matches", "rivals_win", 4, {"pack": "rtkpack"}),
		o.call("rtk_douvikas", "Player of the Round", "Score 30 goals to unlock 87 UCL RTK Douvikas", "goal", 30, {"player": "rtk_" + RTK_OBJ})]:
		Data.objectives.append(x)

func _sbcs() -> void:
	var p = Data.P("rtk_" + RTK_SBC[0])
	if not p.is_empty():
		Data.sbcs.append({"id": "rtk_sbc_ruiz", "cat": "UCL RTK", "name": "UCL RTK %s" % Data.short_name(p.name), "desc": "%d UCL RTK %s — upgrades when %s win in Europe. Submit players worth %s gems." % [p.ovr, p.name, Data.clubs[p.club].name, Sys.fmt(RTK_SBC[1])], "gem": true, "target": RTK_SBC[1], "filter": {}, "reward": {"player": p.id}, "repeat": 1, "size": 0, "reqs": []})
	Data.sbcs.append({"id": "rtk_md", "cat": "UCL RTK", "name": "Matchday Exchange", "desc": "Any players. Rewards a Matchday Pack.", "gem": true, "target": 3000, "filter": {}, "reward": {"pack": "rtksmall"}, "repeat": 10, "size": 0, "reqs": []})
	Data.sbcs.append({"id": "rtk_upg", "cat": "UCL RTK", "name": "RTK Upgrade", "desc": "Any players. Rewards a UCL RTK Pack.", "gem": true, "target": 14000, "filter": {}, "reward": {"pack": "rtkpack"}, "repeat": 2, "size": 0, "reqs": []})
