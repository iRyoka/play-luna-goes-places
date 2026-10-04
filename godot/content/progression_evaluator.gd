class_name ProgressionEvaluator
extends RefCounted


static func get_available_level_ids(
	chapter: ChapterDefinition,
	completed_level_ids: Dictionary[StringName, bool],
) -> Array[StringName]:
	var available_level_ids: Array[StringName] = []
	if chapter == null:
		return available_level_ids

	for node: ChapterProgressionNode in chapter.progression_nodes:
		if completed_level_ids.has(node.level_id) or _has_met_prerequisite_quota(node, completed_level_ids):
			available_level_ids.append(node.level_id)
	return available_level_ids


## Keep a playable saved position; otherwise prefer unfinished available content.
static func get_resume_level_id(
	chapter: ChapterDefinition,
	completed_level_ids: Dictionary[StringName, bool],
	last_played_level_id: StringName,
) -> StringName:
	var available_ids := get_available_level_ids(chapter, completed_level_ids)
	if available_ids.has(last_played_level_id):
		return last_played_level_id
	for level_id: StringName in available_ids:
		if not completed_level_ids.has(level_id):
			return level_id
	return available_ids[0] if not available_ids.is_empty() else &""


static func is_chapter_available(
	chapter: ChapterDefinition,
	completed_level_ids: Dictionary[StringName, bool],
) -> bool:
	if chapter == null:
		return false
	for prerequisite_level_id: StringName in chapter.unlock_prerequisite_level_ids:
		if not completed_level_ids.has(prerequisite_level_id):
			return false
	return true


static func is_level_available(
	chapter: ChapterDefinition,
	completed_level_ids: Dictionary[StringName, bool],
	level_id: StringName,
) -> bool:
	return get_available_level_ids(chapter, completed_level_ids).has(level_id)


static func _has_met_prerequisite_quota(
	node: ChapterProgressionNode,
	completed_level_ids: Dictionary[StringName, bool],
) -> bool:
	var completed_prerequisite_count := 0
	for prerequisite_level_id: StringName in node.prerequisite_level_ids:
		if completed_level_ids.has(prerequisite_level_id):
			completed_prerequisite_count += 1
	return completed_prerequisite_count >= node.required_completed_prerequisites
