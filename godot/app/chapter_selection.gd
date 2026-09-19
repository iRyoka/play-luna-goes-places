class_name ChapterSelection
extends Control

## The chapter entry surface: an open storybook whose page slots hold the
## registered chapters. It presents chapters and reports the chosen chapter ID.
## It does not route, read the route table, or reference other screens.

signal chapter_selected(chapter_id: StringName)
signal sound_requested(sound_id: StringName)

const SLOTS_PER_PAGE := 3
## Card geometry and page columns as fractions of the screen. They were measured
## from the storybook spread's cream page area, which is clear of its floral
## corners between roughly 0.27 and 0.48 horizontally and 0.11 and 0.84
## vertically on the left page, so three cards sit inside the page with margins.
const CARD_SIZE_RATIO := Vector2(0.20, 0.196)
const CARD_GAP_RATIO := 0.035
const PAGE_COLUMN_RATIOS: Array[float] = [0.375, 0.625]
const CHAPTER_THUMBNAILS: Dictionary[StringName, Texture2D] = {
	&"chapter_01": preload("res://assets/environments/chapter-01/map/chapter-background.png"),
}
const CHAPTER_MAP_SNAPSHOT_TEMPLATE := "res://assets/environments/%s/map/chapter-background.png"

@onready var slots: Node2D = %Slots

var _cards: Dictionary[StringName, ChapterSelectionCard] = {}


func _ready() -> void:
	resized.connect(_layout_cards)
	_create_chapter_cards()
	_layout_cards()


func get_presented_chapter_ids() -> Array[StringName]:
	var chapter_ids: Array[StringName] = []
	for chapter_id: StringName in _cards:
		chapter_ids.append(chapter_id)
	return chapter_ids


func is_chapter_presented_as_available(chapter_id: StringName) -> bool:
	return _cards.has(chapter_id)


func _create_chapter_cards() -> void:
	var content_registry := get_node("/root/ContentRegistry") as ContentCatalog
	var game_state := get_node("/root/GameState")
	var chapter_ids := content_registry.get_chapter_ids()
	if chapter_ids.size() > SLOTS_PER_PAGE * PAGE_COLUMN_RATIOS.size():
		push_warning("Chapter selection has more chapters than storybook slots.")
	for chapter_index in chapter_ids.size():
		var chapter_id := chapter_ids[chapter_index]
		var chapter := content_registry.get_chapter(chapter_id)
		if chapter == null:
			continue
		if not _is_chapter_available(chapter, game_state):
			continue
		var card := ChapterSelectionCard.new()
		card.name = "Chapter%dCard" % (chapter_index + 1)
		card.thumbnail = _get_chapter_thumbnail(chapter)
		card.tear_variant = chapter_index
		slots.add_child(card)
		_cards[chapter_id] = card
		_add_card_tap_target(chapter_id, card)


func _is_chapter_available(chapter: ChapterDefinition, game_state: Node) -> bool:
	var completed_level_ids: Dictionary[StringName, bool] = {}
	for prerequisite_level_id: StringName in chapter.unlock_prerequisite_level_ids:
		if game_state.is_level_completed(prerequisite_level_id):
			completed_level_ids[prerequisite_level_id] = true
	return ProgressionEvaluator.is_chapter_available(chapter, completed_level_ids)


func _get_chapter_thumbnail(chapter: ChapterDefinition) -> Texture2D:
	var explicit_thumbnail := CHAPTER_THUMBNAILS.get(chapter.id) as Texture2D
	if explicit_thumbnail != null:
		return explicit_thumbnail
	var snapshot_path := CHAPTER_MAP_SNAPSHOT_TEMPLATE % String(chapter.id).replace("_", "-")
	if ResourceLoader.exists(snapshot_path, "Texture2D"):
		return load(snapshot_path) as Texture2D
	return null


func _add_card_tap_target(chapter_id: StringName, card: ChapterSelectionCard) -> void:
	var target := TapTarget.new()
	target.name = "TapTarget"
	target.destination_id = chapter_id
	target.feedback_target = card
	target.add_to_group(&"chapter_selection_targets")
	var collision := CollisionShape2D.new()
	collision.name = "Collision"
	collision.shape = RectangleShape2D.new()
	target.add_child(collision)
	card.add_child(target)
	target.feedback_requested.connect(_on_target_feedback_requested)
	target.activated.connect(_on_target_activated)


func _layout_cards() -> void:
	var layout_size := size if size != Vector2.ZERO else Vector2(2160.0, 1080.0)
	var card_size := layout_size * CARD_SIZE_RATIO
	var gap := layout_size.y * CARD_GAP_RATIO
	var slot_stride := card_size.y + gap
	var chapter_index := 0
	for chapter_id: StringName in _cards:
		var card := _cards[chapter_id]
		var page_index := chapter_index / SLOTS_PER_PAGE
		var slot_index := chapter_index % SLOTS_PER_PAGE
		if page_index >= PAGE_COLUMN_RATIOS.size():
			card.visible = false
			chapter_index += 1
			continue
		card.card_size = card_size
		card.position = Vector2(
			layout_size.x * PAGE_COLUMN_RATIOS[page_index],
			layout_size.y * 0.5 + (float(slot_index) - float(SLOTS_PER_PAGE - 1) * 0.5) * slot_stride,
		)
		_resize_card_tap_target(card, card_size)
		chapter_index += 1


func _resize_card_tap_target(card: ChapterSelectionCard, card_size: Vector2) -> void:
	var target := card.get_node_or_null("TapTarget") as TapTarget
	if target == null:
		return
	var shape := (target.get_node("Collision") as CollisionShape2D).shape as RectangleShape2D
	shape.size = card_size


func _on_target_activated(chapter_id: StringName) -> void:
	chapter_selected.emit(chapter_id)


func _on_target_feedback_requested() -> void:
	sound_requested.emit(&"tap")
