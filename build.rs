//! Build script.
//!
//! It programmatically configures and generates the type-safe localization module
//! directly into the Cargo build output directory.

use leptos_i18n_build::{Config, FileFormat, ParseOptions, TranslationsInfos};
use std::{env::var_os, error::Error, path::PathBuf};

fn main() -> Result<(), Box<dyn Error>> {
    let parse_options = ParseOptions::default().file_format(FileFormat::Toml);

    let config = Config::new("en")?
        .add_locale("es")?
        .add_locale("pt")?
        .locales_path("./assets/locales")
        .parse_options(parse_options);

    let i18n_module_directory = PathBuf::from(var_os("OUT_DIR").unwrap()).join("i18n");

    let translations_infos = TranslationsInfos::parse(config)?;
    translations_infos.emit_diagnostics();
    translations_infos.rerun_if_locales_changed();
    translations_infos.generate_i18n_module(i18n_module_directory)?;

    Ok(())
}
