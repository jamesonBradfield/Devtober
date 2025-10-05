# MeshHandler.gd
class_name MeshHandler


## Creates multimesh and instance on the rendering server
static func create_multimesh(mesh: Mesh, instance_count: int, world_scenario: RID) -> Dictionary:
	var multimesh_rid = RenderingServer.multimesh_create()
	RenderingServer.multimesh_allocate_data(
		multimesh_rid, instance_count, RenderingServer.MULTIMESH_TRANSFORM_3D, false
	)
	RenderingServer.multimesh_set_mesh(multimesh_rid, mesh.get_rid())
	var instance_rid = RenderingServer.instance_create()
	RenderingServer.instance_set_base(instance_rid, multimesh_rid)
	RenderingServer.instance_set_scenario(instance_rid, world_scenario)

	return {"multimesh_rid": multimesh_rid, "instance_rid": instance_rid}


## Updates visible instance count on the rendering server
static func set_visible_instance_count(multimesh_rid: RID, count: int) -> void:
	RenderingServer.multimesh_set_visible_instances(multimesh_rid, count)


## Gets transform for a specific instance
static func get_transform(multimesh_rid: RID, index: int) -> Transform3D:
	return RenderingServer.multimesh_instance_get_transform(multimesh_rid, index)


## Sets transform for a specific instance
static func set_transform(multimesh_rid: RID, index: int, transform: Transform3D) -> void:
	RenderingServer.multimesh_instance_set_transform(multimesh_rid, index, transform)


## Gets all transforms efficiently
static func get_all_transforms(multimesh_rid: RID, count: int) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	transforms.resize(count)

	for i in range(count):
		transforms[i] = RenderingServer.multimesh_instance_get_transform(multimesh_rid, i)

	return transforms


## Cleans up rendering server resources
static func destroy_multimesh(multimesh_rid: RID, instance_rid: RID) -> void:
	RenderingServer.free_rid(instance_rid)
	RenderingServer.free_rid(multimesh_rid)
