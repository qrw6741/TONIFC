extends Node
## SYSTEMS — squads & chemistry, club, wallet & XP, packs, transfer market,
## objectives, SBCs and competitions (Squad Battles, Rivals, Champions, Draft).
## Prime Points are fictional in-game credits; there are no real-money purchases.

signal currency_changed
signal toast(msg: String, kind: String)
signal market_changed

const MARKET_TAX := 0.05
var _market_t = 0.0
var quiet = false
var market_ver = 0   # bumps when YOUR listings / bids change (screens refresh on it)   # suppress toasts during bulk actions

func now() -> float: return Time.get_unix_time_from_system()
func D(): return Save.data

# ------------------------------------------------------------------ random helpers
func pick(a: Array): return a[randi() % a.size()]
func chance(p: float) -> bool: return randf() < p
func rint(a: int, b: int) -> int: return randi_range(a, b)
func shuffled(a: Array) -> Array:
	var b = a.duplicate(); b.shuffle(); return b
func weighted(entries: Array):   # [[w, v], ...]
	var tot = 0.0
	for e in entries: tot += e[0]
	var r = randf() * tot
	for e in entries:
		r -= e[0]
		if r <= 0: return e[1]
	return entries[-1][1]
func uid() -> String: return str(Time.get_ticks_usec()) + str(randi() % 100000)

func fmt(n) -> String:
	var s = str(int(round(float(n))))
	var neg = s.begins_with("-")
	if neg: s = s.substr(1)
	var out = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + s + out

func fmt_time(sec: float) -> String:
	if sec <= 0: return "Expired"
	var s = int(sec); var h = s / 3600; var m = (s % 3600) / 60
	if h > 0: return "%dh %dm" % [h, m]
	if m > 0: return "%dm %ds" % [m, s % 60]
	return "%ds" % s

func day_key() -> String:
	var d = Time.get_date_dict_from_system(); return "%d-%d-%d" % [d.year, d.month, d.day]
func week_key() -> String:
	var unix = int(now()); var days = unix / 86400
	return "W%d" % ((days + 3) / 7)   # weeks start Monday
func secs_to_reset(kind: String) -> float:
	var t = now(); var day = 86400.0
	if kind == "daily": return day - fmod(t, day)
	var days = floor(t / day) + 3.0
	return (7.0 - fmod(days, 7.0)) * day - fmod(t, day)

# ------------------------------------------------------------------ formations & chemistry
var _link_cache = {}
func formation_links(f: String) -> Array:
	if _link_cache.has(f): return _link_cache[f]
	var pos: Array = Data.formations[f]
	var links = {}
	for i in pos.size():
		var a = pos[i]
		var near = []
		for j in pos.size():
			var b = pos[j]
			near.append([1e9 if i == j else Vector2(a[1] - b[1], (a[2] - b[2]) * 1.25).length(), j])
		near.sort_custom(func(x, y): return x[0] < y[0])
		var k = 2 if a[0] == "GK" else 3
		for n in near.slice(0, k):
			if n[0] < 45:
				var key = "%d-%d" % [min(i, n[1]), max(i, n[1])]
				links[key] = [min(i, n[1]), max(i, n[1])]
	_link_cache[f] = links.values()
	return _link_cache[f]

func _thr(n: int, t: Array) -> int:
	return 3 if n >= t[2] else (2 if n >= t[1] else (1 if n >= t[0] else 0))

## players: Array of Dictionary (or {} for empty)
func chemistry(formation: String, players: Array) -> Dictionary:
	var club = {}; var nat = {}; var lg = {}; var icons = 0
	for p in players:
		if p.is_empty(): continue
		if p.club != "ICN" and p.club != "HER" and p.club != "GAL": club[p.club] = club.get(p.club, 0) + 1
		nat[p.nat] = nat.get(p.nat, 0) + (2 if p.type == "icon" else 1)
		if p.type == "hero": lg[p.lg] = lg.get(p.lg, 0) + 2
		elif p.type != "icon": lg[p.lg] = lg.get(p.lg, 0) + 1
		if p.type == "icon": icons += 1
	var per = []
	var total = 0
	for i in players.size():
		var p: Dictionary = players[i]
		var c = 0
		if not p.is_empty():
			var slot_pos: String = Data.formations[formation][i][0]
			if not Data.fits_pos(p, slot_pos): c = 0
			elif p.type == "icon" or p.type == "hero" or p.type == "gallery": c = 3
			else:
				c = _thr(club.get(p.club, 0), [2, 5, 7]) + _thr(nat.get(p.nat, 0), [2, 5, 8]) + _thr(lg.get(p.lg, 0) + icons, [3, 5, 8])
				c = min(3, c)
		per.append(c); total += c
	var links = []
	for l in formation_links(formation):
		var A: Dictionary = players[l[0]]; var B: Dictionary = players[l[1]]
		var q = "none"
		if not A.is_empty() and not B.is_empty():
			var s = 0
			if A.club == B.club and A.club != "ICN" and A.club != "HER" and A.club != "GAL": s += 2
			if A.nat == B.nat: s += 1
			if A.lg == B.lg or A.type == "icon" or B.type == "icon": s += 1
			q = "green" if s >= 2 else ("yellow" if s == 1 else "red")
		links.append({"a": l[0], "b": l[1], "q": q})
	return {"per": per, "total": total, "links": links}

func squad_rating(players: Array) -> int:
	var r = []
	for p in players: r.append(0 if p.is_empty() else p.ovr)
	while r.size() < 11: r.append(0)
	var sum = 0.0
	for x in r: sum += x
	var avg = sum / 11.0
	var corr = 0.0
	for x in r: if x > avg: corr += x - avg
	return min(99, int(floor((sum + corr) / 11.0)))

func team_strength(formation: String, players: Array, chem = null) -> Dictionary:
	var g = {"ATT": [], "MID": [], "DEF": [], "GK": []}
	for i in players.size():
		var p: Dictionary = players[i]
		if p.is_empty(): continue
		var pos: String = Data.formations[formation][i][0]
		var c: int = chem.per[i] if chem else 3
		g[Data.pos_group[pos]].append(p.ovr - (0 if Data.fits_pos(p, pos) else 6) + (c - 1.5) * 1.2)
	var av = func(a: Array) -> float:
		if a.is_empty(): return 40.0
		var s = 0.0
		for x in a: s += x
		return s / a.size()
	return {"att": av.call(g.ATT), "mid": av.call(g.MID), "def": av.call(g.DEF), "gk": av.call(g.GK)}

# ------------------------------------------------------------------ club & squads
func club_items() -> Array: return D().club
func item(u: String) -> Dictionary:
	for it in D().club: if it.uid == u: return it
	return {}
func item_player(u: String) -> Dictionary:
	var it = item(u); return {} if it.is_empty() else Cons.item_view(it)
## only exclusive rarities are untradeable (Season Pass, Gallery, POTM, Evolutions) — everything else can be sold
const UNTRADEABLE_TYPES := ["pass", "gallery", "potm", "phantom"]
func exclusive(pid: String) -> bool:
	return UNTRADEABLE_TYPES.has(Data.P(pid).get("type", "")) or pid.begins_with("ev")
func club_add(pid: String, untr := false, src := "") -> Dictionary:
	var it = {"uid": uid(), "pid": pid, "untr": untr or exclusive(pid), "at": now(), "src": src}
	D().club.append(it); Gallery.record(pid, src); Save.dirty(); return it
func club_remove(u: String) -> void:
	D().club = D().club.filter(func(i): return i.uid != u)
	for s in D().squads:
		for k in s.slots.size(): if s.slots[k] == u: s.slots[k] = ""
		for k in s.subs.size(): if s.subs[k] == u: s.subs[k] = ""
		if s.captain == u: s.captain = ""
	Save.dirty()
func owns_pid(pid: String) -> bool:
	for it in D().club: if it.pid == pid: return true
	return false
func in_any_squad(u: String) -> bool:
	for s in D().squads: if s.slots.has(u) or s.subs.has(u): return true
	return false
func in_active_squad(u: String) -> bool:
	var s = active_squad(); return not s.is_empty() and (s.slots.has(u) or s.subs.has(u))
func in_market(u: String) -> bool:
	for l in D().market.mine: if l.uid == u and l.status == "active": return true
	return false
func duplicates() -> Array:
	var seen = {}; var out = []
	for it in D().club:
		if seen.has(it.pid): out.append(it)
		else: seen[it.pid] = true
	return out

func active_squad() -> Dictionary:
	if D().squads.is_empty(): return {}
	return D().squads[clamp(int(D().active_squad), 0, D().squads.size() - 1)]
func squad_players(s: Dictionary) -> Array:
	var out = []
	for u in s.slots: out.append({} if u == "" else item_player(u))
	return out
func squad_create(name: String, formation := "4-3-3") -> Dictionary:
	var s = {"id": uid(), "name": name, "formation": formation, "slots": ["", "", "", "", "", "", "", "", "", "", ""], "subs": ["", "", "", "", "", "", ""], "captain": ""}
	D().squads.append(s); Save.dirty(); return s
func squad_info(s: Dictionary) -> Dictionary:
	var ps = squad_players(s)
	var filled = 0
	for p in ps: if not p.is_empty(): filled += 1
	var ch = chemistry(s.formation, ps)
	# chemistry styles boost stats according to each player's chem
	var boosted = []
	for i in ps.size(): boosted.append(Cons.styled(ps[i], int(ch.per[i]) if i < ch.per.size() else 0))
	return {"players": boosted, "chem": ch, "rating": squad_rating(ps), "filled": filled}
func squad_complete(s: Dictionary) -> bool:
	for u in s.slots: if u == "": return false
	return true

func auto_build(s: Dictionary) -> void:
	var items: Array = D().club.filter(func(it): return not in_market(it.uid))
	var used = {}; var used_pids = {}
	var slots: Array = Data.formations[s.formation].map(func(f): return f[0])
	var order = range(11)
	order.sort_custom(func(a, b): return slots[a] == "GK" and slots[b] != "GK")
	var res = ["", "", "", "", "", "", "", "", "", "", ""]
	for i in order:
		var pos: String = slots[i]
		var best = null; var bs = -9999.0
		for it in items:
			if used.has(it.uid) or used_pids.has(it.pid): continue
			var p = Cons.item_view(it)
			var sc: float = p.ovr + (12 if p.pos == pos else (8 if Data.fits_pos(p, pos) else (-99 if (pos == "GK" or p.pos == "GK") else -10)))
			if sc > bs: bs = sc; best = it
		if best != null:
			res[i] = best.uid; used[best.uid] = true; used_pids[best.pid] = true
	s.slots = res
	var rem: Array = items.filter(func(it): return not used.has(it.uid))
	rem.sort_custom(func(a, b): return Data.P(a.pid).ovr > Data.P(b.pid).ovr)
	var subs = []
	for it in rem:
		if Data.P(it.pid).pos == "GK": subs.append(it.uid); break
	for it in rem:
		if subs.size() >= 7: break
		if not subs.has(it.uid): subs.append(it.uid)
	while subs.size() < 7: subs.append("")
	s.subs = subs
	var best_c = ""; var bo = -1
	for u in s.slots:
		if u != "" and item_player(u).ovr > bo: bo = item_player(u).ovr; best_c = u
	s.captain = best_c
	Save.dirty()

func build_ai_squad(strength: float, club := "", formation := "") -> Dictionary:
	if formation == "": formation = pick(Data.formation_names)
	var slots: Array = Data.formations[formation].map(func(f): return f[0])
	var pool: Array
	if club != "": pool = Data.by_club[club].filter(func(p): return p.type == "base")
	else: pool = Data.players.filter(func(p): return p.type == "base" or (not p.type in ["pass", "potm", "gallery", "phantom"] and strength >= 84 and randf() < 0.3))
	var used = {}
	var out = []
	for pos in slots:
		var cands: Array = shuffled(pool.filter(func(p): return not used.has(p.id) and Data.fits_pos(p, pos))).slice(0, 220)
		var best = null; var bd = 1e9
		for c in cands:
			var d: float = abs(c.ovr - (strength + randf_range(-3, 3)))
			if d < bd: bd = d; best = c
		if best == null:
			best = pick(pool.filter(func(p): return not used.has(p.id)))
		used[best.id] = true; out.append(best)
	var subs: Array = shuffled(pool.filter(func(p): return not used.has(p.id) and abs(p.ovr - strength) < 6)).slice(0, 7)
	return {"formation": formation, "players": out, "subs": subs}

## best XI of a real (fictional) club for Kick Off / Career / Tournaments
func club_team(code: String) -> Dictionary:
	var roster: Array = Data.by_club[code].filter(func(p): return p.type == "base")
	roster.sort_custom(func(a, b): return a.ovr > b.ovr)
	var used = {}; var ps = []
	for f in Data.formations["4-3-3"]:
		var pos: String = f[0]; var pl = null
		for x in roster: if not used.has(x.id) and x.pos == pos: pl = x; break
		if pl == null:
			for x in roster: if not used.has(x.id) and Data.fits_pos(x, pos): pl = x; break
		if pl == null:
			for x in roster: if not used.has(x.id) and x.pos != "GK": pl = x; break
		used[pl.id] = true; ps.append(pl)
	var subs = roster.filter(func(x): return not used.has(x.id)).slice(0, 7)
	var cl: Dictionary = Data.clubs[code]
	return {"name": cl.name, "short": code, "kit": {"c1": cl.c[0], "c2": cl.c[1]}, "formation": "4-3-3", "players": ps, "subs": subs, "crest": code}

func user_team() -> Dictionary:
	var s = active_squad(); var pr: Dictionary = D().profile
	var subs = []
	for u in s.subs: if u != "": subs.append(item_player(u))
	var inf = squad_info(s)
	return {"name": pr.club_name, "short": pr.club_name.substr(0, 3).to_upper(), "kit": pr.kit.home, "formation": s.formation, "players": inf.players, "subs": subs, "badge": pr.badge, "chem": inf.chem, "is_user": true}

## lift an AI team until its squad rating reaches the target (boosted copies of its players — base cards top out around 91)
func boost_to(team: Dictionary, target: int) -> void:
	for pass_i in 6:
		var cur: int = squad_rating(team.players)
		if cur >= target: return
		var add: int = target - cur
		var ps = []
		for p in team.players:
			var q: Dictionary = p.duplicate(true)
			q.ovr = min(99, int(q.ovr) + add)
			var st = []
			for v in q.stats: st.append(min(99, int(v) + add))
			q.stats = st; ps.append(q)
		team.players = ps

func ai_team(name: String, strength: float, extreme_floor := true) -> Dictionary:
	if extreme() and extreme_floor: strength = max(strength, 92.0)
	var s = build_ai_squad(strength)
	var k = {"c1": pick(["#c8102e", "#034694", "#ffffff", "#111111", "#00954c", "#6b2ea6", "#ff7f00", "#12a0d7"]), "c2": pick(["#ffffff", "#111111", "#ffd23f"])}
	var sh = ""
	for ch in name: if ch >= "A" and ch <= "Z": sh += ch
	if sh.length() < 2: sh = name.substr(0, 3).to_upper()
	return {"name": name, "short": sh.substr(0, 3), "kit": k, "formation": s.formation, "players": s.players, "subs": s.subs}

# ------------------------------------------------------------------ wallet & XP
func can_afford(cur: String, amt: int) -> bool:
	return (D().coins if cur == "coins" else D().points) >= amt
func add(cur: String, amt: int, desc: String, kind := "reward") -> void:
	if amt == 0: return
	if cur == "coins": D().coins += amt
	else: D().points += amt
	log_tx(kind, amt, cur, desc)
	if amt > 0 and cur == "coins": Sfx.play("coin")
	currency_changed.emit()
func spend(cur: String, amt: int, desc: String, kind := "purchase") -> bool:
	if amt < 0 or not can_afford(cur, amt):
		Sfx.play("error"); toast.emit("Not enough " + ("coins" if cur == "coins" else "Prime Points"), "bad"); return false
	if cur == "coins": D().coins -= amt
	else: D().points -= amt
	log_tx(kind, -amt, cur, desc); currency_changed.emit(); return true
func log_tx(kind: String, amount: int, cur: String, desc: String) -> void:
	D().tx.push_front({"t": now(), "kind": kind, "amount": amount, "cur": cur, "desc": desc})
	if D().tx.size() > 300: D().tx.resize(300)
	Save.dirty()

## ONE XP: every XP you earn fills the Season Pass AND your Club Level by the same amount
func xp_need(_level: int) -> int: return 1000
func add_xp(n: int) -> void: Season.add_xp(n, "XP")
## club level side of an XP gain (already scaled by Season.add_xp)
func club_gain(n: int) -> void:
	if n <= 0: return
	var pr: Dictionary = D().profile
	pr.xp += n
	while pr.xp >= xp_need(pr.level):
		pr.xp -= xp_need(pr.level); pr.level += 1
		var lv: int = pr.level
		add("coins", 500 * lv, "Club Level %d reward" % lv)
		if lv % 5 == 0:
			D().unopened.append("premium"); toast.emit("Level %d! Premium Gold Pack added to My Packs" % lv, "good")
		else: toast.emit("Club Level %d! +%s coins" % [lv, fmt(500 * lv)], "good")
		history("Reached Club Level %d" % lv)
	Save.dirty(); currency_changed.emit()
func history(text: String) -> void:
	D().profile.history.push_front({"t": now(), "text": text})

# ------------------------------------------------------------------ packs
var _tier_pools = {}
func tier_pool(tier: String) -> Array:
	if _tier_pools.has(tier): return _tier_pools[tier]
	var pool: Array
	match tier:
		"special": pool = Data.players.filter(func(p): return ["totw", "promo", "hero", "icon", "rising"].has(p.type))
		"legend": pool = Data.players.filter(func(p): return p.type == "hero" or p.type == "icon")
		"totw", "promo", "hero", "icon", "found", "rising", "fright", "blackout", "rtk", "nltotg": pool = Data.players.filter(func(p): return p.type == tier and not (tier == "fright" and Fright.exclusive_fright(p.id)) and not (tier == "blackout" and Black.exclusive_card(p.id)) and not (tier == "rtk" and Rtk.exclusive_card(p.id)) and not (tier == "nltotg" and NL.exclusive_card(p.id)))
		"ph_finale": pool = Fright.phantom_finale
		"gold": pool = Data.players.filter(func(p): return p.type == "base" and Data.tier_of(p.ovr) == "gold")
		"asc_finale": pool = Data.ascension_finale.duplicate()
		_:
			if tier.begins_with("ovr"):
				var mn: int = int(tier.substr(3))
				pool = Data.players.filter(func(p): return p.type == "base" and p.ovr >= mn)
			else: pool = Data.players.filter(func(p): return p.type == "base" and Data.rarity_key(p) == tier)
	_tier_pools[tier] = pool
	return pool
## EXTREME MODE (per save): high-rated & special pack pulls 1000× rarer, AI maxed in every match
func extreme() -> bool: return Save.data != null and bool(Save.data.settings.get("extreme", false))
## XP after the Extreme divider, with the fractions carried over so nothing is lost
## Extreme no longer cuts XP — it only affects pack odds and opponents
func xp_scaled(n: int, _key: String) -> int: return n
func xp_scaled_preview(n: int) -> int: return n
func roll_tier(tier: String) -> Dictionary:
	var r = _roll_tier(tier)
	# Extreme: an 84+ or special pull only survives 1 time in 1000 (guaranteed-tier pools are left alone)
	if extreme() and not ["legend", "asc_finale", "ph_finale", "special", "totw", "promo", "hero", "icon", "found", "rising", "fright", "blackout", "rtk", "nltotg"].has(tier):
		var pool = tier_pool(tier)
		var low = pool.filter(func(p): return p.type == "base" and p.ovr < 84)
		var tries = 0
		while not low.is_empty() and (r.ovr >= 84 or r.type != "base") and randf() > 0.001 and tries < 50:
			r = _roll_tier(tier); tries += 1
		if (r.ovr >= 84 or r.type != "base") and not low.is_empty() and tries >= 50: r = pick(low)
	return r
func _roll_tier(tier: String) -> Dictionary:
	var pool = tier_pool(tier)
	if tier == "legend":
		var t = "icon" if chance(0.25) else "hero"
		return pick(pool.filter(func(p): return p.type == t))
	var mn = 99
	for p in pool: mn = min(mn, p.ovr)
	if tier == "asc_finale" or tier == "ph_finale": return pick(pool)
	# steep curve: low ratings are common, top-rated players are genuinely rare
	var k = 1.5 if tier.begins_with("gold") else (1.4 if tier.begins_with("ovr") else 6.0)
	return weighted(pool.map(func(p): return [exp(-(p.ovr - mn) / k), p]))
func pack_odds(id: String) -> Array:
	var pk: Dictionary = Data.packs[id]
	var tot = 0.0
	for t in pk.w: tot += pk.w[t]
	var guar_n = 0
	for g in pk.guar: guar_n += int(g[1])
	var free: int = int(pk.items) - guar_n
	var out = []
	for t in pk.w:
		var p: float = pk.w[t] / tot
		var g = 0
		for gg in pk.guar: if gg[0] == t: g += int(gg[1])
		out.append({"tier": t, "per": p, "least": 1.0 if g > 0 else 1.0 - pow(1.0 - p, free)})
	return out
func generate_pack(id: String) -> Array:
	var pk: Dictionary = Data.packs[id]
	var out = []
	for g in pk.guar:
		for i in int(g[1]): out.append(roll_tier(g[0]))
	var ws = []
	for t in pk.w: ws.append([pk.w[t] * (0.001 if extreme() and ["special", "totw", "promo", "hero", "icon", "legend", "found", "rising", "fright", "blackout", "rtk", "nltotg"].has(t) else 1.0), t])
	while out.size() < int(pk.items): out.append(roll_tier(weighted(ws)))
	out.sort_custom(func(a, b): return Data.card_value_score(a) > Data.card_value_score(b))
	return out

# ------------------------------------------------------------------ transfer market
func demand(pid: String) -> float: return D().market.demand.get(pid, 1.0)
func nudge(pid: String, f: float) -> void: D().market.demand[pid] = clamp(demand(pid) * f, 0.6, 1.8)
func cycle() -> float: return cycle_at(now(), "")
## every player's price moves on its own wave (hours-long swings) on top of supply & demand
func cycle_at(t: float, pid: String) -> float:
	var h = t / 3600.0
	var ph: float = float(abs(hash(pid)) % 1000) / 159.0
	return 1.0 + 0.06 * sin(h * 0.26 + ph) + 0.03 * sin(h * 0.71 + ph * 2.0) + 0.008 * sin(h * 2.3 + ph * 3.0)
func value(p: Dictionary) -> int: return value_at(p, now())
func value_at(p: Dictionary, t: float) -> int:
	return clamp(Data._round_price(Data.base_value(p) * demand(p.id) * cycle_at(t, p.id)), 150, Data.MAX_PRICE)
## 24-hour price trend (25 points, oldest first)
func trend(p: Dictionary, hours := 24, pts := 25) -> Array:
	var out = []
	var t = now()
	for i in pts: out.append(value_at(p, t - (hours * 3600.0) * float(pts - 1 - i) / float(pts - 1)))
	return out
func trend_pct(p: Dictionary) -> float:
	var a = value_at(p, now() - 86400.0); var b = value(p)
	return (float(b) - a) / max(1.0, a) * 100.0

# ------------------------------------------------------------------ persistent market
func M() -> Dictionary:
	var m: Dictionary = D().market
	for k in ["pool", "watch", "tl"]: if not m.has(k): m[k] = []
	return m
func _market_player_pool() -> Array:
	return Data.players.filter(func(p): return not p.type in ["found", "pass", "potm", "gallery", "phantom"] and not str(p.id).begins_with("ev"))
var _mpp = []
func _random_listing_player() -> Dictionary:
	if _mpp.is_empty(): _mpp = _market_player_pool()
	# far more low-rated cards than stars, like the real market
	for i in 6:
		var p: Dictionary = pick(_mpp)
		var keep: float = 1.0 if p.ovr < 75 else (0.7 if p.ovr < 80 else (0.4 if p.ovr < 84 else (0.2 if p.ovr < 87 else 0.1)))
		if p.type != "base": keep *= 0.35
		if chance(keep): return p
	return pick(_mpp)
func lowest_bins(pid: String, n := 5) -> Array:
	var p = Data.P(pid)
	var arr: Array = M().pool.filter(func(l): return l.pid == pid and l.ends > now() and not l.get("gone", false))
	while arr.size() < 3:
		var l = make_listing(p); M().pool.append(l); arr.append(l)
	arr.sort_custom(func(a, b): return a.bin < b.bin)
	return arr.slice(0, n)
func recent_sales(p: Dictionary, n := 6) -> Array:
	var out = []
	for i in n:
		var t = now() - (i + 1) * randf_range(900.0, 2400.0)
		out.append({"t": t, "price": max(150, int(round(value_at(p, t) * randf_range(0.93, 1.05) / 50.0)) * 50)})
	return out
func is_watched(l: Dictionary) -> bool: return M().watch.any(func(w): return w.id == l.id)
func toggle_watch(l: Dictionary) -> bool:
	for w in M().watch:
		if w.id == l.id: M().watch.erase(w); Save.dirty(); return false
	M().watch.push_front(l); Save.dirty(); return true

# ------------------------------------------------------------------ transfer list pile (unlisted items)
const TL_MAX := 100
func tl_items() -> Array: return M().tl
func tl_add(pid: String, untr: bool, src := "pack") -> bool:
	if untr or M().tl.size() >= TL_MAX: return false
	M().tl.append({"uid": uid(), "pid": pid, "untr": false, "at": now(), "src": src}); Save.dirty(); return true
func tl_take(u: String) -> Dictionary:
	for it in M().tl:
		if it.uid == u: M().tl.erase(it); Save.dirty(); return it
	return {}
func tl_to_club(u: String) -> void:
	var it = tl_take(u)
	if not it.is_empty(): D().club.append(it); Save.dirty()
func tl_quick_sell(u: String) -> void:
	var it = tl_take(u)
	if not it.is_empty(): var p = Data.P(it.pid); add("coins", Data.quick_sell_value(p), "Quick sold " + p.name, "quicksell"); track("quicksell")

## apply the New Items screen: keep → club, tl → Transfer List, qs → coins
func apply_pending() -> Dictionary:
	var r = {"keep": 0, "tl": 0, "qs": 0, "coins": 0}
	for x in D().pending:
		var dest: String = x.get("dest", "keep")
		if dest == "tl" and tl_add(x.pid, x.untr): r.tl += 1
		elif dest == "qs":
			var v = Data.quick_sell_value(Data.P(x.pid)); r.qs += 1; r.coins += v
		else: club_add(x.pid, x.untr, "pack"); r.keep += 1
	if r.coins: add("coins", r.coins, "Quick sold %d pack items" % r.qs, "quicksell"); track("quicksell", r.qs)
	D().pending = []; Save.dirty()
	return r
## apply one pending item right away (dest: keep / tl / qs). Returns false if it couldn't move.
func apply_one(i: int, dest: String) -> bool:
	var pend: Array = D().pending
	if i < 0 or i >= pend.size(): return false
	var x: Dictionary = pend[i]
	if dest == "tl":
		if x.untr or not tl_add(x.pid, x.untr): return false
	elif dest == "qs":
		var v = Data.quick_sell_value(Data.P(x.pid)); add("coins", v, "Quick sold " + Data.P(x.pid).name, "quicksell"); track("quicksell")
	else: club_add(x.pid, x.untr, "pack")
	pend.remove_at(i); Save.dirty()
	return true
func price_range(p: Dictionary) -> Dictionary:
	var v = value(p)
	return {"min": max(150, Data._round_price(v * 0.45)), "max": min(Data.MAX_PRICE, Data._round_price(v * 3))}
func make_listing(p: Dictionary) -> Dictionary:
	var v = value(p)
	var bin: int = clamp(Data._round_price(v * randf_range(0.92, 1.35)), 200, Data.MAX_PRICE)
	var start: int = max(150, Data._round_price(bin * randf_range(0.45, 0.8)))
	var dur: float = pick([1, 2, 3, 5, 8, 15, 30, 60]) * 60.0
	var has_bid = chance(0.25)
	return {"id": uid(), "pid": p.id, "start": start, "bin": bin, "bid": start if has_bid else 0, "bidder": "ai" if has_bid else "", "ends": now() + dur * randf_range(0.2, 1.0), "listed": now()}
func _match_filter(p: Dictionary, f: Dictionary) -> bool:
	var q: String = f.get("name", "").to_lower()
	if q != "" and not p.name.to_lower().contains(q): return false
	if f.get("pos", "") != "" and p.pos != f.pos: return false
	if f.get("lg", "") != "" and p.lg != f.lg: return false
	if f.get("nat", "") != "" and p.nat != f.nat: return false
	if f.get("club", "") != "" and p.club != f.club: return false
	var rar: String = f.get("rar", "")
	if rar == "rare" and not p.rare: return false
	if rar == "special" and p.type == "base": return false
	if rar == "gold" and not (p.type == "base" and Data.tier_of(p.ovr) == "gold"): return false
	if rar != "" and not rar in ["rare", "special", "gold"] and Data.rarity_key(p) != rar: return false
	if int(f.get("min", 0)) > 0 and p.ovr < int(f.min): return false
	if int(f.get("max", 0)) > 0 and p.ovr > int(f.max): return false
	return true
func _match_price(l: Dictionary, f: Dictionary) -> bool:
	var cur_bid: int = l.bid if l.bid > 0 else l.start
	if int(f.get("min_bin", 0)) > 0 and l.bin < int(f.min_bin): return false
	if int(f.get("max_bin", 0)) > 0 and l.bin > int(f.max_bin): return false
	if int(f.get("min_bid", 0)) > 0 and cur_bid < int(f.min_bid): return false
	if int(f.get("max_bid", 0)) > 0 and cur_bid > int(f.max_bid): return false
	return true
## search the live market. Listings persist: other managers bid on them and snipe bargains.
func market_search(f: Dictionary) -> Array:
	var t = now()
	var res: Array = M().pool.filter(func(l): return l.ends > t and not l.get("gone", false) and _match_filter(Data.P(l.pid), f) and _match_price(l, f))
	if res.size() < 30:
		var pool: Array = _market_player_pool().filter(func(p): return _match_filter(p, f))
		if not pool.is_empty():
			var has_base = pool.any(func(p): return p.type == "base")
			var tries = 0
			while res.size() < 30 and tries < 120:
				tries += 1
				var p: Dictionary = pick(pool)
				if p.type != "base" and has_base and chance(0.6): continue
				var l = make_listing(p)
				M().pool.append(l)
				if _match_price(l, f): res.append(l)
	match f.get("sort", "ends"):
		"bin-asc": res.sort_custom(func(a, b): return a.bin < b.bin)
		"bin-desc": res.sort_custom(func(a, b): return a.bin > b.bin)
		"ovr": res.sort_custom(func(a, b): return Data.P(a.pid).ovr > Data.P(b.pid).ovr)
		_: res.sort_custom(func(a, b): return a.ends < b.ends)
	D().market.listings = res.slice(0, 60); Save.dirty()
	return D().market.listings
func buy_now(l: Dictionary) -> bool:
	var p = Data.P(l.pid)
	if l.ends < now(): toast.emit("This auction has ended", "bad"); return false
	if not spend("coins", l.bin, "Bought %s (%d)" % [p.name, p.ovr], "market"): return false
	club_add(p.id, false, "market"); nudge(p.id, 1.04); market_hist("buy", p, l.bin)
	D().market.listings.erase(l); M().pool.erase(l); l.gone = true; l.won = true
	D().stats.bought += 1; track("buy")
	return true
func min_bid(l: Dictionary) -> int:
	var b: int = l.bid
	if b == 0: return l.start
	return b + (50 if b < 1000 else (100 if b < 10000 else (250 if b < 50000 else 1000)))
func place_bid(l: Dictionary, amt: int) -> bool:
	var p = Data.P(l.pid)
	if l.ends < now(): toast.emit("This auction has ended", "bad"); return false
	if amt < min_bid(l): toast.emit("Minimum bid is %s" % fmt(min_bid(l)), "bad"); return false
	if amt >= l.bin: return buy_now(l)
	if not spend("coins", amt, "Bid on " + p.name, "bid"): return false
	for b in D().market.bids:
		if b.lid == l.id and b.status == "winning":
			add("coins", b.amt, "Bid refund " + p.name, "refund"); b.status = "replaced"
	l.bid = amt; l.bidder = "me"
	if l.ends - now() < 30: l.ends = now() + 30
	D().market.bids.push_front({"lid": l.id, "pid": l.pid, "amt": amt, "ends": l.ends, "status": "winning", "listing": l})
	Save.dirty(); return true
func list_item(u: String, start: int, bin: int, dur_min: int) -> bool:
	var it = item(u)
	if it.is_empty(): return false
	var p = Data.P(it.pid)
	if it.untr: toast.emit("Untradeable items cannot be listed", "bad"); return false
	if in_market(u): toast.emit("Already listed", "bad"); return false
	var rg = price_range(p)
	if bin <= start: toast.emit("Buy Now must be higher than start price", "bad"); return false
	if start < rg.min or bin > rg.max: toast.emit("Price range for this player: %s – %s" % [fmt(rg.min), fmt(rg.max)], "bad"); return false
	for s in D().squads:
		for k in 11: if s.slots[k] == u: s.slots[k] = ""
		for k in 7: if s.subs[k] == u: s.subs[k] = ""
	D().market.mine.push_front({"id": uid(), "uid": u, "pid": p.id, "start": start, "bin": bin, "bid": 0, "ends": now() + dur_min * 60.0, "status": "active", "listed": now(), "lt": now()})
	track("list"); Save.dirty(); return true
func remove_listing(id: String) -> bool:
	for l in D().market.mine:
		if l.id == id:
			if l.status == "active" and l.bid > 0: toast.emit("Cannot remove a listing that has bids", "bad"); return false
			D().market.mine.erase(l); Save.dirty(); return true
	return false
func market_hist(kind: String, p: Dictionary, price: int) -> void:
	D().market.history.push_front({"t": now(), "kind": kind, "pid": p.id, "price": price})
	if D().market.history.size() > 150: D().market.history.resize(150)

func _process(delta: float) -> void:
	if Save.data == null: return
	_market_t += delta
	if _market_t >= 1.0:
		_market_t = 0
		market_tick()

func market_tick() -> void:
	var t = now(); var changed = false
	for l in D().market.mine:
		if l.status != "active": continue
		var p = Data.P(l.pid); var v = value(p)
		var dt: float = min(60.0, t - l.get("lt", l.listed)); l.lt = t
		var r: float = float(l.bin) / v
		var p_buy = 0.08 if r <= 0.95 else (0.025 if r <= 1.1 else (0.006 if r <= 1.3 else 0.0008))
		if randf() < 1.0 - pow(1.0 - p_buy, dt): sell(l, l.bin); changed = true; continue
		var nxt: int = (l.bid + max(50, int(round(l.bid * 0.05 / 50.0)) * 50)) if l.bid > 0 else l.start
		if nxt < v * 0.98 and randf() < 1.0 - pow(0.97, dt): l.bid = nxt; changed = true
		if t >= l.ends:
			if l.bid > 0: sell(l, l.bid)
			else: l.status = "expired"
			changed = true
	for b in D().market.bids:
		if b.status != "winning": continue
		var l: Dictionary = b.listing; var p = Data.P(b.pid); var v = value(p)
		var dt: float = min(60.0, t - b.get("lt", t - 1)); b.lt = t
		var r: float = float(b.amt) / v
		var p_out = 0.06 if r < 0.7 else (0.025 if r < 0.9 else (0.008 if r < 1.0 else 0.001))
		if t < l.ends and randf() < 1.0 - pow(1.0 - p_out, dt):
			b.status = "outbid"; l.bid = min_bid({"bid": b.amt, "start": 0}); l.bidder = "ai"
			add("coins", b.amt, "Outbid on %s — refund" % p.name, "refund")
			toast.emit("Outbid on " + p.name, "bad"); changed = true; continue
		if t >= l.ends:
			b.status = "won"; club_add(p.id, false, "auction"); market_hist("buy", p, b.amt); nudge(p.id, 1.03)
			D().stats.bought += 1; track("buy")
			toast.emit("Won %s for %s coins!" % [p.name, fmt(b.amt)], "good"); changed = true
	if changed: market_ver += 1
	# the rest of the market: other managers snipe underpriced cards, bid near the end, listings expire & refill
	var pool: Array = M().pool
	var keep = []
	for l in pool:
		if l.get("gone", false): continue
		if l.ends <= t:
			l.gone = true; continue
		if l.bidder == "me": keep.append(l); continue
		var v = value(Data.P(l.pid))
		var r: float = float(l.bin) / max(1, v)
		var snipe = 0.12 if r < 0.85 else (0.03 if r < 0.95 else (0.004 if r < 1.05 else 0.0004))
		if chance(snipe):
			l.gone = true; l.sold_ai = true; changed = true; continue
		if l.ends - t < 45 and chance(0.08):
			var nb: int = min_bid(l)
			if nb < l.bin and nb < v * 1.02: l.bid = nb; l.bidder = "ai"; changed = true
		keep.append(l)
	if keep.size() < 220:
		for i in 6: keep.append(make_listing(_random_listing_player()))
	if keep.size() > 600: keep = keep.slice(keep.size() - 600)
	M().pool = keep
	if changed: Save.dirty(); market_changed.emit()

func sell(l: Dictionary, price: int) -> void:
	var p = Data.P(l.pid)
	var net = int(round(price * (1.0 - MARKET_TAX)))
	l.status = "sold"; l.sold = price
	club_remove(l.uid)
	add("coins", net, "Sold %s for %s (5%% tax)" % [p.name, fmt(price)], "sale")
	market_hist("sell", p, price); nudge(p.id, 0.97)
	D().stats.sold += 1; track("sell")
	toast.emit("%s sold for %s! +%s after tax" % [p.name, fmt(price), fmt(net)], "good")

# ------------------------------------------------------------------ objectives & rewards
# ------------------------------------------------------------------ quick objectives (refresh every 3 minutes)
const QUICK_SECS := 180.0
const QUICK_ACTION := [["q_pack", "Pack Opener", "Open 1 pack", "pack", 1, {"coins": 400, "sxp": 15}],
	["q_pack2", "Double Rip", "Open 2 packs", "pack", 2, {"coins": 900}],
	["q_buy", "Market Shopper", "Buy a player on the Transfer Market", "buy", 1, {"coins": 600}],
	["q_list", "Trader", "List a player on the Transfer Market", "list", 1, {"coins": 300, "sxp": 15}],
	["q_qs", "Clear Out", "Quick sell 3 items", "quicksell", 3, {"coins": 400}],
	["q_sbc", "Squad Builder", "Complete any SBC", "sbc", 1, {"pack": "gold"}],
	["q_sell", "Profit Maker", "Sell a player on the Transfer Market", "sell", 1, {"coins": 700}]]
const QUICK_MATCH := [["q_goal", "On Target", "Score a goal in an Ultimate XI match", "goal", 1, {"coins": 700}],
	["q_match", "Matchday", "Finish an Ultimate XI match", "match", 1, {"coins": 800, "sxp": 25}],
	["q_win", "Quick Win", "Win an Ultimate XI match", "win", 1, {"pack": "premium"}],
	["q_assist", "Provider", "Get an assist in Ultimate XI", "assist", 1, {"coins": 600}],
	["q_goals3", "Hat-trick Hunt", "Score 3 goals in Ultimate XI", "goal", 3, {"coins": 1500, "sxp": 30}],
	["q_evo", "Evolve", "Level up an Evolution", "evo_lvl", 1, {"coins": 800}]]
func _ready() -> void:
	for q in QUICK_ACTION + QUICK_MATCH:
		Data.objectives.append({"id": q[0], "cat": "quick", "title": q[1], "desc": q[2], "ev": q[3], "target": q[4], "reward": q[5].duplicate()})
	_tone_down_objectives.call_deferred()

## objectives are a small bonus, not a coin/XP farm: coins cut to 40%, and the only XP is the tier XP (OBJ_XP) — no extra "xp" in rewards
const OBJ_COIN_MULT := 0.4
func _tone_down_objectives() -> void:
	for o in Data.objectives:
		var r: Dictionary = o.reward
		if r.has("xp"): r.erase("xp")
		if r.get("coins", 0) and not r.get("_toned", false):
			r.coins = max(100, int(round(int(r.coins) * OBJ_COIN_MULT / 50.0)) * 50); r._toned = true
func quick_period() -> int: return int(floor(now() / QUICK_SECS))
func quick_left() -> float: return (quick_period() + 1) * QUICK_SECS - now()
var _qcache = {"p": -1, "ids": []}
## the 4 quick objectives live in this 3-minute window (2 quick actions + 2 match goals)
func quick_active() -> Array:
	var pr = quick_period()
	if _qcache.p != pr:
		var rng = RandomNumberGenerator.new(); rng.seed = pr * 7919 + 17
		var a = QUICK_ACTION.duplicate(); var m = QUICK_MATCH.duplicate(); var ids = []
		for k in 2: ids.append(a.pop_at(rng.randi() % a.size())[0])
		for k in 2: ids.append(m.pop_at(rng.randi() % m.size())[0])
		_qcache = {"p": pr, "ids": ids}
	return _qcache.ids
func obj_live(o: Dictionary) -> bool: return o.cat != "quick" or quick_active().has(o.id)

func obj_period(o: Dictionary) -> String:
	match o.cat:
		"quick": return "Q%d" % quick_period()
		"daily": return day_key()
		"weekly": return week_key()
		"season": return Season.ID.to_upper()
		"halloween": return "HW26"
		"blackout": return "BO26"
		"rtk": return "RTK1"
		"nltotg": return "NL27"
		"event": return Event.ID
	return "M"
func obj_key(o: Dictionary) -> String: return o.id + "@" + obj_period(o)
func obj_progress(o: Dictionary) -> int: return min(int(o.target), int(D().objectives.progress.get(obj_key(o), 0)))
func obj_done(o: Dictionary) -> bool: return obj_progress(o) >= int(o.target)
func obj_claimed(o: Dictionary) -> bool: return D().objectives.claimed.has(obj_key(o))
func obj_claimable() -> int:
	var n = 0
	for o in Data.objectives: if o.cat != "quick" and obj_done(o) and not obj_claimed(o): n += 1
	return n
func track(ev: String, n := 1) -> void:
	if D() == null: return
	for o in Data.objectives:
		if o.ev != ev or not obj_live(o): continue
		var k = obj_key(o)
		var before = int(D().objectives.progress.get(k, 0))
		if before >= int(o.target): continue
		D().objectives.progress[k] = min(int(o.target), before + n)
		if D().objectives.progress[k] >= int(o.target):
			if o.cat == "quick":
				D().objectives.claimed[k] = true
				grant(o.reward, "Quick objective: " + o.title)
				toast.emit("⚡ Quick objective complete: %s · %s" % [o.title, reward_text(o.reward)], "good")
			else: toast.emit("Objective complete: %s — claim your reward" % o.title, "good")
	Save.dirty()
func obj_claim(o: Dictionary) -> bool:
	if not obj_done(o) or obj_claimed(o): return false
	D().objectives.claimed[obj_key(o)] = true
	grant(o.reward, "Objective: " + o.title)
	Season.add_xp(obj_xp(o), "%s objective" % obj_tier(o).capitalize())
	return true

## objective difficulty → XP: easy 100 · medium 250 · hard 600 (quick 3-minute objectives keep their small bonus XP)
const OBJ_XP := {"easy": 100, "medium": 250, "hard": 600}
func obj_tier(o: Dictionary) -> String:
	if o.has("tier"): return str(o.tier)
	if str(o.get("id", "")) in ["hw_doku", "bo_nico", "rtk_douvikas", "nl_lammens"]: return "hard"
	match str(o.cat):
		"daily": return "easy"
		"weekly", "halloween", "blackout", "rtk", "nltotg": return "medium"
		"season", "milestone": return "hard"
	return "easy"
func obj_xp(o: Dictionary) -> int: return 0 if o.cat == "quick" else int(OBJ_XP[obj_tier(o)])

func reward_text(r: Dictionary) -> String:
	var parts = []
	if r.get("coins", 0): parts.append("%s Coins" % fmt(r.coins))
	if r.get("points", 0): parts.append("%s Prime Points" % fmt(r.points))
	if r.has("pack"): parts.append(Data.packs[r.pack].name)
	if r.has("player"): var p = Data.P(r.player); parts.append("%d %s" % [p.ovr, p.name])
	if r.get("xp", 0): parts.append("%s XP" % fmt(r.xp))
	if r.get("tokens", 0): parts.append("%d Star Tokens" % int(r.tokens))
	if r.get("sxp", 0): parts.append("%d XP" % int(r.sxp))
	return " + ".join(parts)
func grant(r: Dictionary, src: String) -> void:
	if r.get("coins", 0): add("coins", int(r.coins), src)
	if r.get("points", 0): add("points", int(r.points), src)
	if r.has("pack"):
		D().unopened.append(r.pack); toast.emit(Data.packs[r.pack].name + " added to My Packs", "good")
	if r.has("player"):
		club_add(r.player, false, "reward"); var p = Data.P(r.player)
		toast.emit("%d %s sent to your club" % [p.ovr, p.name], "good")
	if r.get("xp", 0): add_xp(int(r.xp))
	if r.get("tokens", 0): Event.add_tokens(int(r.tokens))
	if r.get("sxp", 0): Season.add_xp(int(r.sxp), "Objective")
	Save.dirty()

# ------------------------------------------------------------------ SBC
func sbc_check(sbc: Dictionary, players: Array, formation: String) -> Dictionary:
	var ps: Array = players.filter(func(p): return not p.is_empty())
	var size = int(sbc.size)
	var chem = chemistry(formation, players) if size == 11 else null
	var rating = 0
	if size == 11: rating = squad_rating(players)
	elif not ps.is_empty():
		var s = 0
		for p in ps: s += p.ovr
		rating = s / ps.size()
	var maxby = func(key: String) -> int:
		var m = {}; var best = 0
		for p in ps: m[p[key]] = m.get(p[key], 0) + 1; best = max(best, m[p[key]])
		return best
	var distinct = func(key: String) -> int:
		var m = {}
		for p in ps: m[p[key]] = true
		return m.size()
	var res = [{"label": "Players: %d/%d" % [ps.size(), size], "ok": ps.size() == size}]
	for r in sbc.reqs:
		var label = ""; var ok = false
		match r.t:
			"tierAll":
				label = "All players: " + String(r.v).capitalize()
				ok = not ps.is_empty() and ps.all(func(p): return Data.tier_of(p.ovr) == r.v and p.type == "base")
			"tierMin":
				label = "Min. %d %s players" % [int(r.n), String(r.v).capitalize()]
				ok = ps.filter(func(p): return Data.tier_of(p.ovr) == r.v).size() >= int(r.n)
			"rare":
				label = "Min. %d Rare players" % int(r.n); ok = ps.filter(func(p): return p.rare).size() >= int(r.n)
			"rating":
				label = "Squad Rating: Min. %d (now %d)" % [int(r.v), rating]; ok = rating >= int(r.v)
			"chem":
				label = "Total Chemistry: Min. %d (now %d)" % [int(r.v), chem.total if chem else 0]; ok = chem != null and chem.total >= int(r.v)
			"sameLeague":
				label = "Same League: %d players" % int(r.n); ok = maxby.call("lg") >= int(r.n)
			"leagues":
				label = "Leagues: Min. %d" % int(r.n); ok = distinct.call("lg") >= int(r.n)
			"nations":
				label = "Nations: Min. %d" % int(r.n); ok = distinct.call("nat") >= int(r.n)
			"nat":
				label = "Same Nation: Min. %d players" % int(r.n); ok = maxby.call("nat") >= int(r.n)
			"special":
				label = "Special cards: Min. %d" % int(r.n); ok = ps.filter(func(p): return p.type != "base").size() >= int(r.n)
		res.append({"label": label, "ok": ok})
	return {"reqs": res, "ok": res.all(func(x): return x.ok), "rating": rating, "chem": chem}
func sbc_count(id: String) -> int: return int(D().sbc.done.get(id, 0))
func sbc_available(s: Dictionary) -> bool: return sbc_count(s.id) < int(s.repeat)
func sbc_submit(sbc: Dictionary, uids: Array, formation: String) -> bool:
	var players = uids.map(func(u): return {} if u == "" else item_player(u))
	var chk = sbc_check(sbc, players, formation)
	if not chk.ok: Sfx.play("error"); toast.emit("Requirements not met", "bad"); return false
	for u in uids: if u != "": club_remove(u)
	D().sbc.done[sbc.id] = sbc_count(sbc.id) + 1
	D().stats.sbcs += 1
	grant(sbc.reward, "SBC: " + sbc.name)
	Season.add_xp(50, "SBC")
	track("sbc"); history('Completed SBC "%s"' % sbc.name)
	Save.dirty(); return true

# ------------------------------------------------------------------ competitions
## Opponents scale with your division AND with how much you win:
## every 10 career wins adds a little, and a win streak makes the next bot tougher.
func experience() -> float: return min(0.15, float(D().stats.wins) * 0.003)
func rivals_streak() -> int: return int(D().modes.rivals.get("streak", 0))
## Extreme Rivals: opponent squad rating range per division (Div 1 = Elite)
const EXTREME_RIVALS := {10: [82, 84], 9: [85, 87], 8: [87, 89], 7: [88, 90], 6: [89, 91], 5: [92, 95], 4: [92, 95], 3: [95, 97], 2: [95, 97], 1: [98, 99]}
func rivals_strength(div: int) -> float:
	if extreme():
		var r: Array = EXTREME_RIVALS.get(clamp(div, 1, 10), [82, 84])
		return float(randi_range(int(r[0]), int(r[1])))
	return min(93.0, 76.0 + (10 - div) * 1.6 + experience() * 25.0 + min(4, rivals_streak()) * 0.6)
func rivals_ai(div: int) -> float:
	if extreme(): return min(1.5, 0.9 + (10 - div) * 0.066 + min(5, rivals_streak()) * 0.02)
	return min(1.3, 0.62 + (10 - div) * 0.065 + experience() + min(5, rivals_streak()) * 0.035)
func ai_label(a: float) -> String:
	return "Beginner" if a < 0.35 else ("Amateur" if a < 0.5 else ("Semi-Pro" if a < 0.63 else ("Professional" if a < 0.76 else ("World Class" if a < 0.88 else ("Legendary" if a < 0.98 else ("Ultimate" if a < 1.1 else "Ultimate+"))))))
func rivals_difficulty(div: int) -> String:
	if extreme(): return "ultimate" if div <= 4 else "legendary"
	return ["", "legendary", "legendary", "worldclass", "worldclass", "professional", "professional", "semipro", "semipro", "amateur", "amateur"][div]
func rivals_record(result: String) -> Dictionary: return Rivals.record(result)

const CHAMPS_MATCHES := 10
func champs_reward(w: int) -> Dictionary:
	if w >= 9: return {"pack": "ultimate", "coins": 50000, "points": 400}
	if w >= 7: return {"pack": "mega", "coins": 25000, "points": 200}
	if w >= 5: return {"pack": "rare", "coins": 12000, "points": 100}
	if w >= 3: return {"pack": "jumbo", "coins": 6000}
	return {"pack": "premium", "coins": 2000}
func draft_reward(w: int) -> Dictionary:
	return [{"coins": 1000, "pack": "gold"}, {"coins": 3000, "pack": "premium"}, {"coins": 8000, "pack": "draftreward", "points": 50}, {"coins": 15000, "pack": "jumbo", "points": 100}, {"coins": 30000, "pack": "mega", "points": 200}][w]
const DRAFT_ROUNDS := ["Round of 16", "Quarter-Final", "Semi-Final", "Final"]
func draft_choices(pos: String, exclude: Dictionary, captain := false) -> Array:
	var pool: Array = Data.players.filter(func(p): return Data.fits_pos(p, pos) and p.ovr >= (86 if captain else 76) and not exclude.has(p.id) and not p.type in ["pass", "potm", "gallery", "phantom"])
	if captain: return shuffled(pool).slice(0, 5)
	var out = []; var seen = exclude.duplicate()
	for i in 200:
		if out.size() >= 5: break
		var tier = weighted([[70, "base"], [14, "totw"], [8, "promo"], [5, "hero"], [3, "icon"]])
		var sub: Array = pool.filter(func(p): return (p.type == "base" if tier == "base" else p.type == tier) and not seen.has(p.id))
		if sub.is_empty(): sub = pool.filter(func(p): return not seen.has(p.id))
		if sub.is_empty(): break
		var pk: Dictionary = pick(sub); out.append(pk); seen[pk.id] = true
	return out

## Poisson score from strengths (used by quick simulation, career & tournaments)
func sim_score(a: float, b: float, home_adv := 1.5) -> Array:
	var diff = (a + home_adv - b) / 10.0
	return [_pois(clamp(1.35 + diff * 0.9, 0.2, 4.0)), _pois(clamp(1.15 - diff * 0.9, 0.2, 4.0))]
func _pois(l: float) -> int:
	var L = exp(-l); var k = 0; var p = 1.0
	while true:
		k += 1; p *= randf()
		if p <= L: break
	return k - 1

## record a finished Ultimate XI match (stats, objectives, XP); returns W/D/L
func record_ut_match(res: Dictionary) -> String:
	var st: Dictionary = D().stats
	var u: String = res.user_side if res.user_side != "" else "home"
	var gf: int = res.hg if u == "home" else res.ag
	var ga: int = res.ag if u == "home" else res.hg
	var r = "W" if gf > ga else ("L" if gf < ga else "D")
	if r == "D" and res.get("pens") != null: r = "W" if res.winner == u else "L"
	st.played += 1; st.gf += gf; st.ga += ga
	if r == "W": st.wins += 1
	elif r == "L": st.losses += 1
	else: st.draws += 1
	track("match")
	if gf > 0: track("goal", gf)
	if r == "W": track("win")
	if ga == 0: track("cleansheet")
	var assists = 0; var mid = false
	for g in res.goals:
		if g.side == u and not g.get("og", false):
			if g.get("assist", "") != "": assists += 1
			if Data.pos_group.get(g.get("pos", ""), "") == "MID": mid = true
	if assists > 0: track("assist", assists); st.assists += assists
	if mid: track("goal_mid")
	res["ut"] = true
	Event.after_match(res, r)
	Evo.after_match(res, r, ga)
	Season.add_match_sp(Season.match_sp(r, str(res.get("mode", ""))), "Match " + ("win" if r == "W" else ("draw" if r == "D" else "played")))
	return r
func log_match(res: Dictionary, mode: String, r: String) -> void:
	D().matches.push_front({"t": now(), "mode": mode, "home": res.home.name, "away": res.away.name, "hg": res.hg, "ag": res.ag, "res": r})
	if D().matches.size() > 100: D().matches.resize(100)
	Save.dirty()
func league3_check(team: Dictionary) -> void:
	var c = {}
	for p in team.players:
		if p.is_empty(): continue
		c[p.lg] = c.get(p.lg, 0) + 1
		if c[p.lg] >= 3: track("league3"); return

## fast statistical match simulation
func simulate_match(cfg: Dictionary) -> Dictionary:
	var H = team_strength(cfg.home.formation, cfg.home.players, cfg.home.get("chem"))
	var A = team_strength(cfg.away.formation, cfg.away.players, cfg.away.get("chem"))
	var hs: float = H.att * 0.4 + H.mid * 0.35 + H.def * 0.25
	var as_: float = A.att * 0.4 + A.mid * 0.35 + A.def * 0.25
	var sc = sim_score(hs, as_, 1.0 if cfg.get("user_side", "") != "" else 1.5)
	var goals = []
	for side in ["home", "away"]:
		var t: Dictionary = cfg[side]
		for i in sc[0 if side == "home" else 1]:
			var ws = []
			for k in t.players.size():
				var w: float = {"ATT": 6.0, "MID": 3.0, "DEF": 1.0, "GK": 0.02}[Data.pos_group[Data.formations[t.formation][k][0]]]
				ws.append([w * t.players[k].stats[1] / 60.0, t.players[k]])
			var p: Dictionary = weighted(ws)
			var ast = pick(t.players.filter(func(x): return x != p)) if chance(0.7) else null
			goals.append({"side": side, "pid": p.id, "name": p.name, "pos": p.pos, "min": rint(1, 90), "assist": ast.name if ast else ""})
	goals.sort_custom(func(a, b): return a.min < b.min)
	var winner = "home" if sc[0] > sc[1] else ("away" if sc[1] > sc[0] else "")
	var pens = null
	if winner == "" and cfg.get("knockout", false):
		var a = rint(3, 5); var b = 4 if a == 5 else rint(2, 5)
		var hw = chance(0.5 + (hs - as_) / 60.0)
		pens = [max(a, b + 1), b] if hw else [b, max(a, b + 1)]
		winner = "home" if pens[0] > pens[1] else "away"
	var poss = int(clamp(round(50 + (H.mid - A.mid) * 1.2 + randf_range(-5, 5)), 30, 70))
	var stats = {"poss": [poss, 100 - poss], "shots": [rint(4, 9) + sc[0] * 2, rint(4, 9) + sc[1] * 2], "sot": [sc[0] + rint(1, 3), sc[1] + rint(1, 3)],
		"passes": [rint(300, 520), rint(300, 520)], "tackles": [rint(8, 20), rint(8, 20)], "fouls": [rint(4, 12), rint(4, 12)], "corners": [rint(1, 8), rint(1, 8)]}
	return {"home": cfg.home, "away": cfg.away, "hg": sc[0], "ag": sc[1], "goals": goals, "stats": stats, "winner": winner, "pens": pens, "user_side": cfg.get("user_side", ""), "simulated": true, "mode": cfg.get("mode", "")}
