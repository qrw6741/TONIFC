extends RefCounted
## Ultimate XI: SBC, Transfers, Play hub, Squad Battles, Rivals, Champions, Draft,
## Friendlies, plus match launching and the full-time results screen.

func _hub(f: Dictionary, tab: String) -> Dictionary:
	return {"node": f.node, "bg": "hub", "tab": tab, "back": func(): UI.reset("main")}
func page_title(t: String) -> Label: return UI.head(t.to_upper(), 38)

# ------------------------------------------------------------------ SBC
func s_sbcbuild(p) -> Dictionary:
	var sbc: Dictionary = {}
	for s in Data.sbcs: if s.id == p.id: sbc = s
	var f = UI.sub_shell(sbc.name, "SBC · " + sbc.cat)
	var size = int(sbc.size)
	var st: Dictionary = Save.data.sbc.draft.get(sbc.id, {"formation": "4-3-3", "uids": []})
	st.uids = st.uids.filter(func(u): return u == "" or not Sys.item(u).is_empty())
	while st.uids.size() < size: st.uids.append("")
	Save.data.sbc.draft[sbc.id] = st
	var row = UI.hb(22); UI.grow(row); f.body.add_child(row)
	var E = SBCEditor.new(sbc, st, row, p.get("cat", sbc.cat))
	row.set_meta("editor", E)
	E.draw(-1)
	return {"node": f.node, "bg": "hub"}

class SBCEditor extends RefCounted:
	var sbc: Dictionary; var st: Dictionary; var row: HBoxContainer; var cat: String
	var cards = []
	func _init(s, state, r, c) -> void: sbc = s; st = state; row = r; cat = c
	func players() -> Array: return st.uids.map(func(u): return {} if u == "" else Sys.item_player(u))
	func draw(focus_i: int) -> void:
		for c in row.get_children(): c.queue_free()
		cards.clear()
		var ps = players(); var chk = Sys.sbc_check(sbc, ps, st.formation)
		var side = UI.vb(12); side.custom_minimum_size.x = 340
		var reqs = UI.vb(4, [UI.caps("Requirements", 11)])
		for r in chk.reqs: reqs.add_child(UI.hb(8, [UI.bold("✓" if r.ok else "✕", 14, UI.GREEN if r.ok else UI.RED), UI.wrapl(UI.label(r.label, 13), 280)]))
		side.add_child(UI.panel(reqs, "Glass"))
		side.add_child(UI.panel(UI.vb(4, [UI.caps("Reward", 11), UI.wrapl(UI.bold(Sys.reward_text(sbc.reward), 14, UI.TEAL), 300)]), "Glass"))
		if int(sbc.size) == 11: side.add_child(UI.field("Formation", UI.option(Data.formation_names.map(func(x): return [x, x]), st.formation, func(v): st.formation = v; Save.dirty(); draw(-1))))
		side.add_child(UI.hb(8, [UI.btn("Auto-fill", func(): autofill(); Save.dirty(); draw(-1), "Small"), UI.btn("Clear", func(): st.uids = st.uids.map(func(_u): return ""); Save.dirty(); draw(-1), "Small")]))
		var sub = UI.btn("Submit squad", submit, "Primary" if chk.ok else ""); sub.disabled = not chk.ok
		side.add_child(sub)
		side.add_child(UI.wrapl(UI.label("Submitted players are permanently removed from your club. Players listed on the market can't be used.", 12, UI.DIM), 320))
		row.add_child(side)
		if int(sbc.size) == 11:
			var pitch = PitchView.new().setup(st.formation, ps, chk.chem)
			pitch.slot_pressed.connect(func(i): slot(i))
			row.add_child(pitch); cards = pitch.cards
		else:
			var flow = HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 14); flow.add_theme_constant_override("v_separation", 14)
			flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for i in ps.size():
				var c = PlayerCard.make(ps[i], 10.0); c.empty_pos = "ANY"
				c.pressed.connect(func(): Sfx.play("select"); slot(i))
				flow.add_child(c); cards.append(c)
			row.add_child(flow)
		_refocus(focus_i)
	func _refocus(i: int) -> void:
		await UI.get_tree().process_frame
		if i >= 0 and i < cards.size() and is_instance_valid(cards[i]): cards[i].grab_focus()
	func slot(i: int) -> void:
		var used = {}; var used_pids = {}
		for u in st.uids: if u != "": used[u] = true; used_pids[Sys.item(u).pid] = true
		if st.uids[i] != "":
			var v = await UI.modal("Slot", UI.player_row(Sys.item_player(st.uids[i]), [], func(): pass), [["Replace", "r", "Primary"], ["Remove", "x", ""], ["Cancel", null, ""]])
			if v == "x": st.uids[i] = ""; Save.dirty(); draw(i); return
			if v != "r": return
		var pos: String = Data.formations[st.formation][i][0] if int(sbc.size) == 11 else ""
		var u = await UI.pick_player("Select player" + ((" · " + pos) if pos != "" else ""), pos, func(it): return not used.has(it.uid) and not used_pids.has(it.pid))
		if u != null: st.uids[i] = u; Save.dirty(); Sfx.play("select")
		draw(i)
	func autofill() -> void:
		var all_tier = null; var min_rat = 0; var same_lg = false
		for r in sbc.reqs:
			if r.t == "tierAll": all_tier = r.v
			if r.t == "rating": min_rat = int(r.v)
			if r.t == "sameLeague": same_lg = true
		var used = {}; var used_pids = {}
		for u in st.uids: if u != "": used[u] = true; used_pids[Sys.item(u).pid] = true
		var pool: Array = Save.data.club.filter(func(it): return not used.has(it.uid) and not Sys.in_market(it.uid) and not used_pids.has(it.pid)).map(func(it): return [it, Data.P(it.pid)])
		if all_tier != null: pool = pool.filter(func(x): return Data.tier_of(x[1].ovr) == all_tier and x[1].type == "base")
		if same_lg:
			var cnt = {}
			for x in pool: cnt[x[1].lg] = cnt.get(x[1].lg, 0) + 1
			var best = ""; var bn = 0
			for k in cnt: if cnt[k] > bn: bn = cnt[k]; best = k
			pool = pool.filter(func(x): return x[1].lg == best)
		pool.sort_custom(func(a, b): return (1 if Sys.in_any_squad(a[0].uid) else 0) * 100 + abs(a[1].ovr - min_rat) < (1 if Sys.in_any_squad(b[0].uid) else 0) * 100 + abs(b[1].ovr - min_rat))
		for i in st.uids.size():
			if st.uids[i] != "": continue
			var pos: String = Data.formations[st.formation][i][0] if int(sbc.size) == 11 else ""
			var k = -1
			for j in pool.size():
				if not used_pids.has(pool[j][1].id) and (pos == "" or Data.fits_pos(pool[j][1], pos)): k = j; break
			if k < 0:
				for j in pool.size():
					if not used_pids.has(pool[j][1].id) and (pos == "" or (pos == "GK") == (pool[j][1].pos == "GK")): k = j; break
			if k < 0: continue
			var x = pool[k]; pool.remove_at(k); used_pids[x[1].id] = true; st.uids[i] = x[0].uid
		Sfx.play("select")
	func submit() -> void:
		var vals = 0
		for p in players(): if not p.is_empty(): vals += Sys.value(p)
		if await UI.modal("Submit SBC?", "%d players (est. value %s coins) will be exchanged for: %s" % [int(sbc.size), Sys.fmt(vals), Sys.reward_text(sbc.reward)], [["Cancel", null, ""], ["Submit", true, "Primary"]]):
			if Sys.sbc_submit(sbc, st.uids, st.formation):
				Sfx.play("bigreveal"); Save.data.sbc.draft.erase(sbc.id)
				UI.toast("SBC complete! " + Sys.reward_text(sbc.reward), "good")
				UI.stack.clear(); UI.replace("sbc", {"cat": cat})

# ------------------------------------------------------------------ TRANSFERS
# ------------------------------------------------------------------ PLAY
func s_play(_p) -> Dictionary:
	var f = UI.hub_shell("play")
	var m: Dictionary = Save.data.modes; var rv: Dictionary = m.rivals
	if m.sb.week != Sys.week_key(): m.sb.week = Sys.week_key(); m.sb.points = 0; m.sb.played = 0
	var sb_rank = sb_rank_for(m.sb.points)
	var sq = Sys.active_squad(); var inf = Sys.squad_info(sq)
	f.body.add_child(UI.hb(10, [page_title("Play"), UI.spacer(), UI.label("Active squad: %s · %d OVR · %d chem%s" % [sq.name, inf.rating, inf.chem.total, "" if Sys.squad_complete(sq) else " · INCOMPLETE"], 14, UI.DIM if Sys.squad_complete(sq) else UI.RED)]))
	var g = GridContainer.new(); g.columns = 3; g.add_theme_constant_override("h_separation", 18); g.add_theme_constant_override("v_separation", 18); UI.grow(g)
	var center = func(nodes: Array) -> Control: var c = CenterContainer.new(); c.size_flags_vertical = Control.SIZE_EXPAND_FILL; c.add_child(UI.vb(4, nodes)); return c
	var rvs = Rivals.st()
	var rivals = UI.tile([UI.bold("Division Rivals", 30), UI.wrapl(UI.bold("Climb ranks I–XII in each division to reach Elite. Rewards every 15 minutes.", 13, UI.TEAL), 380),
		center.call([UI.head("ELITE" if rv.div == 1 else str(rv.div), 64, Rivals.div_color(int(rv.div))), UI.bold(Rivals.div_name(int(rv.div)), 16), UI.bar(int(rvs.step), Rivals.STEPS), UI.label("Rank %d/12 · rewards in %s%s" % [int(rvs.step), Sys.fmt_time(Rivals.cycle_left()), (" · %d to claim" % rvs.unclaimed.size()) if not rvs.unclaimed.is_empty() else ""], 13, UI.DIM)])], func(): UI.go("rivals"), Vector2(0, 0), true)
	var champs: Dictionary = m.champs
	var tiles = [
		rivals,
		UI.tile([UI.bold("Squad Battles", 24), UI.wrapl(UI.bold("Play AI squads. Earn points by difficulty & performance.", 13, UI.TEAL), 300), center.call([UI.head(Sys.fmt(m.sb.points), 28), UI.label("pts this week · " + sb_rank.name, 13, UI.DIM)])], func(): UI.go("squadbattles")),
		UI.tile([UI.bold("FUT Champions", 24), UI.wrapl(UI.bold("Weekly 15-match event. Qualify with 1,000 points from Division Rivals.", 13, UI.TEAL), 300), center.call(_champs_summary())], func(): UI.go("champions")),
		UI.tile([UI.bold("Draft", 24), UI.wrapl(UI.bold("Build a temporary squad from random choices. Win 4 straight.", 13, UI.TEAL), 300), center.call([UI.bold("In progress · %d wins" % m.draft.active.wins if m.draft.active else "● %s or ◆ %d" % [Sys.fmt(Data.draft_cost.coins), Data.draft_cost.points], 15)])], func(): UI.go("draft")),
		UI.tile([UI.bold("Friendlies", 24), UI.wrapl(UI.bold("Casual matches with custom rules. No stakes.", 13, UI.TEAL), 300), center.call([UI.head("⚽", 40)])], func(): UI.go("friendlies"))]
	for t in tiles: UI.grow(t); g.add_child(t)
	g.add_child(Control.new())
	f.body.add_child(g)
	return _hub(f, "play")

func sb_rank_for(pts: int) -> Dictionary:
	for r in Data.sb_ranks: if pts >= r.pts: return r
	return Data.sb_ranks[-1]

func require_squad() -> bool:
	if not Sys.squad_complete(Sys.active_squad()):
		(func():
			if await UI.modal("Squad incomplete", "Your active squad needs 11 players before you can play. Use Auto-build in the Squad Builder.", [["Open Squad Builder", true, "Primary"], ["Cancel", null, ""]]): UI.go("squad")).call()
		return false
	return true

func choose_difficulty(name: String):
	var body = UI.vb(6)
	for k in Data.difficulty_order:
		var d: Dictionary = Data.difficulties[k]
		var b = UI.btn("%s      %d pts · %s coins" % [d.name, d.sbPts, Sys.fmt(d.coins)], func(): UI.close_top(k), "Row", k == "professional")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT; body.add_child(b)
	return await UI.modal("vs %s — choose difficulty" % name, body, [["Cancel", null, ""]])

# ------------------------------------------------------------------ SQUAD BATTLES
func s_squadbattles(_p) -> Dictionary:
	var f = UI.sub_shell("Squad Battles", "Play")
	var sb: Dictionary = Save.data.modes.sb
	if sb.opps.is_empty() or sb.opps_week != Sys.week_key():
		sb.opps_week = Sys.week_key()
		var names: Array = Sys.shuffled(Data.ai_squad_names).slice(0, 8)
		sb.opps = []
		for i in names.size(): sb.opps.append({"name": names[i], "str": 66 + i * 3 + Sys.rint(0, 2), "done": []})
		Save.dirty()
	var rank = sb_rank_for(sb.points)
	var row = UI.hb(20); UI.grow(row)
	var left = UI.vb(10, [UI.wrapl(UI.label("Choose an opponent and difficulty. Higher difficulty = more points; points also scale with goals and clean sheets.", 13, UI.DIM), 800)]); UI.grow(left)
	var flow = HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 14); flow.add_theme_constant_override("v_separation", 14)
	for i in sb.opps.size():
		var o: Dictionary = sb.opps[i]
		flow.add_child(UI.tile([UI.bold(o.name, 18), UI.bold("Squad rating ~%d" % o.str, 13, UI.TEAL), UI.label("Beaten on: " + (", ".join(o.done.map(func(d): return Data.difficulties[d].name)) if not o.done.is_empty() else "—"), 12, UI.DIM)],
			func(): sb_play(o), Vector2(240, 130), i == 0))
	left.add_child(UI.scroll(flow)); row.add_child(left)
	var right = UI.vb(14); right.custom_minimum_size.x = 340
	var week = UI.vb(6, [UI.caps("This week"), UI.head(Sys.fmt(sb.points), 34), UI.bold(rank.name, 16)])
	if rank.reward:
		week.add_child(UI.wrapl(UI.label("Current reward: " + Sys.reward_text(rank.reward), 13, UI.TEAL), 300))
		var cb = UI.btn("Claimed this week" if sb.claimed_week == Sys.week_key() else "Claim rank reward", func():
			if await UI.modal("Claim rank reward?", "Claiming locks in %s for this week: %s." % [rank.name, Sys.reward_text(rank.reward)], [["Cancel", null, ""], ["Claim", true, "Primary"]]):
				sb.claimed_week = Sys.week_key(); Sys.grant(rank.reward, "Squad Battles " + rank.name); UI.rerender(), "Primary")
		cb.disabled = sb.claimed_week == Sys.week_key(); week.add_child(cb)
	right.add_child(UI.panel(week))
	var lb = []
	var frac: float = clamp(fmod(Sys.now(), 604800.0) / 604800.0 + 0.15, 0.0, 1.0)
	for n in Data.ai_squad_names.slice(0, 9):
		lb.append({"n": "%sMgr%d" % [n.split(" ")[0], Gfx.hash_s(n + Sys.week_key()) % 900 + 100], "p": int((Gfx.hash_s(n + Sys.week_key()) % 3800) * frac), "me": false})
	lb.append({"n": Save.data.profile.name + " (you)", "p": sb.points, "me": true})
	lb.sort_custom(func(a, b): return a.p > b.p)
	var lbv = UI.vb(4, [UI.caps("Weekly leaderboard")])
	for i in lb.size(): lbv.add_child(UI.hb(8, [UI.label("%d" % (i + 1), 14, UI.DIM), UI.bold(lb[i].n, 14, UI.TEAL if lb[i].me else UI.TEXT), UI.spacer(), UI.bold(Sys.fmt(lb[i].p), 14)]))
	var lp = UI.panel(lbv); UI.grow(lp, true, false); right.add_child(lp)
	row.add_child(right)
	f.body.add_child(row)
	return {"node": f.node, "bg": "hub"}

func sb_play(o: Dictionary) -> void:
	if not require_squad(): return
	var d = await choose_difficulty(o.name)
	if d == null: return
	var D: Dictionary = Data.difficulties[d]
	var ut = Sys.user_team(); var opp = Sys.ai_team(o.name, round((o.str + D.ovr) / 2.0))
	Sys.league3_check(ut)
	run_match({"home": ut, "away": opp, "user_side": "home", "difficulty": d, "ai": min(1.3, Data.difficulties[d].ai + Sys.experience() * 0.5), "half_len": int(Save.data.settings.half_len), "mode": "sb", "title": "Squad Battles"}, func(res):
		var sb: Dictionary = Save.data.modes.sb
		var r = Sys.record_ut_match(res)
		var pts = int(round(D.sbPts * (1.0 if r == "W" else (0.5 if r == "D" else 0.2)) + res.hg * 10 + (20 if res.ag == 0 else 0)))
		sb.points += pts; sb.played += 1
		if r == "W":
			Sys.track("sb_win")
			if not o.done.has(d): o.done.append(d)
		var coins: int = D.coins * (2 if r == "W" else 1)
		Sys.add("coins", coins, "Squad Battles vs " + o.name)
		Sys.log_match(res, "Squad Battles", r)
		show_results(res, "Squad Battles", "+%d SB points · +%s coins" % [pts, Sys.fmt(coins)], func(): UI.replace("squadbattles")))

# ------------------------------------------------------------------ RIVALS
func _champs_summary() -> Array:
	var r = Champs.run()
	if r != null: return [UI.head("%d pts" % int(r.pts), 28), UI.label("%s · %d/%d played" % [Champs.rank_name(Champs.rank_for(int(r.pts))), int(r.played), Champs.MATCHES], 13, UI.DIM)]
	if Champs.qualified(): return [UI.head("Qualified", 28, UI.GREEN), UI.label("Ready to play", 13, UI.DIM)]
	return [UI.head("%s/%s" % [Sys.fmt(Champs.st().qp), Sys.fmt(Champs.QP_NEED)], 28), UI.label("Qual. Points", 13, UI.DIM)]

func rivals_play() -> void: UI.modules[10].play_match()

# ------------------------------------------------------------------ CHAMPIONS
# ------------------------------------------------------------------ DRAFT
func s_draft(_p) -> Dictionary:
	var f = UI.sub_shell("Draft", "Play")
	var d: Dictionary = Save.data.modes.draft
	if d.active == null:
		var tiers = UI.vb(4)
		for w in 5: tiers.add_child(UI.hb(10, [UI.bold("%d wins" % w, 14), UI.label(Sys.reward_text(Sys.draft_reward(w)), 13, UI.DIM)]))
		var start = func(cur: String):
			if not Sys.spend(cur, Data.draft_cost[cur], "Draft entry"): return
			d.active = {"formation": "", "slots": ["", "", "", "", "", "", "", "", "", "", ""], "captain": "", "wins": 0, "stage": "formation", "opp": null}; Save.dirty(); UI.rerender()
		var v = UI.vb(14, [UI.head("START A DRAFT", 24), UI.wrapl(UI.label("Choose a formation, then pick a captain and one player for each position from five random choices — including Team of the Week, Nightfall, Heroes and Icons. Your draft squad is temporary. Win up to 4 knockout matches for rewards.", 14, UI.DIM), 620), tiers,
			UI.hb(10, [UI.btn("Enter (● %s)" % Sys.fmt(Data.draft_cost.coins), func(): start.call("coins"), "Primary", true), UI.btn("Enter (◆ %d)" % Data.draft_cost.points, func(): start.call("points"))])])
		var cc = CenterContainer.new(); UI.grow(cc); cc.add_child(UI.panel(v)); f.body.add_child(cc)
		return {"node": f.node, "bg": "hub"}
	var A: Dictionary = d.active
	if A.stage == "formation":
		f.body.add_child(UI.head("CHOOSE YOUR FORMATION", 28))
		var h = UI.hb(16)
		for fm in Sys.shuffled(Data.formation_names).slice(0, 5):
			h.add_child(UI.tile([UI.bold(fm, 22), UI.icon("minipitch", {"formation": fm, "players": []}, Vector2(180, 200))], func(): A.formation = fm; A.stage = "pick"; Save.dirty(); UI.rerender(), Vector2(220, 280)))
		f.body.add_child(h)
		return {"node": f.node, "bg": "hub"}
	var players: Array = A.slots.map(func(id): return {} if id == "" else Data.P(id))
	var chem = Sys.chemistry(A.formation, players)
	var cap_idx: int = A.slots.find(A.captain) if A.captain != "" else -1
	var row = UI.hb(22); UI.grow(row)
	var side = UI.vb(12); side.custom_minimum_size.x = 320
	side.add_child(UI.hb(10, [UI.panel(UI.vb(0, [UI.head(str(Sys.squad_rating(players)), 30), UI.caps("Rating", 10)]), "Glass"), UI.panel(UI.vb(0, [UI.head(str(chem.total), 30), UI.caps("Chem", 10)]), "Glass")]))
	var pitch = PitchView.new().setup(A.formation, players, chem, cap_idx)
	if A.stage == "pick":
		side.add_child(UI.wrapl(UI.label("Select each position on the pitch to pick from 5 players. " + ("" if A.captain != "" else "Start with your captain (any position)."), 14, UI.DIM), 300))
		if not A.slots.has(""): side.add_child(UI.btn("Start tournament", func(): A.stage = "play"; Save.dirty(); UI.rerender(), "Primary", true))
		side.add_child(UI.btn("Abandon draft", func():
			if await UI.modal("Abandon draft?", "Your entry fee is not refunded.", [["Cancel", null, ""], ["Abandon", true, "Danger"]]): d.active = null; Save.dirty(); UI.rerender(), "Danger"))
		pitch.slot_pressed.connect(func(i): draft_pick(A, i))
	else:
		if A.opp == null: A.opp = {"name": Sys.pick(Data.ai_squad_names), "str": 80 + A.wins * 2.5}
		side.add_child(UI.head(Sys.DRAFT_ROUNDS[A.wins].to_upper(), 24))
		side.add_child(UI.label("vs %s (~%d OVR)" % [A.opp.name, int(A.opp.str)], 14, UI.DIM))
		var prog = UI.hb(6)
		for i in 4: prog.add_child(UI.pill(["R16", "QF", "SF", "F"][i], UI.GREEN if i < A.wins else UI.TEXT))
		side.add_child(prog)
		side.add_child(UI.wrapl(UI.label("Current reward: " + Sys.reward_text(Sys.draft_reward(A.wins)), 13, UI.TEAL), 300))
		side.add_child(UI.btn("Ⓐ  Play " + Sys.DRAFT_ROUNDS[A.wins], func(): draft_play(A, players, chem), "Primary", true))
		side.add_child(UI.btn("Quit & claim rewards", func(): draft_end(A), "Small"))
	row.add_child(side); row.add_child(pitch)
	f.body.add_child(row)
	return {"node": f.node, "bg": "hub"}

func draft_pick(A: Dictionary, i: int) -> void:
	if A.slots[i] != "": UI.toast("Already picked"); return
	var pos: String = Data.formations[A.formation][i][0]
	var excl = {}
	for id in A.slots: if id != "": excl[id] = true
	var choices = Sys.draft_choices(pos, excl, A.captain == "")
	var h = UI.hb(12); h.alignment = BoxContainer.ALIGNMENT_CENTER
	for p in choices:
		var c = UI.card(p, 10.5, false, func(): UI.close_top(p.id))
		h.add_child(UI.vb(4, [c, UI.label(Data.rarity_name(p), 12, UI.DIM)]))
	var pick = await UI.modal(("Pick your captain · " if A.captain == "" else "Pick · ") + pos, h, [["Cancel", null, ""]], true)
	if pick != null:
		A.slots[i] = pick
		if A.captain == "": A.captain = pick
		Sfx.play("reveal"); Save.dirty(); UI.rerender()

func draft_end(A: Dictionary) -> void:
	var d: Dictionary = Save.data.modes.draft
	var rw = Sys.draft_reward(A.wins)
	Sys.grant(rw, "Draft: %d wins" % A.wins); d.history.push_front({"t": Sys.now(), "w": A.wins}); d.active = null; Save.dirty(); Sfx.play("bigreveal")
	await UI.modal("Draft over — %d win%s" % [A.wins, "" if A.wins == 1 else "s"], "Rewards: " + Sys.reward_text(rw))
	UI.replace("draft")

func draft_play(A: Dictionary, players: Array, chem: Dictionary) -> void:
	var pr: Dictionary = Save.data.profile
	var team = {"name": pr.club_name + " Draft", "short": "DRF", "kit": pr.kit.home, "formation": A.formation, "players": players, "subs": [], "badge": pr.badge, "chem": chem, "is_user": true}
	var o = Sys.ai_team(A.opp.name, round(A.opp.str))
	run_match({"home": team, "away": o, "user_side": "home", "difficulty": "worldclass" if A.wins >= 2 else "professional", "half_len": int(Save.data.settings.half_len), "mode": "draft", "title": "Draft · " + Sys.DRAFT_ROUNDS[A.wins], "knockout": true}, func(res):
		Sys.record_ut_match(res)
		var won: bool = res.winner == "home"
		Sys.log_match(res, "Draft", "W" if won else "L")
		if won: A.wins += 1; A.opp = null; Sys.track("draft_win")
		Save.dirty()
		show_results(res, "Draft", ("Draft champion!" if A.wins >= 4 else "Through to the next round") if won else "Eliminated", func():
			if not won or A.wins >= 4: draft_end(A)
			else: UI.replace("draft")))

# ------------------------------------------------------------------ FRIENDLIES
const RULES := {"classic": ["Classic Match", "Standard rules."], "golden": ["Golden Goal", "Draw after 90 minutes? Next goal wins."], "longshot": ["Long Shots", "Goals from outside the box count double."],
	"headers": ["Headers & Volleys", "Only goals from headers or volleys count."], "nofouls": ["No Rules", "No fouls, no cards. Anything goes."]}

func s_friendlies(_p) -> Dictionary:
	var f = UI.sub_shell("Friendlies", "Play")
	var st = {"str": 80, "diff": Save.data.settings.difficulty}
	var list = UI.vb(10); UI.grow(list)
	var first = true
	for k in RULES:
		var t = UI.tile([UI.hb(10, [UI.vb(2, [UI.bold(RULES[k][0], 20), UI.bold(RULES[k][1], 13, UI.TEAL)]), UI.spacer(), UI.pill("Play")])], func():
			if not require_squad(): return
			var ut = Sys.user_team(); var opp = Sys.ai_team(Sys.pick(Data.ai_squad_names), st.str)
			run_match({"home": ut, "away": opp, "user_side": "home", "difficulty": st.diff, "half_len": int(Save.data.settings.half_len), "mode": "friendly", "rules": k, "title": RULES[k][0]}, func(res):
				var r = Sys.record_ut_match(res); Sys.log_match(res, "Friendly", r)
				show_results(res, "Friendly · " + RULES[k][0], "", func(): UI.replace("friendlies"))), Vector2.ZERO, first)
		first = false
		list.add_child(t)
	var side = UI.vb(12, [UI.caps("Opponent"), UI.field("Opponent strength", UI.option([70, 75, 80, 84, 88].map(func(v): return [v, "~%d OVR" % v]), 80, func(v): st.str = v)),
		UI.field("Difficulty", UI.option(Data.difficulty_order.map(func(k): return [k, Data.difficulties[k].name]), st.diff, func(v): st.diff = v)),
		UI.wrapl(UI.label("Friendlies count toward objectives but give no coins.", 12, UI.DIM), 260)])
	var sp = UI.panel(side); sp.custom_minimum_size.x = 320
	var row = UI.hb(22, [list, sp]); UI.grow(row); f.body.add_child(row)
	return {"node": f.node, "bg": "hub"}

# ------------------------------------------------------------------ match glue & results
func kit_clash(a: String, b: String) -> bool:
	var x = Color(a); var y = Color(b)
	return Vector3(x.r - y.r, x.g - y.g, x.b - y.b).length() < 0.47

func run_match(cfg: Dictionary, on_done: Callable) -> void:
	if kit_clash(cfg.home.kit.c1, cfg.away.kit.c1):
		var k: Dictionary = cfg.away
		if k.get("is_user", false): k.kit = Save.data.profile.kit.away
		else:
			var alt = "#ffffff" if not kit_clash("#ffffff", cfg.home.kit.c1) else "#111111"
			k.kit = {"c1": k.kit.c2 if not kit_clash(k.kit.c2, cfg.home.kit.c1) else alt, "c2": k.kit.c1}
	var start = func(sim: bool):
		if sim: on_done.call(Sys.simulate_match(cfg))
		else:
			var scene = preload("res://scripts/match/match_scene.gd").new()
			scene.setup(cfg, on_done)
			UI.root.add_child(scene)
			# keep the match BELOW the overlay layer so the pause menu, substitutions and toasts show on top
			UI.root.move_child(scene, UI.overlay.get_index())
	if cfg.has("sim"): start.call(cfg.sim); return
	var badge_for = func(t: Dictionary) -> Control:
		if t.has("badge"): return UI.icon("badge", t.badge, Vector2(70, 70))
		if t.has("crest"): return UI.icon("crest", t.crest, Vector2(70, 70))
		return UI.icon("badge", {"shape": "round", "c1": t.kit.c2, "c2": t.kit.c1, "icon": "ball"}, Vector2(70, 70))
	var side = func(t: Dictionary) -> Control:
		var v = UI.vb(6, [badge_for.call(t), UI.bold(t.name, 16), UI.label("%d OVR" % Sys.squad_rating(t.players), 13, UI.DIM)])
		for c in v.get_children(): c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.custom_minimum_size.x = 200; return v
	var info = "%s · %d-minute halves%s" % [Data.difficulties.get(cfg.get("difficulty", "professional"), {"name": ""}).name, int(cfg.get("half_len", 3)), (" · " + RULES[cfg.rules][0]) if cfg.get("rules", "classic") != "classic" else ""]
	var body = UI.vb(10, [UI.hb(20, [side.call(cfg.home), UI.head("VS", 30), side.call(cfg.away)]), UI.label(info, 14, UI.DIM)])
	body.get_child(0).alignment = BoxContainer.ALIGNMENT_CENTER
	var v = await UI.modal(cfg.get("title", "Match"), body, [["Cancel", null, ""], ["Simulate", "sim", ""], ["Play Match", "play", "Primary"]])
	if v != null: start.call(v == "sim")

func show_results(res: Dictionary, title: String, rewards: String, on_continue: Callable) -> void:
	var f = UI.sub_shell("Full Time", title)
	var row = UI.hb(24); UI.grow(row)
	var main = UI.vb(14); main.alignment = BoxContainer.ALIGNMENT_BEGIN
	var hn = UI.bold(res.home.name, 20); hn.custom_minimum_size.x = 240; hn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var an = UI.bold(res.away.name, 20); an.custom_minimum_size.x = 240
	main.add_child(UI.hb(30, [hn, UI.head("%d - %d" % [res.hg, res.ag], 76), an]))
	if res.get("pens") != null: main.add_child(UI.bold("Penalties %d - %d" % [res.pens[0], res.pens[1]], 16))
	if res.get("simulated", false): main.add_child(UI.pill("Simulated"))
	var gl = UI.vb(4); gl.custom_minimum_size.x = 280; var gr = UI.vb(4); gr.custom_minimum_size.x = 280
	for g in res.goals:
		var txt = "⚽ %s %d'%s%s" % [Data.short_name(g.name), g.min, " (OG)" if g.get("og", false) else "", (" (" + Data.short_name(g.assist) + ")") if g.get("assist", "") != "" else ""]
		var l = UI.label(txt, 14)
		if g.side == "home": l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; gl.add_child(l)
		else: gr.add_child(l)
	main.add_child(UI.hb(40, [gl, gr]))
	if rewards != "": main.add_child(UI.pill(rewards, UI.GREEN))
	main.add_child(UI.btn("Ⓐ  Continue", on_continue, "Primary", true))
	for c in main.get_children(): c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var mp = UI.panel(main); UI.grow(mp); row.add_child(mp)
	var S: Dictionary = res.stats
	var sv = UI.vb(10, [UI.caps("Match stats")])
	for kv in [["Possession %", "poss"], ["Shots", "shots"], ["Shots on target", "sot"], ["Passes", "passes"], ["Tackles", "tackles"], ["Fouls", "fouls"], ["Corners", "corners"]]:
		var a: int = S[kv[1]][0]; var b: int = S[kv[1]][1]; var tot: float = max(1, a + b)
		var bar = HBoxContainer.new(); bar.add_theme_constant_override("separation", 0)
		var l1 = ColorRect.new(); l1.color = UI.TEAL; l1.custom_minimum_size = Vector2(360.0 * a / tot, 6)
		var l2 = ColorRect.new(); l2.color = Color("#ff6a8a"); l2.custom_minimum_size = Vector2(360.0 * b / tot, 6)
		bar.add_child(l1); bar.add_child(l2)
		var lab = UI.caps(kv[0], 11); lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; UI.grow(lab, false, true)
		sv.add_child(UI.hb(8, [UI.bold(str(a), 15), lab, UI.bold(str(b), 15)])); sv.add_child(bar)
	var sp = UI.panel(sv); sp.custom_minimum_size.x = 420; row.add_child(sp)
	f.body.add_child(row)
	# show as a screen without pushing to the history stack
	if UI.cur and is_instance_valid(UI.cur): UI.cur.queue_free()
	UI.cur = f.node; UI.cur_name = "results"; UI.cur_tab = ""; UI.cur_back = on_continue
	UI.bg.set_mode("hub")
	f.node.set_anchors_preset(Control.PRESET_FULL_RECT)
	UI.host.add_child(f.node)
	Sfx.music_on()
	await UI.get_tree().process_frame
	UI.focus_first(f.node)
