extends Node
## Consumables (FC-style): Chemistry Style cards (Shadow, Hunter, Anchor, Wall…) and Position Change cards.
## Styles are applied to a club item and boost its stats in your squad depending on that player's chemistry
## (1 chem = a third of the boost, 2 = two thirds, 3 = full). Position Change gives the item a new main position.

## stat order: PAC SHO PAS DRI DEF PHY (GK: DIV HAN KIC REF SPD POS)
const STYLES := {
	"Shadow": [6, 0, 0, 0, 4, 0], "Hunter": [6, 4, 0, 0, 0, 0], "Anchor": [3, 0, 0, 0, 4, 4], "Catalyst": [5, 0, 4, 0, 0, 0],
	"Engine": [2, 0, 3, 4, 0, 0], "Hawk": [3, 3, 0, 0, 0, 2], "Sniper": [0, 4, 0, 3, 0, 0], "Finisher": [0, 4, 0, 0, 0, 3],
	"Deadeye": [0, 3, 3, 0, 0, 0], "Marksman": [0, 3, 0, 2, 0, 2], "Artist": [0, 0, 4, 4, 0, 0], "Architect": [0, 0, 4, 0, 0, 4],
	"Powerhouse": [0, 0, 3, 0, 3, 0], "Maestro": [0, 3, 3, 2, 0, 0], "Sentinel": [0, 0, 0, 0, 4, 4], "Guardian": [0, 0, 0, 3, 4, 0],
	"Gladiator": [0, 3, 0, 0, 4, 0], "Backbone": [0, 0, 2, 0, 3, 3]}
const GK_STYLES := {"Wall": [3, 3, 3, 0, 0, 0], "Shield": [0, 0, 3, 3, 3, 0], "Cat": [0, 0, 0, 3, 3, 3], "Glove": [3, 3, 0, 0, 0, 3]}
const PRICE := {"Shadow": 3000, "Hunter": 3000, "Anchor": 2000, "Catalyst": 1500, "Engine": 1500, "Wall": 1500, "Cat": 1500}
const STYLE_PRICE := 1000
const POS_PRICE := 1500
const OUTFIELD := ["CB", "LB", "RB", "CDM", "CM", "CAM", "LM", "RM", "LW", "RW", "ST", "CF"]

func st() -> Dictionary:
	var d = Save.data
	if typeof(d.get("consum")) != TYPE_DICTIONARY:
		d.consum = {"styles": {"Shadow": 1, "Hunter": 1, "Anchor": 1, "Wall": 1}, "pos": 3}   # starter cards
	return d.consum

func styles_for(p: Dictionary) -> Dictionary: return GK_STYLES if p.get("pos", "") == "GK" else STYLES
func price(style: String) -> int: return int(PRICE.get(style, STYLE_PRICE))
func owned(style: String) -> int: return int(st().styles.get(style, 0))
func pos_owned() -> int: return int(st().pos)

func boost_text(style: String, gk := false) -> String:
	var b: Array = (GK_STYLES if gk else STYLES).get(style, [])
	var lab: Array = Data.GK_LABELS if gk else Data.STAT_LABELS
	var out = []
	for i in b.size(): if int(b[i]) > 0: out.append("+%d %s" % [b[i], lab[i]])
	return " · ".join(out)

## the item's player with overrides (position change + style tag) — stats unchanged
func item_view(it: Dictionary) -> Dictionary:
	var p: Dictionary = Data.P(it.pid)
	if p.is_empty() or (not it.has("pos") and not it.has("style")): return p
	var c: Dictionary = p.duplicate()
	if it.has("pos") and it.pos != p.pos:
		var alt: Array = (p.alt as Array).duplicate()
		alt.erase(it.pos)
		if not alt.has(p.pos): alt.push_front(p.pos)
		c.pos = it.pos; c.alt = alt; c.orig_pos = p.pos
	if it.has("style"): c.style = it.style
	return c

## stats with the chemistry style applied for a given chem (0–3)
func styled(p: Dictionary, chem: int) -> Dictionary:
	if p.is_empty() or not p.has("style") or chem <= 0: return p
	var b: Array = styles_for(p).get(p.style, [])
	if b.is_empty(): return p
	var c: Dictionary = p.duplicate()
	var st2 = []
	for i in 6: st2.append(min(99, int(p.stats[i]) + int(round(int(b[i]) * min(3, chem) / 3.0))))
	c.stats = st2
	return c

## use an owned card or buy one with coins. Returns true if paid.
func _pay(kind: String, style := "") -> bool:
	if kind == "pos":
		if pos_owned() > 0: st().pos = pos_owned() - 1; return true
		return Sys.spend("coins", POS_PRICE, "Position Change card", "store")
	if owned(style) > 0: st().styles[style] = owned(style) - 1; return true
	return Sys.spend("coins", price(style), "%s Chemistry Style" % style, "store")

func apply_style(u: String, style: String) -> bool:
	var it = Sys.item(u)
	if it.is_empty() or it.get("style", "") == style: return false
	if not _pay("style", style): return false
	it.style = style; Save.dirty()
	return true

func change_pos(u: String, pos: String) -> bool:
	var it = Sys.item(u)
	if it.is_empty(): return false
	var base: Dictionary = Data.P(it.pid)
	var cur: String = it.get("pos", base.pos)
	if pos == cur or base.pos == "GK" or pos == "GK": return false
	if pos == base.pos:   # going back to the original position is free
		it.erase("pos"); Save.dirty(); return true
	if not _pay("pos"): return false
	it.pos = pos; Save.dirty()
	return true
