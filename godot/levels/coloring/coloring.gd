class_name ColoringLevel
extends LevelController

@onready var board: ColoringBoard = %Board


func _ready() -> void:
	super._ready()
	board.meaningful_action.connect(record_quiet_progress)
