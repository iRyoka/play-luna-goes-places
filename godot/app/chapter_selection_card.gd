class_name ChapterSelectionCard
extends Node2D

## One chapter on the storybook spread: its map picture torn from paper and
## pasted onto the page. The card is composed once into a single texture so the
## torn silhouette cuts the picture, the paper fringe, and the shadow alike.
##
const TORN_MASK: Texture2D = preload("res://assets/ui/chapter-selection/torn-card-mask.png")
const PAPER_COLOR := Color("#f6eed6")
const SHADOW_COLOR := Color(0.44, 0.35, 0.22, 0.28)
const SHADOW_OFFSET := Vector2(5.0, 10.0)
## Paper visible around the picture, as a fraction of card width. The torn edge
## wanders further than this, so it cuts into the picture in places instead of
## leaving an even border.
const PICTURE_INSET_RATIO := 0.024
var card_size := Vector2(410.0, 205.0):
	set(value):
		card_size = value
		_rebuild()
var thumbnail: Texture2D:
	set(value):
		thumbnail = value
		_rebuild()
## Mirrors the shared torn mask so neighbouring cards do not repeat one silhouette.
var tear_variant := 0:
	set(value):
		tear_variant = value
		_rebuild()

var _card_texture: ImageTexture
var _shadow_texture: ImageTexture


func _draw() -> void:
	if _card_texture == null:
		return
	var rect := Rect2(-card_size * 0.5, card_size)
	# The shadow uses this card's own torn silhouette, mirroring included.
	draw_texture_rect(_shadow_texture, Rect2(rect.position + SHADOW_OFFSET, rect.size), false, SHADOW_COLOR)
	draw_texture_rect(_card_texture, rect, false)


func _rebuild() -> void:
	var width := int(round(card_size.x))
	var height := int(round(card_size.y))
	if width <= 0 or height <= 0:
		return
	var card := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	card.fill(PAPER_COLOR)
	var inset := int(round(card_size.x * PICTURE_INSET_RATIO))
	var picture_size := Vector2i(width - inset * 2, height - inset * 2)
	if picture_size.x > 0 and picture_size.y > 0:
		card.blit_rect(
			_get_picture_image(picture_size),
			Rect2i(Vector2i.ZERO, picture_size),
			Vector2i(inset, inset),
		)
	var mask := _get_tear_mask(width, height)
	_shadow_texture = ImageTexture.create_from_image(mask)
	_card_texture = ImageTexture.create_from_image(_apply_paper_edge(card, mask))
	queue_redraw()


func _get_picture_image(picture_size: Vector2i) -> Image:
	if thumbnail == null:
		return _get_placeholder_image(picture_size)
	var picture := thumbnail.get_image().duplicate() as Image
	picture.convert(Image.FORMAT_RGBA8)
	# Fill the card without squashing the landscape: scale to cover, then centre-crop.
	var source_size := picture.get_size()
	var cover_scale := maxf(
		float(picture_size.x) / float(source_size.x),
		float(picture_size.y) / float(source_size.y),
	)
	picture.resize(
		ceili(source_size.x * cover_scale),
		ceili(source_size.y * cover_scale),
		Image.INTERPOLATE_LANCZOS,
	)
	var crop_origin := (picture.get_size() - picture_size) / 2
	var cropped := Image.create_empty(picture_size.x, picture_size.y, false, Image.FORMAT_RGBA8)
	cropped.blit_rect(picture, Rect2i(crop_origin, picture_size), Vector2i.ZERO)
	return cropped


func _get_placeholder_image(picture_size: Vector2i) -> Image:
	# A chapter without a map background yet reuses the temporary Chapter 2
	# palette, so the selector and that chapter's own map agree visually.
	var placeholder := Image.create_empty(picture_size.x, picture_size.y, false, Image.FORMAT_RGBA8)
	placeholder.fill(Chapter02Backdrop.SKY_COLOR)
	for band: Dictionary in Chapter02Backdrop.BANDS:
		var band_top := int(picture_size.y * float(band["height"]))
		placeholder.fill_rect(
			Rect2i(0, band_top, picture_size.x, picture_size.y - band_top),
			band["color"] as Color,
		)
	return placeholder


func _get_tear_mask(width: int, height: int) -> Image:
	var mask := TORN_MASK.get_image().duplicate() as Image
	mask.convert(Image.FORMAT_RGBA8)
	mask.resize(width, height, Image.INTERPOLATE_BILINEAR)
	if tear_variant & 1:
		mask.flip_x()
	if tear_variant & 2:
		mask.flip_y()
	return mask


func _apply_paper_edge(card: Image, mask: Image) -> Image:
	var card_data := card.get_data()
	var mask_data := mask.get_data()
	for index in range(0, card_data.size(), 4):
		card_data[index + 3] = card_data[index + 3] * mask_data[index + 3] / 255
	return Image.create_from_data(
		card.get_width(),
		card.get_height(),
		false,
		Image.FORMAT_RGBA8,
		card_data,
	)
