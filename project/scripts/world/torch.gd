extends Node2D
## Torch: flickering flame animation.

var sprite: Sprite2D

func setup(meta: Dictionary) -> void:
	sprite = $Sprite
	sprite.texture = load("res://assets/objs/torch.png")
	sprite.hframes = 2
	sprite.offset = Vector2(0, -14)
	var tw := sprite.create_tween()
	tw.set_loops()
	tw.tween_interval(0.22)
	tw.tween_callback(func(): sprite.frame = (sprite.frame + 1) % 2)
