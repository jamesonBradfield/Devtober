use godot::prelude::*;
use rand::prelude::*;

pub trait RandomVectorExt {
    fn random_vector(&mut self, num: i32, min: Vector3, max: Vector3) -> Vec<Vector3>;
    fn random_vector_from_float(&mut self, num: i32, min: f32, max: f32) -> Vec<Vector3>;
}

impl RandomVectorExt for StdRng {
    fn random_vector(&mut self, num: i32, min: Vector3, max: Vector3) -> Vec<Vector3> {
        (0..num)
            .map(|_| {
                Vector3::new(
                    self.random_range(min.x..max.x),
                    self.random_range(min.y..max.y),
                    self.random_range(min.z..max.z),
                )
            })
            .collect()
    }

    fn random_vector_from_float(&mut self, num: i32, min: f32, max: f32) -> Vec<Vector3> {
        (0..num)
            .map(|_| {
                Vector3::new(
                    self.random_range(min..max),
                    self.random_range(min..max),
                    self.random_range(min..max),
                )
            })
            .collect()
    }
}
