Architecture & Lessons Learned (Multi-Mesh Branch)

This branch represents the 100k-entity milestone, achieved by moving the core simulation into a Rust GDExtension. This iteration focuses on high-concurrency spatial partitioning and direct communication with Godot’s low-level servers.
1. Data-Oriented Design (SoA)

To maximize CPU cache locality, entities are treated as pure data rather than Objects or Nodes. Boid state is managed in a Structure of Arrays (SoA) format (positions: Vec<Vector3>, directions: Vec<Vector3>). This ensures that during heavy steering calculations, the CPU is pulling contiguous blocks of memory, drastically reducing cache misses compared to a standard Node-based approach.
2. High-Concurrency Steering via Rayon

By decoupling the data from the SceneTree, we leverage the rayon crate to perform data-parallel multithreading. Steering forces (Separation, Alignment, and Cohesion) are calculated across all available CPU cores simultaneously using into_par_iter().

    The Multithreading Trade-off: To maintain a lock-free, blazing-fast pipeline, I accepted a minor architectural trade-off: boids processed on separate threads may occasionally fail to query a neighbor's state at thread boundaries. In a 100,000-entity swarm, these micro-inaccuracies are invisible to the viewer, but the performance gain is the difference between a slideshow and a fluid simulation.

3. Custom Spatial Partitioning (BVH)

To bypass the O(n2) complexity of neighbor lookups, the system rebuilds a Bounding Volume Hierarchy (BVH) every frame.

    Unlike the experimental "index-only" OctTree from previous C# iterations, this Rust implementation utilizes a safe, tree-based BVH (bvh_node.rs) that partitions boids along the longest spatial axis.

    This culls thousands of unnecessary distance checks per boid, allowing the simulation to scale to massive counts even on modest hardware.

4. Direct RenderingServer Integration

The "SceneTree bottleneck" is eliminated by communicating directly with Godot’s RenderingServer.

    We utilize MultimeshTransformFormat::TRANSFORM_3D to allocate instance data directly on the GPU.

    Optimized Batching: Instead of updating transforms individually (which incurs high overhead), mass_render.rs implements draw_transforms_batched. This method packs all 100k transforms into a single 1D PackedFloat32Array and ships the entire buffer to the GPU in one massive operation via rs.multimesh_set_buffer().

5. Performance Benchmark

    Target Hardware: Athlon 3000GE (2-Core / 4-Thread Budget APU).

    Performance: ~25 FPS at 100,000 entities.

    Significance: This benchmark proves that through aggressive memory management and direct server access, high-fidelity simulations can be made viable even on entry-level, low-thread-count hardware.
