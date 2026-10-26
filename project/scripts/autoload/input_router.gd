extends Node
## InputRouter: input context stack. WORLD < DIALOGUE < MENU < TITLE.

enum Mode { WORLD, DIALOGUE, MENU, TITLE, DEAD, VICTORY }

var stack: Array = [Mode.TITLE]

func mode() -> int:
	return stack.back()

func push(m: int) -> void:
	stack.append(m)

func pop() -> void:
	if stack.size() > 1:
		stack.pop_back()

func set_mode(m: int) -> void:
	stack = [m]

func world_ok() -> bool:
	return mode() == Mode.WORLD

func dialogue_ok() -> bool:
	return mode() == Mode.DIALOGUE

func ui_blocked() -> bool:
	return mode() != Mode.WORLD
