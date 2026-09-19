class_name DragMatchLevel
extends LevelController

@onready var backdrop: Control = %PlaceholderArt
@onready var pieces_container: Node2D = %Pieces
@onready var targets_container: Node2D = %Targets

var _pieces: Array[Draggable] = []
var _targets: Array[DropTarget] = []
var _placed_count := 0
var _placement_rng := RandomNumberGenerator.new()

@export var shuffle_seed := -1

const TARGET_SLOTS := [
	Vector2(720.0, 340.0),
	Vector2(1080.0, 340.0),
	Vector2(1440.0, 340.0),
]
const PIECE_SLOTS := [
	Vector2(720.0, 790.0),
	Vector2(1080.0, 790.0),
	Vector2(1440.0, 790.0),
]


func _ready() -> void:
	super._ready()
	if shuffle_seed >= 0:
		_placement_rng.seed = shuffle_seed
	else:
		_placement_rng.randomize()
	for child: Node in pieces_container.get_children():
		var piece := child as Draggable
		if piece == null:
			continue
		_pieces.append(piece)
		piece.drag_started.connect(_on_piece_drag_started)
		piece.drop_requested.connect(_on_piece_drop_requested)
		piece.placed.connect(_on_piece_placed)
	for child: Node in targets_container.get_children():
		var target := child as DropTarget
		if target == null:
			continue
		_targets.append(target)
	_shuffle_layout()
	completion_started.connect(_on_completion_started)


func get_placed_count() -> int:
	return _placed_count


func _shuffle_layout() -> void:
	var target_slot_order := [0, 1, 2]
	for index: int in range(target_slot_order.size() - 1, 0, -1):
		var swap_index := _placement_rng.randi_range(0, index)
		var swap_value: int = target_slot_order[index]
		target_slot_order[index] = target_slot_order[swap_index]
		target_slot_order[swap_index] = swap_value
	var piece_slot_offset := _placement_rng.randi_range(1, TARGET_SLOTS.size() - 1)

	for index: int in _targets.size():
		_targets[index].global_position = TARGET_SLOTS[target_slot_order[index]]
		var piece_slot_index: int = (target_slot_order[index] + piece_slot_offset) % PIECE_SLOTS.size()
		_pieces[index].set_home_global_position(PIECE_SLOTS[piece_slot_index])


func _on_piece_drop_requested(piece: Draggable, drop_position: Vector2) -> void:
	if is_level_complete() or piece.is_placed():
		return

	var touched_target: DropTarget
	for target: DropTarget in _targets:
		if target.contains_drop_point(drop_position):
			touched_target = target
			break

	if touched_target != null and touched_target.can_accept(piece.match_id, drop_position):
		request_sound_effect(&"drop")
		if touched_target.accept_piece(piece.match_id):
			piece.snap_to(touched_target.global_position)
			return
	elif touched_target != null:
		touched_target.play_wrong_feedback()
	request_sound_effect(&"wrong")
	piece.return_home()


func _on_piece_drag_started() -> void:
	request_sound_effect(&"grab")


func _on_piece_placed(_piece: Draggable) -> void:
	_placed_count += 1
	if _placed_count == _pieces.size():
		complete_level()


func _on_completion_started() -> void:
	for piece: Draggable in _pieces:
		piece.set_interaction_enabled(false)
	pieces_container.visible = false
	targets_container.visible = false
	backdrop.call("play_completion_reaction")
