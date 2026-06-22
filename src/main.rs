//! Server application entry point.
//!
//! It bootstraps the web server, configures the server-side rendering (SSR),
//! and serves the static files required for the WebAssembly (WASM) client hydration.

/// The main entry point for the server executable.
///
/// This function configures the application routes for server-side rendering (SSR)
/// and sets up a fallback to serve static assets.
///
/// It also binds to a network port to listen for incoming HTTP requests.
///
/// # Feature flags
///
/// Only compiled when the `ssr` feature is enabled.
#[cfg(feature = "ssr")]
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    use axum::{Router, serve};
    use leptos::prelude::*;
    use leptos_axum::{LeptosRoutes, generate_route_list};
    use mega::app::{App, shell};
    use tokio::net::TcpListener;
    use tower_http::services::ServeDir;
    use tracing_subscriber::fmt::init;

    init();

    let configuration = get_configuration(None)?;
    let options = configuration.leptos_options;

    let site_addr = options.site_addr;
    let site_root = options.site_root.as_ref();

    let route_list = generate_route_list(App);
    let fallback_service = ServeDir::new(site_root);

    let shell_handler = {
        let shell_options = options.clone();
        move || shell(shell_options.clone())
    };

    let router = Router::new()
        .leptos_routes(&options, route_list, shell_handler)
        .fallback_service(fallback_service)
        .with_state(options);

    let tcp_listener = TcpListener::bind(site_addr).await?;
    serve(tcp_listener, router).await?;

    Ok(())
}

/// A stub entry point for the non-SSR feature build.
///
/// This function exists solely to satisfy the compiler's requirement
/// for a binary target when server features are disabled.
///
/// # Feature flags
///
/// Only compiled when the `ssr` feature is not enabled.
#[cfg(not(feature = "ssr"))]
fn main() {}
