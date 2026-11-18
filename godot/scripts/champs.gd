extends Node
## FUT Champions (FC-style).
## • Qualify: earn 1,000 Champions Qualification Points in Division Rivals (win 200 · draw 100 · loss 50)
##   and be in Rivals Division 10 or better.
## • Event: a weekly 15-match run. Win = 4 pts, loss = 1 pt. 15 ranks: Contender V–I, Elite V–I, Champion V–I.
## • Rewards for the HIGHEST rank reached (Champions Tokens, coins, packs, picks) when the run ends.
## • 5-minute cooldown after every Champions RUN before you can start the next one.
## • Champions Tokens are spent in the Champions Token Store.

signal changed

const QP_NEED := 1000
const MATCHES := 15
const COOLDOWN := 300.0
const WIN_PTS := 4
const LOSS_PTS := 1
const MIN_DIV := 10
const TIERS := ["Contender", "Elite", "Champion"]
const NUM := ["V", "IV", "III", "II", "I"]
const RANK_PTS := [1, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 46, 52, 56, 60]
## rank rewards: Champions Tokens + coins (+ QP) — spend the tokens in the Champions Token Store
const REWARDS := [
	{"tokens": 15, "coins": 6000}, {"tokens": 25, "coins": 9000}, {"tokens": 35, "coins": 12000}, {"tokens": 45, "coins": 16000}, {"tokens": 60, "coins": 20000},
	{"tokens": 80, "coins": 26000, "qp": 300}, {"tokens": 100, "coins": 32000, "qp": 300}, {"tokens": 120, "coins": 40000, "qp": 400}, {"tokens": 140, "coins": 48000, "qp": 500}, {"tokens": 170, "coins": 58000, "qp": 500},
	{"tokens": 200, "coins": 70000, "qp": 1000}, {"tokens": 240, "coins": 85000, "qp": 1000}, {"tokens": 280, "coins": 100000, "qp": 1000}, {"tokens": 330, "coins": 120000, "qp": 1000}, {"tokens": 450, "coins": 250000, "qp": 1000}]

func _ready() -> void:
	# Champions Player Pick: 1 of 5 players rated 86+ (Elite I and above)
	if not Data.packs.has("champpick"):
		Data.packs["champpick"] = {"name": "Champions 86+ Pick", "items": 1, "coins": 0, "points": 0, "art": "pick", "guar": [["ovr86", 1]], "w": {"ovr86": 1}, "desc": "Choose 1 of 5 players rated 86 or higher.", "reward": true, "pick": {"n": 5, "tier": "ovr86"}}

const STORE := [
	{"id": "coins", "name": "5,000 Coins", "cost": 10, "limit": 0, "reward": {"coins": 5000}},
	{"id": "premium", "name": "Premium Gold Pack", "cost": 25, "limit": 0, "reward": {"pack": "premium"}},
	{"id": "rare", "name": "Rare Players Pack", "cost": 60, "limit": 0, "reward": {"pack": "rare"}},
	{"id": "pp83", "name": "83+ x2 Players Pack", "cost": 90, "limit": 5, "reward": {"pack": "pp83x2"}},
	{"id": "mega", "name": "Mega Pack", "cost": 120, "limit": 0, "reward": {"pack": "mega"}},
	{"id": "pick84", "name": "84+ Player Pick", "cost": 150, "limit": 3, "reward": {"pack": "pick84"}},
	{"id": "pp85", "name": "85+ Player Pack", "cost": 180, "limit": 3, "reward": {"pack": "pp85x1"}},
	{"id": "totw", "name": "Team of the Week Pack", "cost": 200, "limit": 2, "reward": {"pack": "totwpack"}},
	{"id": "pick86", "name": "86+ Player Pick", "cost": 300, "limit": 2, "reward": {"pack": "pick86"}},
	{"id": "ultimate", "name": "Ultimate Pack", "cost": 350, "limit": 2, "reward": {"pack": "ultimate"}},
	{"id": "champpick", "name": "Champions 86+ Pick (1 of 5)", "cost": 400, "limit": 2, "reward": {"pack": "champpick"}},
	{"id": "rtk", "name": "UCL RTK Pack", "cost": 450, "limit": 1, "reward": {"pack": "rtkpack"}},
	{"id": "blackout", "name": "Blackout Pack", "cost": 450, "limit": 1, "reward": {"pack": "blackoutpack"}},
	{"id": "pick88", "name": "88+ Player Pick", "cost": 550, "limit": 1, "reward": {"pack": "pick88"}},
	{"id": "hero", "name": "Hero Player Pick", "cost": 600, "limit": 1, "reward": {"pack": "pickhero"}},
	{"id": "icon", "name": "Icon Player Pick", "cost": 1200, "limit": 1, "reward": {"pack": "pickicon"}}]

func st() -> Dictionary:
	var d = Save.data
	if d == null: return {}
	var c: Dictionary = d.modes.champs
	for kv in [["qp", 0], ["run", null], ["tokens", 0], ["bought", {}], ["history", []], ["next_at", 0.0]]:
		if not c.has(kv[0]): c[kv[0]] = kv[1]
	return c

func rank_name(i: int) -> String: return "%s %s" % [TIERS[i / 5], NUM[i % 5]] if i >= 0 else "Unranked"
## index of the highest rank reached with these points (-1 = none)
func rank_for(pts: int) -> int:
	var r = -1
	for i in RANK_PTS.size(): if pts >= RANK_PTS[i]: r = i
	return r

func run() -> Variant: return st().run
func qualified() -> bool: return int(st().qp) >= QP_NEED
func div_ok() -> bool: return int(Save.data.modes.rivals.div) <= MIN_DIV
func cooldown_left() -> float: return max(0.0, float(st().next_at) - Sys.now())
func event_left() -> float: return Sys.secs_to_reset("weekly")

func add_qp(result: String) -> int:
	var c = st()
	if c.run != null: return 0
	var n: int = {"W": 200, "D": 100, "L": 50}[result]
	var before: int = int(c.qp)
	c.qp = min(QP_NEED, before + n)
	if before < QP_NEED and int(c.qp) >= QP_NEED: Sys.toast.emit("Qualified for FUT Champions!", "good")
	Save.dirty(); changed.emit()
	return int(c.qp) - before

## start a run (uses the qualification points)
func start() -> bool:
	var c = st()
	if c.run != null or not qualified() or not div_ok() or cooldown_left() > 0: return false
	c.qp = 0
	c.run = {"week": Sys.week_key(), "played": 0, "w": 0, "l": 0, "pts": 0, "results": [], "done": false}
	Sys.history("Qualified and entered FUT Champions")
	Save.dirty(); changed.emit(); return true

func record(won: bool, score: String, opp: String) -> Dictionary:
	var r = st().run
	r.played += 1
	if won: r.w += 1; r.pts += WIN_PTS; Sys.track("champs_win")
	else: r.l += 1; r.pts += LOSS_PTS
	r.results.append({"won": won, "score": score, "opp": opp})
	var rk = rank_for(int(r.pts))
	if r.played >= MATCHES: r.done = true
	Save.dirty(); changed.emit()
	return {"pts": WIN_PTS if won else LOSS_PTS, "rank": rk}

func remaining() -> int: return MATCHES - int(run().played) if run() != null else MATCHES

## the run is over (15 played, ended early, or the weekly event closed): pay the highest rank reached
func claim() -> Dictionary:
	var c = st(); var r = c.run
	if r == null: return {}
	var rk = rank_for(int(r.pts))
	var rw: Dictionary = REWARDS[rk] if rk >= 0 else {}
	if not rw.is_empty(): grant(rw, "FUT Champions " + rank_name(rk))
	c.history.push_front({"t": Sys.now(), "w": r.w, "l": r.l, "pts": r.pts, "rank": rk})
	c.run = null
	c.next_at = Sys.now() + COOLDOWN
	Sys.history("FUT Champions finished: %d-%d · %s" % [r.w, r.l, rank_name(rk)])
	Save.dirty(); changed.emit()
	return {"rank": rk, "reward": rw}

func grant(rw: Dictionary, src: String) -> void:
	if rw.get("tokens", 0): c_add_tokens(int(rw.tokens))
	if rw.get("qp", 0): st().qp = min(QP_NEED, int(st().qp) + int(rw.qp))
	var r2 = rw.duplicate(); r2.erase("tokens"); r2.erase("qp")
	if r2.has("packs"):
		for p in r2.packs: Save.data.unopened.append(p)
		Sys.toast.emit("%d packs added to My Packs" % r2.packs.size(), "good"); r2.erase("packs")
	Sys.grant(r2, src)

func c_add_tokens(n: int) -> void: st().tokens = int(st().tokens) + n; Save.dirty()
func tokens() -> int: return int(st().tokens)
func reward_text(rw: Dictionary) -> String:
	var parts = []
	if rw.get("tokens", 0): parts.append("%d x Champions Token" % rw.tokens)
	if rw.get("qp", 0): parts.append("%s Champions Qualification Points" % Sys.fmt(rw.qp))
	if rw.get("coins", 0): parts.append("%s Coins" % Sys.fmt(rw.coins))
	if rw.has("pack"): parts.append(Data.packs[rw.pack].name)
	for p in rw.get("packs", []): parts.append(Data.packs[p].name)
	return " · ".join(parts)

## called when the Champions screen opens: an unfinished run from a past week pays out automatically
func check_week() -> Dictionary:
	var r = run()
	if r != null and r.week != Sys.week_key(): return claim()
	return {}

func bought(i: String) -> int: return int(st().bought.get(i, 0))
func can_buy(it: Dictionary) -> bool: return tokens() >= int(it.cost) and (int(it.limit) == 0 or bought(it.id) < int(it.limit))
func buy(it: Dictionary) -> bool:
	if not can_buy(it): Sfx.play("error"); return false
	st().tokens = tokens() - int(it.cost); st().bought[it.id] = bought(it.id) + 1
	Sys.grant(it.reward, "Champions Token Store"); Save.dirty(); changed.emit(); return true
