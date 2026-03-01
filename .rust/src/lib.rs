use godot::prelude::*;

mod bvh_node;
mod data_handler;
mod mass_render;
mod nav_agent;
mod rand_vector;

#[cfg(feature = "profiling")]
static TRACY_CLIENT: std::sync::OnceLock<tracing_tracy::client::Client> =
    std::sync::OnceLock::new();

struct BoidsExtension;

#[gdextension]
unsafe impl ExtensionLibrary for BoidsExtension {
    fn on_level_init(_level: InitLevel) {
        #[cfg(feature = "profiling")]
        {
            use std::sync::Once;
            use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
            use tracing_tracy::{client::Client, TracyLayer};

            // Only initialize during the Scene level to avoid editor startup noise
            if _level == InitLevel::Scene && !godot::classes::Engine::singleton().is_editor_hint() {
                godot_print!("Tracy Profiling: INITIALIZED");

                static START: Once = Once::new();
                START.call_once(|| {
                    // Start Tracy manually
                    let client = Client::start();
                    let _ = TRACY_CLIENT.set(client);

                    // Install the Tracy layer
                    let _ = tracing_subscriber::registry()
                        .with(TracyLayer::default())
                        .try_init();
                });
            }
        }
    }

    fn on_level_deinit(_level: InitLevel) {
        #[cfg(feature = "profiling")]
        {
            if _level == InitLevel::Scene && !godot::classes::Engine::singleton().is_editor_hint() {
                godot_print!("Tracy Profiling: SHUTTING DOWN");
                // Explicitly kill Tracy's threads to release the Windows file lock!
                unsafe {
                    tracing_tracy::client::sys::___tracy_shutdown_profiler();
                }
            }
        }
    }
}
