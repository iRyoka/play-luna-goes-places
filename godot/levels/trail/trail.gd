class_name TrailLevel
extends LevelController

## Guides one actor along a chained authored route. A stage is one place with one
## actor, and its segments are the legs of that place's journey: each segment
## starts where the last one ended, so a stage reads as one trip. Finishing the
## last segment of the last stage completes the level.
##
## The level owns stage and segment succession, the board owns the route and the
## drag, and the shared controller owns completion, persistence, and navigation.

const SEGMENT_ADVANCE_DELAY := 0.55
const COURSE_COMPLETION_DELAY := 0.9

@export var course: TrailCourse

@onready var trail_board: TrailBoard = %TrailBoard

var _stage_index := 0
var _segment_index := 0
var _course_finishing := false


func _ready() -> void:
	super._ready()
	completion_started.connect(_on_completion_started)
	if get_tree().current_scene == self:
		replay_requested.connect(_restart_preview)
	if course == null:
		push_error("Trail level %s has no authored course." % level_id)
		trail_board.set_input_enabled(false)
		return
	var errors := course.validate()
	if not errors.is_empty():
		for error in errors:
			push_error("Trail course problem in %s: %s" % [level_id, error])
		trail_board.set_input_enabled(false)
		return
	trail_board.actor_grabbed.connect(_on_actor_grabbed)
	trail_board.segment_restarted.connect(_on_segment_restarted)
	trail_board.segment_completed.connect(_on_segment_completed)
	trail_board.configure(course)


func get_stage_index() -> int:
	return _stage_index


func get_stage_count() -> int:
	if course == null:
		return 0
	return course.get_stage_count()


func get_segment_index() -> int:
	return _segment_index


func get_segment_count() -> int:
	var stage := _current_stage()
	return stage.get_segment_count() if stage != null else 0


func _current_stage() -> TrailStage:
	if course == null:
		return null
	return course.get_stage(_stage_index)


func _on_actor_grabbed() -> void:
	request_sound_effect(&"grab")


func _on_segment_restarted() -> void:
	# A soft landing cue, not a failure cue: leaving the corridor costs the walk
	# back from the last checkpoint and nothing else.
	request_sound_effect(&"drop")


func _on_segment_completed(segment_index: int) -> void:
	if segment_index != _segment_index or _course_finishing:
		return
	request_sound_effect(&"correct")
	var stage := _current_stage()
	if stage == null:
		return
	if segment_index < stage.get_segment_count() - 1:
		await get_tree().create_timer(SEGMENT_ADVANCE_DELAY).timeout
		if not is_inside_tree():
			return
		# The next segment starts where this one ended, so the actor stays put and
		# the route ahead of it changes.
		_segment_index = segment_index + 1
		trail_board.set_active_segment(_segment_index)
		return
	if _stage_index >= course.get_stage_count() - 1:
		_course_finishing = true
		await get_tree().create_timer(COURSE_COMPLETION_DELAY).timeout
		if not is_inside_tree():
			return
		complete_level()
		return
	# The journey moves on to a different place with a different actor, so this
	# handover is a visible change of scene rather than a continuation.
	await get_tree().create_timer(course.stage_handover_duration).timeout
	if not is_inside_tree():
		return
	_stage_index += 1
	_segment_index = 0
	trail_board.set_active_stage(_stage_index)


func _on_completion_started() -> void:
	trail_board.set_input_enabled(false)
	trail_board.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _restart_preview() -> void:
	get_tree().reload_current_scene()
