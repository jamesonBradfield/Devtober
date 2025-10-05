class_name UIHandler


func connect_signals(data_handler: DataHandler):
	var spawner = data_handler.get_parent().get_node("UI").get_node("TabContainer/Spawner/Spawner")
	var x_bounds_slider = spawner.get_node("x_bounds_slider")
	var y_bounds_slider = spawner.get_node("y_bounds_slider")
	var z_bounds_slider = spawner.get_node("z_bounds_slider")
	var instance_count_slider = spawner.get_node("instance_count_slider")
	var visible_instance_count_slider = spawner.get_node("visible_instance_count_slider")
	x_bounds_slider.value = data_handler.x_bounds
	y_bounds_slider.value = data_handler.y_bounds
	z_bounds_slider.value = data_handler.z_bounds
	instance_count_slider.value = data_handler.instance_count
	visible_instance_count_slider.value = data_handler.visible_instance_count
