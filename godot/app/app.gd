extends Control

const SETTINGS_MODAL_SCENE := preload("res://app/settings_modal.tscn")
const CHAPTER_SELECTION_SCENE := preload("res://app/chapter_selection.tscn")

@onready var content: Control = %Content
@onready var map_music: AudioStreamPlayer = %MapMusic
@onready var gameplay_music: AudioStreamPlayer = %GameplayMusic
@onready var sfx_player: SfxPlayer = %SfxPlayer

var _active_chapter_id: StringName = &""
var _current_level_id: StringName = &""
var _settings_modal: SettingsModal
var _active_music_player: AudioStreamPlayer


func _ready() -> void:
	var game_state := get_node("/root/GameState")
	game_state.connect("music_enabled_changed", _apply_music_enabled)
	game_state.connect("sound_effects_enabled_changed", _apply_sound_effects_enabled)
	_configure_music_loops()
	_apply_music_enabled(bool(game_state.get("music_enabled")))
	_apply_sound_effects_enabled(bool(game_state.get("sound_effects_enabled")))
	if _get_content_registry() != null:
		show_chapter(_get_cold_start_chapter_id())


func _exit_tree() -> void:
	# Release native audio playback before the players and their streams are freed.
	# This matters for explicit App teardown in smoke tests and embedding hosts.
	map_music.stop()
	gameplay_music.stop()
	map_music.stream = null
	gameplay_music.stream = null
	_active_music_player = null


func show_chapter(chapter_id: StringName = _active_chapter_id) -> void:
	var content_registry := _get_content_registry()
	if content_registry == null:
		return
	var chapter := content_registry.get_chapter(chapter_id)
	if chapter == null:
		push_error("Unknown chapter: %s" % chapter_id)
		return
	if not _is_chapter_available(chapter):
		push_error("Chapter %s is not unlocked yet." % chapter_id)
		return

	var chapter_scene := _load_scene(chapter.map_scene_path, "Chapter %s" % chapter_id)
	if chapter_scene == null:
		return
	var chapter_map := chapter_scene.instantiate() as ChapterMap
	if chapter_map == null:
		push_error("Chapter %s scene has the wrong root type." % chapter_id)
		return

	_active_chapter_id = chapter_id
	_current_level_id = &""
	chapter_map.chapter_id = chapter_id
	_set_screen(chapter_map)
	chapter_map.sound_requested.connect(sfx_player.play_sound)
	chapter_map.location_selected.connect(_on_location_selected)
	chapter_map.chapter_selection_requested.connect(_on_chapter_selection_requested)
	chapter_map.settings_requested.connect(open_settings)
	_play_music(map_music)


func show_chapter_selection() -> void:
	if _get_content_registry() == null:
		return
	var selection := CHAPTER_SELECTION_SCENE.instantiate() as ChapterSelection
	if selection == null:
		push_error("Chapter selection scene has the wrong root type.")
		return

	# No chapter is active while the selector is mounted, so the recorded IDs are
	# cleared rather than left pointing at a screen that is gone.
	_active_chapter_id = &""
	_current_level_id = &""
	_set_screen(selection)
	selection.sound_requested.connect(sfx_player.play_sound)
	selection.chapter_selected.connect(_on_chapter_selected)
	_play_music(map_music)


func open_level(level_id: StringName) -> void:
	var content_registry := _get_content_registry()
	if content_registry == null:
		return
	var level_definition := content_registry.get_level(level_id)
	if level_definition == null:
		push_error("Unknown chapter destination: %s" % level_id)
		return

	var level_scene := _load_scene(level_definition.scene_path, "Level %s" % level_id)
	if level_scene == null:
		return
	var level := level_scene.instantiate() as LevelController
	if level == null:
		push_error("Level %s scene has the wrong root type." % level_id)
		return

	_active_chapter_id = level_definition.chapter_id
	_current_level_id = level_id
	var game_state := get_node("/root/GameState")
	game_state.set_last_played_level_id(level_id)
	level.back_to_chapter_requested.connect(_on_level_back_requested)
	level.replay_requested.connect(_on_level_replay_requested)
	level.continue_to_chapter_requested.connect(show_chapter)
	level.sound_requested.connect(sfx_player.play_sound)
	_set_screen(level)
	_play_music(gameplay_music)


func replay_current_level() -> void:
	if _current_level_id == &"":
		push_warning("Cannot replay because no level is open.")
		return
	open_level(_current_level_id)


func open_settings() -> void:
	if _settings_modal != null or content.get_child_count() != 1:
		return
	if not content.get_child(0) is ChapterMap:
		return
	_settings_modal = SETTINGS_MODAL_SCENE.instantiate() as SettingsModal
	_settings_modal.close_requested.connect(_close_settings)
	_settings_modal.sound_requested.connect(sfx_player.play_sound)
	add_child(_settings_modal)


func get_current_screen_name() -> StringName:
	if content.get_child_count() == 0:
		return &""
	return content.get_child(0).name


func get_current_level_id() -> StringName:
	return _current_level_id


func get_active_chapter_id() -> StringName:
	return _active_chapter_id


func get_settings_modal() -> SettingsModal:
	return _settings_modal


func get_active_music_player() -> AudioStreamPlayer:
	return _active_music_player


func _on_location_selected(level_id: StringName) -> void:
	await _wait_for_sfx_output()
	open_level(level_id)


func _on_chapter_selection_requested() -> void:
	await _wait_for_sfx_output()
	show_chapter_selection()


func _on_chapter_selected(chapter_id: StringName) -> void:
	await _wait_for_sfx_output()
	show_chapter(chapter_id)


func _on_level_back_requested() -> void:
	await _wait_for_sfx_output()
	show_chapter()


func _on_level_replay_requested() -> void:
	await _wait_for_sfx_output()
	replay_current_level()


func _wait_for_sfx_output() -> void:
	var delay_seconds := sfx_player.get_estimated_output_delay_seconds()
	if delay_seconds > 0.0:
		await get_tree().create_timer(delay_seconds).timeout


func _load_scene(scene_path: String, label: String) -> PackedScene:
	var scene := ResourceLoader.load(scene_path, "PackedScene") as PackedScene
	if scene == null:
		push_error("%s scene could not load: %s" % [label, scene_path])
	return scene


func _get_cold_start_chapter_id() -> StringName:
	var content_registry := _get_content_registry()
	if content_registry == null:
		return &""
	# Returning to the chapter of the last opened level keeps a restart on the map
	# the child left, without persisting any route of its own.
	var last_played_level := content_registry.get_level(get_node("/root/GameState").last_played_level_id as StringName)
	if last_played_level != null:
		var chapter := content_registry.get_chapter(last_played_level.chapter_id)
		if chapter != null and _is_chapter_available(chapter):
			return chapter.id
	return content_registry.get_first_chapter_id()


func _is_chapter_available(chapter: ChapterDefinition) -> bool:
	var game_state := get_node("/root/GameState")
	var completed_level_ids: Dictionary[StringName, bool] = {}
	for prerequisite_level_id: StringName in chapter.unlock_prerequisite_level_ids:
		if game_state.is_level_completed(prerequisite_level_id):
			completed_level_ids[prerequisite_level_id] = true
	return ProgressionEvaluator.is_chapter_available(chapter, completed_level_ids)


func _get_content_registry() -> ContentCatalog:
	var content_registry := get_node_or_null("/root/ContentRegistry") as ContentCatalog
	if content_registry == null:
		push_error("Content registry is unavailable.")
	return content_registry


func _set_screen(screen: Node) -> void:
	_close_settings(false)
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	content.add_child(screen)


func _close_settings(play_close_sound := true) -> void:
	if _settings_modal == null:
		return
	if play_close_sound:
		sfx_player.play_sound(&"tap")
	var modal := _settings_modal
	_settings_modal = null
	modal.queue_free()


func _apply_music_enabled(enabled: bool) -> void:
	_set_bus_enabled(&"Music", enabled)


func _apply_sound_effects_enabled(enabled: bool) -> void:
	_set_bus_enabled(&"SFX", enabled)


func _set_bus_enabled(bus_name: StringName, enabled: bool) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("Missing audio bus: %s" % bus_name)
		return
	AudioServer.set_bus_mute(bus_index, not enabled)


func _configure_music_loops() -> void:
	var map_stream := map_music.stream as AudioStreamOggVorbis
	if map_stream == null:
		push_error("Map music must use an Ogg Vorbis stream.")
	else:
		map_stream.loop = true
		map_stream.loop_offset = 0.0

	var gameplay_stream := gameplay_music.stream as AudioStreamWAV
	if gameplay_stream == null:
		push_error("Gameplay music must use a WAV stream.")
	else:
		gameplay_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		gameplay_stream.loop_begin = 0
		gameplay_stream.loop_end = int(gameplay_stream.get_length() * gameplay_stream.mix_rate)


func _play_music(next_player: AudioStreamPlayer) -> void:
	if _active_music_player == next_player and next_player.playing:
		return
	if _active_music_player != null:
		_active_music_player.stop()
	_active_music_player = next_player
	next_player.play()
