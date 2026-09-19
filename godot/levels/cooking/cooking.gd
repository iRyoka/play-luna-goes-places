class_name CookingLevel
extends LevelController

## Cooks an ordered run of recipes.
##
## Each stage owns one food story and resolves its own food. The finished dish
## holds, the kitchen hands over to the next recipe, and only the last stage
## reaches the shared completion sequence, so the level completes and persists
## exactly once however many recipes it holds. A further recipe is a stage scene
## and its artwork rather than a change here.

const HANDOVER_FADE := 0.3
## The blank beat between two kitchens. Cooking stages are whole rooms rather
## than pictures on one board, so the change of place needs its own moment.
const HANDOVER_HOLD := 0.35

@export var stage_scenes: Array[PackedScene] = []

@onready var stage_host: Control = %StageHost

var _stage_index := -1
var _stage: CookingStage


func _ready() -> void:
	super._ready()
	completion_started.connect(_on_completion_started)
	if get_tree().current_scene == self:
		replay_requested.connect(_restart_preview)
	if stage_scenes.is_empty():
		push_error("Cooking level %s has no recipe stages." % level_id)
		return
	if not _build_stage(0):
		return
	_stage.begin()


func get_stage_index() -> int:
	return _stage_index


func get_stage_count() -> int:
	return stage_scenes.size()


func get_current_stage() -> CookingStage:
	return _stage


func _build_stage(index: int) -> bool:
	var scene: PackedScene = stage_scenes[index]
	if scene == null:
		push_error("Cooking level %s has no scene for recipe %d." % [level_id, index])
		return false
	var root := scene.instantiate()
	var stage := root as CookingStage
	if stage == null:
		root.free()
		push_error("Cooking level %s recipe %d is not a CookingStage." % [level_id, index])
		return false
	_stage_index = index
	_stage = stage
	stage.recipe_finished.connect(_on_recipe_finished, CONNECT_ONE_SHOT)
	stage.sound_requested.connect(request_sound_effect)
	stage_host.add_child(stage)
	return true


func _on_recipe_finished() -> void:
	if is_level_complete():
		return
	if _stage_index + 1 >= stage_scenes.size():
		complete_level()
		return
	_hand_over_to_next_recipe()


## The finished dish fades away and the next kitchen fades in, so the child reads
## one continued cooking activity rather than a new level.
func _hand_over_to_next_recipe() -> void:
	var next_index := _stage_index + 1
	_stage.set_input_enabled(false)
	var handover := create_tween().set_trans(Tween.TRANS_SINE)
	handover.tween_property(gameplay, "modulate:a", 0.0, HANDOVER_FADE)
	handover.tween_callback(func() -> void:
		_clear_stage()
		_build_stage(next_index)
	)
	handover.tween_interval(HANDOVER_HOLD)
	handover.tween_property(gameplay, "modulate:a", 1.0, HANDOVER_FADE)
	handover.tween_callback(func() -> void:
		if _stage != null:
			_stage.begin()
	)


## Leaves the tree immediately rather than at the end of the frame, so the next
## kitchen never shares a frame with the finished one.
func _clear_stage() -> void:
	if _stage == null:
		return
	stage_host.remove_child(_stage)
	_stage.queue_free()
	_stage = null


func _on_completion_started() -> void:
	if _stage != null:
		_stage.set_input_enabled(false)


func _restart_preview() -> void:
	get_tree().reload_current_scene()
