//! Build script.
//!
//! It programmatically configures and generates the type-safe localization module
//! into the `i18n/` subdirectory of the Cargo build output directory.

use leptos_i18n_build::{Config, FileFormat, ParseOptions, TranslationsInfos};
use std::{env::var_os, error::Error, path::PathBuf};

/// Executes the build pipeline for internationalization.
///
/// It configures the `leptos_i18n` code generator to read translation files,
/// formatted as TOML, from the `assets/locales` directory.
///
/// # Supported locales
///
/// * English ("en") - default locale.
/// * Spanish ("es").
/// * Portuguese ("pt").
///
/// # Errors
///
/// Returns an error if the translation files fail to parse, if the specified locales are invalid,
/// or if the generated module cannot be written to disk.
///
/// # Panics
///
/// Panics if the `CARGO_MANIFEST_DIR` or `OUT_DIR` environment variables are not set.
/// This typically only occurs if the build script is executed directly outside of Cargo.
fn main() -> Result<(), Box<dyn Error>> {
    let manifest_dir = var_os("CARGO_MANIFEST_DIR").expect("Failed to fetch CARGO_MANIFEST_DIR");
    let locales_path = PathBuf::from(manifest_dir).join("assets/locales");

    let parse_options = ParseOptions::default().file_format(FileFormat::Toml);

    let config = Config::new("en")?
        .add_locale("es")?
        .add_locale("pt")?
        .locales_path(locales_path)
        .parse_options(parse_options);

    let out_dir = var_os("OUT_DIR").expect("Failed to fetch OUT_DIR");
    let i18n_module_directory = PathBuf::from(out_dir).join("i18n");

    let translations_infos = TranslationsInfos::parse(config)?;
    translations_infos.emit_diagnostics();
    translations_infos.rerun_if_locales_changed();
    translations_infos.generate_i18n_module(i18n_module_directory)?;

    Ok(())
}
