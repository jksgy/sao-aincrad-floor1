extends Node
## Inventory: 20 slots + equipment. Data lives here; serialized with the save.

signal changed
signal potions_changed(n: int)

const SLOT_COUNT := 20

var slots: Array = []          # Array[Dictionary] {id, count}
var equipped: Dictionary = { "weapon": "", "armor": "", "accessory": "" }

func _ready() -> void:
	clear()

func clear() -> void:
	slots = []
	for i in SLOT_COUNT:
		slots.append({ "id": "", "count": 0 })
	equipped = { "weapon": "", "armor": "", "accessory": "" }
	changed.emit()

func start_items() -> void:
	clear()
	add_item(str(Config.b("player.start.weapon", "sword_starter")), 1)
	add_item(str(Config.b("player.start.armor", "armor_cloth")), 1)
	add_item("potion", int(Config.b("player.start.potions", 3)))
	# equip starter gear
	equip_item(find_slot("sword_starter"))
	equip_item(find_slot("armor_cloth"))

func find_slot(item_id: String) -> int:
	for i in slots.size():
		if slots[i].id == item_id:
			return i
	return -1

func find_free_slot() -> int:
	for i in slots.size():
		if slots[i].id == "":
			return i
	return -1

func can_add(item_id: String, n: int) -> bool:
	var def := Config.item(item_id)
	if def.is_empty():
		return false
	var stack := int(def.get("stack", 1))
	var need := n
	for s in slots:
		if s.id == item_id and s.count < stack:
			need -= stack - s.count
			if need <= 0:
				return true
	if need > 0:
		var free := 0
		for s in slots:
			if s.id == "":
				free += 1
		return free * stack >= need
	return true

func add_item(item_id: String, n: int) -> bool:
	if n <= 0:
		return true
	var def := Config.item(item_id)
	if def.is_empty():
		return false
	var stack := int(def.get("stack", 1))
	var remaining := n
	for s in slots:
		if s.id == item_id and s.count < stack:
			var take := mini(stack - s.count, remaining)
			s.count += take
			remaining -= take
			if remaining <= 0:
				break
	while remaining > 0:
		var f := find_free_slot()
		if f < 0:
			changed.emit()
			_potions()
			return false
		var take := mini(stack, remaining)
		slots[f] = { "id": item_id, "count": take }
		remaining -= take
	changed.emit()
	_potions()
	return true

func remove_item(item_id: String, n: int) -> bool:
	if count(item_id) < n:
		return false
	var remaining := n
	for i in slots.size():
		if slots[i].id == item_id:
			var take := mini(slots[i].count, remaining)
			slots[i].count -= take
			remaining -= take
			if slots[i].count <= 0:
				slots[i] = { "id": "", "count": 0 }
			if remaining <= 0:
				break
	changed.emit()
	_potions()
	return true

func count(item_id: String) -> int:
	var total := 0
	for s in slots:
		if s.id == item_id:
			total += s.count
	return total

func potion_count() -> int:
	return count("potion")

func _potions() -> void:
	potions_changed.emit(potion_count())

func item_type(item_id: String) -> String:
	return str(Config.item(item_id).get("type", ""))

# ---------- equipment ----------
func equip_item(slot_index: int) -> bool:
	var s: Dictionary = slots[slot_index]
	if s.id == "":
		return false
	var t := item_type(s.id)
	if t != "weapon" and t != "armor" and t != "accessory":
		return false
	# swap with currently equipped
	var cur: String = equipped[t]
	equipped[t] = s.id
	remove_item(s.id, 1)
	if cur != "":
		add_item(cur, 1)
	changed.emit()
	return true

func unequip_slot(slot: String) -> bool:
	var id: String = equipped.get(slot, "")
	if id == "":
		return false
	if not add_item(id, 1):
		return false
	equipped[slot] = ""
	changed.emit()
	return true

func equip_stats() -> Dictionary:
	var atk := 0
	var defn := 0
	var maxhp := 0
	for slot in equipped.values():
		if slot == "":
			continue
		var d := Config.item(str(slot))
		atk += int(d.get("atk", 0))
		defn += int(d.get("def", 0))
		maxhp += int(d.get("maxhp", 0))
	return { "atk": atk, "def": defn, "maxhp": maxhp }

func use_item(slot_index: int) -> String:
	var s: Dictionary = slots[slot_index]
	if s.id == "":
		return "empty"
	var def := Config.item(s.id)
	if not bool(def.get("usable", false)):
		return "not_usable"
	if s.id == "potion":
		if GameState.hp >= GameState.max_hp():
			return "hp_full"
		GameState.heal(int(def.get("heal", 40)))
		remove_item("potion", 1)
		AudioMan.play_sfx("potion")
		return "ok"
	return "not_usable"

func to_dict() -> Dictionary:
	return { "slots": slots, "equipped": equipped }

func from_dict(d: Dictionary) -> void:
	clear()
	var s: Array = d.get("slots", [])
	for i in mini(s.size(), SLOT_COUNT):
		var e: Dictionary = s[i]
		slots[i] = { "id": str(e.get("id", "")), "count": int(e.get("count", 0)) }
	var eq: Dictionary = d.get("equipped", {})
	for k in equipped.keys():
		equipped[k] = str(eq.get(k, ""))
	changed.emit()
	_potions()
