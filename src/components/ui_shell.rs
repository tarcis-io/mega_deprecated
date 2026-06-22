use leptos::prelude::*;

#[component]
pub fn UIShell(children: Children) -> impl IntoView {
    view! {
        <main>
            { children() }
        </main>
    }
}
