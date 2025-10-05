# DataHandler.gd
class_name DataHandler
extends Node3D

var multimesh_rid: RID
var instance_rid: RID
var space_rid: RID

var boid_body_rids: Array[RID] = []
var boid_shape_rids: Array[RID] = []
var rid_to_index: Dictionary = {}

@export var boid_mesh: Mesh
@export var instance_count: int = 1000
@export var boid_collision_radius: float = 0.5
@export var visible_instance_count: int = 1000
var velocity_array: Array[Vector3]
var acceleration_array: Array[Vector3]
@export var bounds: Vector3 = Vector3(100.0, 100.0, 100.0)
@export var max_speed: float = 5.0
@export var alignment_perception_radius: float = 10.0:
	set(value):
		alignment_perception_radius = value
		max_perception_radius = maxf(
			alignment_perception_radius,
			maxf(separation_perception_radius, cohesion_perception_radius)
		)
	get:
		return alignment_perception_radius

@export var cohesion_perception_radius: float = 10.0:
	set(value):
		cohesion_perception_radius = value
		max_perception_radius = maxf(
			alignment_perception_radius,
			maxf(separation_perception_radius, cohesion_perception_radius)
		)
	get:
		return cohesion_perception_radius

@export var separation_perception_radius: float = 5.0:
	set(value):
		separation_perception_radius = value
		max_perception_radius = maxf(
			alignment_perception_radius,
			maxf(separation_perception_radius, cohesion_perception_radius)
		)
	get:
		return separation_perception_radius

var max_perception_radius: float
@export var alignment_weight: float = 1.0
@export var cohesion_weight: float = 1.0
@export var separation_weight: float = 1.5

const BOID_COLLISION_LAYER = 1
const BOID_COLLISION_MASK = 1


func _ready() -> void:
	space_rid = get_world_3d().space

	var result = MeshHandler.create_multimesh(boid_mesh, instance_count, get_world_3d().scenario)

	multimesh_rid = result["multimesh_rid"]
	instance_rid = result["instance_rid"]

	MeshHandler.set_visible_instance_count(multimesh_rid, visible_instance_count)
	initialize_boids()


func _process(delta: float) -> void:
	var transforms = MeshHandler.get_all_transforms(multimesh_rid, visible_instance_count)

	for i in range(visible_instance_count):
		PhysicsHandler.update_boid_body_position(boid_body_rids[i], transforms[i].origin)

	for i in range(visible_instance_count):
		var neighbor_rids = PhysicsHandler.find_neighbors_physics(
			space_rid,
			transforms[i].origin,
			max_perception_radius,
			boid_body_rids[i],
			BOID_COLLISION_MASK
		)

		var neighbors: Array[int] = []
		for rid in neighbor_rids:
			if rid_to_index.has(rid):
				neighbors.append(rid_to_index[rid])

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
	boid_body_rids.clear()
	boid_shape_rids.clear()
	rid_to_index.clear()

	for i in range(visible_instance_count):
		var random_position = PhysicsHandler.generate_random_position(bounds)

		MeshHandler.set_transform(multimesh_rid, i, Transform3D().translated(random_position))

		velocity_array.append(PhysicsHandler.generate_random_velocity(max_speed))
		acceleration_array.append(Vector3.ZERO)

		var body_data = PhysicsHandler.create_boid_body(
			space_rid,
			random_position,
			boid_collision_radius,
			BOID_COLLISION_LAYER,
			BOID_COLLISION_MASK
		)

		boid_body_rids.append(body_data["body_rid"])
		boid_shape_rids.append(body_data["shape_rid"])
		rid_to_index[body_data["body_rid"]] = i


func _exit_tree() -> void:
	for i in range(boid_body_rids.size()):
		PhysicsHandler.destroy_boid_body(boid_body_rids[i], boid_shape_rids[i])

	MeshHandler.destroy_multimesh(multimesh_rid, instance_rid)
