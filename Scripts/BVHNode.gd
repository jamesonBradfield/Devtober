class_name BVHNode

var bounds: AABB
var left: BVHNode
var right: BVHNode
var objects: PackedVector3Array


func _init():
	pass


static func create_leaf(_objects) -> BVHNode:
	var new_instance = BVHNode.new()
	new_instance.objects = _objects
	return new_instance


static func create_internal(_bounds, _left, _right) -> BVHNode:
	var new_instance = BVHNode.new()
	new_instance.bounds = _bounds
	new_instance.left = _left
	new_instance.right = _right
	return new_instance


## Recursively builds a BVH tree from the given objects
func BuildBVH(_objects: PackedVector3Array) -> BVHNode:
	if _objects.size() <= 5:
		return create_leaf(_objects)

	bounds = ComputeBoundingBox(_objects)
	var axis = ChooseSplitAxis(bounds)
	var split_point = CalculateSplitPoint(_objects, axis)

	var left_objects = PackedVector3Array()
	var right_objects = PackedVector3Array()

	for object in _objects:
		if object[axis] < split_point[axis]:
			left_objects.append(object)
		else:
			right_objects.append(object)

	if left_objects.size() == 0:
		left_objects.append(_objects[0])
		right_objects.resize(right_objects.size() - 1)

	if right_objects.size() == 0:
		right_objects.append(_objects[_objects.size() - 1])
		left_objects.resize(left_objects.size() - 1)

	var left_child = BuildBVH(left_objects)
	var right_child = BuildBVH(right_objects)

	return create_internal(bounds, left_child, right_child)


## Computes the axis-aligned bounding box containing all objects
func ComputeBoundingBox(_objects: PackedVector3Array) -> AABB:
	if _objects.size() == 0:
		return AABB()

	var result = AABB(_objects[0], Vector3.ZERO)

	for object in _objects:
		result = result.expand(object)

	return result


## Selects the axis with the largest extent for splitting
func ChooseSplitAxis(_bounds: AABB) -> int:
	var size = _bounds.size

	if size.x >= size.y and size.x >= size.z:
		return 0

	if size.y >= size.z:
		return 1

	return 2


## Calculates the split point as the median along the specified axis
func CalculateSplitPoint(_objects: PackedVector3Array, axis: int) -> Vector3:
	if _objects.size() == 0:
		return Vector3.ZERO

	var sum = 0.0
	for object in _objects:
		sum += object[axis]

	var median = sum / _objects.size()
	var split_point = Vector3.ZERO
	split_point[axis] = median

	return split_point


func ClearRecursive():
	objects.clear()
	if left == null and right == null:
		return
	left.ClearRecursive()
	right.ClearRecursive()
	left = null
	right = null


func QueryRecursive(
	_check_bounds: AABB,
	exclude_index: int,
) -> PackedInt32Array:
	var neighbors: PackedInt32Array
	if left == null and right == null:
		for i in range(objects.size()):
			if _check_bounds.has_point(objects[i]) and i != exclude_index:
				neighbors.append(i)
		return neighbors

	if !bounds.intersects(_check_bounds):
		return neighbors

	neighbors.append_array(left.QueryRecursive(_check_bounds, exclude_index))
	neighbors.append_array(right.QueryRecursive(_check_bounds, exclude_index))
	return neighbors
