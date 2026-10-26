extends Node
## SaveManager: atomic save with backup, corrupt fallback, settings persistence.

const SAVE_PATH := "user://savegame.json"
const SAVE_BAK := "user://savegame.json.bak"
const SETTINGS_PATH := "user://settings.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_BAK)

func collect() -> Dictionary:
	return {
		"player": GameState.to_dict(),
		"inventory": Inv.to_dict(),
		"quests": Quests.to_dict(),
	}

func apply(d: Dictionary) -> void:
	GameState.from_dict(d.get("player", {}))
	Inv.from_dict(d.get("inventory", {}))
	Quests.from_dict(d.get("quests", {}))

func save_game() -> Dictionary:
	var data := JSON.stringify(collect(), "\t")
	# backup current valid save
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH),
				ProjectSettings.globalize_path(SAVE_BAK))
	var tmp := FileAccess.open("user://savegame.tmp", FileAccess.WRITE)
	if tmp == null:
		return { "ok": false, "error": "无法创建临时存档文件" }
	tmp.store_string(data)
	tmp.close()
	var tmp_f := FileAccess.open("user://savegame.tmp", FileAccess.READ)
	if tmp_f == null or tmp_f.get_as_text() != data:
		return { "ok": false, "error": "存档写入校验失败" }
	tmp_f.close()
	var err := DirAccess.rename_absolute(
			ProjectSettings.globalize_path("user://savegame.tmp"),
			ProjectSettings.globalize_path(SAVE_PATH))
	if err != OK:
		return { "ok": false, "error": "存档替换失败（错误码 %d）" % err }
	return { "ok": true, "error": "" }

func load_game() -> Dictionary:
	var paths := [SAVE_PATH, SAVE_BAK]
	var last_err := "没有找到存档"
	for path in paths:
		if not FileAccess.file_exists(path):
			last_err = "存档文件缺失"
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			last_err = "存档无法读取"
			continue
		var text := f.get_as_text()
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary and parsed.has("player"):
			apply(parsed)
			return { "ok": true, "error": "" }
		last_err = "存档数据损坏"
	return { "ok": false, "error": last_err + "（主存档与备份均不可用）" }

func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(GameState.settings))
		f.close()

func load_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		for k in GameState.settings.keys():
			if parsed.has(k):
				GameState.settings[k] = parsed[k]

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if FileAccess.file_exists(SAVE_BAK):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_BAK))
