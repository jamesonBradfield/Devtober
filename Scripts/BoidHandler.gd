# BoidHandler.gd
class_name BoidHandler


static func calculate_separation(
	boid_position: Vector3,
	all_transforms: Array[Transform3D],
	neighbors: Array[int],
	radius: float,
	weight: float
) -> Vector3:
	var steering = Vector3.ZERO
	var count = 0

	for neighbor_index in neighbors:
		var neighbor_position = all_transforms[neighbor_index].origin
		var distance = boid_position.distance_to(neighbor_position)

		if distance < radius and distance > 0:
			var diff = boid_position - neighbor_position
			diff = diff.normalized() / distance
			steering += diff
			count += 1

	if count > 0:
		steering /= count
		return steering.normalized() * weight

	return Vector3.ZERO


static func calculate_cohesion(
	boid_position: Vector3,
	all_transforms: Array[Transform3D],
	neighbors: Array[int],
	radius: float,
	weight: float
) -> Vector3:
	var center_of_mass = Vector3.ZERO
	var count = 0

	for neighbor_index in neighbors:
		var neighbor_position = all_transforms[neighbor_index].origin
		var distance = boid_position.distance_to(neighbor_position)

		if distance < radius:
			center_of_mass += neighbor_position
			count += 1

	if count > 0:
		center_of_mass /= count
		var desired_direction = (center_of_mass - boid_position).normalized()
		return desired_direction * weight

	return Vector3.ZERO


static func calculate_alignment(
	boid_velocity: Vector3, neighbor_velocities: Array[Vector3], radius: float, weight: float
) -> Vector3:
	var count = neighbor_velocities.size()

	if count == 0:
		return Vector3.ZERO

	var average_velocity = Vector3.ZERO
	for velocity in neighbor_velocities:
		average_velocity += velocity

	average_velocity /= count
	return (average_velocity - boid_velocity).normalized() * weight
