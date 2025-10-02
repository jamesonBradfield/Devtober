@tool
extends Node3D

@export_range(0, 99999, 1) var count: int:
	set(value):
		update_count_dynamically(value)
		count = value
	get:
		return count
@export var bounds: Vector3
@export var mesh: Mesh


func update_count_dynamically(target_value: int):
	var current_child_count: int = get_child_count()
	var delta = target_value - current_child_count
	if target_value != current_child_count:
		if target_value < current_child_count:
			for i in range(current_child_count + delta, current_child_count):
				get_child(i).queue_free()
		else:
			for i in range(current_child_count, current_child_count + delta):
				var mesh_instance: MeshInstance3D = MeshInstance3D.new()
				mesh_instance.mesh = self.mesh
				mesh_instance.name = "boid " + str(i)
				mesh_instance.position = random_vector(-bounds, bounds)
				add_child(mesh_instance)
				mesh_instance.owner = get_tree().edited_scene_root


func random_vector(min: Vector3, max: Vector3) -> Vector3:
	var random_X = randf_range(min.x, max.x)
	var random_Y = randf_range(min.y, max.y)
	var random_Z = randf_range(min.z, max.z)
	return Vector3(random_X, random_Y, random_Z)
