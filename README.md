## Architecture & Lessons Learned (Multi-Mesh Branch)

This branch contains a specific iteration of the Mass Rendering system, relying on Godot's `RenderingServer` and a custom Rust-based BVH to achieve high entity counts.

* **Data-Oriented Design (SoA):** Entities are not objects. Boid data is stripped down to parallel Structure of Arrays (`positions: Vec<Vector3>` and `directions: Vec<Vector3>`). This ensures contiguous memory blocks that are highly cache-friendly.
* **Multithreaded Steering via Rayon:** Because the boid data is flat and decoupled from Godot's Node tree, we leverage the `rayon` crate (`into_par_iter()`) to calculate Separation, Alignment, and Cohesion forces across all available CPU cores simultaneously.
* **Custom BVH Spatial Partitioning:** To prevent $O(n^2)$ distance checks, the system builds a Bounding Volume Hierarchy (`bvh_node.rs`) every frame. The BVH dynamically computes explicit `Aabb` bounds and partitions boids along the longest spatial axis, drastically culling the number of neighbors checked during steering calculations.
* **Direct RenderingServer Access:** We bypass the SceneTree bottleneck. The system allocates data directly in Godot's `RenderingServer` using `MultimeshTransformFormat::TRANSFORM_3D` and syncs the Rust position vectors directly to the GPU memory.
  * *(Note: `mass_render.rs` includes the highly optimized `draw_transforms_batched` method which packs floats into a single 1D buffer, avoiding the overhead of looped transform updates).*
