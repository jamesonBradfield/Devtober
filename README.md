## Post Mortem: The Journey to 100k

**THE RUST IS NOT LOST!!! See the `multi-mesh` branch.**

Watch the 100k Boids Demonstration:
* Early Implementation: https://www.youtube.com/watch?v=NAF7I6-K-Vo
* Last Documented Implementation (100k at 60fps): https://youtu.be/MLxljNBpJ9o

### Lessons Learned & Architecture Decisions

* **The C# OctTree Origins:** Early iterations of this project utilized C# and explored highly experimental memory architectures, such as pure index-based flat array OctTrees. By packing node logic into integers and sorting arrays, it attempted to eliminate pointer-chasing and cache misses. While clever, this approach ultimately fell short of the 100,000 instance goal.
* **The Pivot to Rust:** To push past the CPU bottleneck, the core simulation logic was transitioned to a Rust GDExtension. This allowed the project to leverage the `rayon` crate for massive data-parallel multithreading, calculating boid steering forces (Separation, Alignment, Cohesion) across all available CPU cores simultaneously on flat `Vec<Vector3>` arrays.
* **Navigating `godot-rust`:** The transition required ditching some of the "greener pasture" index-based ideas in favor of memory-safe Rust paradigms. The spatial partitioning system was rebuilt into a safe Bounding Volume Hierarchy (BVH) using standard heap allocations (`Box`) and explicit Godot `Aabb` types. It proved that writing safe, idiomatic Rust was still fast enough to shatter the performance ceiling.
* **Direct Server Access (Bypassing the SceneTree):** The language used doesn't matter nearly as much as how you talk to the engine. Standard Godot Node trees carry too much overhead for massive simulations. The 100k milestone was achieved by treating entities as pure data and directly feeding a raw, row-major `PackedFloat32Array` of transforms to the `RenderingServer` in a single batched buffer update.
