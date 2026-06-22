//! Application root.
//!
//! This module provides the root component, routing configuration,
//! and the server-side rendering (SSR) shell for the application.

use leptos::prelude::*;

/// Renders the full HTML document shell for server-side rendering (SSR).
///
/// It wraps the application in the outer HTML structure
/// and injects the scripts required for WebAssembly hydration on the client.
///
/// # Feature flags
///
/// Only compiled when the `ssr` feature is enabled.
#[cfg(feature = "ssr")]
pub fn shell(options: LeptosOptions) -> impl IntoView {
    view! {}
}

/// Root application component.
///
/// It initializes the meta context required for modyfing the document's head,
/// mounts the router, and declares all top-level routes.
#[component]
pub fn App() -> impl IntoView {
    view! {}
}
