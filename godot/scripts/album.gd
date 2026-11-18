extends Node
## ALBUM — a sticker book. One page per big football nation (its 12 best players) plus an Icons page.
## A sticker is collected the moment any version of that player (gold, TOTW, promo…) has been in your club.
## Half a page and a full page pay rewards, and so do album milestones (total stickers).

const PER_PAGE := 12
const PAGE_COUNT := 16
const HALF := 6
const MILESTONES := [[25, {"pack": "mega"}], [60, {"pack": "pp83x2", "coins": 20000}], [100, {"pack": "pick86"}], [150, {"pack": "pick88", "coins": 50000}], [200, {"pack": "pickhero"}], [-1, {"pack": "pickicon", "coins": 100000}]]

var pages = []      # [{id, name, kind, code, pids}]
var _total = 0

var _cache_save = null
func _ready() -> void:
	Gallery.changed.connect(func(): _dirty = true)
	# nations with the most strong players get a page
	var by_nat = {}
	for p in Data.players:
		if p.type != "base" or p.club == "ICN" or p.club == "HER": continue
		if not by_nat.has(p.nat): by_nat[p.nat] = []
		by_nat[p.nat].append(p)
	var nats: Array = by_nat.keys()
	nats.sort_custom(func(a, b): return _strength(by_nat[a]) > _strength(by_nat[b]))
	for i in min(PAGE_COUNT, nats.size()):
		var code: String = nats[i]
		var ps: Array = by_nat[code].duplicate(); ps.sort_custom(func(a, b): return a.ovr > b.ovr)
		pages.append({"id": "nat_" + code, "name": Data.nations.get(code, {}).get("name", code), "kind": "nat", "code": code, "pids": ps.slice(0, PER_PAGE).map(func(p): return p.id), "big": i < 5})
	var icons: Array = Data.players.filter(func(p): return p.type == "icon"); icons.sort_custom(func(a, b): return a.ovr > b.ovr)
	pages.append({"id": "icons", "name": "Icons", "kind": "icon", "code": "ICN", "pids": icons.slice(0, PER_PAGE).map(func(p): return p.id), "big": true})
	for pg in pages: _total += pg.pids.size()

func _strength(ps: Array) -> float:
	var r: Array = ps.map(func(p): return int(p.ovr)); r.sort(); r.reverse()
	var s = 0.0
	for k in min(12, r.size()): s += r[k]
	return s + min(12, r.size()) * 100.0

func st() -> Dictionary:
	var d = Save.data
	if d == null: return {}
	if typeof(d.get("album")) != TYPE_DICTIONARY: d.album = {"claimed": {}, "ms": 0}
	return d.album

## any version of the player counts (special cards remember their base id)
var _cache = {}; var _dirty = true
func have(base_pid: String) -> bool:
	if _dirty or Save.data != _cache_save:
		_dirty = false; _cache_save = Save.data; _cache = {}
		for k in Gallery.st().get("seen", {}):
			var p: Dictionary = Data.P(k)
			if p.is_empty(): continue
			_cache[k] = true
			if p.has("base"): _cache[str(p.base)] = true
	return _cache.has(base_pid)

func page_count(pg: Dictionary) -> int:
	var n = 0
	for pid in pg.pids: if have(pid): n += 1
	return n
func total_have() -> int:
	var n = 0
	for pg in pages: n += page_count(pg)
	return n
func total() -> int: return _total

func page_reward(pg: Dictionary, full: bool) -> Dictionary:
	if pg.kind == "icon": return {"pack": "pickicon", "coins": 50000} if full else {"pack": "pickhero"}
	if full: return {"pack": "pick86" if pg.big else "pick84", "coins": 25000}
	return {"pack": "premium", "coins": 5000}

func claimed(pg: Dictionary, full: bool) -> bool: return st().claimed.has(pg.id + ("_full" if full else "_half"))
func can_claim(pg: Dictionary, full: bool) -> bool:
	return not claimed(pg, full) and page_count(pg) >= (pg.pids.size() if full else HALF)
func claim(pg: Dictionary, full: bool) -> bool:
	if not can_claim(pg, full): return false
	st().claimed[pg.id + ("_full" if full else "_half")] = true
	Sys.grant(page_reward(pg, full), "Album: %s" % pg.name)
	Save.dirty(); return true

func ms_target(i: int) -> int: return total() if int(MILESTONES[i][0]) < 0 else int(MILESTONES[i][0])
func ms_claimable() -> int:
	var n = 0
	for i in MILESTONES.size(): if i >= int(st().ms) and total_have() >= ms_target(i): n += 1
	return n
func claim_milestones() -> int:
	var n = 0
	while int(st().ms) < MILESTONES.size() and total_have() >= ms_target(int(st().ms)):
		Sys.grant(MILESTONES[int(st().ms)][1], "Album milestone"); st().ms = int(st().ms) + 1; n += 1
	if n: Save.dirty()
	return n
func claimable_count() -> int:
	var n = ms_claimable()
	for pg in pages:
		if can_claim(pg, false): n += 1
		if can_claim(pg, true): n += 1
	return n
