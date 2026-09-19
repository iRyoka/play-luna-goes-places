class_name TrailCourse
extends Resource

## The complete authored configuration of one trail level: its ordered stages and
## the forgiveness values they share. A stage is one place with one actor; the
## segments inside it are the legs of that place's route. Adding a place is a new
## stage resource plus its artwork, and adding a whole trail level is a new course.
## Changing mechanic code to add either means a genuinely new mechanic dimension
## is being introduced.

@export_group("Journey")
## The places of this level, travelled in order.
@export var stages: Array[TrailStage] = []

@export_group("Feel")
## How far from the actor a press may land and still pick it up. It is shared,
## because a child's aim does not change between one place and the next.
@export var actor_capture_radius := 220.0
## How close to the end of a route counts as arriving. It must be generous enough
## that an actor travelling along the corridor wall reaches its marker without
## the child having to steer onto the very last point of the centre-line.
@export var goal_reach := 130.0
## Extra grace beyond the corridor edge before the pointer counts as off route.
@export var off_route_tolerance := 60.0
## Seconds the actor takes to fly back to its checkpoint after leaving a
## restarting corridor.
@export var restart_duration := 0.45

@export_group("Presentation")
## Drawn when a stage supplies no background. A missing background is a quiet
## plain backing, never an error.
@export var placeholder_background_color := Color(0.80, 0.87, 0.68)
## Seconds the finished place rests before the next one arrives. It is longer
## than a segment handover because the whole screen changes.
@export var stage_handover_duration := 0.9


func get_stage_count() -> int:
	return stages.size()


func get_stage(index: int) -> TrailStage:
	if index < 0 or index >= stages.size():
		return null
	return stages[index]


func get_start_point() -> Vector2:
	var first := get_stage(0)
	if first == null:
		return Vector2.ZERO
	return first.get_start_point()


## Authoring errors that make the course unplayable. An empty result means the
## course is safe to present. Stages are not required to join up: each one is its
## own place, and the actor is expected to change between them.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if stages.is_empty():
		errors.append("A course needs at least one stage.")
		return errors
	for index in range(stages.size()):
		var stage := stages[index]
		if stage == null:
			errors.append("Stage %d is missing." % index)
			continue
		for error in stage.validate():
			errors.append("Stage %d: %s" % [index, error])
	return errors
