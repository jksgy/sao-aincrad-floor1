extends Node2D
## Pickup: dropped loot left in the scene when the bag is full. Collect with E, expires.

var item_id := ""
var sprite: Sprite2D
var life := 60.0

func setup(meta: Dictionary) -> void:
	item_id = str(meta.get("id", ""))
	set_meta("interact_name", "掉落物")
	add_to_group("interactables")
	sprite = $Sprite
	var icons: Texture2D = load("res://assets/ui/icons.png")
	var mapping := { "potion": 0, "sword_starter": 1, "sword_bronze": 2, "sword_iron": 3,
		"armor_cloth": 4, "armor_leather": 5, "charm": 6, "col": 7, "meat": 8 }
	var at := AtlasTexture.new()
	at.atlas = icons
	at.region = Rect2(int(mapping.get(item_id, 0)) * 16, 0, 16, 16)
	sprite.texture = at
	sprite.offset = Vector2(0, -6)
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(self, "position:y", position.y - 3.0, 0.6)
	tw.tween_property(self, "position:y", position.y, 0.6)

func interact() -> void:
	if not Inv.can_add(item_id, 1):
		GameState.toast.emit("背包已满", Color(1.0, 0.6, 0.5))
		return
	Inv.add_item(item_id, 1)
	GameState.toast.emit("拾取了 %s" % Config.item(item_id).get("name", item_id), Color(0.7, 1.0, 0.7))
	AudioMan.play_sfx("pickup")
	queue_free()

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
