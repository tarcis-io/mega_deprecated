//! Shared application library and module registry.
//!
//! This module is compiled into both the server binary for Server-Side Rendering (SSR)
//! and the WebAssembly (WASM) client.
//!
//! It declares all primary top-level modules
//! and, when compiled for WASM, provides the entry point to hydrate the client application.

pub mod app;

include!(concat!(env!("OUT_DIR"), "/i18n/mod.rs"));

/// The main entry point for the WebAssembly client bundle.
///
/// It installs the panic hook, initializes tracing, and hydrates the Leptos application
/// by attaching client-side reactivity and event listeners to the static HTML previously rendered by the server.
///
/// # Feature flags
///
/// Only compiled when the target architecture is `wasm32`
/// and the `hydrate` feature is enabled.
#[cfg(all(target_arch = "wasm32", feature = "hydrate"))]
#[wasm_bindgen::prelude::wasm_bindgen]
pub fn hydrate() {
    use app::App;
    use console_error_panic_hook::set_once;
    use leptos::mount::hydrate_body;
    use tracing_wasm::set_as_global_default;

    set_once();
    set_as_global_default();

    hydrate_body(App);
}
