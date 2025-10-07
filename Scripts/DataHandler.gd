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

var velocity_array: Array[Vector3]

var all_transforms: Array[Transform3D] = []

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


func _physics_process(delta: float) -> void:
	for index in range(visible_instance_count):
		neighbor_query.transform = Transform3D(Basis.IDENTITY, all_transforms[index].origin)
		neighbor_query.exclude = [boid_body_rids[index]]

		var results = PhysicsServer3D.space_get_direct_state(space_rid).intersect_shape(
			neighbor_query
		)

		var neighbors: Array[int] = []
		for dict in results:
			if !rid_to_index.has(dict["rid"]):
				continue
			neighbors.append(rid_to_index[dict["rid"]])

		var neighbor_velocities: Array[Vector3] = []
		for neighbor_index in neighbors:
			neighbor_velocities.append(velocity_array[neighbor_index])

		var separation_force = BoidHandler.calculate_separation(
			all_transforms[index].origin,
			all_transforms,
			neighbors,
			separation_perception_radius,
			separation_weight
		)

		var cohesion_force = BoidHandler.calculate_cohesion(
			all_transforms[index].origin,
			all_transforms,
			neighbors,
			cohesion_perception_radius,
			cohesion_weight
		)

		var alignment_force = BoidHandler.calculate_alignment(
			velocity_array[index],
			neighbor_velocities,
			alignment_perception_radius,
			alignment_weight
		)

		var acceleration = separation_force + cohesion_force + alignment_force

		velocity_array[index] = (
			velocity_array[index] + (acceleration * delta)
			if velocity_array[index].length() > max_speed
			else velocity_array[index].normalized() * max_speed
		)

		all_transforms[index].origin = all_transforms[index].origin + velocity_array[index] * delta

		var half_bounds = bounds / 2.0
		var wrapped_position = all_transforms[index].origin

		if wrapped_position.x > half_bounds.x:
			wrapped_position.x = -half_bounds.x
		elif wrapped_position.x < -half_bounds.x:
			wrapped_position.x = half_bounds.x

		if wrapped_position.y > half_bounds.y:
			wrapped_position.y = -half_bounds.y
		elif wrapped_position.y < -half_bounds.y:
			wrapped_position.y = half_bounds.y

		if wrapped_position.z > half_bounds.z:
			wrapped_position.z = -half_bounds.z
		elif wrapped_position.z < -half_bounds.z:
			wrapped_position.z = half_bounds.z

		all_transforms[index].origin = wrapped_position
		PhysicsServer3D.body_set_state(
			boid_body_rids[index], PhysicsServer3D.BODY_STATE_TRANSFORM, all_transforms[index]
		)


func _process(delta: float) -> void:
	var buffer: PackedFloat32Array
	buffer.resize(visible_instance_count * 12)

	for index in range(visible_instance_count):
		var offset = index * 12
		var _basis = all_transforms[index].basis
		var _origin = all_transforms[index].origin

		buffer[offset + 0] = _basis.x.x
		buffer[offset + 1] = _basis.y.x
		buffer[offset + 2] = _basis.z.x
		buffer[offset + 3] = _origin.x
		buffer[offset + 4] = _basis.x.y
		buffer[offset + 5] = _basis.y.y
		buffer[offset + 6] = _basis.z.y
		buffer[offset + 7] = _origin.y
		buffer[offset + 8] = _basis.x.z
		buffer[offset + 9] = _basis.y.z
		buffer[offset + 10] = _basis.z.z
		buffer[offset + 11] = _origin.z

		RenderingServer.multimesh_set_buffer(multimesh_rid, buffer)


func initialize_boids() -> void:
	boid_body_rids.clear()
	boid_shape_rids.clear()
	rid_to_index.clear()

	for index in range(visible_instance_count):
		var random_position = Vector3(
			randf() * bounds.x - (bounds.x / 2.0),
			randf() * bounds.y - (bounds.y / 2.0),
			randf() * bounds.z - (bounds.z / 2.0)
		)

		RenderingServer.multimesh_instance_set_transform(
			multimesh_rid, index, Transform3D().translated(random_position)
		)
		var random_velocity = Vector3(
			randf_range(-max_speed, max_speed),
			randf_range(-max_speed, max_speed),
			randf_range(-max_speed, max_speed)
		)

		# create boid physics body in PhysicsServer
		var body_rid = PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(body_rid, PhysicsServer3D.BODY_MODE_KINEMATIC)
		PhysicsServer3D.body_set_space(body_rid, space_rid)

		var shape_rid = PhysicsServer3D.sphere_shape_create()
		PhysicsServer3D.shape_set_data(shape_rid, boid_collision_radius)
		PhysicsServer3D.body_add_shape(body_rid, shape_rid)

		var _transform = Transform3D(Basis.IDENTITY, random_position)
		PhysicsServer3D.body_set_state(body_rid, PhysicsServer3D.BODY_STATE_TRANSFORM, _transform)
		all_transforms.append(_transform)
		boid_body_rids.append(body_rid)
		boid_shape_rids.append(shape_rid)
		rid_to_index[body_rid] = index
		velocity_array.append(random_velocity)


func _exit_tree() -> void:
	for i in range(boid_body_rids.size()):
		PhysicsServer3D.free_rid(boid_body_rids[i])
		PhysicsServer3D.free_rid(boid_shape_rids[i])

	RenderingServer.free_rid(instance_rid)
	RenderingServer.free_rid(multimesh_rid)
