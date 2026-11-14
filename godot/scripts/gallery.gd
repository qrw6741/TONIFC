extends Node
## FUT Gallery (FC 27-style collection book).
## Every player item that passes through your club is RECORDED (never consumed).
## Each item is worth Gems (by rating & rarity). Sets — one per top-5 league and one per
## top-6 club of each league — only count the items YOU place in them (Upgrade). Score = Gems + bonus tags,
## graded D / C / B / A / S. Each new grade pays Gallery Tokens + coins once.
## Total set score builds your Gallery Level (25 levels, milestone every 5).

signal changed

const LEAGUES := ["ENG1", "ESP1", "ITA1", "GER1", "FRA1"]
const GRADES := ["D", "C", "B", "A", "S"]
const GRADE_FRAC := [0.0, 0.45, 0.7, 0.95, 1.3]          # of the set's best-base-items score; S needs special cards (D = all slots filled)
const CLUB_SLOTS := 11
const LEAGUE_SLOTS := 15
const CLUB_TOKENS := [10, 20, 35, 60, 100]
const LEAGUE_TOKENS := [25, 50, 90, 150, 250]
const LEVEL_PTS := 800000
const MAX_LEVEL := 25
const RARITY_MULT := {"base": 1.0, "found": 1.5, "totw": 2.0, "promo": 2.5, "hero": 3.0, "pass": 3.0, "rising": 2.5, "icon": 4.0, "gallery": 3.5}

var top_clubs = {}      # league -> [club codes] (top 6 by squad strength)
var _max_cache = {}

func _ready() -> void:
	for lg in LEAGUES:
		var clubs: Array = Data.clubs.keys().filter(func(c): return Data.clubs[c].lg == lg and Data.by_club.has(c))
		clubs.sort_custom(func(a, b): return _club_strength(a) > _club_strength(b))
		top_clubs[lg] = clubs.slice(0, 6)
	# Gallery Token Store picks
	var rp = func(name: String, tier: String, desc: String) -> Dictionary:
		return {"name": name, "items": 1, "coins": 0, "points": 0, "art": "gallery", "guar": [[tier, 1]], "w": {tier: 1}, "desc": desc, "reward": true, "pick": {"n": 3, "tier": tier}}
	Data.packs["pickhero"] = rp.call("Hero Player Pick", "hero", "Choose 1 of 3 Hero players.")
	Data.packs["pickicon"] = rp.call("Icon Player Pick", "icon", "Choose 1 of 3 Icons.")
	Data.tier_label["hero"] = "Hero"; Data.tier_label["icon"] = "Icon"
	_make_gallery_cards()

## Gallery-exclusive rarity: 5 untradeable cards of retired players who were underrated in their prime,
## bought only with Gallery Tokens. [id, name, nat, league, pos, alt, ovr, stats, sm, wf, foot, height, age, workrates, face, cost]
const GALLERY_CARDS := [
	["gal_carrick", "Michael Carrick", "ENG", "ENG1", "CDM", ["CM", "CB"], 86, [66, 72, 90, 81, 82, 77], 3, 4, "R", 189, 45, ["M", "H"], {"skin": 1, "hair": 1, "hairC": 1, "beard": 0, "brow": 1, "seed": 3101}, 900],
	["gal_kuyt", "Dirk Kuyt", "NED", "ENG1", "RW", ["ST", "RM"], 85, [80, 82, 79, 81, 56, 86], 3, 4, "R", 183, 46, ["H", "H"], {"skin": 0, "hair": 2, "hairC": 3, "beard": 0, "brow": 0, "seed": 3102}, 1000],
	["gal_arteta", "Mikel Arteta", "ESP", "ENG1", "CM", ["CDM", "CAM"], 85, [72, 77, 89, 86, 71, 70], 4, 4, "R", 176, 44, ["M", "M"], {"skin": 2, "hair": 1, "hairC": 0, "beard": 1, "brow": 1, "seed": 3103}, 1000],
	["gal_king", "Ledley King", "ENG", "ENG1", "CB", [], 86, [81, 50, 66, 70, 89, 86], 2, 3, "L", 188, 46, ["M", "H"], {"skin": 6, "hair": 0, "hairC": 0, "beard": 1, "brow": 1, "seed": 3104}, 1100],
	["gal_sneijder", "Wesley Sneijder", "NED", "ITA1", "CAM", ["CM"], 87, [76, 87, 91, 88, 50, 70], 4, 5, "R", 170, 42, ["H", "M"], {"skin": 0, "hair": 0, "hairC": 3, "beard": 0, "brow": 0, "seed": 3105}, 1300]]
## first version of the Gallery cards (boosted current players) — kept only so existing saves stay valid
const GALLERY_LEGACY := [["p226", 87], ["p834", 87], ["p485", 87], ["p1524", 87], ["p1233", 88]]
func _make_gallery_cards() -> void:
	Data.card_types["gallery"] = {"name": "Gallery", "order": 5}
	Data.clubs["GAL"] = {"name": "Gallery Legends", "lg": null, "c": ["#1a1430", "#ff6fd8"], "special": true}
	for g in GALLERY_CARDS:
		var p = {"id": g[0], "name": g[1], "nat": g[2], "lg": g[3], "club": "GAL", "pos": g[4], "alt": g[5], "ovr": g[6], "stats": g[7], "sm": g[8], "wf": g[9],
			"foot": g[10], "height": g[11], "age": g[12], "wr": g[13], "face": g[14], "type": "gallery", "rare": true}
		Data.players.append(p); Data.by_id[p.id] = p
	for g in GALLERY_LEGACY:
		var b: Dictionary = Data.by_id.get(g[0], {})
		if b.is_empty(): continue
		var p: Dictionary = b.duplicate(true)
		var boost: int = max(1, int(g[1]) - int(b.ovr))
		p.id = "gal_" + b.id; p.base = b.id; p.type = "gallery"; p.rare = true; p.ovr = int(g[1])
		var stt = []
		for i in 6: stt.append(min(99, int(b.stats[i]) + boost + (1 if int(b.stats[i]) >= 80 else 0)))
		p.stats = stt; p.sm = min(5, int(b.sm) + 1)
		Data.players.append(p); Data.by_id[p.id] = p
func gallery_cards() -> Array: return GALLERY_CARDS.map(func(g): return Data.P(g[0])).filter(func(p): return not p.is_empty())

func _club_strength(c: String) -> float:
	var r: Array = Data.by_club[c].filter(func(p): return p.type == "base").map(func(p): return p.ovr)
	r.sort(); r.reverse()
	var s = 0.0
	for i in min(11, r.size()): s += r[i]
	return s

# ------------------------------------------------------------------ gems
## how many Gems a player item is worth in the Gallery
## how many Gems a player item is worth (FC-style item score — used by Gem SBCs and the Gallery)
## bronze ~10k–15k · silver ~22k–26k · gold ~34k–69k · special cards 80k+ (×100 scale)
func gems(p: Dictionary) -> int:
	if p.is_empty(): return 0
	var o: int = int(p.ovr)
	if p.type != "base": return max(800, 860 + (o - 85) * 30) * 100
	var g = 0
	match Data.tier_of(o):
		"bronze": g = 100 + max(0, o - 55) * 5
		"silver": g = 220 + (o - 71) * 8
		_: g = 340 + (o - 76) * 22
	if p.rare: g += 20
	return g * 100

# ------------------------------------------------------------------ state
func st() -> Dictionary:
	var d = Save.data
	if d == null: return {}
	if typeof(d.get("gallery")) != TYPE_DICTIONARY:
		d.gallery = {"seen": {}, "grades": {}, "tokens": 0, "level_claimed": 0, "bought": {}, "placed": {}}
		for it in d.club: record(it.pid, it.get("src", "pack"), true)
	if not d.gallery.has("placed"):
		# older saves: sets that were already graded keep their items; everything else starts empty
		d.gallery.placed = {}
		for id in set_ids():
			if int(d.gallery.grades.get(id, -1)) >= 0: d.gallery.placed[id] = best_items(id).map(func(p): return p.id)
	return d.gallery

func tokens() -> int: return int(st().tokens)

## record an item in the Gallery. First Owner = obtained from packs/rewards (not the market)
func record(pid: String, src := "", silent := false) -> void:
	var s = st()
	if s.is_empty() or Data.P(pid).is_empty(): return
	var first: bool = not ["market", "auction"].has(src)
	var prev: int = int(s.seen.get(pid, 0))
	var nv: int = 2 if first else 1
	if nv > prev: s.seen[pid] = nv
	if not silent: Save.dirty(); changed.emit()

func seen(pid: String) -> bool: return st().seen.has(pid)
func first_owner(pid: String) -> bool: return int(st().seen.get(pid, 0)) == 2

# ------------------------------------------------------------------ sets
func set_ids() -> Array:
	var out = []
	for lg in LEAGUES:
		out.append("L:" + lg)
		for c in top_clubs[lg]: out.append("C:" + c)
	return out

func set_title(id: String) -> String:
	var code = id.substr(2)
	return Data.leagues[code].name if id.begins_with("L:") else Data.clubs[code].name
func set_slots(id: String) -> int: return LEAGUE_SLOTS if id.begins_with("L:") else CLUB_SLOTS
func _fits(id: String, p: Dictionary) -> bool:
	var code = id.substr(2)
	return p.lg == code if id.begins_with("L:") else p.club == code
func set_tokens(id: String) -> Array: return LEAGUE_TOKENS if id.begins_with("L:") else CLUB_TOKENS

## every player in the database that belongs to this set (the "album")
func album(id: String) -> Array:
	var code = id.substr(2)
	var pool: Array = Data.players.filter(func(p): return p.lg == code) if id.begins_with("L:") else Data.by_club.get(code, []).duplicate()
	pool.sort_custom(func(a, b): return gems(a) > gems(b))
	return pool

## items you've placed in this set (in slot order, "" = empty slot)
func placed_ids(id: String) -> Array:
	var a: Array = st().placed.get(id, []).duplicate()
	while a.size() < set_slots(id): a.append("")
	return a.slice(0, set_slots(id))
func placed_items(id: String) -> Array:
	return placed_ids(id).filter(func(x): return x != "" and not Data.P(x).is_empty()).map(func(x): return Data.P(x))
func place(id: String, slot: int, pid: String) -> void:
	var a = placed_ids(id)
	var key: String = Data.P(pid).get("base", pid) if pid != "" else ""
	for i in a.size():   # one version of each real player per set
		if a[i] != "" and i != slot and Data.P(a[i]).get("base", a[i]) == key: a[i] = ""
	a[slot] = pid
	st().placed[id] = a; Save.dirty(); changed.emit()
## items you could place in this set (recorded, fits, best version per player)
func eligible(id: String) -> Array:
	var by_base = {}
	for pid in st().seen:
		var p = Data.P(pid)
		if p.is_empty() or not _fits(id, p): continue
		var key: String = p.get("base", p.id)
		if not by_base.has(key) or gems(p) > gems(by_base[key]): by_base[key] = p
	var arr: Array = by_base.values()
	arr.sort_custom(func(a, b): return gems(a) > gems(b))
	return arr
## Upgrade: put your best recorded items into the set (you choose when)
func upgrade(id: String) -> int:
	var before: int = score(id).total
	st().placed[id] = best_items(id).map(func(p): return p.id)
	Save.dirty(); changed.emit()
	return score(id).total - before
func upgrade_gain(id: String) -> int:
	var b = 0
	for p in best_items(id): b += gems(p)
	var c = 0
	for p in placed_items(id): c += gems(p)
	return max(0, b - c)

## best recorded items for this set (one per real player)
func best_items(id: String) -> Array:
	var by_base = {}
	for pid in st().seen:
		var p = Data.P(pid)
		if p.is_empty() or not _fits(id, p): continue
		var key: String = p.get("base", p.id)
		if not by_base.has(key) or gems(p) > gems(by_base[key]): by_base[key] = p
	var arr: Array = by_base.values()
	arr.sort_custom(func(a, b): return gems(a) > gems(b))
	return arr.slice(0, set_slots(id))

## max reference score: the best base items in the database for this set
func max_score(id: String) -> int:
	if _max_cache.has(id): return _max_cache[id]
	var base: Array = album(id).filter(func(p): return p.type == "base")
	var t = 0
	for i in min(set_slots(id), base.size()): t += gems(base[i])
	_max_cache[id] = max(1, t)
	return _max_cache[id]

func tags(items: Array) -> Array:
	## [[name, pct, active]]
	var out = []
	var sp = items.filter(func(p): return p.type != "base").size()
	var pct_sp = 15 if sp >= 7 else (8 if sp >= 4 else (4 if sp >= 2 else 0))
	out.append(["Special items (2+/4+/7+)", pct_sp, pct_sp > 0])
	var fo = items.filter(func(p): return first_owner(p.id)).size()
	var pct_fo = 10 if items.size() > 0 and fo * 2 >= items.size() else 0
	out.append(["First Owner (half from packs & rewards)", pct_fo, pct_fo > 0])
	var golden = items.size() > 0 and items.all(func(p): return p.ovr >= 76)
	out.append(["Golden (every item 76+)", 5 if golden else 0, golden])
	var nats = {}
	for p in items: nats[p.nat] = nats.get(p.nat, 0) + 1
	var mx = 0
	for k in nats: mx = max(mx, nats[k])
	out.append(["Same Nation (5+ from one nation)", 6 if mx >= 5 else 0, mx >= 5])
	return out

func score(id: String) -> Dictionary:
	var items = placed_items(id)
	var base = 0
	for p in items: base += gems(p)
	var tg = tags(items)
	var pct = 0
	for t in tg: pct += int(t[1])
	var total: int = base + int(round(base * pct / 100.0))
	var full: bool = items.size() >= set_slots(id)
	var g = -1
	if full:
		for i in GRADES.size():
			if total >= int(GRADE_FRAC[i] * max_score(id)): g = i
	var nxt = -1
	if g < GRADES.size() - 1 and full: nxt = int(GRADE_FRAC[g + 1] * max_score(id))
	return {"items": items, "base": base, "pct": pct, "total": total, "grade": g, "next": nxt, "full": full, "tags": tg}

func grade_letter(g: int) -> String: return "–" if g < 0 else GRADES[g]
func claimed_grade(id: String) -> int: return int(st().grades.get(id, -1))
func claimable(id: String) -> bool: return score(id).grade > claimed_grade(id)

## grade a set: pays every newly reached grade once
func grade(id: String) -> Dictionary:
	var sc = score(id)
	var from = claimed_grade(id)
	if sc.grade <= from: return {"tokens": 0, "coins": 0}
	var tk = 0
	for g in range(from + 1, sc.grade + 1): tk += set_tokens(id)[g]
	st().grades[id] = sc.grade
	st().tokens = tokens() + tk
	var coins = tk * 40
	Sys.add("coins", coins, "Gallery grade %s · %s" % [GRADES[sc.grade], set_title(id)])
	Sys.history("Gallery: %s graded %s" % [set_title(id), GRADES[sc.grade]])
	Save.dirty(); check_level(); changed.emit()
	return {"tokens": tk, "coins": coins, "grade": sc.grade}

func grade_all() -> Dictionary:
	var tk = 0; var n = 0
	Sys.quiet = true
	for id in set_ids():
		var r = grade(id)
		if r.tokens > 0: tk += r.tokens; n += 1
	Sys.quiet = false
	return {"tokens": tk, "sets": n}

# ------------------------------------------------------------------ level
func total_score() -> int:
	var t = 0
	for id in set_ids(): t += score(id).total
	return t
func level() -> int: return min(MAX_LEVEL, total_score() / LEVEL_PTS)
func level_reward(lv: int) -> Dictionary:
	match lv:
		5: return {"pack": "pick84"}
		10: return {"pack": "rare"}
		15: return {"pack": "pick86"}
		20: return {"pack": "pickhero"}
		25: return {"pack": "pickicon"}
	return {"coins": 1000 + lv * 250}
func check_level() -> void:
	var s = st(); var lv = level()
	while int(s.level_claimed) < lv:
		s.level_claimed = int(s.level_claimed) + 1
		var L: int = s.level_claimed
		Sys.grant(level_reward(L), "Gallery Level %d" % L)
		Sys.toast.emit("Gallery Level %d reached!" % L, "good")
	Save.dirty()

# ------------------------------------------------------------------ token store
const STORE := [
	{"id": "coins", "name": "5,000 Coins", "cost": 60, "limit": 0, "reward": {"coins": 5000}},
	{"id": "rare", "name": "Rare Players Pack", "cost": 120, "limit": 0, "reward": {"pack": "rare"}},
	{"id": "pp83", "name": "83+ x2 Players Pack", "cost": 200, "limit": 5, "reward": {"pack": "pp83x2"}},
	{"id": "pick84", "name": "84+ Player Pick", "cost": 350, "limit": 3, "reward": {"pack": "pick84"}},
	{"id": "pick86", "name": "86+ Player Pick", "cost": 800, "limit": 2, "reward": {"pack": "pick86"}},
	{"id": "hero", "name": "Hero Player Pick", "cost": 1400, "limit": 1, "reward": {"pack": "pickhero"}},
	{"id": "icon", "name": "Icon Player Pick", "cost": 2500, "limit": 1, "reward": {"pack": "pickicon"}}]

## store rows: the 5 Gallery cards first, then packs & picks
func store_items() -> Array:
	var out = []
	for g in GALLERY_CARDS:
		var p = Data.P(g[0])
		if p.is_empty(): continue
		out.append({"id": g[0], "name": "%d %s" % [p.ovr, Data.short_name(p.name)], "cost": int(g[15]), "limit": 1, "reward": {"player": p.id}, "card": true})
	return out + STORE

func bought(item_id: String) -> int: return int(st().bought.get(item_id, 0))
func can_buy(it: Dictionary) -> bool: return tokens() >= int(it.cost) and (int(it.limit) == 0 or bought(it.id) < int(it.limit))
func buy(it: Dictionary) -> bool:
	if not can_buy(it): Sfx.play("error"); return false
	st().tokens = tokens() - int(it.cost)
	st().bought[it.id] = bought(it.id) + 1
	Sys.grant(it.reward, "Gallery Token Store")
	Save.dirty(); changed.emit(); return true
