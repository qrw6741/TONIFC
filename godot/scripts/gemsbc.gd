extends Node
## Gem SBCs ("Streamlined SBCs"): every item has a Gem score. Select pre-filtered players
## from your club until you reach the target score, submit, get the reward.

const MAX_ITEMS := 11

func _ready() -> void:
	Data.packs["pp76"] = {"name": "76+ Gold Player Pack", "items": 1, "coins": 0, "points": 0, "art": "gold", "guar": [["ovr76", 1]], "w": {"ovr76": 1}, "desc": "1 gold player rated 76+.", "reward": true}
	var defs = [
		["ex_intro", "Exchanges", "Intro to Streamlined SBCs", "Submit any players worth 1,000 gems.", 1000, {}, {"coins": 2500}, 1],
		["ex_bronze", "Exchanges", "Bronze Exchange", "Bronze players only.", 900, {"tiers": ["bronze"]}, {"pack": "silver"}, 99],
		["ex_silver", "Exchanges", "Silver Exchange", "Silver players only.", 1800, {"tiers": ["silver"]}, {"pack": "gold"}, 99],
		["ex_reroll", "Exchanges", "Bronze and Silver Re-roll", "Bronze and silver players only.", 2200, {"tiers": ["bronze", "silver"]}, {"pack": "pp76"}, 99],
		["ex_gold", "Exchanges", "Gold Exchange", "Regular gold players only.", 2600, {"tiers": ["gold"], "base_only": true}, {"pack": "premium"}, 99],
		["ex_rare", "Exchanges", "Rare Exchange", "Any players.", 3800, {}, {"pack": "rare"}, 10],
		["ex_83", "Exchanges", "83+ x2 Upgrade", "Any players.", 5000, {}, {"pack": "pp83x2"}, 5],
		["ex_82", "Exchanges", "82+ x5 Upgrade", "Any players.", 5800, {}, {"pack": "pp82x5"}, 3],
		["ex_special", "Exchanges", "Special Exchange", "You'll need special cards to hit this score.", 7000, {}, {"pack": "pick84"}, 2],
		["ex_rs", "Rising Stars", "Rising Stars Exchange", "Any players — streamlined.", 6000, {}, {"pack": "rspack"}, 3]]
	for d in defs:
		Data.sbcs.append({"id": d[0], "cat": d[1], "name": d[2], "desc": d[3], "gem": true, "target": d[4], "filter": d[5], "reward": d[6], "repeat": d[7], "size": MAX_ITEMS, "reqs": []})

func filter_text(sbc: Dictionary) -> String:
	var f: Dictionary = sbc.get("filter", {})
	var parts = []
	if f.has("tiers"): parts.append(" / ".join(f.tiers.map(func(x): return x.capitalize())) + " only")
	if f.get("base_only", false): parts.append("no special cards")
	if f.has("max_ovr"): parts.append("max %d OVR" % f.max_ovr)
	return ", ".join(parts) if not parts.is_empty() else "Any players"

func eligible(sbc: Dictionary, it: Dictionary, include_squad := false) -> bool:
	var p = Data.P(it.pid)
	if p.is_empty() or Sys.in_market(it.uid) or Evo.busy(it.uid): return false
	if not include_squad and Sys.in_active_squad(it.uid): return false
	var f: Dictionary = sbc.get("filter", {})
	if f.has("tiers") and (p.type != "base" or not (f.tiers as Array).has(Data.tier_of(p.ovr))): return false
	if f.get("base_only", false) and p.type != "base": return false
	if f.has("max_ovr") and p.ovr > int(f.max_ovr): return false
	return true

func score(uids: Array) -> int:
	var t = 0
	for u in uids: t += Gallery.gems(Data.P(Sys.item(u).get("pid", "")))
	return t

## cheapest set of eligible items that reaches the target (duplicates first, then lowest gems)
func autofill(sbc: Dictionary, include_squad := false) -> Array:
	var items: Array = Save.data.club.filter(func(it): return eligible(sbc, it, include_squad))
	var dupes = {}
	for it in Sys.duplicates(): dupes[it.uid] = true
	items.sort_custom(func(a, b):
		var da = 0 if dupes.has(a.uid) else 1; var db = 0 if dupes.has(b.uid) else 1
		if da != db: return da < db
		return Gallery.gems(Data.P(a.pid)) < Gallery.gems(Data.P(b.pid)))
	var target: int = int(sbc.target)
	# greedy: take the cheapest until the remaining gap can be closed by one item, then pick the smallest item that closes it
	var out = []; var tot = 0
	var pool = items.duplicate()
	while tot < target and out.size() < MAX_ITEMS and not pool.is_empty():
		var gap = target - tot
		var closer = null
		if out.size() == MAX_ITEMS - 1 or true:
			for it in pool:
				if Gallery.gems(Data.P(it.pid)) >= gap and (closer == null or Gallery.gems(Data.P(it.pid)) < Gallery.gems(Data.P(closer.pid))): closer = it
		var slots_left = MAX_ITEMS - out.size()
		var take = pool[0]
		# if cheap items can't reach the target in the slots left, take the best closer / bigger items
		var cheap_max = 0
		for k in min(slots_left, pool.size()): cheap_max += Gallery.gems(Data.P(pool[k].pid))
		if closer != null and (Gallery.gems(Data.P(take.pid)) >= gap or cheap_max < gap or slots_left == 1): take = closer
		elif cheap_max < gap:
			pool.sort_custom(func(a, b): return Gallery.gems(Data.P(a.pid)) > Gallery.gems(Data.P(b.pid)))
			take = pool[0]
		out.append(take.uid); tot += Gallery.gems(Data.P(take.pid)); pool.erase(take)
	return out

func submit(sbc: Dictionary, uids: Array) -> bool:
	if score(uids) < int(sbc.target) or uids.size() > MAX_ITEMS or not Sys.sbc_available(sbc): Sfx.play("error"); return false
	for u in uids: Sys.club_remove(u)
	Save.data.sbc.done[sbc.id] = Sys.sbc_count(sbc.id) + 1
	Save.data.stats.sbcs += 1
	Sys.grant(sbc.reward, "SBC: " + sbc.name)
	Season.add_xp(300, "SBC")
	Sys.track("sbc"); Sys.history('Completed SBC "%s"' % sbc.name)
	Save.dirty(); return true
