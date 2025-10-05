# DataHandler.gd
class_name DataHandler
extends Node3D

var multimesh_rid: RID
var instance_rid: RID

@export var boid_mesh: Mesh
@export var instance_count: int = 1000
var visible_instance_count: int = 1000

var velocity_array: Array[Vector3]
var acceleration_array: Array[Vector3]

var bounds: Vector3 = Vector3(100.0, 100.0, 100.0)

var max_speed: float = 5.0
var alignment_perception_radius: float = 10.0:
	set(value):
		alignment_perception_radius = value
		max_perception_radius = maxf(
			alignment_perception_radius,
			maxf(separation_perception_radius, separation_perception_radius)
		)
	get:
		return alignment_perception_radius

var cohesion_perception_radius: float = 10.0:
	set(value):
		cohesion_perception_radius = value
		max_perception_radius = maxf(
			alignment_perception_radius,
			maxf(separation_perception_radius, separation_perception_radius)
		)
	get:
		return cohesion_perception_radius
var separation_perception_radius: float = 5.0:
	set(value):
		separation_perception_radius = value
		max_perception_radius = maxf(
			alignment_perception_radius,
			maxf(separation_perception_radius, separation_perception_radius)
		)
	get:
		return separation_perception_radius
var max_perception_radius: float
var alignment_weight: float = 1.0
var cohesion_weight: float = 1.0
var separation_weight: float = 1.5


func _ready() -> void:
	var result = MeshHandler.create_multimesh(boid_mesh, instance_count, get_world_3d().scenario)

	multimesh_rid = result["multimesh_rid"]
	instance_rid = result["instance_rid"]

	MeshHandler.set_visible_instance_count(multimesh_rid, visible_instance_count)
	initialize_boids()


func _process(delta: float) -> void:
	var transforms = MeshHandler.get_all_transforms(multimesh_rid, visible_instance_count)
	var currentFrame = Engine.get_process_frames()

	for i in range(visible_instance_count):
		var neighbors = BoidHandler.find_neighbors(
			transforms[i].origin, transforms, i, max_perception_radius
		)

		var separation_force = BoidHandler.calculate_separation(
			transforms[i].origin,
			transforms,
			neighbors,
			separation_perception_radius,
			separation_weight
		)

		var cohesion_force = BoidHandler.calculate_cohesion(
			transforms[i].origin, transforms, neighbors, cohesion_perception_radius, cohesion_weight
		)

		var alignment_force = BoidHandler.calculate_alignment(
			velocity_array[i],
			velocity_array,
			neighbors,
			alignment_perception_radius,
			alignment_weight
		)

		acceleration_array[i] = separation_force + cohesion_force + alignment_force

		velocity_array[i] = PhysicsHandler.update_velocity(
			velocity_array[i], acceleration_array[i], delta, max_speed
		)

		transforms[i] = PhysicsHandler.apply_velocity(transforms[i], velocity_array[i], delta)

		MeshHandler.set_transform(multimesh_rid, i, transforms[i])


func initialize_boids() -> void:
	velocity_array.clear()
	acceleration_array.clear()

	for i in range(visible_instance_count):
		var random_position = PhysicsHandler.generate_random_position(bounds)

		MeshHandler.set_transform(multimesh_rid, i, Transform3D().translated(random_position))

		velocity_array.append(PhysicsHandler.generate_random_velocity(max_speed))
		acceleration_array.append(Vector3.ZERO)


func _exit_tree() -> void:
	MeshHandler.destroy_multimesh(multimesh_rid, instance_rid)
