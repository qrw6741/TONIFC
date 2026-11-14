extends Node
## HALLOWEEN CONTENT DROP — "Fright Night"
## • Fright Night promo cards (packs, objectives, SBCs) · tradeable
## • Phantom Pass cards — Season 2 Pass-only rarity (modest 83–86) · untradeable
## • Team of the Week 2 (12 in-forms)
## • Halloween objectives & SBCs, Fright Night pack, and the Halloween menu theme

const THEME := true   # Halloween look for menus & backgrounds

## [base id, final ovr]
const FRIGHT := [["p233", 90], ["p467", 89], ["p270", 89], ["p1516", 89], ["p239", 89], ["p817", 89], ["p18", 88], ["p251", 88], ["p1190", 88], ["p813", 88], ["p869", 88], ["p409", 87]]
const FRIGHT_OBJ := ["p253", 87]            # earned from Halloween objectives
const FRIGHT_SBC := [["p11", 90, 900000], ["p1543", 88, 600000]]   # player SBCs (gems)
## Season 2 Phantom Pass: [base, ovr]
const PHANTOM_FREE := [["p15", 83], ["p131", 84], ["p294", 84], ["p231", 85]]
const PHANTOM_PREM := [["p313", 83], ["p221", 84], ["p430", 85], ["p234", 85], ["p19", 86]]
const PHANTOM_FINALE := [["p1525", 86], ["p275", 86], ["p276", 86]]
## Team of the Week 2
const TOTW2 := [["p0", 89], ["p10", 88], ["p289", 88], ["p447", 88], ["p1518", 88], ["p342", 87], ["p434", 87], ["p806", 87], ["p1511", 87], ["p405", 85], ["p1183", 85], ["p254", 83], ["p278", 83]]

var fright = []
var phantom_finale = []
var totw_latest = []

func _ready() -> void:
	Data.card_types["fright"] = {"name": "Fright Night", "order": 4}
	Data.card_types["phantom"] = {"name": "Phantom Pass", "order": 5}
	for f in FRIGHT: fright.append(_make(f[0], f[1], "fright", "fr_"))
	_make(FRIGHT_OBJ[0], FRIGHT_OBJ[1], "fright", "fr_")
	for f in FRIGHT_SBC: _make(f[0], f[1], "fright", "fr_")
	for f in PHANTOM_FREE + PHANTOM_PREM: _make(f[0], f[1], "phantom", "ph_")
	for f in PHANTOM_FINALE: phantom_finale.append(_make(f[0], f[1], "phantom", "ph_"))
	for f in TOTW2: totw_latest.append(_make(f[0], f[1], "totw", "t2_"))
	_packs(); _objectives(); _sbcs()

## Fright cards that are only earned from objectives / SBCs never drop in packs
func exclusive_fright(id: String) -> bool:
	if id == "fr_" + FRIGHT_OBJ[0]: return true
	for f in FRIGHT_SBC: if id == "fr_" + f[0]: return true
	return false

func _make(base_id: String, target: int, type: String, prefix: String) -> Dictionary:
	var b: Dictionary = Data.by_id.get(base_id, {})
	if b.is_empty(): return {}
	if Data.by_id.has(prefix + base_id): return Data.by_id[prefix + base_id]
	var p: Dictionary = b.duplicate(true)
	var boost: int = max(1, target - int(b.ovr))
	p.id = prefix + base_id; p.base = b.id; p.type = type; p.rare = true; p.ovr = target
	var st = []
	for i in 6: st.append(min(99, int(b.stats[i]) + boost + (1 if int(b.stats[i]) >= 80 and type != "totw" else 0)))
	p.stats = st
	if type != "totw": p.sm = min(5, int(b.sm) + 1)
	if type == "fright": p.wf = min(5, int(b.wf) + 1)
	Data.players.append(p); Data.by_id[p.id] = p
	return p

func _packs() -> void:
	Data.packs["frightpack"] = {"name": "Fright Night Pack", "items": 3, "coins": 250000, "points": 2500, "art": "fright", "guar": [["fright", 1], ["gold-rare", 2]], "w": {"gold-rare": 100}, "desc": "3 Rare Gold players. 1 Fright Night card guaranteed.", "promo": true}
	Data.packs["frightsmall"] = {"name": "Trick or Treat Pack", "items": 6, "coins": 0, "points": 0, "art": "fright", "guar": [["gold-rare", 2]], "w": {"gold-rare": 80, "gold": 18, "fright": 2}, "desc": "6 gold players with a small chance of a Fright Night card.", "reward": true}
	Data.packs["pickph"] = {"name": "Phantom Pass Player Pick", "items": 1, "coins": 0, "points": 0, "art": "phantom", "guar": [["ph_finale", 1]], "w": {"ph_finale": 1}, "desc": "Choose 1 of 3 Phantom Pass cards: Barcola, Mbeumo or Cunha (86).", "reward": true, "pick": {"n": 3, "tier": "ph_finale"}}
	Data.tier_label["fright"] = "Fright Night"; Data.tier_label["ph_finale"] = "Phantom Pass"
	if not Data.pack_order.has("frightpack"): Data.pack_order.insert(0, "frightpack")
	# a pinch of Fright Night in the big packs
	for id in ["premium", "mega", "ultimate", "rare", "jumbo"]:
		if Data.packs.has(id): Data.packs[id].w["fright"] = 0.6
	if Data.packs.has("totwpack"): Data.packs.totwpack.desc = "3 Rare Gold. 1 Team of the Week card guaranteed — TOTW 2 is live!"

func _objectives() -> void:
	var o = func(id, title, desc, ev, target, reward): return {"id": id, "cat": "halloween", "title": title, "desc": desc, "ev": ev, "target": target, "reward": reward}
	for x in [
		o.call("hw_play", "Trick or Treat", "Play 3 matches in any Ultimate XI mode", "match", 3, {"pack": "frightsmall"}),
		o.call("hw_goals", "Pumpkin Smasher", "Score 13 goals", "goal", 13, {"coins": 6660}),
		o.call("hw_wins", "Haunted Wins", "Win 6 matches", "win", 6, {"pack": "frightsmall"}),
		o.call("hw_clean", "Ghost Defence", "Keep 3 clean sheets", "cleansheet", 3, {"coins": 9999}),
		o.call("hw_rivals", "Night of the Rivals", "Win 4 Division Rivals matches", "rivals_win", 4, {"pack": "frightpack"}),
		o.call("hw_sbc", "Witch's Brew", "Complete 3 SBCs", "sbc", 3, {"coins": 13000}),
		o.call("hw_packs", "Cursed Packs", "Open 13 packs", "pack", 13, {"pack": "frightsmall"}),
		o.call("hw_doku", "The Headless Winger", "Score 31 goals this Halloween to unlock 87 Fright Night Doku", "goal", 31, {"player": "fr_p253"})]:
		Data.objectives.append(x)

func _sbcs() -> void:
	var add = func(id, name, desc, target, reward, rep):
		Data.sbcs.append({"id": id, "cat": "Halloween", "name": name, "desc": desc, "gem": true, "target": target, "filter": {}, "reward": reward, "repeat": rep, "size": 0, "reqs": []})
	for f in FRIGHT_SBC:
		var p = Data.P("fr_" + f[0])
		add.call("hw_sbc_" + f[0], "Fright Night %s" % Data.short_name(p.name), "%d Fright Night %s. Submit players worth %s gems." % [p.ovr, p.name, Sys.fmt(f[2])], f[2], {"player": p.id}, 1)
	add.call("hw_pumpkin", "Pumpkin Patch Exchange", "Any players. Rewards a Trick or Treat Pack.", 3000, {"pack": "frightsmall"}, 10)
	add.call("hw_haunted", "Haunted House Upgrade", "Any players. Rewards a Fright Night Pack.", 12000, {"pack": "frightpack"}, 2)
	add.call("hw_totw2", "TOTW 2 Upgrade", "Any players. Rewards a Team of the Week Pack.", 9000, {"pack": "totwpack"}, 2)
