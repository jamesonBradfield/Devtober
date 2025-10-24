use crate::{mass_render::MassRenderingNode, rand_vector::RandomVectorExt};
use godot::classes::ArrayMesh;
use godot::classes::Node3D;
use godot::prelude::*;
use rand::rngs::StdRng;
use rand::SeedableRng;
//TODO: migrate from Vector3 to transform3D
#[derive(GodotClass)]
#[class(base=Node3D)]
pub struct DumbEnemy {
    base: Base<Node3D>,
    #[export]
    speed: f32,
    #[export]
    target: Option<Gd<Node3D>>,
    #[export]
    count: i32,
    #[export]
    visible_count: i32,
    #[export]
    render_node_path: NodePath,
    #[var]
    render_node: OnReady<Gd<MassRenderingNode>>,
    positions: Vec<Transform3D>,
    #[export]
    boid_mesh: Option<Gd<ArrayMesh>>,
    #[export]
    seed: i64,
}

#[godot_api]
impl INode3D for DumbEnemy {
    fn init(base: Base<Node3D>) -> Self {
        Self {
            base,
            render_node: OnReady::manual(),
            render_node_path: NodePath::default(),
            seed: 0,
            speed: 0.0,
            target: None,
            count: 0,
            visible_count: 0,
            positions: vec![],
            boid_mesh: None,
        }
    }

    fn ready(&mut self) {
        let node = self
            .base()
            .get_node_as::<MassRenderingNode>(&self.render_node_path);
        self.render_node.init(node);

        self.render_node.bind_mut().set_mesh(self.boid_mesh.clone());
        self.render_node.bind_mut().set_visible_count(self.count);
        let mut rng = StdRng::seed_from_u64(self.seed as u64);
        let positions_random = rng.random_vector_from_float(self.count, -500.0, 500.0);
        self.positions = (0..self.count)
            .map(|i| Transform3D {
                origin: positions_random[i as usize],
                basis: Basis::IDENTITY,
            })
            .collect();

        self.render_node.bind_mut().setup_multimesh();
    }

    fn process(&mut self, _delta: f64) {
        let target = self
            .target
            .as_ref()
            .map(|t| t.get_transform().origin)
            .unwrap_or_default();
        let speed_delta = self.speed * _delta as f32;

        for i in 0..self.count as usize {
            let pos = self.positions[i];
            let direction = target - pos.origin;

            if direction.length_squared() > 0.001 {
                self.positions[i] = Transform3D {
                    origin: pos.origin + direction.normalized() * speed_delta,
                    basis: Basis::IDENTITY,
                };
            }
        }

        self.render_node
            .bind_mut()
            .draw_transforms_batched(self.positions.clone());
    }
}
