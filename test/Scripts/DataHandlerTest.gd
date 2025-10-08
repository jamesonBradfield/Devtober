extends GdUnitTestSuite

var data_handler: DataHandler
var scene_root: Node3D
var test_world: World3D

const TEST_INSTANCE_COUNT = 100
const SAMPLE_SIZE = 20


func before() -> void:
	scene_root = auto_free(Node3D.new())
	test_world = World3D.new()

	data_handler = auto_free(DataHandler.new())
	data_handler.instance_count = TEST_INSTANCE_COUNT
	data_handler.visible_instance_count = TEST_INSTANCE_COUNT
	data_handler.use_bvh = true
	data_handler.cache_neighbors = false
	data_handler.bvh_rebuild_interval = 3
	data_handler.bounds = Vector3(50, 50, 50)

	scene_root.add_child(data_handler)

	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.5, 0.5, 0.5)
	data_handler.boid_mesh = mesh

	add_child(scene_root)
	await get_tree().process_frame
	await get_tree().process_frame


func after() -> void:
	if data_handler:
		data_handler.queue_free()
	if scene_root:
		scene_root.queue_free()


func test_bvh_returns_same_neighbors_as_physics() -> void:
	setup_physics_bodies()
	data_handler.rebuild_bvh()

	var mismatches = 0
	var samples = get_sample_indices(SAMPLE_SIZE)

	for boid_index in samples:
		var bvh_neighbors = query_bvh(boid_index)
		var physics_neighbors = query_physics(boid_index)

		var bvh_set = array_to_set(bvh_neighbors)
		var physics_set = array_to_set(physics_neighbors)

		if !sets_equal(bvh_set, physics_set):
			mismatches += 1
			var missed = get_set_difference(physics_set, bvh_set)
			var false_positives = get_set_difference(bvh_set, physics_set)

			print(
				(
					"Boid %d: BVH=%d Physics=%d Missed=%d FalsePos=%d"
					% [
						boid_index,
						bvh_neighbors.size(),
						physics_neighbors.size(),
						missed.size(),
						false_positives.size()
					]
				)
			)

	var accuracy = float(SAMPLE_SIZE - mismatches) / SAMPLE_SIZE * 100.0
	print(
		"BVH accuracy: %.1f%% (%d/%d matches)" % [accuracy, SAMPLE_SIZE - mismatches, SAMPLE_SIZE]
	)

	assert_that(mismatches).is_equal(0)


func test_bvh_excludes_self() -> void:
	data_handler.rebuild_bvh()

	var samples = get_sample_indices(10)
	for boid_index in samples:
		var neighbors = query_bvh(boid_index)
		assert_that(neighbors.has(boid_index)).is_false()


func test_bvh_respects_perception_radius() -> void:
	data_handler.rebuild_bvh()

	var test_index = 0
	var test_pos = data_handler.position_array[test_index]
	var neighbors = query_bvh(test_index)

	for neighbor_index in neighbors:
		var neighbor_pos = data_handler.position_array[neighbor_index]
		var distance = test_pos.distance_to(neighbor_pos)
		assert_that(distance).is_less_equal(data_handler.max_perception_radius)


func test_bvh_rebuild_maintains_accuracy() -> void:
	setup_physics_bodies()
	data_handler.rebuild_bvh()

	var first_pass = query_bvh(0)

	move_boids_randomly()
	update_physics_positions()
	data_handler.rebuild_bvh()

	var second_pass_bvh = query_bvh(0)
	var second_pass_physics = query_physics(0)

	var bvh_set = array_to_set(second_pass_bvh)
	var physics_set = array_to_set(second_pass_physics)

	assert_that(sets_equal(bvh_set, physics_set)).is_true()


func test_neighbor_cache_accuracy() -> void:
	setup_physics_bodies()
	data_handler.cache_neighbors = true
	data_handler.rebuild_bvh()

	var test_index = 5
	var cached = data_handler.neighbor_cache[test_index]
	var fresh = query_bvh(test_index)

	assert_that(arrays_equal(cached, fresh)).is_true()


func test_bvh_performance_versus_physics() -> void:
	setup_physics_bodies()
	data_handler.rebuild_bvh()

	var bvh_total_time = 0.0
	var physics_total_time = 0.0
	var iterations = 50

	for _i in range(iterations):
		var test_index = randi() % data_handler.visible_instance_count

		var bvh_start = Time.get_ticks_usec()
		var _bvh_result = query_bvh(test_index)
		bvh_total_time += Time.get_ticks_usec() - bvh_start

		var physics_start = Time.get_ticks_usec()
		var _physics_result = query_physics(test_index)
		physics_total_time += Time.get_ticks_usec() - physics_start

	var bvh_avg = bvh_total_time / iterations
	var physics_avg = physics_total_time / iterations
	var speedup = physics_avg / bvh_avg

	print(
		"BVH avg: %.2f Âµs, Physics avg: %.2f Âµs, Speedup: %.2fx" % [bvh_avg, physics_avg, speedup]
	)

	assert_that(bvh_avg).is_less(physics_avg)


func test_empty_bvh_returns_no_neighbors() -> void:
	var empty_handler = auto_free(DataHandler.new())
	empty_handler.instance_count = 1
	empty_handler.visible_instance_count = 1
	empty_handler.use_bvh = true
	empty_handler.boid_mesh = BoxMesh.new()

	scene_root.add_child(empty_handler)
	await get_tree().process_frame

	empty_handler.rebuild_bvh()

	var half_radius = empty_handler.max_perception_radius
	var search_bounds = AABB(
		empty_handler.position_array[0] - Vector3(half_radius, half_radius, half_radius),
		Vector3(half_radius * 2, half_radius * 2, half_radius * 2)
	)

	var neighbors = empty_handler.query_bvh_neighbors(0, search_bounds)
	assert_that(neighbors.size()).is_equal(0)


func query_bvh(boid_index: int) -> PackedInt32Array:
	var half_radius = data_handler.max_perception_radius
	var search_bounds = AABB(
		data_handler.position_array[boid_index] - Vector3(half_radius, half_radius, half_radius),
		Vector3(half_radius * 2, half_radius * 2, half_radius * 2)
	)
	return data_handler.query_bvh_neighbors(boid_index, search_bounds)


func query_physics(boid_index: int) -> PackedInt32Array:
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = data_handler.max_perception_radius
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, data_handler.position_array[boid_index])
	query.collision_mask = data_handler.BOID_COLLISION_MASK

	if boid_index < data_handler.boid_body_rids.size():
		query.exclude = [data_handler.boid_body_rids[boid_index]]

	var results = PhysicsServer3D.space_get_direct_state(data_handler.space_rid).intersect_shape(
		query
	)

	var neighbors: PackedInt32Array = []
	for dict in results:
		if data_handler.rid_to_index.has(dict["rid"]):
			neighbors.append(data_handler.rid_to_index[dict["rid"]])

	return neighbors


func setup_physics_bodies() -> void:
	data_handler.use_bvh = false
	data_handler.initialize_boids()
	await get_tree().physics_frame
	data_handler.use_bvh = true


func update_physics_positions() -> void:
	for i in range(data_handler.visible_instance_count):
		PhysicsServer3D.body_set_state(
			data_handler.boid_body_rids[i],
			PhysicsServer3D.BODY_STATE_TRANSFORM,
			Transform3D(Basis.IDENTITY, data_handler.position_array[i])
		)
	await get_tree().physics_frame


func move_boids_randomly() -> void:
	for i in range(data_handler.visible_instance_count):
		var offset = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
		data_handler.position_array[i] += offset


func get_sample_indices(count: int) -> Array[int]:
	var indices: Array[int] = []
	var actual_count = mini(count, data_handler.visible_instance_count)

	for i in range(actual_count):
		indices.append(i)

	return indices


func array_to_set(arr: PackedInt32Array) -> Dictionary:
	var result = {}
	for item in arr:
		result[item] = true
	return result


func sets_equal(set_a: Dictionary, set_b: Dictionary) -> bool:
	if set_a.size() != set_b.size():
		return false

	for key in set_a.keys():
		if !set_b.has(key):
			return false

	return true


func get_set_difference(set_a: Dictionary, set_b: Dictionary) -> Array:
	var diff = []
	for key in set_a.keys():
		if !set_b.has(key):
			diff.append(key)
	return diff


func arrays_equal(arr_a: PackedInt32Array, arr_b: PackedInt32Array) -> bool:
	return sets_equal(array_to_set(arr_a), array_to_set(arr_b))
