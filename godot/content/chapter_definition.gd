class_name ChapterDefinition
extends RefCounted

var id: StringName
var map_scene_path: String
var level_ids: Array[StringName]
var progression_nodes: Array[ChapterProgressionNode]
## Levels from earlier chapters that must all be completed before this chapter
## may be entered. An empty list means the chapter is always available.
var unlock_prerequisite_level_ids: Array[StringName]


func _init(
	chapter_id: StringName = &"",
	chapter_map_scene_path := "",
	chapter_level_ids: Array[StringName] = [],
	chapter_progression_nodes: Array[ChapterProgressionNode] = [],
	chapter_unlock_prerequisite_level_ids: Array[StringName] = [],
) -> void:
	id = chapter_id
	map_scene_path = chapter_map_scene_path
	level_ids = chapter_level_ids.duplicate()
	progression_nodes = chapter_progression_nodes.duplicate()
	unlock_prerequisite_level_ids = chapter_unlock_prerequisite_level_ids.duplicate()
