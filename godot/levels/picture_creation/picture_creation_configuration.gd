class_name PictureCreationConfiguration
extends Resource

@export var reference_size := Vector2(2160.0, 1080.0)
## The level's presentation background. The board draws it inside its own
## transform so that zooming into a detail enlarges the picture together with the
## surface it is drawn on, instead of sliding the picture off a fixed backdrop.
@export var background_art: Texture2D
@export var base_art: Texture2D
@export var outline_art: Texture2D
@export var coloring_outline_art: Texture2D
@export var trace_stages: Array[PictureTraceStage] = []
@export var color_regions: Array[PictureColorRegion] = []
@export var palette: PackedColorArray = PackedColorArray()

@export_group("Presentation")
## Paper field drawn behind the picture. Leave the alpha at zero when the level
## scene supplies the paper as background artwork instead.
@export var paper_field_color := Color("#fff7e8")
## Wash drawn over everything outside the workspace while a trace is zoomed in.
@export var trace_fade_color := Color(1.0, 0.9686, 0.9098, 0.84)

@export_group("Palette layout")
## Centre of the first swatch. Later swatches fill rows left to right.
@export var palette_origin := Vector2(720.0, 970.0)
@export var palette_spacing := Vector2(150.0, 0.0)
@export var palette_columns := 5
@export var palette_swatch_radius := 52.0
## The selected color's disc, drawn larger and rimmed instead of highlighted.
@export var palette_selected_radius := 68.0
@export var palette_touch_radius := 58.0


func is_valid() -> bool:
	if reference_size.x <= 0.0 or reference_size.y <= 0.0 or trace_stages.is_empty() or color_regions.is_empty() or palette.is_empty():
		return false
	if palette_columns < 1 or palette_swatch_radius <= 0.0 or palette_touch_radius < palette_swatch_radius:
		return false
	var stage_ids: Dictionary[StringName, bool] = {}
	for stage: PictureTraceStage in trace_stages:
		if stage == null or not stage.is_valid() or stage_ids.has(stage.id):
			return false
		stage_ids[stage.id] = true
	var region_ids: Dictionary[StringName, bool] = {}
	for region: PictureColorRegion in color_regions:
		if region == null or not region.is_valid() or region_ids.has(region.id):
			return false
		region_ids[region.id] = true
	return true
