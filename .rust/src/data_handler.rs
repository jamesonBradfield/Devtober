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
        let count = 1000;
        let visible_count = 1000;
        let max_speed = 10.0;

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
        }
    }

    fn ready(&mut self) {
        self.setup_multimesh();
        godot_print!("BoidHandler is ready!");
    }

    fn process(&mut self, _delta: f64) {
        self.update_multimesh_transforms();
    }
}

#[godot_api]
impl BoidHandler {
    fn setup_multimesh(&mut self) {
        let mut rs = RenderingServer::singleton();

        self.multimesh = rs.multimesh_create();

        rs.multimesh_set_mesh(self.multimesh, self.create_boid_mesh());

        rs.multimesh_allocate_data(
            self.multimesh,
            self.visible_count,
            MultimeshTransformFormat::TRANSFORM_3D,
        );

        self.multimesh_instance = rs.instance_create();
        rs.instance_set_base(self.multimesh_instance, self.multimesh);

        let scenario = self
            .base()
            .get_world_3d()
            .expect("Failed to get World3D")
            .get_scenario();
        rs.instance_set_scenario(self.multimesh_instance, scenario);

        rs.instance_set_visible(self.multimesh_instance, true);
    }

    fn create_boid_mesh(&self) -> Rid {
        let mut rs = RenderingServer::singleton();
        let mesh = rs.mesh_create();

        let vertices = PackedVector3Array::from(&[
            Vector3::new(0.0, 0.0, 1.0),
            Vector3::new(-0.3, 0.0, -0.5),
            Vector3::new(0.3, 0.0, -0.5),
            Vector3::new(0.0, 0.3, 0.0),
        ]);

        let indices = PackedInt32Array::from(&[0, 1, 2, 0, 2, 3, 0, 3, 1, 1, 3, 2]);

        let mut arrays = Array::new();
        let array_max = godot::classes::mesh::ArrayType::MAX.ord() as usize;

        for _ in 0..array_max {
            arrays.push(&Variant::nil());
        }

        let vertex_idx = godot::classes::mesh::ArrayType::VERTEX.ord() as usize;
        let index_idx = godot::classes::mesh::ArrayType::INDEX.ord() as usize;

        arrays.set(vertex_idx, &vertices.to_variant());
        arrays.set(index_idx, &indices.to_variant());

        rs.mesh_add_surface_from_arrays(
            mesh,
            godot::classes::rendering_server::PrimitiveType::TRIANGLES,
            &arrays,
        );

        mesh
    }

    fn update_multimesh_transforms(&mut self) {
        let mut buffer = PackedFloat32Array::new();
        buffer.resize((self.visible_count * 12) as usize);

        for i in 0..self.visible_count as usize {
            let pos = self.positions[i];
            let vel = self.velocities[i];

            let forward = vel.normalized();
            let right = Vector3::UP.cross(forward).normalized();
            let up = forward.cross(right);

            let base_idx = i * 12;

            buffer[base_idx] = right.x;
            buffer[base_idx + 1] = right.y;
            buffer[base_idx + 2] = right.z;
            buffer[base_idx + 3] = pos.x;

            buffer[base_idx + 4] = up.x;
            buffer[base_idx + 5] = up.y;
            buffer[base_idx + 6] = up.z;
            buffer[base_idx + 7] = pos.y;

            buffer[base_idx + 8] = forward.x;
            buffer[base_idx + 9] = forward.y;
            buffer[base_idx + 10] = forward.z;
            buffer[base_idx + 11] = pos.z;
        }

        RenderingServer::singleton().multimesh_set_buffer(self.multimesh, &buffer);
    }
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
