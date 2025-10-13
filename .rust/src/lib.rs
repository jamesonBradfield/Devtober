use godot::prelude::*;

mod data_handler;
mod bvh_node;

struct MyExtension;

#[gdextension]
unsafe impl ExtensionLibrary for MyExtension {}
