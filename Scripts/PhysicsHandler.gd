# PhysicsHandler.gd
class_name PhysicsHandler


static func get_body_velocity(body_rid: RID) -> Vector3:
	return PhysicsServer3D.body_get_state(body_rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY)


static func set_body_velocity(body_rid: RID, velocity: Vector3) -> void:
	PhysicsServer3D.body_set_state(body_rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, velocity)


static func get_body_transform(body_rid: RID) -> Transform3D:
	return PhysicsServer3D.body_get_state(body_rid, PhysicsServer3D.BODY_STATE_TRANSFORM)


static func set_body_transform(body_rid: RID, transform: Transform3D) -> void:
	PhysicsServer3D.body_set_state(body_rid, PhysicsServer3D.BODY_STATE_TRANSFORM, transform)


static func update_velocity(
	current_velocity: Vector3, acceleration: Vector3, delta: float, max_speed: float
) -> Vector3:
	var new_velocity = current_velocity + (acceleration * delta)

	if new_velocity.length() > max_speed:
		return new_velocity.normalized() * max_speed

	return new_velocity


static func apply_velocity(transform: Transform3D, velocity: Vector3, delta: float) -> Transform3D:
	var new_transform = transform
	new_transform.origin += velocity * delta
	return new_transform


static func apply_bounds_wrap(position: Vector3, bounds: Vector3) -> Vector3:
	var half_bounds = bounds / 2.0
	var wrapped_position = position

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

	return wrapped_position


static func apply_bounds_bounce(velocity: Vector3, position: Vector3, bounds: Vector3) -> Vector3:
	var half_bounds = bounds / 2.0
	var new_velocity = velocity

	if abs(position.x) > half_bounds.x:
		new_velocity.x = -new_velocity.x

	if abs(position.y) > half_bounds.y:
		new_velocity.y = -new_velocity.y

	if abs(position.z) > half_bounds.z:
		new_velocity.z = -new_velocity.z

	return new_velocity


static func generate_random_position(bounds: Vector3) -> Vector3:
	return Vector3(
		randf() * bounds.x - (bounds.x / 2.0),
		randf() * bounds.y - (bounds.y / 2.0),
		randf() * bounds.z - (bounds.z / 2.0)
	)


static func generate_random_velocity(max_speed: float) -> Vector3:
	return Vector3(
		randf_range(-max_speed, max_speed),
		randf_range(-max_speed, max_speed),
		randf_range(-max_speed, max_speed)
	)


static func create_boid_body(
	space_rid: RID, position: Vector3, radius: float, collision_layer: int, collision_mask: int
) -> Dictionary:
	var body_rid = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(body_rid, PhysicsServer3D.BODY_MODE_RIGID)
	PhysicsServer3D.body_set_space(body_rid, space_rid)
	PhysicsServer3D.body_set_param(body_rid, PhysicsServer3D.BODY_PARAM_GRAVITY_SCALE, 0.0)

	var shape_rid = PhysicsServer3D.sphere_shape_create()
	PhysicsServer3D.shape_set_data(shape_rid, radius)
	PhysicsServer3D.body_add_shape(body_rid, shape_rid)

	var transform = Transform3D(Basis.IDENTITY, position)
	PhysicsServer3D.body_set_state(body_rid, PhysicsServer3D.BODY_STATE_TRANSFORM, transform)

	PhysicsServer3D.body_set_collision_layer(body_rid, collision_layer)
	PhysicsServer3D.body_set_collision_mask(body_rid, collision_mask)

	return {"body_rid": body_rid, "shape_rid": shape_rid}


static func update_boid_body_position(body_rid: RID, position: Vector3) -> void:
	var transform = Transform3D(Basis.IDENTITY, position)
	PhysicsServer3D.body_set_state(body_rid, PhysicsServer3D.BODY_STATE_TRANSFORM, transform)


static func find_neighbors_physics(
	space_rid: RID, position: Vector3, radius: float, exclude_rid: RID, collision_mask: int
) -> Array[RID]:
	var query = PhysicsShapeQueryParameters3D.new()

	var shape = SphereShape3D.new()
	shape.radius = radius
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, position)
	query.collision_mask = collision_mask
	query.exclude = [exclude_rid]

	var results = PhysicsServer3D.space_get_direct_state(space_rid).intersect_shape(query)

	var neighbor_rids: Array[RID] = []
	for result in results:
		neighbor_rids.append(result["rid"])

	return neighbor_rids


static func find_neighbors_with_query(
	space_rid: RID, query: PhysicsShapeQueryParameters3D, position: Vector3, exclude_rid: RID
) -> Array[RID]:
	query.transform = Transform3D(Basis.IDENTITY, position)
	query.exclude = [exclude_rid]

	var results = PhysicsServer3D.space_get_direct_state(space_rid).intersect_shape(query)

	var neighbor_rids: Array[RID] = []
	for result in results:
		neighbor_rids.append(result["rid"])

	return neighbor_rids


static func destroy_boid_body(body_rid: RID, shape_rid: RID) -> void:
	PhysicsServer3D.free_rid(body_rid)
	PhysicsServer3D.free_rid(shape_rid)
