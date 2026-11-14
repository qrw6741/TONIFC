extends Node
## SAVE — 3 save slots (user://pf27_slot1..3.json), versioned, debounced autosave.
## The active slot is remembered in user://pf27_meta.json. The old single save becomes Slot 1.

const PATH := "user://pf27_save.json"   # legacy single-save file (migrated to slot 1)
const META := "user://pf27_meta.json"
const SLOTS := 3
var slot = 1
const VERSION := 1
var data = null   # Dictionary or null
var _dirty = false
var _t = 0.0

func default_settings() -> Dictionary:
	return {"music": 0.5, "sfx": 0.8, "crowd": 0.7, "difficulty": "professional", "half_len": 3, "camera": "broadcast", "show_links": true, "fullscreen": false, "vibration": true,
		"game_speed": "normal", "fps_cap": 60, "vsync": true, "perf_mode": false, "replays": true}

func new_save(name: String) -> Dictionary:
	var now = Time.get_unix_time_from_system()
	return {
		"v": VERSION, "created": now,
		"profile": {
			"name": name, "club_name": "Phoenix FC", "level": 1, "xp": 0,
			"badge": {"shape": "shield", "c1": "#e8b631", "c2": "#14161c", "icon": "star"},
			"kit": {"home": {"c1": "#e8b631", "c2": "#14161c", "pattern": "plain"}, "away": {"c1": "#f2f2f2", "c2": "#2a6fdb", "pattern": "sash"}},
			"stadium": {"name": "Phoenix Park", "seats": "#3a3f4d", "tifo": "flames", "theme": "gold"},
			"history": [{"t": now, "text": "Club founded"}]
		},
		"coins": 5000, "points": 500,
		"tx": [{"t": now, "kind": "reward", "amount": 5000, "cur": "coins", "desc": "Welcome bonus"}, {"t": now, "kind": "reward", "amount": 500, "cur": "points", "desc": "Welcome Prime Points"}],
		"club": [], "squads": [], "active_squad": 0, "unopened": [], "pending": [],
		"market": {"listings": [], "mine": [], "bids": [], "history": [], "demand": {}, "last_filter": {}, "pool": [], "watch": [], "tl": []},
		"objectives": {"progress": {}, "claimed": {}},
		"sbc": {"done": {}, "draft": {}},
		"modes": {
			"sb": {"week": "", "points": 0, "played": 0, "opps": [], "opps_week": "", "claimed_week": ""},
			"rivals": {"div": 10, "pts": 0, "played": 0, "wins": 0, "best": 10, "week_wins": 0, "week": ""},
			"champs": {"qp": 0, "run": null, "tokens": 0, "bought": {}, "history": [], "next_at": 0.0},
			"draft": {"active": null, "history": []}
		},
		"career": null, "tourn": null, "daily_pts": "", "pick_cur": null,
		"season": {"id": "s1", "xp": 0, "premium": false, "free": {}, "prem": {}, "bonus": 0},
		"matches": [],
		"stats": {"played": 0, "wins": 0, "draws": 0, "losses": 0, "gf": 0, "ga": 0, "packs": 0, "sbcs": 0, "sold": 0, "bought": 0, "assists": 0},
		"settings": default_settings()
	}

func slot_path(n: int) -> String: return "user://pf27_slot%d.json" % n
func path() -> String: return slot_path(slot)

func _read_meta() -> void:
	if FileAccess.file_exists(META):
		var m = JSON.parse_string(FileAccess.get_file_as_string(META))
		if typeof(m) == TYPE_DICTIONARY: slot = clamp(int(m.get("slot", 1)), 1, SLOTS)
	# first run with slots: the old single save becomes Slot 1
	if FileAccess.file_exists(PATH) and not FileAccess.file_exists(slot_path(1)):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(slot_path(1)))
func _write_meta() -> void:
	var f = FileAccess.open(META, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"slot": slot}))

func _read_file(p: String):
	if not FileAccess.file_exists(p): return null
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if typeof(d) != TYPE_DICTIONARY or int(d.get("v", 0)) != VERSION: return null
	return d

func load_save() -> bool:
	_read_meta()
	var d = _read_file(path())
	if d == null: return false
	data = _migrate(_ints(d))
	return true

## summary of a slot for the Save Slots screen ({} = empty)
func slot_info(n: int) -> Dictionary:
	var d = data if n == slot and data != null else _read_file(slot_path(n))
	if d == null: return {}
	var pr: Dictionary = d.get("profile", {})
	return {"name": pr.get("name", "Manager"), "club": pr.get("club_name", "Club"), "level": int(pr.get("level", 1)), "coins": int(d.get("coins", 0)),
		"played": int(d.get("stats", {}).get("played", 0)), "players": d.get("club", []).size(), "extreme": bool(d.get("settings", {}).get("extreme", false)),
		"saved": int(d.get("saved_at", 0)), "badge": pr.get("badge", {})}

## switch to another slot (saves the current one first). Returns true if that slot has a club.
func use_slot(n: int) -> bool:
	write_now()
	slot = clamp(n, 1, SLOTS); _write_meta()
	data = null
	var d = _read_file(path())
	if d != null: data = _migrate(_ints(d))
	return data != null

func delete_slot(n: int) -> void:
	if n == slot: data = null
	var p = slot_path(n)
	if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

## JSON numbers load as floats; restore whole numbers to ints so indexing & %d formatting stay exact
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

func _migrate(d: Dictionary) -> Dictionary:
	var base = new_save(d.get("profile", {}).get("name", "Manager"))
	for k in base: if not d.has(k): d[k] = base[k]
	for k in base.settings: if not d.settings.has(k): d.settings[k] = base.settings[k]
	for k in base.modes: if not d.modes.has(k): d.modes[k] = base.modes[k]
	for k in base.stats: if not d.stats.has(k): d.stats[k] = base.stats[k]
	# v2: only exclusive cards stay untradeable (and players currently in an Evolution)
	if not d.get("trade_v2", false):
		var locked = {}
		if typeof(d.get("evos")) == TYPE_DICTIONARY: for e in d.evos.get("active", []): locked[e.uid] = true
		if typeof(d.get("event")) == TYPE_DICTIONARY: for e in d.event.get("evos", []): locked[e.uid] = true
		for it in d.club:
			var pid: String = str(it.pid)
			var excl: bool = ["pass", "gallery", "potm"].has(Data.P(pid).get("type", "")) or pid.begins_with("ev")
			if not excl and not locked.has(it.uid): it.untr = false
		for x in d.get("pending", []):
			var px: String = str(x.pid)
			if not (["pass", "gallery", "potm"].has(Data.P(px).get("type", "")) or px.begins_with("ev")): x.untr = false
		d.trade_v2 = true
	return d

func create(name: String) -> void:
	data = new_save(name)
	write_now()

func dirty() -> void:
	_dirty = true; _t = 0.3

func _process(delta: float) -> void:
	if _dirty:
		_t -= delta
		if _t <= 0: write_now()

func write_now() -> void:
	_dirty = false
	if data == null: return
	data.saved_at = int(Time.get_unix_time_from_system())
	var f = FileAccess.open(path(), FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(data))
	_write_meta()

func wipe() -> void:
	delete_slot(slot)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		write_now()
