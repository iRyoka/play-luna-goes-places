class_name PuzzleBoard
extends Resource

## The complete authored configuration of one puzzle-assembly level: its ordered
## picture stages and the forgiveness values they share. Adding a picture is a
## new stage in a board resource; changing mechanic code to add one means a
## genuinely new mechanic dimension is being introduced.

## Background used by any stage that does not carry its own.
@export var default_background: Texture2D
## Shown when neither the stage nor the board supplies a background. A missing
## background is a quiet plain backing, never an error.
@export var placeholder_background_color := Color("#f3e7d2")
## The pictures of this level, assembled in order.
@export var stages: Array[PuzzleStage] = []
## Extra radius added to every part's touch region, so the hit shape is always
## larger than the artwork.
@export var touch_padding := 46.0
## How much of its start slot a resting part fills.
@export var home_slot_fill := 0.96
## Ceiling on a resting part's scale relative to its assembled scale, so a part
## waiting in its slot always reads as smaller than the picture it belongs to.
@export var home_to_assembled_scale_ratio := 0.9
## Seconds the finished picture rests before the next stage arrives.
@export var stage_handover_duration := 0.4


func get_stage_count() -> int:
	return stages.size()


func get_stage(index: int) -> PuzzleStage:
	if index < 0 or index >= stages.size():
		return null
	return stages[index]


func get_background_for(stage: PuzzleStage) -> Texture2D:
	if stage != null and stage.background != null:
		return stage.background
	return default_background


## Authoring errors that make the board unplayable. An empty result means the
## board is safe to present.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if stages.is_empty():
		errors.append("A board needs at least one stage.")
		return errors
	for index in range(stages.size()):
		var stage := stages[index]
		if stage == null:
			errors.append("Stage %d is missing." % index)
			continue
		errors.append_array(_validate_stage(stage, index))
	return errors


func _validate_stage(stage: PuzzleStage, index: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if stage.parts.is_empty():
		errors.append("Stage %d has no parts." % index)
	var seen_ids: Array[StringName] = []
	for part_index in range(stage.parts.size()):
		var part := stage.parts[part_index]
		if part == null:
			errors.append("Stage %d part %d is missing." % [index, part_index])
			continue
		if part.part_id == StringName():
			errors.append("Stage %d part %d has no id." % [index, part_index])
		elif seen_ids.has(part.part_id):
			errors.append("Stage %d repeats part id '%s'." % [index, part.part_id])
		else:
			seen_ids.append(part.part_id)
		if part.artwork == null:
			errors.append("Stage %d part '%s' has no artwork." % [index, part.part_id])
		if part.assembled_scale.x <= 0.0 or part.assembled_scale.y <= 0.0:
			errors.append("Stage %d part '%s' needs a positive assembled scale." % [index, part.part_id])
		if part.get_snap_radius() <= 0.0:
			errors.append("Stage %d part '%s' needs a positive snap radius." % [index, part.part_id])
	for backing_index in range(stage.backing_parts.size()):
		var backing: PuzzlePart = stage.backing_parts[backing_index]
		if backing == null:
			errors.append("Stage %d backing %d is missing." % [index, backing_index])
		elif backing.artwork == null:
			errors.append("Stage %d backing %d has no artwork." % [index, backing_index])
	if stage.start_slots.size() < stage.parts.size():
		errors.append("Stage %d has %d start slots for %d parts." % [index, stage.start_slots.size(), stage.parts.size()])
	for slot_index in range(stage.start_slots.size()):
		var slot: Rect2 = stage.start_slots[slot_index]
		if slot.size.x <= 0.0 or slot.size.y <= 0.0:
			errors.append("Stage %d start slot %d has no area." % [index, slot_index])
			continue
		for other_index in range(slot_index + 1, stage.start_slots.size()):
			var other: Rect2 = stage.start_slots[other_index]
			if slot.intersects(other):
				errors.append("Stage %d start slots %d and %d overlap." % [index, slot_index, other_index])
	return errors
