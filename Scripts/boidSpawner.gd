@tool
extends MultiMeshInstance3D

@export_range(0, 99999) var instance_count: int = 0:
	set = set_instance_count,
	get = get_instance_count

@export_range(0, 99999) var visible_instance_count: int = 0:
	set = set_visible_instance_count,
	get = get_visible_instance_count

@export_range(0, 300) var spawn_x_bounds: float = 0:
	set = set_spawn_x_bounds,
	get = get_spawn_x_bounds

@export_range(0, 300) var spawn_y_bounds: float = 0:
	set = set_spawn_y_bounds,
	get = get_spawn_y_bounds

@export_range(0, 300) var spawn_z_bounds: float = 0:
	set = set_spawn_z_bounds,
	get = get_spawn_z_bounds


func set_spawn_x_bounds(new_value: float) -> void:
	spawn_x_bounds = new_value
	randomize_instance_positions()


func set_spawn_y_bounds(new_value: float) -> void:
	spawn_y_bounds = new_value
	randomize_instance_positions()


func set_spawn_z_bounds(new_value: float) -> void:
	spawn_z_bounds = new_value
	randomize_instance_positions()


func set_instance_count(new_value: int) -> void:
	multimesh.instance_count = new_value
	instance_count = new_value


func set_visible_instance_count(new_value: int) -> void:
	multimesh.visible_instance_count = new_value
	visible_instance_count = new_value
	randomize_instance_positions()


func get_spawn_x_bounds() -> float:
	return spawn_x_bounds


func get_spawn_y_bounds() -> float:
	return spawn_y_bounds


func get_spawn_z_bounds() -> float:
	return spawn_z_bounds


func get_instance_count() -> int:
	return instance_count


func get_visible_instance_count() -> int:
	return visible_instance_count


func randomize_instance_positions():
	for i in range(visible_instance_count):
		var _position = Transform3D()
		_position = _position.translated(
			Vector3(
				randf() * spawn_x_bounds - (spawn_x_bounds / 2),
				randf() * spawn_y_bounds - (spawn_y_bounds / 2),
				randf() * spawn_z_bounds - (spawn_z_bounds / 2)
			)
		)
		multimesh.set_instance_transform(i, _position)
