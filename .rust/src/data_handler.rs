use godot::classes::rendering_server::MultimeshTransformFormat;
use godot::classes::{Node3D, RenderingServer};
use godot::prelude::*;
use rand::prelude::*;

trait RandomVectorExt {
    fn random_vector(&mut self, num: i32, min: Vector3, max: Vector3) -> Vec<Vector3>;
    fn random_vector_from_float(&mut self, num: i32, min: f32, max: f32) -> Vec<Vector3>;
}

impl RandomVectorExt for StdRng {
    fn random_vector(&mut self, num: i32, min: Vector3, max: Vector3) -> Vec<Vector3> {
        (0..num)
            .map(|_| Vector3 {
                x: self.random_range(min.x..max.x),
                y: self.random_range(min.y..max.y),
                z: self.random_range(min.z..max.z),
            })
            .collect()
    }

    fn random_vector_from_float(&mut self, num: i32, min: f32, max: f32) -> Vec<Vector3> {
        (0..num)
            .map(|_| Vector3 {
                x: self.random_range(min..max),
                y: self.random_range(min..max),
                z: self.random_range(min..max),
            })
            .collect()
    }
}
#[derive(GodotClass)]
#[class(base=Node3D)]
pub struct BoidHandler {
    base: Base<Node3D>,

    #[export]
    simulation_bounds: Vector3,

    #[export]
    count: i32,

    #[export]
    visible_count: i32,

    #[export]
    alignment_weight: f32,

    #[export]
    cohesion_weight: f32,

    #[export]
    separation_weight: f32,

    #[export]
    alignment_range: f32,

    #[export]
    cohesion_range: f32,

    #[export]
    separation_range: f32,

    #[export]
    max_speed: f32,

    #[export]
    seed: i64,

    positions: Vec<Vector3>,
    velocities: Vec<Vector3>,
    multimesh_instance: Rid,
    multimesh: Rid,
    transform_buffer: PackedFloat32Array,
}

#[godot_api]
impl INode3D for BoidHandler {
    fn init(base: Base<Node3D>) -> Self {
        let seed: i64 = 12345;
        let mut rng = StdRng::seed_from_u64(seed as u64);
        // Create local variables first
        let simulation_bounds = Vector3 {
            x: 100.0,
            y: 100.0,
            z: 100.0,
        };
        let count = 999;
        let visible_count = 999;
        let max_speed = 10.0;
        let mut transform_buffer = PackedFloat32Array::new();
        transform_buffer.resize((visible_count * 12) as usize);
        // Now use them to construct the struct
        Self {
            base,
            max_speed,
            simulation_bounds,
            count,
            visible_count,
            seed,
            positions: rng.random_vector(visible_count, -simulation_bounds, simulation_bounds),
            velocities: rng.random_vector_from_float(visible_count, -max_speed, max_speed),
            alignment_weight: 1.0,
            cohesion_weight: 1.0,
            separation_weight: 1.0,
            alignment_range: 10.0,
            cohesion_range: 10.0,
            separation_range: 10.0,
            multimesh_instance: Rid::Invalid,
            multimesh: Rid::Invalid,
            transform_buffer,
        }
    }

    fn ready(&mut self) {}

    fn process(&mut self, _delta: f64) {}
}

#[godot_api]
impl BoidHandler {
    #[func]
    pub fn regenerate_with_seed(&mut self, new_seed: i64) {
        self.seed = new_seed;
        let mut rng = StdRng::seed_from_u64(new_seed as u64);
        self.positions = rng.random_vector(
            self.visible_count,
            -self.simulation_bounds,
            self.simulation_bounds,
        );
        self.velocities =
            rng.random_vector_from_float(self.visible_count, -self.max_speed, self.max_speed);
    }
    #[func]
    pub fn regenerate(&mut self) {
        self.regenerate_with_seed(self.seed);
    }
}
