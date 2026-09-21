@tool
extends Node2D

@onready var puppet_root: Node2D = $PuppetRoot
@onready var kite_hand_anchor: Marker2D = $PuppetRoot/KiteHandAnchor
@onready var kite_anchor: Marker2D = $PuppetRoot/KiteAnchor
@onready var tail_anchor: Marker2D = $PuppetRoot/TailAnchor
@onready var bow_one_anchor: Marker2D = $PuppetRoot/BowOneAnchor
@onready var bow_two_anchor: Marker2D = $PuppetRoot/BowTwoAnchor
@onready var bow_three_anchor: Marker2D = $PuppetRoot/BowThreeAnchor


func _process(_delta: float) -> void:
	# Keep cords visible while transforms are adjusted in the 2D editor.
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 2160.0, 1080.0), Color("9bdcff"))
	draw_circle(Vector2(1080.0, 1300.0), 900.0, Color("80cc71"))
	if not is_instance_valid(puppet_root):
		return
	var hand := puppet_root.position + kite_hand_anchor.position
	var kite := puppet_root.position + kite_anchor.position
	var tail := puppet_root.position + tail_anchor.position
	draw_line(hand, kite, Color("755030"), 7.0, true)
	draw_line(tail, puppet_root.position + bow_one_anchor.position, Color("8a6a9d"), 5.0, true)
	draw_line(puppet_root.position + bow_one_anchor.position, puppet_root.position + bow_two_anchor.position, Color("8a6a9d"), 5.0, true)
	draw_line(puppet_root.position + bow_two_anchor.position, puppet_root.position + bow_three_anchor.position, Color("8a6a9d"), 5.0, true)
