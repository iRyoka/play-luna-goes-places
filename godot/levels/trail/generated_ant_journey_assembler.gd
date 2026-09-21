class_name GeneratedAntJourneyAssembler
extends RefCounted

## Cuts movement intervals from one panorama; Bee is the unchanged authored stage.
const AUTHORED := preload("res://levels/trail/courses/meadow_and_stream.tres")
const MARKER_ROOT := "res://assets/gameplay/trail/generated-ant/markers/"
const MIN_LEG := 650.0
const MAX_LEG := 1250.0
const SCREEN_MARGIN := AntJourney.SCREEN_ORIGIN
static var _presentations: Dictionary = {}
static var _marker_manifest: Dictionary = {}


static func assemble(seed: int,bee_stage: TrailStage) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed=seed+92000
	for attempt in range(64):
		var route := AntRouteGenerator.generate(seed+attempt*7919)
		if not route.errors.is_empty(): continue
		var journey := _journey(route,rng)
		var course := _course(journey,bee_stage,rng)
		if course!=null and validate_generated_course(course).is_empty():
			return {"course":course,"journey":journey,"signature":route.signature,"seed":seed,"effective_seed":route.seed,"checkpoint_attempt":attempt,"errors":PackedStringArray()}
	return {"course":null,"seed":seed,"errors":PackedStringArray(["No valid checkpoint placement in bounded attempts."])}


static func fallback(bee_stage: TrailStage) -> TrailCourse:
	return assemble(94016,bee_stage).get("course") as TrailCourse


static func _presentation(id: String) -> Dictionary:
	if not _presentations.has(id):
		var data := AntRouteGenerator.get_tile(id).duplicate()
		data.texture=load(data.artwork) as Texture2D
		data.support=(load(data.support) as Texture2D).get_image()
		data.grace=(load(data.grace) as Texture2D).get_image()
		# CPU hit-test masks need one channel, not a second full RGBA artwork copy.
		data.support.convert(Image.FORMAT_L8)
		data.grace.convert(Image.FORMAT_L8)
		_presentations[id]=data
	return _presentations[id]


static func _journey(route: Dictionary,rng: RandomNumberGenerator) -> AntJourney:
	if _marker_manifest.is_empty():
		_marker_manifest=JSON.parse_string(FileAccess.get_file_as_string(MARKER_ROOT+"markers.json"))
	var journey := AntJourney.new()
	journey.initialize(route)
	journey.background=load("res://assets/gameplay/trail/generated-ant/background-panorama.png")
	for placement: Dictionary in route.placements:
		var tile := _presentation(placement.id).duplicate()
		tile.merge(placement,true)
		journey.tiles.append(tile)
	for index in range(1,journey.tiles.size()):
		var a: Dictionary=journey.tiles[index-1]
		var b: Dictionary=journey.tiles[index]
		if _seam_matches(a,b): continue
		var path: PackedVector2Array=b.points
		var connector: Dictionary=_marker_manifest.connectors[0 if rng.randf()<0.75 else 1]
		journey.covers.append({"position":path[0],"angle":(path[1]-path[0]).angle(),"texture":load(MARKER_ROOT+String(connector.file)),"anchor":Vector2(float(connector.anchor[0]),float(connector.anchor[1]))})
	return journey


static func _seam_matches(a: Dictionary,b: Dictionary) -> bool:
	if a.material!=b.material: return false
	if a.material=="stone": return true
	var key := "%s:%s:%s:%s" % [a.family,a.orientation,b.family,b.orientation]
	return key in ["E03:T-R:E03:L-T","E03:B-R:E03:L-B","E05:T-R:E05:L-T","S02:L-R:S02:L-R","S02:L-R-flip:S02:L-R-flip"]


static func _berry(rng: RandomNumberGenerator) -> Dictionary:
	var record: Dictionary=_marker_manifest.berries[rng.randi_range(0,5)]
	return {"texture":load(MARKER_ROOT+String(record.file)),"anchor":Vector2(float(record.anchor[0]),float(record.anchor[1]))}


static func _stable_checkpoint(journey: AntJourney,distance: float) -> bool:
	var point := journey.path.point_at_distance(distance)
	if absf(point.x-1800)<150 or absf(point.x-3600)<150: return false
	for cover: Dictionary in journey.covers:
		if point.distance_to(cover.position)<140: return false
	for tile: Dictionary in journey.tiles:
		for binder: Dictionary in tile.binder_placements:
			var base := Vector2(float(binder.center[0]),float(binder.center[1]))
			var position := AntJourney.pixel_in_source(base,tile.size,tile.orientation)+Vector2(tile.offset)
			if point.distance_to(position)<100: return false
	var a := journey.path.tangent_at_distance(distance-45)
	var b := journey.path.tangent_at_distance(distance+45)
	return absf(rad_to_deg(a.angle_to(b)))<=18


static func _checkpoints(journey: AntJourney,start: float,end: float) -> PackedFloat32Array:
	var length := end-start
	for legs in range(maxi(2,ceili(length/1150.0)),floori(length/MIN_LEG)+1):
		var chosen := PackedFloat32Array([start])
		for index in range(1,legs):
			var target := start+length*float(index)/legs
			var selected := -1.0
			for step in range(25):
				for direction in [1.0,-1.0]:
					var candidate: float=target+step*15.0*direction
					var remaining := legs-index
					if candidate-chosen[-1]<MIN_LEG or candidate-chosen[-1]>MAX_LEG: continue
					if end-candidate<remaining*MIN_LEG or end-candidate>remaining*MAX_LEG: continue
					if not _stable_checkpoint(journey,candidate): continue
					selected=candidate
					break
				if selected>=0: break
			if selected<0: break
			chosen.append(selected)
		if chosen.size()==legs and end-chosen[-1]>=MIN_LEG and end-chosen[-1]<=MAX_LEG:
			chosen.append(end)
			return chosen
	return PackedFloat32Array()


static func _course(journey: AntJourney,bee: TrailStage,rng: RandomNumberGenerator) -> TrailCourse:
	var course := TrailCourse.new()
	course.stages=[bee]
	var style := AUTHORED.get_stage(1)
	for zi in range(3):
		var zone: Dictionary=journey.zones[zi]
		var start := journey.distances[int(zone.start_index)]
		var end := journey.distances[int(zone.end_index)]
		var anchors := _checkpoints(journey,start,end)
		if anchors.is_empty(): return null
		var stage := TrailStage.new()
		stage.ant_journey=journey
		stage.view_origin=zi*1800.0
		stage.continuous_checkpoints=true
		stage.containment=TrailSegment.Containment.RESTART_ON_EXIT
		stage.actor_frames=style.actor_frames
		stage.actor_draw_radius=style.actor_draw_radius
		stage.actor_radius=38
		stage.background=load("res://assets/gameplay/trail/generated-ant/background-midstream.png")
		stage.travelled_color=Color.TRANSPARENT
		for index in range(1,anchors.size()):
			stage.segments.append(_slice(journey,anchors[index-1],anchors[index],stage.view_origin))
			if index<anchors.size()-1:
				var marker := _berry(rng)
				marker.merge({"position":journey.path.point_at_distance(anchors[index]),"distance":anchors[index],"objective":false})
				journey.markers.append(marker)
		course.stages.append(stage)
	var goal := _berry(rng)
	goal.merge({"position":journey.points[-1],"distance":journey.distances[-1],"objective":true})
	journey.markers.append(goal)
	return course


static func _slice(journey: AntJourney,start: float,end: float,origin: float) -> TrailSegment:
	var segment := TrailSegment.new()
	segment.smooth=false
	segment.path_width=130
	segment.global_start_distance=start
	var offset := SCREEN_MARGIN-Vector2(origin,0)
	segment.points.append(journey.path.point_at_distance(start)+offset)
	segment.width_samples.append(journey.width_at(start))
	for index in range(journey.points.size()):
		if journey.distances[index]>start+0.001 and journey.distances[index]<end-0.001:
			segment.points.append(journey.points[index]+offset)
			segment.width_samples.append(journey.widths[index])
	segment.points.append(journey.path.point_at_distance(end)+offset)
	segment.width_samples.append(journey.width_at(end))
	return segment


static func validate_generated_course(course: TrailCourse) -> PackedStringArray:
	if course==null or course.stages.size()!=4:
		return PackedStringArray(["Ant needs Bee plus three movement windows."])
	var errors := course.validate()
	if course.get_stage(1).ant_journey != null:
		errors.append_array(validate_back_clearance(course.get_stage(1).ant_journey))
	for index in range(1,4):
		var stage := course.get_stage(index)
		if stage.ant_journey==null or stage.view_origin!=(index-1)*1800 or not stage.continuous_checkpoints:
			errors.append("Ant window lost shared panorama or held checkpoints.")
		for segment in stage.segments:
			if segment.get_length()<MIN_LEG-0.5 or segment.get_length()>MAX_LEG+0.5:
				errors.append("Ant recovery leg violates calibrated bounds.")
	return errors


static func validate_back_clearance(journey: AntJourney) -> PackedStringArray:
	# Check cleaned visible support, including the neighboring zone in each overlap.
	var exclusion := Rect2(40,40,260,260)
	for window in range(3):
		for tile: Dictionary in journey.tiles:
			var origin := Vector2(tile.offset)+SCREEN_MARGIN-Vector2(window*1800,0)
			var overlap := exclusion.intersection(Rect2(origin,tile.size))
			if not overlap.has_area(): continue
			var a := AntJourney.pixel_in_source(overlap.position-origin,tile.size,tile.orientation)
			var b := AntJourney.pixel_in_source(overlap.end-origin,tile.size,tile.orientation)
			var low := a.min(b).floor()
			var high := a.max(b).ceil()
			var support: Image=tile.support
			var pixels := support.get_region(Rect2i(Vector2i(low),Vector2i(high-low)))
			pixels.convert(Image.FORMAT_L8)
			if pixels.get_data().has(255):
				return PackedStringArray(["Ant support enters the expanded Back exclusion in window %d." % (window+1)])
	return PackedStringArray()
