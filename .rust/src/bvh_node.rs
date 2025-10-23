use godot::{builtin::Aabb, classes::ImmediateMesh, prelude::*};

pub struct BVHNode {
    pub bounds: Aabb,
    pub left: Option<Box<BVHNode>>,
    pub right: Option<Box<BVHNode>>,
    pub children: Vec<usize>,
}

impl Default for BVHNode {
    fn default() -> Self {
        Self {
            bounds: Aabb {
                position: Vector3::ZERO,
                size: Vector3::ZERO,
            },
            left: None,
            right: None,
            children: vec![],
        }
    }
}

impl BVHNode {
    fn compute_bounds(positions: &[Vector3], indices: &[usize]) -> Aabb {
        if indices.is_empty() {
            return Aabb {
                position: Vector3::ZERO,
                size: Vector3::ZERO,
            };
        }

        let first = positions[indices[0]];
        let (mut min, mut max) = (first, first);

        for &idx in indices.iter().skip(1) {
            let pos = positions[idx];
            min.x = min.x.min(pos.x);
            min.y = min.y.min(pos.y);
            min.z = min.z.min(pos.z);
            max.x = max.x.max(pos.x);
            max.y = max.y.max(pos.y);
            max.z = max.z.max(pos.z);
        }

        Aabb {
            position: min,
            size: max - min,
        }
    }

    pub fn build_recursive(
        &mut self,
        positions: &[Vector3],
        depth: usize,
        max_depth: usize,
        min_boids: usize,
    ) {
        if depth >= max_depth || self.children.len() <= min_boids {
            return;
        }

        self.bounds = Self::compute_bounds(positions, &self.children);

        let size = self.bounds.size;
        let axis = if size.x >= size.y && size.x >= size.z {
            Vector3Axis::X
        } else if size.y >= size.z {
            Vector3Axis::Y
        } else {
            Vector3Axis::Z
        };

        let midpoint = self.bounds.position + size / 2.0;
        let split = match axis {
            Vector3Axis::X => midpoint.x,
            Vector3Axis::Y => midpoint.y,
            Vector3Axis::Z => midpoint.z,
        };

        let (left_indices, right_indices): (Vec<_>, Vec<_>) =
            self.children.drain(..).partition(|&idx| {
                let pos = positions[idx];
                match axis {
                    Vector3Axis::X => pos.x < split,
                    Vector3Axis::Y => pos.y < split,
                    Vector3Axis::Z => pos.z < split,
                }
            });

        if left_indices.is_empty() || right_indices.is_empty() {
            self.children = left_indices.into_iter().chain(right_indices).collect();
            return;
        }

        self.left = Some(Box::new(BVHNode {
            bounds: Self::compute_bounds(positions, &left_indices),
            left: None,
            right: None,
            children: left_indices,
        }));

        self.right = Some(Box::new(BVHNode {
            bounds: Self::compute_bounds(positions, &right_indices),
            left: None,
            right: None,
            children: right_indices,
        }));

        if let Some(ref mut left) = self.left {
            left.build_recursive(positions, depth + 1, max_depth, min_boids);
        }
        if let Some(ref mut right) = self.right {
            right.build_recursive(positions, depth + 1, max_depth, min_boids);
        }
    }

    fn aabb_intersects_sphere(aabb: &Aabb, center: Vector3, radius: f32) -> bool {
        let min = aabb.position;
        let max = aabb.position + aabb.size;
        let closest = Vector3::new(
            center.x.clamp(min.x, max.x),
            center.y.clamp(min.y, max.y),
            center.z.clamp(min.z, max.z),
        );
        center.distance_squared_to(closest) <= radius * radius
    }

    pub fn query_range(
        &self,
        positions: &[Vector3],
        pos: Vector3,
        radius: f32,
        results: &mut Vec<usize>,
    ) {
        if !Self::aabb_intersects_sphere(&self.bounds, pos, radius) {
            return;
        }

        for &idx in &self.children {
            if pos.distance_squared_to(positions[idx]) <= radius * radius {
                results.push(idx);
            }
        }

        if let Some(ref left) = self.left {
            left.query_range(positions, pos, radius, results);
        }
        if let Some(ref right) = self.right {
            right.query_range(positions, pos, radius, results);
        }
    }

    #[allow(dead_code)]
    pub fn render_debug_wireframe(
        &self,
        mesh: &mut Gd<ImmediateMesh>,
        depth: usize,
        max_depth: usize,
    ) {
        if depth > max_depth {
            return;
        }

        let color = Color::from_hsv((depth as f64 * 0.15) % 1.0, 0.8, 0.9);
        self.draw_aabb(mesh, color);

        if let Some(ref left) = self.left {
            left.render_debug_wireframe(mesh, depth + 1, max_depth);
        }
        if let Some(ref right) = self.right {
            right.render_debug_wireframe(mesh, depth + 1, max_depth);
        }
    }

    #[allow(dead_code)]
    fn draw_aabb(&self, mesh: &mut Gd<ImmediateMesh>, color: Color) {
        let min = self.bounds.position;
        let max = min + self.bounds.size;

        let corners = [
            Vector3::new(min.x, min.y, min.z),
            Vector3::new(max.x, min.y, min.z),
            Vector3::new(max.x, max.y, min.z),
            Vector3::new(min.x, max.y, min.z),
            Vector3::new(min.x, min.y, max.z),
            Vector3::new(max.x, min.y, max.z),
            Vector3::new(max.x, max.y, max.z),
            Vector3::new(min.x, max.y, max.z),
        ];

        let edges = [
            (0, 1),
            (1, 2),
            (2, 3),
            (3, 0),
            (4, 5),
            (5, 6),
            (6, 7),
            (7, 4),
            (0, 4),
            (1, 5),
            (2, 6),
            (3, 7),
        ];

        for (start, end) in edges {
            mesh.surface_set_color(color);
            mesh.surface_add_vertex(corners[start]);
            mesh.surface_set_color(color);
            mesh.surface_add_vertex(corners[end]);
        }
    }
}
