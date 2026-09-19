class_name LevelDefinition
extends RefCounted

var id: StringName
var chapter_id: StringName
var scene_path: String
var mechanic_family: StringName
var map_marker_id: StringName
var progression_group_id: StringName


func _init(
	level_id: StringName = &"",
	level_chapter_id: StringName = &"",
	level_scene_path := "",
	level_mechanic_family: StringName = &"",
	level_map_marker_id: StringName = &"",
	level_progression_group_id: StringName = &"",
) -> void:
	id = level_id
	chapter_id = level_chapter_id
	scene_path = level_scene_path
	mechanic_family = level_mechanic_family
	map_marker_id = level_map_marker_id
	progression_group_id = level_progression_group_id
