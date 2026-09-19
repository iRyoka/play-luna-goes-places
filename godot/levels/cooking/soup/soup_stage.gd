class_name SoupStage
extends CookingStage

## Vegetable soup: carrot, tomato, one to three stirred circles, then the salt
## shaker placed and tapped twice. The stage owns the ordered story and the
## board owns the drawing and the gestures.

enum Step { CARROT, TOMATO, STIR, SALT, READY }

const READY_CELEBRATION_DELAY := 2.5
const STIR_COMPLETION_HOLD_SECONDS := 0.4
const SALT_COMPLETION_HOLD_SECONDS := 0.32

## Approved safe arrangements of the two ingredients, carrot then tomato. This is
## soup's only authored run variation, and it exists so a child's understanding of
## the interaction can be told apart from familiarity with one layout.
const INGREDIENT_ARRANGEMENTS: Array = [
	[Vector2(470.0, 750.0), Vector2(1690.0, 750.0)],
	[Vector2(1690.0, 750.0), Vector2(470.0, 750.0)],
]

## Fixed ingredient arrangement for tests. Below zero picks a fresh approved one.
@export var ingredient_arrangement_index := -1

@onready var soup_board: SoupBoard = %SoupBoard

var _step := Step.CARROT
var _seasoning_finishing := false
var _stir_finishing := false


func _ready() -> void:
	var index := ingredient_arrangement_index
	if index < 0:
		index = randi() % INGREDIENT_ARRANGEMENTS.size()
	var arrangement: Array = INGREDIENT_ARRANGEMENTS[index % INGREDIENT_ARRANGEMENTS.size()]
	soup_board.configure_ingredient_positions(arrangement[0], arrangement[1])
	soup_board.ingredient_dropped.connect(_on_ingredient_dropped)
	soup_board.stirring_turn_completed.connect(_on_stirring_turn_completed)
	soup_board.stirring_finished.connect(_on_stirring_finished)
	soup_board.salt_dispensed.connect(_on_salt_dispensed)
	# The first cue is drawn before input opens, so the kitchen fades in already
	# showing the child what to reach for.
	soup_board.set_active_step(_step)


func begin() -> void:
	set_input_enabled(true)


func set_input_enabled(enabled: bool) -> void:
	soup_board.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func get_current_step() -> Step:
	return _step


func get_stir_progress() -> float:
	return soup_board.stir_progress


func get_salt_tap_count() -> int:
	return soup_board.salt_tap_count


func _on_ingredient_dropped(ingredient_id: StringName) -> void:
	var expected := &"carrot" if _step == Step.CARROT else &"tomato"
	if ingredient_id != expected:
		return
	soup_board.accept_ingredient(ingredient_id)
	sound_requested.emit(&"drop")
	_advance_step()


func _on_stirring_finished() -> void:
	if _step != Step.STIR or _stir_finishing:
		return
	_stir_finishing = true
	await get_tree().create_timer(STIR_COMPLETION_HOLD_SECONDS).timeout
	if _step != Step.STIR:
		return
	_advance_step()


func _on_stirring_turn_completed() -> void:
	if _step == Step.STIR:
		sound_requested.emit(&"correct")


func _on_salt_dispensed() -> void:
	if _step != Step.SALT or _seasoning_finishing:
		return
	soup_board.register_salt_tap()
	sound_requested.emit(&"correct")
	if soup_board.salt_tap_count >= 2:
		_seasoning_finishing = true
		await get_tree().create_timer(SALT_COMPLETION_HOLD_SECONDS).timeout
		if _step != Step.SALT:
			return
		_advance_step()


func _advance_step() -> void:
	_step += 1
	soup_board.set_active_step(_step)
	if _step == Step.READY:
		# The finished soup is seen before the level hands over or celebrates.
		await get_tree().create_timer(READY_CELEBRATION_DELAY).timeout
		if _step != Step.READY:
			return
		recipe_finished.emit()
