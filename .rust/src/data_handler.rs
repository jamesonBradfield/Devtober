use crate::{bvh_node::BVHNode, rand_vector::RandomVectorExt};
use godot::{
    builtin::Aabb,
    classes::{
        base_material_3d::{Flags, ShadingMode, Transparency},
        mesh::PrimitiveType,
        rendering_server::MultimeshTransformFormat,
        ArrayMesh, ImmediateMesh, Material, Mesh, MeshInstance3D, Node, Node3D, RenderingServer,
        StandardMaterial3D,
    },
    prelude::*,
};
use rand::prelude::*;
use rayon::prelude::*;

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
    #[export]
    debug_bvh: bool,
    #[export]
    debug_bvh_max_depth: i32,

    root: BVHNode,

    // Structure of Arrays - direction-only optimization
    positions: Vec<Vector3>,
    directions: Vec<Vector3>, // Always normalized unit vectors

    multimesh: Option<Rid>,
    _multimesh_instance: Option<Rid>,
    _boid_mesh: Option<Gd<ArrayMesh>>,
    debug_mesh: Option<Gd<ImmediateMesh>>,
    debug_instance: Option<Gd<MeshInstance3D>>,
}

#[godot_api]
impl INode3D for BoidHandler {
    fn init(base: Base<Node3D>) -> Self {
        Self {
            base,
            simulation_bounds: Vector3::ZERO,
            count: 0,
            visible_count: 0,
            alignment_weight: 0.0,
            cohesion_weight: 0.0,
            separation_weight: 0.0,
            alignment_range: 0.0,
            cohesion_range: 0.0,
            separation_range: 0.0,
            max_speed: 0.0,
            seed: 0,
            debug_bvh: false,
            debug_bvh_max_depth: 0,
            positions: vec![],
            directions: vec![],
            root: BVHNode::default(),
            multimesh: None,
            _multimesh_instance: None,
            _boid_mesh: None,
            debug_mesh: None,
            debug_instance: None,
        }
    }

    fn ready(&mut self) {
        let Ok(mesh) = try_load::<ArrayMesh>("res://Meshes/boid.obj") else {
            godot_warn!("Failed to load boid mesh");
            return;
        };
        self._boid_mesh = Some(mesh);

        self.setup_multimesh();
        self.setup_debug_wireframe();

        if self.visible_count > 0 && self.simulation_bounds != Vector3::ZERO {
            self.regenerate();
        }
    }

    fn process(&mut self, delta: f64) {
        if self.positions.is_empty() || self.multimesh.is_none() {
            return;
        }

        self.rebuild_bvh();
        self.update_boids(delta as f32);
        self.render_boids();

        if self.debug_bvh {
            self.render_debug_bvh();
        }
    }
}

#[godot_api]
impl BoidHandler {
    fn setup_multimesh(&mut self) {
        if self.visible_count <= 0 {
            godot_warn!("visible_count must be greater than 0");
            return;
        }

        let Some(world) = self.base().get_world_3d() else {
            godot_warn!("Failed to get world_3d");
            return;
        };

        let Some(mesh) = &self._boid_mesh else {
            godot_warn!("Boid mesh not loaded yet");
            return;
        };

        if !mesh.is_instance_valid() {
            godot_warn!("Mesh instance is not valid");
            return;
        }

        if mesh.get_surface_count() == 0 {
            godot_warn!("Mesh has no surfaces");
            return;
        }

        let mut rs = RenderingServer::singleton();
        let multimesh = rs.multimesh_create();

        rs.multimesh_set_mesh(multimesh, mesh.get_rid());
        rs.multimesh_allocate_data(
            multimesh,
            self.visible_count,
            MultimeshTransformFormat::TRANSFORM_3D,
        );

        let instance = rs.instance_create();
        rs.instance_set_scenario(instance, world.get_scenario());
        rs.instance_set_base(instance, multimesh);
        rs.instance_set_visible(instance, true);

        self.multimesh = Some(multimesh);
        self._multimesh_instance = Some(instance);
    }

    fn setup_debug_wireframe(&mut self) {
        let immediate_mesh = ImmediateMesh::new_gd();
        let mut material = StandardMaterial3D::new_gd();

        material.set_shading_mode(ShadingMode::UNSHADED);
        material.set_transparency(Transparency::ALPHA);
        material.set_flag(Flags::DISABLE_DEPTH_TEST, true);
        material.set_flag(Flags::ALBEDO_FROM_VERTEX_COLOR, true);

        let mut mesh_instance = MeshInstance3D::new_alloc();
        mesh_instance.set_mesh(&immediate_mesh.clone().upcast::<Mesh>());
        mesh_instance.set_material_override(&material.upcast::<Material>());
        self.base_mut()
            .add_child(&mesh_instance.clone().upcast::<Node>());

        self.debug_mesh = Some(immediate_mesh);
        self.debug_instance = Some(mesh_instance);
    }

    fn rebuild_bvh(&mut self) {
        self.root.left = None;
        self.root.right = None;
        self.root.children = (0..self.positions.len()).collect();
        self.root.build_recursive(&self.positions, 0, 10, 4);
    }

    fn update_boids(&mut self, delta: f32) {
        // Extract thread-safe references
        let positions_ref = &self.positions;
        let directions_ref = &self.directions;
        let root_ref = &self.root;
        let sep_range = self.separation_range;
        let ali_range = self.alignment_range;
        let coh_range = self.cohesion_range;
        let sep_weight = self.separation_weight;
        let ali_weight = self.alignment_weight;
        let coh_weight = self.cohesion_weight;
        let max_speed = self.max_speed;

        let steering_forces: Vec<_> = (0..self.positions.len())
            .into_par_iter()
            .map(|i| {
                let pos = positions_ref[i];
                let dir = directions_ref[i];

                let max_range = sep_range.max(ali_range).max(coh_range);
                let mut all_neighbors = Vec::new();
                root_ref.query_range(positions_ref, pos, max_range, &mut all_neighbors);
                all_neighbors.retain(|&idx| idx != i);

                let sep_range_sq = sep_range * sep_range;
                let ali_range_sq = ali_range * ali_range;
                let coh_range_sq = coh_range * coh_range;

                let mut separation = Vector3::ZERO;
                let mut alignment = Vector3::ZERO;
                let mut cohesion = Vector3::ZERO;
                let (mut ali_count, mut coh_count) = (0, 0);

                for &neighbor_idx in &all_neighbors {
                    let neighbor_pos = positions_ref[neighbor_idx];
                    let dist_sq = pos.distance_squared_to(neighbor_pos);

                    // Separation: avoid close neighbors
                    if dist_sq <= sep_range_sq && dist_sq > 0.001 * 0.001 {
                        let diff = pos - neighbor_pos;
                        let dist = dist_sq.sqrt();
                        let weight = (sep_range - dist) / dist;
                        separation += diff.normalized() * weight;
                    }

                    // Alignment: steer toward average direction of nearby boids
                    if dist_sq <= ali_range_sq {
                        alignment += directions_ref[neighbor_idx];
                        ali_count += 1;
                    }

                    // Cohesion: steer toward average position of nearby boids
                    if dist_sq <= coh_range_sq {
                        cohesion += neighbor_pos;
                        coh_count += 1;
                    }
                }

                if ali_count > 0 {
                    // Alignment: steer toward average direction
                    let avg_dir = alignment / ali_count as f32;
                    alignment = avg_dir - dir;
                }

                if coh_count > 0 {
                    cohesion = cohesion / coh_count as f32 - pos;
                }

                separation * sep_weight + alignment * ali_weight + cohesion * coh_weight
            })
            .collect();

        // Apply steering forces and update positions
        for i in 0..self.positions.len() {
            // Calculate new velocity from current direction
            let current_vel = self.directions[i] * max_speed;
            let new_vel = current_vel + steering_forces[i] * delta;

            // Normalize to get new direction (simpler than speed clamping!)
            let speed = new_vel.length();
            if speed > 0.001 {
                self.directions[i] = new_vel / speed;
            }

            // Move at constant max speed
            self.positions[i] += self.directions[i] * max_speed * delta;

            // Wrap around bounds
            let bounds = self.simulation_bounds;
            if self.positions[i].x > bounds.x {
                self.positions[i].x = -bounds.x;
            } else if self.positions[i].x < -bounds.x {
                self.positions[i].x = bounds.x;
            }

            if self.positions[i].y > bounds.y {
                self.positions[i].y = -bounds.y;
            } else if self.positions[i].y < -bounds.y {
                self.positions[i].y = bounds.y;
            }

            if self.positions[i].z > bounds.z {
                self.positions[i].z = -bounds.z;
            } else if self.positions[i].z < -bounds.z {
                self.positions[i].z = bounds.z;
            }
        }
    }

    fn render_boids(&mut self) {
        let Some(multimesh) = self.multimesh else {
            return;
        };

        if self.positions.is_empty() {
            return;
        }

        let mut rs = RenderingServer::singleton();
        let count = self.positions.len().min(self.visible_count as usize);

        rs.multimesh_set_visible_instances(multimesh, count as i32);

        // Build transforms on-the-fly from position and direction
        for i in 0..count {
            let mut transform = Transform3D {
                basis: Basis::IDENTITY,
                origin: self.positions[i],
            };

            // Orient boid to face forward along its direction
            if self.directions[i].length() > 0.001 {
                let forward = self.directions[i].normalized();
                let right = Vector3::UP.cross(forward).normalized();
                let up = forward.cross(right).normalized();
                transform.basis = Basis::from_cols(right, up, forward);
            }

            rs.multimesh_instance_set_transform(multimesh, i as i32, transform);
        }
    }

    #[allow(dead_code)]
    fn render_debug_bvh(&mut self) {
        let Some(mesh) = &mut self.debug_mesh else {
            return;
        };
        mesh.clear_surfaces();
        mesh.surface_begin(PrimitiveType::LINES);
        self.root
            .render_debug_wireframe(mesh, 0, self.debug_bvh_max_depth as usize);
        mesh.surface_end();
    }

    #[func]
    pub fn regenerate(&mut self) {
        self.root.bounds = Aabb {
            position: self.base().get_position() - self.simulation_bounds / 2.0,
            size: self.simulation_bounds,
        };

        let mut rng = StdRng::seed_from_u64(self.seed as u64);

        // Clear arrays
        self.positions.clear();
        self.directions.clear();

        // Generate boids with random positions and directions
        for _ in 0..self.visible_count {
            let pos = rng.random_vector(1, -self.simulation_bounds, self.simulation_bounds)[0];
            let dir = rng.random_vector_from_float(1, -1.0, 1.0)[0].normalized();

            self.positions.push(pos);
            self.directions.push(dir);
        }
    }

    #[func]
    pub fn toggle_debug_bvh(&mut self) {
        self.debug_bvh = !self.debug_bvh;

        if let Some(instance) = &mut self.debug_instance {
            instance.set_visible(self.debug_bvh);
        }

        if !self.debug_bvh {
            if let Some(mesh) = &mut self.debug_mesh {
                mesh.clear_surfaces();
            }
        }
    }
}
