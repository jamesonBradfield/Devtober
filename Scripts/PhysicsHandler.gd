# PhysicsHandler.gd
class_name PhysicsHandler


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
