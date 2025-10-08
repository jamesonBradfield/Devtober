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
