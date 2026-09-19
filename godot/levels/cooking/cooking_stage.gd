class_name CookingStage
extends Control

## One recipe inside a cooking level.
##
## A stage owns its own food story: its kitchen, its objects, its ordered steps,
## and its input. The level owns entry, the handover between recipes, completion,
## and persistence, so a stage never completes a level or touches game state.

## The food is resolved and the dish has been seen. The level decides whether
## another recipe follows or the celebration begins.
signal recipe_finished

## A feedback beat worth hearing. The level forwards it to the shared player.
signal sound_requested(sound_id: StringName)


## Called once the stage is fully on screen. A stage starts closed to input, so
## a touch during a handover fade cannot reach a recipe the child cannot see.
func begin() -> void:
	pass


## The level closes a stage's input during a handover and at completion.
func set_input_enabled(_enabled: bool) -> void:
	pass
