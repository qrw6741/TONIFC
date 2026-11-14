extends Node
## Gem SBCs ("Streamlined SBCs"): every item has a Gem score. Select pre-filtered players
## from your club until you reach the target score, submit, get the reward.

const MAX_ITEMS := 0   # 0 = no limit: submit as many players as you like

## Player of the Month — SBC-only cards. [base id, boost, league label, gem target]
const POTM := [["p230", 4, "Premier League", 1500000], ["p444", 4, "LaLiga", 1500000], ["p1523", 4, "Ligue 1", 1200000], ["p1189", 4, "Bundesliga", 1200000], ["p807", 4, "Serie A", 750000]]

func _ready() -> void:
	Data.packs["pp76"] = {"name": "76+ Gold Player Pack", "items": 1, "coins": 0, "points": 0, "art": "gold", "guar": [["ovr76", 1]], "w": {"ovr76": 1}, "desc": "1 gold player rated 76+.", "reward": true}
	var defs = [
		["ex_intro", "Exchanges", "Intro to Streamlined SBCs", "Submit any players worth 400 gems.", 400, {}, {"coins": 2500}, 1],
		["ex_bronze", "Exchanges", "Bronze Exchange", "Bronze players only.", 280, {"tiers": ["bronze"]}, {"pack": "silver"}, 99],
		["ex_silver", "Exchanges", "Silver Exchange", "Silver players only.", 525, {"tiers": ["silver"]}, {"pack": "gold"}, 99],
		["ex_reroll", "Exchanges", "Bronze and Silver Re-roll", "Bronze and silver players only.", 560, {"tiers": ["bronze", "silver"]}, {"pack": "pp76"}, 99],
		["ex_gold", "Exchanges", "Gold Exchange", "Regular gold players only.", 2500, {"tiers": ["gold"], "base_only": true}, {"pack": "premium"}, 99],
		["ex_rare", "Exchanges", "Rare Exchange", "Any players.", 4000, {}, {"pack": "rare"}, 10],
		["ex_83", "Exchanges", "83+ x2 Upgrade", "Any players.", 6000, {}, {"pack": "pp83x2"}, 5],
		["ex_82", "Exchanges", "82+ x5 Upgrade", "Any players.", 8000, {}, {"pack": "pp82x5"}, 3],
		["ex_special", "Exchanges", "Special Exchange", "You'll need special cards to hit this score.", 20000, {}, {"pack": "pick84"}, 2],
		["ex_rs", "Rising Stars", "Rising Stars Exchange", "Any players — streamlined.", 4000, {}, {"pack": "rspack"}, 3]]
	# POTM cards + their SBCs
	Data.card_types["potm"] = {"name": "Player of the Month", "order": 4}
	Data.tier_label["potm"] = "Player of the Month"
	for a in POTM:
		var b: Dictionary = Data.by_id.get(a[0], {})
		if b.is_empty(): continue
		var pm: Dictionary = b.duplicate(true)
		pm.id = "potm_" + a[0]; pm.base = a[0]; pm.type = "potm"; pm.rare = true; pm.potm_league = a[2]
		pm.ovr = min(96, int(b.ovr) + int(a[1]))
		var stt = []
		for i in 6: stt.append(min(99, int(b.stats[i]) + int(a[1]) + (1 if int(b.stats[i]) >= 80 else 0)))
		pm.stats = stt; pm.sm = min(5, int(b.sm) + 1)
		Data.players.append(pm); Data.by_id[pm.id] = pm; Data.by_club[pm.club].append(pm)
		defs.append(["potm_" + a[0], "POTM", "POTM %s" % Data.short_name(b.name), "%s Player of the Month. Submit players worth %s gems." % [a[2], Sys.fmt(a[3])], a[3], {}, {"player": pm.id}, 1])
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

func limit_text() -> String: return "unlimited" if MAX_ITEMS == 0 else str(MAX_ITEMS)
func full(n: int) -> bool: return MAX_ITEMS > 0 and n >= MAX_ITEMS

func score(uids: Array) -> int:
	var t = 0
	for u in uids: t += Gallery.gems(Data.P(Sys.item(u).get("pid", "")))
	return t

## cheapest set of eligible items that reaches the target: duplicates first, then lowest gems,
## then drop any item that isn't needed and swap the last pick for the smallest one that still closes the gap
func autofill(sbc: Dictionary, include_squad := false) -> Array:
	var items: Array = Save.data.club.filter(func(it): return eligible(sbc, it, include_squad))
	var dupes = {}
	for it in Sys.duplicates(): dupes[it.uid] = true
	var gm = func(it) -> int: return Gallery.gems(Data.P(it.pid))
	items.sort_custom(func(a, b):
		var da = 0 if dupes.has(a.uid) else 1; var db = 0 if dupes.has(b.uid) else 1
		if da != db: return da < db
		return gm.call(a) < gm.call(b))
	var target: int = int(sbc.target)
	var out = []; var tot = 0
	for it in items:
		if tot >= target: break
		var gap = target - tot
		# if one remaining item can close the gap on its own, take the smallest such item
		var closer = null
		for c in items:
			if out.has(c) or gm.call(c) < gap: continue
			if closer == null or gm.call(c) < gm.call(closer): closer = c
		if closer != null and gm.call(closer) <= gm.call(it) * 2: out.append(closer); tot += gm.call(closer); break
		if out.has(it): continue
		out.append(it); tot += gm.call(it)
	# trim items that aren't needed
	out.sort_custom(func(a, b): return gm.call(a) > gm.call(b))
	var i = 0
	while i < out.size():
		if tot - gm.call(out[i]) >= target: tot -= gm.call(out[i]); out.remove_at(i)
		else: i += 1
	if tot < target or (MAX_ITEMS > 0 and out.size() > MAX_ITEMS): return []
	return out.map(func(it): return it.uid)

func submit(sbc: Dictionary, uids: Array) -> bool:
	if score(uids) < int(sbc.target) or (MAX_ITEMS > 0 and uids.size() > MAX_ITEMS) or not Sys.sbc_available(sbc): Sfx.play("error"); return false
	for u in uids: Sys.club_remove(u)
	Save.data.sbc.done[sbc.id] = Sys.sbc_count(sbc.id) + 1
	Save.data.stats.sbcs += 1
	Sys.grant(sbc.reward, "SBC: " + sbc.name)
	Season.add_xp(300, "SBC")
	Sys.track("sbc"); Sys.history('Completed SBC "%s"' % sbc.name)
	Save.dirty(); return true
