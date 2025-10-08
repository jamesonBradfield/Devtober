class_name BVHNodeOld

var bounds: AABB
var left: BVHNode
var right: BVHNode
var indices: PackedInt32Array  # Store indices instead of positions


func _init():
	pass


static func create_leaf(_indices: PackedInt32Array) -> BVHNode:
	var new_instance = BVHNode.new()
	new_instance.indices = _indices
	return new_instance


static func create_internal(_bounds, _left, _right) -> BVHNode:
	var new_instance = BVHNode.new()
	new_instance.bounds = _bounds
	new_instance.left = _left
	new_instance.right = _right
	return new_instance


func BuildBVH(positions: PackedVector3Array) -> BVHNode:
	var _indices: PackedInt32Array
	_indices.resize(positions.size())
	for i in range(positions.size()):
		_indices[i] = i

	return BuildBVHRecursive(positions, _indices)


func BuildBVHRecursive(positions: PackedVector3Array, _indices: PackedInt32Array) -> BVHNode:
	if _indices.size() <= 5:
		return create_leaf(_indices)

	bounds = ComputeBoundingBox(positions, _indices)
	var axis = ChooseSplitAxis(bounds)
	var split_point = CalculateSplitPoint(positions, _indices, axis)

	var left_indices: PackedInt32Array
	var right_indices: PackedInt32Array

	for idx in _indices:
		if positions[idx][axis] < split_point[axis]:
			left_indices.append(idx)
		else:
			right_indices.append(idx)

	if left_indices.size() == 0:
		left_indices.append(_indices[0])
		right_indices.resize(right_indices.size() - 1)

	if right_indices.size() == 0:
		right_indices.append(_indices[_indices.size() - 1])
		left_indices.resize(left_indices.size() - 1)

	var left_child = BuildBVHRecursive(positions, left_indices)
	var right_child = BuildBVHRecursive(positions, right_indices)

	return create_internal(bounds, left_child, right_child)


func ComputeBoundingBox(positions: PackedVector3Array, _indices: PackedInt32Array) -> AABB:
	if _indices.size() == 0:
		return AABB()

	var result = AABB(positions[_indices[0]], Vector3.ZERO)

	for idx in _indices:
		result = result.expand(positions[idx])

	return result


func ChooseSplitAxis(_bounds: AABB) -> int:
	var size = _bounds.size

	if size.x >= size.y and size.x >= size.z:
		return 0

	if size.y >= size.z:
		return 1

	return 2


func CalculateSplitPoint(
	positions: PackedVector3Array, _indices: PackedInt32Array, axis: int
) -> Vector3:
	if _indices.size() == 0:
		return Vector3.ZERO

	var sum = 0.0
	for idx in _indices:
		sum += positions[idx][axis]

	var median = sum / _indices.size()
	var split_point = Vector3.ZERO
	split_point[axis] = median

	return split_point


func ClearRecursive():
	indices.clear()
	if left == null and right == null:
		return
	left.ClearRecursive()
	right.ClearRecursive()
	left = null
	right = null


func QueryRecursive(
	positions: PackedVector3Array, _check_bounds: AABB, exclude_index: int, result: PackedInt32Array
) -> void:
	if left == null and right == null:
		for idx in indices:
			if idx != exclude_index and _check_bounds.has_point(positions[idx]):
				result.append(idx)
		return

	if !bounds.intersects(_check_bounds):
		return

	left.QueryRecursive(positions, _check_bounds, exclude_index, result)
	right.QueryRecursive(positions, _check_bounds, exclude_index, result)
