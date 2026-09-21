extends Node

signal completed_levels_changed
signal last_played_level_changed(level_id: StringName)
signal music_enabled_changed(enabled: bool)
signal sound_effects_enabled_changed(enabled: bool)

const CURRENT_SCHEMA_VERSION := 4
const DEFAULT_STORAGE_PATH := "user://game_state.cfg"

var music_enabled := true
var sound_effects_enabled := true
var last_played_level_id := &""

var _completed_level_ids: Dictionary[StringName, bool] = {}
var _storage_path := DEFAULT_STORAGE_PATH
var _is_dirty := false
var _persistence_blocked := false
var _retry_scheduled := false
var _has_loaded := false


func _ready() -> void:
	if not _has_loaded:
		_load_state()


func mark_level_completed(level_id: StringName) -> void:
	if not _is_valid_level_id(String(level_id)) or _completed_level_ids.has(level_id):
		return

	_completed_level_ids[level_id] = true
	_persist_change()
	completed_levels_changed.emit()


func is_level_completed(level_id: StringName) -> bool:
	return _completed_level_ids.has(level_id)


func set_last_played_level_id(level_id: StringName) -> void:
	if not _is_valid_level_id(String(level_id)) or last_played_level_id == level_id:
		return
	last_played_level_id = level_id
	_persist_change()
	last_played_level_changed.emit(level_id)


func set_music_enabled(enabled: bool) -> void:
	if music_enabled == enabled:
		return
	music_enabled = enabled
	_persist_change()
	music_enabled_changed.emit(enabled)


func set_sound_effects_enabled(enabled: bool) -> void:
	if sound_effects_enabled == enabled:
		return
	sound_effects_enabled = enabled
	_persist_change()
	sound_effects_enabled_changed.emit(enabled)


func reset_completed_levels() -> void:
	if _completed_level_ids.is_empty():
		return
	_completed_level_ids.clear()
	_persist_change()
	completed_levels_changed.emit()


func configure_test_storage(storage_path: String) -> void:
	var is_user_test_path := storage_path.begins_with("user://")
	var is_workspace_test_path := storage_path.begins_with("res://../builds/")
	assert(is_user_test_path or is_workspace_test_path, "Test storage must remain under user:// or the workspace builds directory.")
	_storage_path = storage_path
	_is_dirty = false
	_persistence_blocked = false
	_retry_scheduled = false
	_load_state()


func get_storage_paths() -> PackedStringArray:
	return PackedStringArray([_storage_path, _backup_storage_path(), _temporary_storage_path()])


func _load_state() -> void:
	_has_loaded = true
	_set_defaults()
	var primary_result := _read_snapshot(_storage_path)
	if primary_result.status == &"valid":
		_apply_snapshot(primary_result.snapshot)
		if primary_result.needs_writeback:
			_is_dirty = true
			_try_save()
		return

	if primary_result.status == &"newer":
		_persistence_blocked = true
		var safe_backup := _read_snapshot(_backup_storage_path())
		if safe_backup.status == &"valid":
			_apply_snapshot(safe_backup.snapshot)
		push_warning("GameState found a newer unsupported save version and will not overwrite it.")
		return

	var backup_result := _read_snapshot(_backup_storage_path())
	if backup_result.status == &"valid":
		_apply_snapshot(backup_result.snapshot)
		_restore_primary(backup_result.snapshot)
		push_warning("GameState recovered progress from the backup snapshot.")
	elif primary_result.status == &"invalid" or backup_result.status == &"invalid":
		push_warning("GameState could not validate saved data and started with defaults.")


func _set_defaults() -> void:
	_completed_level_ids.clear()
	music_enabled = true
	sound_effects_enabled = true
	last_played_level_id = &""


func _read_snapshot(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": &"missing"}

	var config := ConfigFile.new()
	if config.load(path) != OK:
		return {"status": &"invalid"}

	if not config.has_section_key("meta", "version"):
		return {"status": &"invalid"}
	var version_value: Variant = config.get_value("meta", "version")
	if typeof(version_value) != TYPE_INT:
		return {"status": &"invalid"}

	var stored_version := int(version_value)
	if stored_version > CURRENT_SCHEMA_VERSION:
		return {"status": &"newer"}

	var raw_snapshot := _snapshot_from_config(config, stored_version)
	if raw_snapshot.is_empty():
		return {"status": &"invalid"}

	var migrated_snapshot := _migrate_snapshot(raw_snapshot, stored_version)
	if migrated_snapshot.is_empty() or not _is_valid_snapshot(migrated_snapshot):
		return {"status": &"invalid"}

	return {
		"status": &"valid",
		"snapshot": migrated_snapshot,
		"needs_writeback": stored_version != CURRENT_SCHEMA_VERSION,
	}


func _snapshot_from_config(config: ConfigFile, version: int) -> Dictionary:
	if version != 1 and version != 2 and version != 3 and version != 4:
		return {}
	var required_keys: Array[PackedStringArray] = [
		PackedStringArray(["progress", "completed_level_ids"]),
		PackedStringArray(["preferences", "music_enabled"]),
		PackedStringArray(["preferences", "sound_effects_enabled"]),
	]
	if version == 1:
		required_keys.append(PackedStringArray(["preferences", "vibration_enabled"]))
	if version >= 3:
		required_keys.append(PackedStringArray(["progress", "last_played_level_id"]))
	for section_and_key: PackedStringArray in required_keys:
		if not config.has_section_key(section_and_key[0], section_and_key[1]):
			return {}

	var completed_ids: Variant = config.get_value("progress", "completed_level_ids")
	var music_value: Variant = config.get_value("preferences", "music_enabled")
	var sound_effects_value: Variant = config.get_value("preferences", "sound_effects_enabled")
	if typeof(completed_ids) != TYPE_PACKED_STRING_ARRAY:
		return {}
	if typeof(music_value) != TYPE_BOOL or typeof(sound_effects_value) != TYPE_BOOL:
		return {}
	if version == 1 and typeof(config.get_value("preferences", "vibration_enabled")) != TYPE_BOOL:
		return {}
	var last_played_id := ""
	if version >= 3:
		var last_played_value: Variant = config.get_value("progress", "last_played_level_id")
		if typeof(last_played_value) != TYPE_STRING:
			return {}
		last_played_id = last_played_value

	return {
		"completed_level_ids": completed_ids,
		"music_enabled": music_value,
		"sound_effects_enabled": sound_effects_value,
		"last_played_level_id": last_played_id,
	}


func _migrate_snapshot(snapshot: Dictionary, stored_version: int) -> Dictionary:
	var migrated := snapshot.duplicate(true)
	var version := stored_version
	while version < CURRENT_SCHEMA_VERSION:
		match version:
			1:
				# Vibration is intentionally retired; keep all still-supported values.
				migrated.erase("vibration_enabled")
			2:
				migrated["last_played_level_id"] = ""
			3:
				# Flower Planters is retained as a ghost scene, not playable content.
				# Its historical completion stays intact, while its route reference moves
				# to Chapter 1's stable entry point.
				if migrated["last_played_level_id"] == "chapter_01/numbers":
					migrated["last_played_level_id"] = "chapter_01/drag_match"
			_:
				return {}
		version += 1
	return migrated


func _is_valid_snapshot(snapshot: Dictionary) -> bool:
	if typeof(snapshot.get("completed_level_ids")) != TYPE_PACKED_STRING_ARRAY:
		return false
	if typeof(snapshot.get("music_enabled")) != TYPE_BOOL:
		return false
	if typeof(snapshot.get("sound_effects_enabled")) != TYPE_BOOL:
		return false
	if typeof(snapshot.get("last_played_level_id")) != TYPE_STRING:
		return false

	for level_id: String in snapshot.completed_level_ids:
		if not _is_valid_level_id(level_id):
			return false
	return snapshot.last_played_level_id.is_empty() or _is_valid_level_id(snapshot.last_played_level_id)


func _is_valid_level_id(level_id: String) -> bool:
	var parts := level_id.split("/", false)
	return parts.size() == 2 and _is_valid_id_segment(parts[0]) and _is_valid_id_segment(parts[1])


func _is_valid_id_segment(segment: String) -> bool:
	if segment.is_empty():
		return false
	for index in segment.length():
		var code := segment.unicode_at(index)
		var is_lowercase_letter := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		if not is_lowercase_letter and not is_digit and code != 95:
			return false
	return true


func _apply_snapshot(snapshot: Dictionary) -> void:
	_completed_level_ids.clear()
	for stored_id: String in snapshot.completed_level_ids:
		_completed_level_ids[StringName(stored_id)] = true
	music_enabled = snapshot.music_enabled
	sound_effects_enabled = snapshot.sound_effects_enabled
	last_played_level_id = StringName(snapshot.last_played_level_id)


func _build_snapshot() -> Dictionary:
	var completed_ids := PackedStringArray()
	for level_id: StringName in _completed_level_ids:
		completed_ids.append(String(level_id))
	completed_ids.sort()
	return {
		"completed_level_ids": completed_ids,
		"music_enabled": music_enabled,
		"sound_effects_enabled": sound_effects_enabled,
		"last_played_level_id": String(last_played_level_id),
	}


func _persist_change() -> void:
	_is_dirty = true
	if not _try_save():
		_schedule_retry()


func _try_save() -> bool:
	if not _is_dirty:
		return true
	if _persistence_blocked:
		return false

	var snapshot := _build_snapshot()
	var temporary_path := _temporary_storage_path()
	if _write_snapshot(snapshot, temporary_path) != OK:
		push_warning("GameState could not write the temporary save snapshot.")
		return false

	var verification := _read_snapshot(temporary_path)
	if verification.status != &"valid" or verification.snapshot != snapshot:
		_remove_file_if_present(temporary_path)
		push_warning("GameState rejected the temporary save snapshot during verification.")
		return false

	var backup_path := _backup_storage_path()
	if FileAccess.file_exists(_storage_path):
		var rotate_error := _rename_file(_storage_path, backup_path)
		if rotate_error != OK:
			_remove_file_if_present(temporary_path)
			push_warning("GameState could not rotate the previous save snapshot.")
			return false

	var replace_error := _rename_file(temporary_path, _storage_path)
	if replace_error != OK:
		if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(_storage_path):
			_rename_file(backup_path, _storage_path)
		push_warning("GameState could not replace the primary save snapshot.")
		return false

	_is_dirty = false
	return true


func _restore_primary(snapshot: Dictionary) -> void:
	var temporary_path := _temporary_storage_path()
	if _write_snapshot(snapshot, temporary_path) != OK:
		return
	var verification := _read_snapshot(temporary_path)
	if verification.status != &"valid" or verification.snapshot != snapshot:
		_remove_file_if_present(temporary_path)
		return
	_rename_file(temporary_path, _storage_path)


func _write_snapshot(snapshot: Dictionary, path: String) -> Error:
	var config := ConfigFile.new()
	config.set_value("meta", "version", CURRENT_SCHEMA_VERSION)
	config.set_value("progress", "completed_level_ids", snapshot.completed_level_ids)
	config.set_value("progress", "last_played_level_id", snapshot.last_played_level_id)
	config.set_value("preferences", "music_enabled", snapshot.music_enabled)
	config.set_value("preferences", "sound_effects_enabled", snapshot.sound_effects_enabled)
	return config.save(path)


func _schedule_retry() -> void:
	if _retry_scheduled or _persistence_blocked or not is_inside_tree():
		return
	_retry_scheduled = true
	get_tree().create_timer(2.0).timeout.connect(_retry_dirty_save)


func _retry_dirty_save() -> void:
	_retry_scheduled = false
	_try_save()


func _backup_storage_path() -> String:
	return _storage_path + ".backup"


func _temporary_storage_path() -> String:
	return _storage_path + ".tmp"


func _rename_file(from_path: String, to_path: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(from_path), ProjectSettings.globalize_path(to_path))


func _remove_file_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
