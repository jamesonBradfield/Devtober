use godot::prelude::*;

mod bvh_node;
mod data_handler;
mod mass_render;
mod nav_agent;
mod rand_vector;

struct MyExtension;

#[gdextension]
unsafe impl ExtensionLibrary for MyExtension {}
