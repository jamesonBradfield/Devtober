# PhysicsHandler.gd
class_name PhysicsHandler


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
