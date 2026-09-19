class_name ChapterProgressionNode
extends RefCounted

var level_id: StringName
var prerequisite_level_ids: Array[StringName]
var required_completed_prerequisites: int


func _init(
	progression_level_id: StringName = &"",
	progression_prerequisite_level_ids: Array[StringName] = [],
	progression_required_completed_prerequisites := 0,
) -> void:
	level_id = progression_level_id
	prerequisite_level_ids = progression_prerequisite_level_ids.duplicate()
	required_completed_prerequisites = progression_required_completed_prerequisites
