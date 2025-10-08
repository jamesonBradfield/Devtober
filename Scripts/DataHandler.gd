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
var velocity_array: PackedVector3Array
var bvh_root: BVHNode
var position_array: PackedVector3Array
var frames_since_bvh_rebuild: int = 0

@export var boid_mesh: Mesh
@export var bvh_rebuild_interval: int = 3
@export var instance_count: int = 1000
@export var boid_collision_radius: float = 0.5
@export var visible_instance_count: int = 1000
@export var bounds: Vector3 = Vector3(100.0, 100.0, 100.0)
@export var max_speed: float = 5.0
@export var use_bvh: bool = true
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
		var neighbors: PackedInt32Array = []

		if use_bvh:
			var search_bounds: AABB = AABB()
			search_bounds.size = Vector3(
				max_perception_radius, max_perception_radius, max_perception_radius
			)
			search_bounds.position = position_array[index]
			if bvh_root != null:
				neighbors = query_bvh_neighbors(index, search_bounds)
			else:
				print("bvh_root is null when trying to query_bvh_neighbors!!")
		else:
			neighbor_query.transform = Transform3D(Basis.IDENTITY, position_array[index])
			neighbor_query.exclude = [boid_body_rids[index]]
			var results = PhysicsServer3D.space_get_direct_state(space_rid).intersect_shape(
				neighbor_query
			)

			for dict in results:
				if !rid_to_index.has(dict["rid"]):
					continue
				neighbors.append(rid_to_index[dict["rid"]])

		var neighbor_velocities: PackedVector3Array = []
		for neighbor_index in neighbors:
			neighbor_velocities.append(velocity_array[neighbor_index])

		var separation_force = calculate_separation(
			position_array[index], position_array, neighbors, separation_weight
		)

		var cohesion_force = calculate_cohesion(
			position_array[index], position_array, neighbors, cohesion_weight
		)

		var alignment_force = calculate_alignment(
			velocity_array[index], neighbor_velocities, alignment_weight
		)

		var acceleration = separation_force + cohesion_force + alignment_force
		velocity_array[index] = (
			velocity_array[index] + (acceleration * delta)
			if velocity_array[index].length() <= max_speed
			else velocity_array[index].normalized() * max_speed
		)

		position_array[index] = position_array[index] + velocity_array[index] * delta

		var half_bounds = bounds / 2.0
		var wrapped_position = position_array[index]

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

		position_array[index] = wrapped_position

		if !use_bvh:
			PhysicsServer3D.body_set_state(
				boid_body_rids[index], PhysicsServer3D.BODY_STATE_TRANSFORM, position_array[index]
			)


# TODO: FIX THIS MESS OF CONVERSIONS PLEASE!!!!
static func calculate_separation(
	boid_position: Vector3, positions: PackedVector3Array, neighbors: Array[int], weight: float
) -> Vector3:
	var steering = Vector3.ZERO
	var count = 0

	for neighbor_index in neighbors:
		var distance = boid_position.distance_to(positions[neighbor_index])

		if distance > 0:
			var diff = boid_position - positions[neighbor_index]
			diff = diff.normalized() / distance
			steering += diff
			count += 1

	if count > 0:
		steering /= count
		return steering.normalized() * weight

	return Vector3.ZERO


static func calculate_cohesion(
	boid_position: Vector3, positions: PackedVector3Array, neighbors: Array[int], weight: float
) -> Vector3:
	var center_of_mass = Vector3.ZERO
	var count = 0

	for neighbor_index in neighbors:
		center_of_mass += positions[neighbor_index]
		count += 1

	if count > 0:
		center_of_mass /= count
		var desired_direction = (center_of_mass - boid_position).normalized()
		return desired_direction * weight

	return Vector3.ZERO


static func calculate_alignment(
	boid_velocity: Vector3, neighbor_velocities: PackedVector3Array, weight: float
) -> Vector3:
	var count = neighbor_velocities.size()

	if count == 0:
		return Vector3.ZERO

	var average_velocity = Vector3.ZERO
	for velocity in neighbor_velocities:
		average_velocity += velocity

	average_velocity /= count
	return (average_velocity - boid_velocity).normalized() * weight


func _process(_delta: float) -> void:
	if use_bvh:
		frames_since_bvh_rebuild += 1
		if frames_since_bvh_rebuild >= bvh_rebuild_interval:
			rebuild_bvh()
			frames_since_bvh_rebuild = 0

	var buffer: PackedFloat32Array
	buffer.resize(visible_instance_count * 12)

	for index in range(visible_instance_count):
		var offset = index * 12
		var _basis = basis
		var _origin = position_array[index]

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


func rebuild_bvh() -> void:
	if bvh_root != null:
		bvh_root.ClearRecursive()

	position_array.clear()
	position_array.resize(visible_instance_count)

	for index in range(visible_instance_count):
		position_array[index] = position_array[index]

	bvh_root = bvh_root.BuildBVH(position_array)


func query_bvh_neighbors(exclude_index: int, search_bounds: AABB) -> PackedInt32Array:
	var neighbors: PackedInt32Array = []

	if bvh_root == null:
		return neighbors

	bvh_root.QueryRecursive(search_bounds, exclude_index)
	return neighbors


func initialize_boids() -> void:
	boid_body_rids.clear()
	boid_shape_rids.clear()
	rid_to_index.clear()
	bvh_root = BVHNode.new()
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

		if !use_bvh:
			var body_rid = PhysicsServer3D.body_create()
			PhysicsServer3D.body_set_mode(body_rid, PhysicsServer3D.BODY_MODE_KINEMATIC)
			PhysicsServer3D.body_set_space(body_rid, space_rid)

			var shape_rid = PhysicsServer3D.sphere_shape_create()
			PhysicsServer3D.shape_set_data(shape_rid, boid_collision_radius)
			PhysicsServer3D.body_add_shape(body_rid, shape_rid)

			var _transform = Transform3D(Basis.IDENTITY, random_position)
			PhysicsServer3D.body_set_state(
				body_rid, PhysicsServer3D.BODY_STATE_TRANSFORM, _transform
			)
			PhysicsServer3D.body_set_collision_mask(body_rid, BOID_COLLISION_MASK)
			PhysicsServer3D.body_set_collision_layer(body_rid, BOID_COLLISION_LAYER)

			boid_body_rids.append(body_rid)
			boid_shape_rids.append(shape_rid)
			rid_to_index[body_rid] = index

		position_array.append(random_position)
		velocity_array.append(random_velocity)

	if use_bvh:
		rebuild_bvh()
		frames_since_bvh_rebuild = 0


func _exit_tree() -> void:
	if bvh_root != null:
		bvh_root.ClearRecursive()
		bvh_root = null

	for i in range(boid_body_rids.size()):
		PhysicsServer3D.free_rid(boid_body_rids[i])
		PhysicsServer3D.free_rid(boid_shape_rids[i])

	RenderingServer.free_rid(instance_rid)
	RenderingServer.free_rid(multimesh_rid)
