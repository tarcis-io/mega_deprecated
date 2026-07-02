//! Application root.
//!
//! This module provides the root component, routing configuration,
//! and the server-side rendering (SSR) shell for the application.

use leptos::prelude::*;
use leptos_meta::{Meta, Title, provide_meta_context};
use leptos_router::{
    components::{FlatRoutes, Route, Router},
    path,
};

use crate::components::UIShell;
use crate::features::{Home, NotFound};

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
    use leptos_meta::MetaTags;

    view! {
        <!DOCTYPE html>
        <html lang="en">
            <head>
                <meta charset="UTF-8" />
                <meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no" />

                <MetaTags />

                <AutoReload options=options.clone() />
                <HydrationScripts options />
            </head>
            <body>
                <App />
            </body>
        </html>
    }
}

/// Root application component.
///
/// It initializes the meta context required for modifying the document's head,
/// mounts the router, and declares all top-level routes.
#[component]
pub fn App() -> impl IntoView {
    provide_meta_context();

    view! {
        <Title text="Mega" />
        <Meta name="description" content="The hallucinator machine." />

        <Router>
            <UIShell>
                <FlatRoutes fallback=NotFound>
                    <Route path=path!("/") view=Home />
                    <Route path=path!("/*path") view=NotFound />
                </FlatRoutes>
            </UIShell>
        </Router>
    }
}
