class_name MemoryLevelConfiguration
extends Resource

@export var stages: Array[MemoryConfiguration] = []


func is_valid() -> bool:
	if stages.is_empty():
		return false
	for stage in stages:
		if stage == null or not stage.is_valid():
			return false
	return true
