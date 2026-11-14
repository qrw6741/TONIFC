extends Node
## SAVE — persistent, versioned save file (user://pf27_save.json), debounced autosave.

const PATH := "user://pf27_save.json"
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

func load_save() -> bool:
	if not FileAccess.file_exists(PATH): return false
	var f = FileAccess.open(PATH, FileAccess.READ)
	if f == null: return false
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY or int(d.get("v", 0)) != VERSION: return false
	data = _migrate(_ints(d))
	return true

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
	var f = FileAccess.open(PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(data))

func wipe() -> void:
	data = null
	if FileAccess.file_exists(PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		write_now()
