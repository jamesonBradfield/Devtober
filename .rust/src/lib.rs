use godot::prelude::*;

mod bvh_node;
mod data_handler;
mod nav_agent;
mod rand_vector;
mod rendering;

struct MyExtension;

#[gdextension]
unsafe impl ExtensionLibrary for MyExtension {}
