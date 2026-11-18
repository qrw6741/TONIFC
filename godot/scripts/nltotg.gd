extends Node
## NATIONS LEAGUE TOTG — the Nations League A Team of the Season, all 11 are in the game
## Boosted, tradeable cards. Lamine Yamal (8.3, player of the season) is the top card.
## Packs: Nations League TOTG Pack · Objective: Lammens · Gem SBC: De Bruyne

const NAME := "Nations League TOTG"
## [base id, TOTG ovr, season rating] — laid out like the team sheet (4-3-3)
const TEAM := [["p443", 95, 8.3], ["p1194", 94, 8.1], ["p1189", 93, 8.2], ["p229", 92, 8.1], ["p871", 91, 8.1], ["p1186", 89, 8.1],
	["p409", 90, 7.8], ["p141", 88, 7.7], ["p285", 87, 7.9], ["p288", 88, 8.0], ["p259", 87, 8.2]]
const OBJ := "p259"                 # Lammens — objectives
const SBC := ["p871", 800000]       # De Bruyne — gem SBC

var design = 1       # card look: 0 = original, 1 = Mosaic (chosen), 2 = Prism, 3 = Fiesta
var cards = []        # pack-able
var all_cards = []

func _ready() -> void:
	Data.card_types["nltotg"] = {"name": "Nations League TOTG", "order": 5}
	for f in TEAM:
		var p: Dictionary = Fright._make(f[0], f[1], "nltotg", "nl_")
		if p.is_empty(): continue
		p.nl_rating = f[2]
		all_cards.append(p)
		if f[0] != OBJ and f[0] != SBC[0]: cards.append(p)
	_packs(); _objectives(); _sbcs()

func exclusive_card(id: String) -> bool: return id == "nl_" + OBJ or id == "nl_" + SBC[0]

func _packs() -> void:
	Data.packs["nlpack"] = {"name": "Nations League TOTG Pack", "items": 3, "coins": 350000, "points": 3500, "art": "nltotg", "guar": [["nltotg", 1], ["gold-rare", 2]], "w": {"gold-rare": 100}, "desc": "3 Rare Gold players. 1 Nations League TOTG card guaranteed.", "promo": true}
	Data.packs["nlsmall"] = {"name": "Nations Pack", "items": 6, "coins": 0, "points": 0, "art": "nltotg", "guar": [["gold-rare", 2]], "w": {"gold-rare": 80, "gold": 18, "nltotg": 1.5}, "desc": "6 gold players with a small chance of a Nations League TOTG card.", "reward": true}
	Data.tier_label["nltotg"] = "Nations League TOTG"
	Data.pack_order.erase("nlpack"); Data.pack_order.insert(0, "nlpack")
	for id in ["premium", "mega", "ultimate", "rare", "jumbo"]:
		if Data.packs.has(id): Data.packs[id].w["nltotg"] = 0.3

func _objectives() -> void:
	var o = func(id, title, desc, ev, target, reward): return {"id": id, "cat": "nltotg", "title": title, "desc": desc, "ev": ev, "target": target, "reward": reward}
	for x in [
		o.call("nl_play", "International Break", "Play 4 matches in any Ultimate XI mode", "match", 4, {"pack": "nlsmall"}),
		o.call("nl_wins", "Group A Winners", "Win 5 matches", "win", 5, {"pack": "nlsmall"}),
		o.call("nl_clean", "Safe Hands", "Keep 4 clean sheets", "cleansheet", 4, {"coins": 10000}),
		o.call("nl_rivals", "Final Four", "Win 4 Division Rivals matches", "rivals_win", 4, {"pack": "nlpack"}),
		o.call("nl_lammens", "Wall of Belgium", "Keep 8 clean sheets to unlock 87 Nations League TOTG Lammens", "cleansheet", 8, {"player": "nl_" + OBJ})]:
		Data.objectives.append(x)

func _sbcs() -> void:
	var p = Data.P("nl_" + SBC[0])
	if not p.is_empty():
		Data.sbcs.append({"id": "nl_sbc_kdb", "cat": "Nations League", "name": "NL TOTG %s" % Data.short_name(p.name), "desc": "%d Nations League TOTG %s. Submit players worth %s gems." % [p.ovr, p.name, Sys.fmt(SBC[1])], "gem": true, "target": SBC[1], "filter": {}, "reward": {"player": p.id}, "repeat": 1, "size": 0, "reqs": []})
	Data.sbcs.append({"id": "nl_ex", "cat": "Nations League", "name": "Nations Exchange", "desc": "Any players. Rewards a Nations Pack.", "gem": true, "target": 3000, "filter": {}, "reward": {"pack": "nlsmall"}, "repeat": 10, "size": 0, "reqs": []})
	Data.sbcs.append({"id": "nl_upg", "cat": "Nations League", "name": "TOTG Upgrade", "desc": "Any players. Rewards a Nations League TOTG Pack.", "gem": true, "target": 16000, "filter": {}, "reward": {"pack": "nlpack"}, "repeat": 2, "size": 0, "reqs": []})
