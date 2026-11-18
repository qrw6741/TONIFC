extends Node
## DATA — loads the shared game database (players, clubs, leagues, packs, objectives, SBCs)
## from res://data/gamedata.json. The same data powers the web version, so both builds
## have identical players and rules. All players, clubs and leagues are fictional.

var nations = {}
var leagues = {}
var clubs = {}
var positions = []
var alt_pos = {}
var pos_group = {}
var card_types = {}
var formations = {}        # name -> [[pos, x, y], ...]
var formation_names = []
var players = []
var by_id = {}
var by_club = {}
var packs = {}
var pack_order = []
var tier_label = {}
var objectives = []
var sbcs = []
var difficulties = {}
var difficulty_order = ["beginner", "amateur", "semipro", "professional", "worldclass", "legendary", "ultimate"]
var sb_ranks = []
var rivals_divs = []
var ai_squad_names = []
var draft_cost = {}

const SKINS := ["#f6d3b3", "#ecc09a", "#d9a277", "#c48a5c", "#a86f45", "#8a5634", "#6b3f24", "#4e2c18"]
const HAIRC := ["#141010", "#2d1d12", "#5a3a1e", "#8a5a2b", "#c99a4b", "#e3cc8c", "#7a7a7a", "#efe6d2", "#b5541f"]
const STAT_LABELS := ["PAC", "SHO", "PAS", "DRI", "DEF", "PHY"]
const GK_LABELS := ["DIV", "HAN", "KIC", "REF", "SPD", "POS"]

func _ready() -> void:
	var f = FileAccess.open("res://data/gamedata.json", FileAccess.READ)
	var d: Dictionary = _ints(JSON.parse_string(f.get_as_text()))
	nations = d.nations; leagues = d.leagues; clubs = d.clubs; positions = d.positions
	alt_pos = d.alt_pos; pos_group = d.pos_group; card_types = d.card_types
	formations = d.formations; formation_names = formations.keys()
	players = d.players; packs = d.packs; pack_order = d.pack_order; tier_label = d.tier_label
	objectives = d.objectives; sbcs = d.sbcs; difficulties = d.difficulties; sb_ranks = d.sb_ranks
	rivals_divs = d.rivals_divs; ai_squad_names = d.ai_squad_names; draft_cost = d.draft_cost
	for p in players:
		p.ovr = int(p.ovr)
		var st = []
		for s in p.stats: st.append(int(s))
		p.stats = st
		p.sm = int(p.sm); p.wf = int(p.wf); p.height = int(p.height); p.age = int(p.age)
		by_id[p.id] = p
		if not by_club.has(p.club): by_club[p.club] = []
		by_club[p.club].append(p)
	_add_season_content()
	# harder game: every difficulty level plays smarter
	for k in difficulties: difficulties[k].ai = min(1.2, float(difficulties[k].ai) + 0.14)
	# special cards are much rarer in every non-promo pack (guaranteed slots unaffected)
	for id in packs:
		if packs[id].get("promo", false): continue
		for t in ["totw", "promo", "hero", "icon"]:
			if packs[id].w.has(t): packs[id].w[t] = float(packs[id].w[t]) * 0.35

# ---------------- Season Pass exclusive content ----------------
## Ascension — Season Pass-only rarity. [base player id, final OVR, finale-pick?]
## Deliberately modest (83–86): good upgrades, not overpowered.
const ASCENSION := [
	["p1526", 83, false], ["p377", 84, false], ["p298", 84, false], ["p973", 85, false],   # free track
	["p988", 83, false], ["p464", 84, false], ["p56", 85, false], ["p12", 85, false], ["p35", 86, false],   # premium track
	["p833", 86, true], ["p894", 86, true], ["p13", 86, true]]   # level 50 Ascension Player Pick
## earlier Ascension cards stay valid for saves that already own them
const ASCENSION_LEGACY := [["p14", 4], ["p229", 3], ["p812", 4], ["p247", 4], ["p130", 3], ["p2", 4], ["p1515", 4], ["p437", 4], ["p421", 5], ["p420", 4], ["p443", 5], ["p256", 4]]
var ascension_finale = []

func asc_id(base_id: String) -> String: return "asc_" + base_id

func _make_asc(b: Dictionary, target: int) -> Dictionary:
	var p: Dictionary = b.duplicate(true)
	var boost: int = max(1, target - int(b.ovr))
	p.id = asc_id(b.id); p.base = b.id; p.type = "pass"; p.rare = true; p.ovr = target
	var st = []
	for i in 6: st.append(min(99, int(b.stats[i]) + boost + (1 if int(b.stats[i]) >= 78 else 0)))
	p.stats = st
	p.sm = min(5, int(b.sm) + 1); p.wf = min(5, int(b.wf) + 1)
	players.append(p); by_id[p.id] = p
	return p

func _add_season_content() -> void:
	card_types["pass"] = {"name": "Ascension", "order": 5}
	for p in players: preload("res://scripts/faces.gd").apply(p)   # real-player looks for stars, nationality-based looks for everyone else (cards created below copy them)
	for a in ASCENSION:
		var b: Dictionary = by_id.get(a[0], {})
		if b.is_empty(): continue
		var p = _make_asc(b, int(a[1]))
		if a[2]: ascension_finale.append(p)
	for a in ASCENSION_LEGACY:
		var b: Dictionary = by_id.get(a[0], {})
		if not b.is_empty() and not by_id.has(asc_id(a[0])): _make_asc(b, min(97, int(b.ovr) + int(a[1])))
	for t in [["ovr82", "82+ Player"], ["ovr83", "83+ Player"], ["ovr84", "84+ Player"], ["ovr85", "85+ Player"], ["ovr86", "86+ Player"], ["ovr88", "88+ Player"], ["asc_finale", "Ascension"]]:
		tier_label[t[0]] = t[1]
	var rp = func(name: String, items: int, tier: String, desc: String, art := "pass") -> Dictionary:
		return {"name": name, "items": items, "coins": 0, "points": 0, "art": art, "guar": [[tier, items]], "w": {tier: 1}, "desc": desc, "reward": true}
	packs["pp82x5"] = rp.call("82+ x5 Players Pack", 5, "ovr82", "5 players rated 82 or higher. Season Pass reward.")
	packs["pp83x2"] = rp.call("83+ x2 Players Pack", 2, "ovr83", "2 players rated 83 or higher. Season Pass reward.")
	packs["pp85x1"] = rp.call("85+ Player Pack", 1, "ovr85", "1 player rated 85 or higher. Season Pass reward.")
	for pk in [["pick84", "84+ Player Pick", "ovr84", "Choose 1 of 3 players rated 84 or higher."], ["pick86", "86+ Player Pick", "ovr86", "Choose 1 of 3 players rated 86 or higher."],
			["pick88", "88+ Player Pick", "ovr88", "Choose 1 of 3 players rated 88 or higher."], ["pickasc", "Ascension Player Pick", "asc_finale", "Choose 1 of 3 Ascension cards: Pulisic, Lookman or Eze (86)."]]:
		var d = rp.call(pk[1], 1, pk[2], pk[3], "pick"); d.pick = {"n": 3, "tier": pk[2]}
		packs[pk[0]] = d

func P(id: String) -> Dictionary:
	if not by_id.has(id) and id.begins_with("evo"): return Event.ensure_evo(id)
	if not by_id.has(id) and id.begins_with("ev_"): return Evo.ensure(id)
	return by_id.get(id, {})

func division(div: int) -> Dictionary:
	return rivals_divs[div - 1]

func tier_of(ovr: int) -> String:
	return "gold" if ovr >= 76 else ("silver" if ovr >= 71 else "bronze")

func rarity_key(p: Dictionary) -> String:
	if p.type != "base": return p.type
	return tier_of(p.ovr) + ("-rare" if p.rare else "")

func rarity_name(p: Dictionary) -> String:
	if p.type != "base": return card_types[p.type].name
	var t = tier_of(p.ovr)
	return ("Rare " if p.rare else "") + t.capitalize()

func fits_pos(p: Dictionary, pos: String) -> bool:
	return p.pos == pos or (p.alt as Array).has(pos)

func short_name(n: String) -> String:
	var parts = n.split(" ")
	if parts.size() > 1:
		parts.remove_at(0)
		return " ".join(parts)
	return n

## FC 27-style market prices: cheap up to ~83, then steep — a 91 rare gold striker (Mbappé) is ~3M, icons are multi-million
const GOLD_CURVE := {76: 700, 77: 900, 78: 1200, 79: 1600, 80: 2200, 81: 3200, 82: 5000, 83: 8000, 84: 13000, 85: 21000, 86: 36000, 87: 65000, 88: 140000, 89: 330000, 90: 900000, 91: 2500000, 92: 3800000, 93: 5200000, 94: 6800000, 95: 8500000, 96: 10000000, 97: 11500000, 98: 13000000, 99: 14500000}
const MAX_PRICE := 15000000
const TYPE_MULT := {"base": 1.0, "totw": 2.5, "found": 1.8, "promo": 4.0, "hero": 6.0, "icon": 8.0, "pass": 4.0, "rising": 3.5, "potm": 4.0, "gallery": 4.0, "fright": 4.0, "phantom": 4.0, "blackout": 4.5, "rtk": 4.5, "nltotg": 5.0}
## minimum price for the big special rarities, whatever their rating
const TYPE_FLOOR := {"icon": 2000000, "hero": 600000, "blackout": 150000, "rtk": 150000, "nltotg": 250000, "fright": 120000, "promo": 100000, "potm": 150000, "totw": 20000}
func base_value(p: Dictionary) -> int:
	var o: int = int(p.ovr); var v = 0.0
	if o < 71: v = 150 + (o - 58) * 15
	elif o < 76: v = 350 + (o - 71) * 60 + (150 if p.rare else 0)
	else: v = float(GOLD_CURVE.get(clamp(o, 76, 99), 700)) * (1.0 if p.rare or o >= 84 else 0.6)
	var pos_m: float = {"ST": 1.2, "LW": 1.15, "RW": 1.15, "CAM": 1.1, "CB": 1.05, "GK": 0.8, "CF": 1.1}.get(p.pos, 1.0)
	v = max(v * float(TYPE_MULT.get(p.type, 1.0)) * pos_m, float(TYPE_FLOOR.get(p.type, 0)))
	return clamp(_round_price(v), 150, MAX_PRICE)
func _round_price(v: float) -> int:
	var step = 50 if v < 10000 else (250 if v < 100000 else (1000 if v < 1000000 else 10000))
	return int(round(v / step)) * step

## quick sell stays modest (it's not a market price): roughly the old curve
func quick_sell_value(p: Dictionary) -> int:
	var o: int = int(p.ovr); var v = 0.0
	if o < 71: v = 150 + (o - 58) * 15
	elif o < 76: v = 350 + (o - 71) * 60
	else: v = 750 * pow(1.38, min(o, 92) - 76)
	return clamp(int(round(v * 0.08 / 10.0)) * 10, 50, 25000)

func card_value_score(p: Dictionary) -> float:
	return p.ovr + card_types[p.type].order * 4 + (1 if p.rare else 0)

# ---------- colours for rarities (card rendering) ----------
## returns {top, mid, bot, text, trim, glow}
func rarity_style(key: String) -> Dictionary:
	match key:
		"bronze": return {"top": Color("#e2b48c"), "mid": Color("#b07a4f"), "bot": Color("#7d4f2c"), "text": Color("#2a1606"), "trim": Color(0.31, 0.16, 0.04, 0.45), "glow": Color("#e2b48c")}
		"bronze-rare": return {"top": Color("#f0c49c"), "mid": Color("#b8784a"), "bot": Color("#6e3f1d"), "text": Color("#251202"), "trim": Color(1, 0.86, 0.75, 0.7), "glow": Color("#f0c49c"), "shards": true}
		"silver": return {"top": Color("#f1f3f6"), "mid": Color("#b9c1cb"), "bot": Color("#8b95a3"), "text": Color("#1c232c"), "trim": Color(0.16, 0.2, 0.24, 0.35), "glow": Color("#ffffff")}
		"silver-rare": return {"top": Color("#ffffff"), "mid": Color("#c4ccd6"), "bot": Color("#7f8a99"), "text": Color("#141a21"), "trim": Color(1, 1, 1, 0.9), "glow": Color("#ffffff"), "shards": true}
		"gold": return {"top": Color("#f8e4a6"), "mid": Color("#e0be62"), "bot": Color("#b88f2e"), "text": Color("#2a1d02"), "trim": Color(0.35, 0.24, 0, 0.35), "glow": Color("#ffe28a")}
		"gold-rare": return {"top": Color("#fff3c4"), "mid": Color("#f0c94e"), "bot": Color("#c3901c"), "text": Color("#241800"), "trim": Color("#fffadc"), "glow": Color("#ffd34a"), "shards": true}
		"totw": return {"top": Color("#2a2a2a"), "mid": Color("#0b0b0b"), "bot": Color("#1d1a12"), "text": Color("#f3d88a"), "trim": Color("#d9b25c"), "glow": Color("#f3c64a"), "shards": true, "shard_col": Color(0.91, 0.71, 0.19, 0.2)}
		"promo": return {"top": Color("#3a1268"), "mid": Color("#120a2e"), "bot": Color("#08142e"), "text": Color("#ffe6f6"), "trim": Color("#ff4fa3"), "glow": Color("#ff4fa3"), "shards": true, "shard_col": Color(1, 0.31, 0.64, 0.25)}
		"found": return {"top": Color("#1d5d5a"), "mid": Color("#0c2c32"), "bot": Color("#081d22"), "text": Color("#dffff8"), "trim": Color("#6ff3dc"), "glow": Color("#3fe0c5"), "shards": true, "shard_col": Color(0.47, 1, 0.9, 0.22)}
		"hero": return {"top": Color("#6b2ea6"), "mid": Color("#3a1666"), "bot": Color("#24093f"), "text": Color("#fff2c2"), "trim": Color("#ffd23f"), "glow": Color("#ffd23f"), "shards": true, "shard_col": Color(1, 0.82, 0.25, 0.2)}
		"potm": return {"top": Color("#ffe08a"), "mid": Color("#5b1fb0"), "bot": Color("#140733"), "text": Color("#fff8e6"), "trim": Color("#ffd36b"), "glow": Color("#b36bff"), "shards": true, "shard_col": Color(1, 0.85, 0.42, 0.22)}
		"rising": return {"top": Color("#8af4ff"), "mid": Color("#2140c9"), "bot": Color("#0a0d3a"), "text": Color("#f2fbff"), "trim": Color("#a8f7ff"), "glow": Color("#4fd1ff"), "shards": true, "shard_col": Color(0.66, 0.97, 1, 0.22)}
		"pass": return {"top": Color("#ff6a3d"), "mid": Color("#8c0f24"), "bot": Color("#1c0410"), "text": Color("#fff1e0"), "trim": Color("#ffc76b"), "glow": Color("#ff5a36"), "shards": true, "shard_col": Color(1, 0.78, 0.42, 0.25)}
		"fright": return {"top": Color("#ff7a1a"), "mid": Color("#3a0f4a"), "bot": Color("#0b0410"), "text": Color("#ffe9c7"), "trim": Color("#ff8a1f"), "glow": Color("#ff7a1a"), "shards": true, "shard_col": Color(1, 0.55, 0.1, 0.22)}
		"nltotg": return {"top": Color("#ffffff"), "mid": Color("#e9edf5"), "bot": Color("#c9d3e6"), "text": Color("#10204a"), "trim": Color("#1a3a8f"), "glow": Color("#ffd23f"), "shards": false}
		"rtk": return {"top": Color("#1d3a8a"), "mid": Color("#071436"), "bot": Color("#020818"), "text": Color("#f2f6ff"), "trim": Color("#b9d2ff"), "glow": Color("#4f86ff"), "shards": true, "shard_col": Color(0.72, 0.82, 1, 0.16)}
		"blackout": return {"top": Color("#1c2638"), "mid": Color("#05070c"), "bot": Color("#0b1626"), "text": Color("#eaffff"), "trim": Color("#36f0ff"), "glow": Color("#36f0ff"), "shards": true, "shard_col": Color(1, 0.92, 0.2, 0.18)}
		"phantom": return {"top": Color("#c8f7ff"), "mid": Color("#3b4a7a"), "bot": Color("#0d1022"), "text": Color("#f0fbff"), "trim": Color("#9ff1ff"), "glow": Color("#7fe8ff"), "shards": true, "shard_col": Color(0.75, 0.97, 1, 0.2)}
		"gallery": return {"top": Color("#1a1430"), "mid": Color("#0a0814"), "bot": Color("#2a0f3a"), "text": Color("#ffe9fb"), "trim": Color("#ff6fd8"), "glow": Color("#ff6fd8"), "shards": false}
		"icon": return {"top": Color("#fffaf0"), "mid": Color("#eadcb8"), "bot": Color("#c6aa6a"), "text": Color("#3b2c0c"), "trim": Color("#b8913a"), "glow": Color("#fff3c4"), "shards": true, "shard_col": Color(1, 1, 1, 0.4)}
	return rarity_style("gold")

func ovr_color(p: Dictionary) -> Color:
	if p.type == "pass": return Color("#ff6a3d")
	if p.type == "rising": return Color("#4fd1ff")
	if p.type == "potm": return Color("#b36bff")
	if p.type == "gallery": return Color("#ff6fd8")
	if p.type == "fright": return Color("#ff7a1a")
	if p.type == "blackout": return Color("#36f0ff")
	if p.type == "rtk": return Color("#4f86ff")
	if p.type == "nltotg": return Color("#1a3a8f")
	if p.type == "phantom": return Color("#7fe8ff")
	if p.type != "base": return Color("#b04fd6")
	match tier_of(p.ovr):
		"gold": return Color("#e0be62")
		"silver": return Color("#b9c1cb")
	return Color("#b07a4f")

func _ints(v):
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if v == floor(v) and abs(v) < 9.0e15 else v
		TYPE_DICTIONARY:
			for k in v.keys(): v[k] = _ints(v[k])
			return v
		TYPE_ARRAY:
			for i in v.size(): v[i] = _ints(v[i])
			return v
	return v
