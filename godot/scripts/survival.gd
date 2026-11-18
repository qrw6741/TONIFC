extends Node
## SURVIVAL — take your squad as far as it can go.
## Every round the opponent is stronger. Win to climb the reward ladder (the further you go, the bigger the prize).
## Every loss knocks one of your XI out of the run (a 55-rated youth player takes his place). 3 losses and you're out.
## Cash out any time to bank the reward for the round you reached — get knocked out and you only keep half the coins
## and drop two steps down the ladder.

const LIVES := 3
## reward for reaching (winning) each round
const LADDER := [
	{"coins": 2000}, {"coins": 4000}, {"pack": "premium", "coins": 3000}, {"pack": "premium", "coins": 6000}, {"pack": "rare", "coins": 8000},
	{"pack": "rare", "coins": 12000}, {"pack": "mega", "coins": 15000}, {"pack": "pick84", "coins": 20000}, {"pack": "pp85x1", "coins": 25000}, {"pack": "pick86", "coins": 30000},
	{"pack": "pick86", "coins": 40000}, {"pack": "totwpack", "coins": 50000}, {"pack": "pick88", "coins": 60000}, {"pack": "ultimate", "coins": 75000}, {"pack": "pick88", "coins": 90000},
	{"pack": "pickhero", "coins": 110000}, {"pack": "champpick", "coins": 130000}, {"pack": "pickhero", "coins": 160000}, {"pack": "pick88", "coins": 200000}, {"pack": "pickicon", "coins": 300000}]

func st() -> Dictionary:
	var d = Save.data
	if typeof(d.modes.get("survival")) != TYPE_DICTIONARY: d.modes.survival = {"run": null, "best": 0, "history": []}
	return d.modes.survival
func run(): return st().run

func start() -> bool:
	var sq = Sys.active_squad()
	if not Sys.squad_complete(sq): return false
	st().run = {"slots": sq.slots.duplicate(), "out": [], "wins": 0, "losses": 0, "formation": sq.formation, "name": sq.name}
	Save.dirty(); return true

## opponent for the next round: starts gentle, +1.6 OVR a round, AI gets sharper too
func opp_strength(round_i: int) -> float: return min(97.0, 74.0 + round_i * 1.6)
func opp_ai(round_i: int) -> float: return min(1.4, 0.45 + round_i * 0.05)

func reward_for(wins: int) -> Dictionary:
	if wins <= 0: return {}
	return LADDER[min(wins, LADDER.size()) - 1]

## the run's team: knocked-out players are replaced by youth players
func team() -> Dictionary:
	var r = run()
	var ut = Sys.user_team()
	var F: Array = Data.formations[r.formation]
	var ps = []
	for i in 11:
		var u: String = r.slots[i]
		if r.out.has(i) or u == "" or Sys.item(u).is_empty(): ps.append(youth(F[i][0]))
		else: ps.append(Sys.item_player(u))
	ut.players = ps; ut.formation = r.formation; ut.subs = []
	return ut
func youth(pos: String) -> Dictionary:
	# the weakest real players who can play there, shown as a 55-rated youth
	var pool = Data.players.filter(func(p): return p.type == "base" and Data.fits_pos(p, pos))
	pool.sort_custom(func(a, b): return a.ovr < b.ovr)
	var p: Dictionary = pool[abs(hash(pos)) % min(20, pool.size())].duplicate()
	var drop: int = max(0, int(p.ovr) - 55)
	p.ovr = 55; p.stats = p.stats.map(func(v): return max(30, int(v) - drop)); p.youth = true; p.id = "youth_" + pos
	return p

## after a match: returns {result, knocked (slot or -1), over, reward}
func record(result: String) -> Dictionary:
	var r = run(); var out = {"result": result, "knocked": -1, "over": false, "reward": {}}
	if result == "W":
		r.wins = int(r.wins) + 1
		st().best = max(int(st().best), int(r.wins))
	else:
		r.losses = int(r.losses) + 1
		var alive = []
		for i in 11: if not r.out.has(i): alive.append(i)
		if not alive.is_empty():
			var k: int = alive[randi() % alive.size()]; r.out.append(k); out.knocked = k
		if int(r.losses) >= LIVES:
			out.over = true; out.reward = _finish(true)
	Save.dirty()
	return out

func cash_out() -> Dictionary: return _finish(false)

func _finish(knocked_out: bool) -> Dictionary:
	var r = run()
	var wins: int = int(r.wins)
	var rw: Dictionary = reward_for(wins - (2 if knocked_out else 0)).duplicate()
	if knocked_out and rw.has("coins"): rw.coins = int(rw.coins) / 2
	if not rw.is_empty(): Sys.grant(rw, "Survival · %d wins" % wins)
	st().history.push_front({"t": Sys.now(), "wins": wins, "out": knocked_out})
	if st().history.size() > 20: st().history.resize(20)
	st().run = null
	Sys.history("Survival run over: %d wins%s" % [wins, " (knocked out)" if knocked_out else " (cashed out)"])
	Save.dirty()
	return rw
