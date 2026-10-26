extends Node2D
## Chest: one-time loot, persistent open state, bag-full protection.

var chest_id := ""
var open := false
var loot: Array = []
var sprite: Sprite2D

func set_meta_id(id: String) -> void:
	chest_id = id

func setup(meta: Dictionary) -> void:
	chest_id = str(meta.get("id", chest_id))
	set_meta("id", chest_id)
	set_meta("interact_name", "宝箱")
	add_to_group("interactables")
	sprite = $Sprite
	sprite.texture = load("res://assets/objs/chest.png")
	sprite.hframes = 2
	sprite.offset = Vector2(0, -10)
	# loot from map header
	var md: MapBuilder.MapData = get_parent().get_parent().get_meta("data")
	for c in md.chests:
		if c.id == chest_id:
			loot = c.loot
	open = GameState.is_chest_open(chest_id)
	sprite.frame = 1 if open else 0

func interact() -> void:
	if open:
		return
	# capacity check
	for item_id in loot:
		if item_id.begins_with("col"):
			continue
		if not Inv.can_add(item_id, 1):
			GameState.toast.emit("背包已满，宝箱暂未开启", Color(1.0, 0.75, 0.4))
			return
	open = true
	GameState.open_chest(chest_id)
	sprite.frame = 1
	AudioMan.play_sfx("chest")
	Fx.spark(global_position + Vector2(0, -12))
	var gained: Array = []
	for item_id in loot:
		if item_id.begins_with("col"):
			var n := int(item_id.substr(3))
			GameState.add_col(n)
			gained.append("%d 珂尔" % n)
		else:
			Inv.add_item(item_id, 1)
			gained.append(str(Config.item(item_id).get("name", item_id)))
	GameState.toast.emit("获得：%s" % "、".join(gained), Color(1.0, 0.9, 0.5))
