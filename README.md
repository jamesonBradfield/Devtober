Post Mortem
A later version of our OctTreeTestProject using rust and our RenderServer, the other project finalized the architecture, this scaled it up and used the RenderServer...
sadly using the godot gitignore ignored our rust..
The Rust implementation (GDExtension) for this OctTree was unfortunately lost during a system migration, but the video below demonstrates the performance achieved (100k boids at 60fps).

Watch the 100k Boids Demonstration
Lessons Learned & Architecture Decisions

    Architecture > Language: The language used doesn't matter nearly as much as the memory architecture. Flat arrays and direct UID/RID interactions with Godot's PhysicsServer and RenderingServer are the closest you can get to the metal, bypassing the overhead of the standard Node tree.

    The Godot-Rust "Sweet Spot": Rust is phenomenal for offloading heavy computational loops. However, it becomes a bottleneck if you try to deeply integrate with or replicate the engine's internal data structures (e.g., trying to set up an in-engine BVH is not worth the friction).

    Array-Backed Linked Lists: Transitioned away from traditional object-oriented collections (like C#'s List<T>) to pure index-based linked lists. By packing the node logic into just two integers (count and index) inside a flat array, and sorting the boid array every rebuild, sibling entities were kept perfectly contiguous in memory, eliminating pointer-chasing and cache misses.

    Prevented Boundary Thrashing (Loose Margins): Designed the OctTree with boundary overlap ("empty space") and a MaxElementCount per node. This allowed octants to dynamically and greedily encompass entire flocks, preventing the expensive CPU overhead of constantly re-assigning boids that hover on strict mathematical borders.

    Data-Oriented Design & Cache Locality: Achieved 100k boids by leveraging rayon for data-parallel multithreading over the flat arrays. Furthermore, implemented implicit AABBs—calculating bounds dynamically on the fly via integer math (Vector3i) from a single RootAABB rather than storing floats per-node. Combined with a coarse/fine grid where only leaf nodes handle positions, this drastically minimized the memory footprint and maximized CPU L1/L2 cache locality.
