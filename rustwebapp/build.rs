use std::process::Command;
use std::str;

fn main() {
    let output = Command::new("rustc")
        .arg("--version")
        .output()
        .expect("No se pudo ejecutar 'rustc --version'.");

    let version_str = str::from_utf8(&output.stdout)
        .unwrap_or("Versión desconocida")
        .trim();

    println!("cargo:rustc-env=COMPILER_VERSION={}", version_str);
}
