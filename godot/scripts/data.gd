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
const HAIRC := ["#141010", "#2d1d12", "#5a3a1e", "#8a5a2b", "#c99a4b", "#d9c38a", "#6b6b6b"]
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

func P(id: String) -> Dictionary:
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

func base_value(p: Dictionary) -> int:
	var v = 0.0
	if p.ovr < 71: v = 150 + (p.ovr - 58) * 15
	elif p.ovr < 76: v = 350 + (p.ovr - 71) * 60 + (150 if p.rare else 0)
	else: v = round(750 * pow(1.38, p.ovr - 76)) + (400 if p.rare else 0)
	var mult: float = {"base": 1.0, "totw": 2.2, "found": 1.6, "promo": 3.0, "hero": 3.5, "icon": 4.5}.get(p.type, 1.0)
	var pos_m: float = {"ST": 1.2, "LW": 1.15, "RW": 1.15, "CAM": 1.1, "CB": 1.05, "GK": 0.8, "CF": 1.1}.get(p.pos, 1.0)
	return max(150, int(round(v * mult * pos_m / 50.0)) * 50)

func quick_sell_value(p: Dictionary) -> int:
	return max(50, int(round(base_value(p) * 0.08 / 10.0)) * 10)

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
		"icon": return {"top": Color("#fffaf0"), "mid": Color("#eadcb8"), "bot": Color("#c6aa6a"), "text": Color("#3b2c0c"), "trim": Color("#b8913a"), "glow": Color("#fff3c4"), "shards": true, "shard_col": Color(1, 1, 1, 0.4)}
	return rarity_style("gold")

func ovr_color(p: Dictionary) -> Color:
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
