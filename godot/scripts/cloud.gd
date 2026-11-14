extends Node
## CLOUD SAVES (Supabase) — username + PIN accounts.
## Each save slot can be linked to one cloud account. While linked, every save is uploaded a few
## seconds later, and on start-up a newer cloud save (e.g. from the companion app) is downloaded.
## The table is only reachable through the pf_* functions in cloud/supabase_setup.sql.

signal status_changed

const CONFIG_RES := "res://cloud_config.json"      # baked server settings (url + public anon key)
const CONFIG_USER := "user://pf27_cloud_server.json"
const AUTH := "user://pf27_cloud_auth.json"        # per-slot login, stays on this device only

var url = ""
var key = ""
var status = "Not signed in"
var busy = false
var _dirty = false
var _t = 0.0
var _suspend = false

func _ready() -> void:
	_load_config()

func companion() -> bool: return OS.has_feature("web") or OS.get_cmdline_user_args().has("--companion")
func device() -> String: return "Companion (web)" if companion() else OS.get_name()

# ------------------------------------------------------------------ config & auth
func _load_config() -> void:
	for p in [CONFIG_USER, CONFIG_RES]:
		if FileAccess.file_exists(p):
			var c = JSON.parse_string(FileAccess.get_file_as_string(p))
			if typeof(c) == TYPE_DICTIONARY and str(c.get("url", "")) != "":
				url = str(c.url).strip_edges().trim_suffix("/"); key = str(c.get("key", "")).strip_edges(); return
func configured() -> bool: return url != "" and key != ""
func set_server(u: String, k: String) -> void:
	url = u.strip_edges().trim_suffix("/"); key = k.strip_edges()
	var f = FileAccess.open(CONFIG_USER, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"url": url, "key": key}))

func _auth_all() -> Dictionary:
	if not FileAccess.file_exists(AUTH): return {}
	var a = JSON.parse_string(FileAccess.get_file_as_string(AUTH))
	return a if typeof(a) == TYPE_DICTIONARY else {}
func auth() -> Dictionary: return _auth_all().get(str(Save.slot), {})
func _set_auth(a: Dictionary) -> void:
	var all = _auth_all()
	if a.is_empty(): all.erase(str(Save.slot))
	else: all[str(Save.slot)] = a
	var f = FileAccess.open(AUTH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(all))
func signed_in() -> bool: return not auth().is_empty()
func username() -> String: return str(auth().get("user", ""))

# ------------------------------------------------------------------ HTTP
func _rpc(fn: String, body: Dictionary) -> Dictionary:
	if not configured(): return {"ok": false, "error": "Cloud server not set up yet"}
	var h = HTTPRequest.new(); h.timeout = 25.0
	add_child(h)
	# new Supabase publishable keys (sb_publishable_…) go in apikey only; legacy anon JWT keys (eyJ…) also as Bearer
	var headers = ["apikey: " + key, "Content-Type: application/json"]
	if key.begins_with("eyJ"): headers.append("Authorization: Bearer " + key)
	var err = h.request(url + "/rest/v1/rpc/" + fn, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK: h.queue_free(); return {"ok": false, "error": "Couldn't reach the cloud (error %d)" % err}
	var res = await h.request_completed
	h.queue_free()
	var code: int = res[1]
	var txt: String = (res[3] as PackedByteArray).get_string_from_utf8()
	if res[0] != HTTPRequest.RESULT_SUCCESS: return {"ok": false, "error": "No internet connection to the cloud"}
	var d = JSON.parse_string(txt)
	if code >= 300 or typeof(d) != TYPE_DICTIONARY:
		var msg = d.get("message", txt) if typeof(d) == TYPE_DICTIONARY else txt
		return {"ok": false, "error": "Cloud error %d: %s" % [code, str(msg).left(160)]}
	return d

func _set_status(s: String) -> void: status = s; status_changed.emit()

# ------------------------------------------------------------------ account actions
## create an account and upload this slot's club to it
func register(user: String, pin: String) -> Dictionary:
	busy = true; _set_status("Creating account…")
	var r = await _rpc("pf_register", {"p_user": user, "p_pin": pin})
	busy = false
	if not r.get("ok", false): _set_status(str(r.get("error", "Failed"))); return r
	_set_auth({"user": user.strip_edges().to_lower(), "pin": pin, "rev": 0})
	_set_status("Signed in as " + username())
	if Save.data != null: return await push(true)
	return r

## sign in. Returns {ok, save (cloud save or null), rev}. The caller decides whether to use the cloud club.
func sign_in(user: String, pin: String) -> Dictionary:
	busy = true; _set_status("Signing in…")
	var r = await _rpc("pf_load", {"p_user": user, "p_pin": pin})
	busy = false
	if not r.get("ok", false): _set_status(str(r.get("error", "Failed"))); return r
	_set_auth({"user": user.strip_edges().to_lower(), "pin": pin, "rev": int(r.get("rev", 0))})
	_set_status("Signed in as " + username())
	return r

func sign_out() -> void:
	_set_auth({}); _set_status("Not signed in")

## use a downloaded cloud save in the current slot
func apply_cloud(save, rev: int) -> bool:
	if typeof(save) != TYPE_DICTIONARY or save.is_empty(): return false
	_suspend = true
	Save.data = Save._migrate(Save._ints(save))
	Save.write_now()
	_suspend = false
	var a = auth(); a.rev = rev; a.dirty = false; _set_auth(a)
	_set_status("Downloaded cloud club · rev %d" % rev)
	return true

## upload this slot. force = overwrite even if another device saved since our last sync
func push(force := false) -> Dictionary:
	var a = auth()
	if a.is_empty() or Save.data == null: return {"ok": false, "error": "Not signed in"}
	busy = true; _set_status("Uploading…")
	var r = await _rpc("pf_save", {"p_user": a.user, "p_pin": a.pin, "p_save": Save.data, "p_rev": int(a.get("rev", 0)), "p_device": device(), "p_force": force})
	busy = false
	if r.get("ok", false):
		a = auth(); a.rev = int(r.rev); a.dirty = false; _set_auth(a)
		_set_status("Synced · %s" % Time.get_time_string_from_system().left(5))
	elif str(r.get("error", "")) == "conflict":
		_set_status("Cloud has newer progress from %s" % str(r.get("device", "another device")))
	else: _set_status(str(r.get("error", "Upload failed")))
	return r

## download the cloud save into this slot (replaces local progress)
func pull() -> Dictionary:
	var a = auth()
	if a.is_empty(): return {"ok": false, "error": "Not signed in"}
	busy = true; _set_status("Downloading…")
	var r = await _rpc("pf_load", {"p_user": a.user, "p_pin": a.pin})
	busy = false
	if not r.get("ok", false): _set_status(str(r.get("error", "Download failed"))); return r
	if r.get("save") == null: _set_status("The cloud has no club yet"); return {"ok": false, "error": "The cloud has no club yet"}
	apply_cloud(r.save, int(r.rev))
	return r

## on start-up / resume: download if the cloud is newer and this device has nothing unsynced.
## returns "pulled", "conflict", "same" or "" (not signed in / offline)
func check_newer() -> String:
	var a = auth()
	if a.is_empty(): return ""
	var r = await _rpc("pf_rev", {"p_user": a.user, "p_pin": a.pin})
	if not r.get("ok", false): _set_status(str(r.get("error", "Offline"))); return ""
	if int(r.rev) <= int(a.get("rev", 0)): _set_status("Signed in as %s · up to date" % a.user); return "same"
	if a.get("dirty", false): _set_status("Cloud has newer progress from %s" % str(r.get("device", "another device"))); return "conflict"
	await pull()
	return "pulled"

# ------------------------------------------------------------------ autosync
## called by Save after every write
func local_changed() -> void:
	if _suspend or not signed_in(): return
	var a = auth()
	if not a.get("dirty", false): a.dirty = true; _set_auth(a)
	_dirty = true; _t = 4.0 if companion() else 20.0

func _process(delta: float) -> void:
	if not _dirty or busy: return
	_t -= delta
	if _t <= 0.0:
		_dirty = false
		push()

func _notification(what: int) -> void:
	# best effort: flush when the app closes / the browser tab is hidden
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _dirty and not busy: _dirty = false; push()
