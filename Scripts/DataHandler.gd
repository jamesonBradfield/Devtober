# DataHandler.gd
class_name DataHandler
extends Node3D

var multimesh_rid: RID
var instance_rid: RID
var space_rid: RID

var boid_body_rids: Array[RID] = []
var boid_shape_rids: Array[RID] = []
var rid_to_index: Dictionary = {}

var neighbor_query: PhysicsShapeQueryParameters3D
var neighbor_sphere: SphereShape3D

@export var boid_mesh: Mesh
@export var instance_count: int = 1000
@export var boid_collision_radius: float = 0.5
@export var visible_instance_count: int = 1000
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

	max_perception_radius = maxf(
		alignment_perception_radius, maxf(separation_perception_radius, cohesion_perception_radius)
	)
	MeshHandler.set_visible_instance_count(multimesh_rid, visible_instance_count)

	neighbor_sphere = SphereShape3D.new()
	neighbor_sphere.radius = max_perception_radius
	neighbor_query = PhysicsShapeQueryParameters3D.new()
	neighbor_query.shape = neighbor_sphere
	neighbor_query.collision_mask = BOID_COLLISION_MASK

	initialize_boids()


func _process(delta: float) -> void:
	var all_transforms: Array[Transform3D] = []
	all_transforms.resize(visible_instance_count)

	for i in range(visible_instance_count):
		all_transforms[i] = PhysicsHandler.get_body_transform(boid_body_rids[i])

	for i in range(visible_instance_count):
		var current_transform = all_transforms[i]
		var current_velocity = PhysicsHandler.get_body_velocity(boid_body_rids[i])

		var neighbor_rids = PhysicsHandler.find_neighbors_with_query(
			space_rid, neighbor_query, current_transform.origin, boid_body_rids[i]
		)

		var neighbors: Array[int] = []
		for rid in neighbor_rids:
			if !rid_to_index.has(rid):
				continue
			neighbors.append(rid_to_index[rid])

		var neighbor_velocities: Array[Vector3] = []
		for neighbor_index in neighbors:
			neighbor_velocities.append(
				PhysicsHandler.get_body_velocity(boid_body_rids[neighbor_index])
			)

		var separation_force = BoidHandler.calculate_separation(
			current_transform.origin,
			all_transforms,
			neighbors,
			separation_perception_radius,
			separation_weight
		)

		var cohesion_force = BoidHandler.calculate_cohesion(
			current_transform.origin,
			all_transforms,
			neighbors,
			cohesion_perception_radius,
			cohesion_weight
		)

		var alignment_force = BoidHandler.calculate_alignment(
			current_velocity, neighbor_velocities, alignment_perception_radius, alignment_weight
		)

		var acceleration = separation_force + cohesion_force + alignment_force

		var new_velocity = PhysicsHandler.update_velocity(
			current_velocity, acceleration, delta, max_speed
		)

		PhysicsHandler.set_body_velocity(boid_body_rids[i], new_velocity)

		var new_transform = PhysicsHandler.apply_velocity(current_transform, new_velocity, delta)
		new_transform.origin = PhysicsHandler.apply_bounds_wrap(new_transform.origin, bounds)

		PhysicsHandler.set_body_transform(boid_body_rids[i], new_transform)
		MeshHandler.set_transform(multimesh_rid, i, new_transform)


func initialize_boids() -> void:
	boid_body_rids.clear()
	boid_shape_rids.clear()
	rid_to_index.clear()

	for i in range(visible_instance_count):
		var random_position = PhysicsHandler.generate_random_position(bounds)

		MeshHandler.set_transform(multimesh_rid, i, Transform3D().translated(random_position))

		var random_velocity = PhysicsHandler.generate_random_velocity(max_speed)

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

		PhysicsHandler.set_body_velocity(body_data["body_rid"], random_velocity)


func _exit_tree() -> void:
	for i in range(boid_body_rids.size()):
		PhysicsHandler.destroy_boid_body(boid_body_rids[i], boid_shape_rids[i])

	MeshHandler.destroy_multimesh(multimesh_rid, instance_rid)
