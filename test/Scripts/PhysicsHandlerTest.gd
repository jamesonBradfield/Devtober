extends GdUnitTestSuite

var position_fuzzer_min: Vector3 = Vector3(-999, -999, -999)
var position_fuzzer_max: Vector3 = Vector3(999, 999, 999)
var speed_fuzzer: float = 999


#NOTE: these don't take into account any size for our positions generated.
func test_generate_random_position(
	fuzzer_a := Fuzzers.rangev3(position_fuzzer_min, position_fuzzer_max), fuzzer_iterations = 1000
):
	var random_position = PhysicsHandler.generate_random_position(fuzzer_a.next_value())
	assert_vector(random_position).is_between(position_fuzzer_min, position_fuzzer_max)


func test_generate_random_velocity(
	fuzzer_a := Fuzzers.rangef(-speed_fuzzer, speed_fuzzer), fuzzer_iterations = 1000
):
	var random_velocity = PhysicsHandler.generate_random_velocity(fuzzer_a.next_value())
	assert_vector(random_velocity).is_between(
		Vector3(-speed_fuzzer, -speed_fuzzer, -speed_fuzzer),
		Vector3(speed_fuzzer, speed_fuzzer, speed_fuzzer)
	)


#TODO: implement the test cases.
func test_apply_velocity():
	pass


func test_update_velocity():
	pass
