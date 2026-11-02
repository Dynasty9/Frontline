use std::{
    env, fs,
    path::{Path, PathBuf},
};

fn source_files(dir: &Path, out: &mut Vec<PathBuf>) {
    for entry in fs::read_dir(dir).unwrap() {
        let path = entry.unwrap().path();
        if path.is_dir() {
            source_files(&path, out);
        } else if path.extension().is_some_and(|e| e == "rs") {
            out.push(path);
        }
    }
}
fn main() {
    let manifest = PathBuf::from(env::var_os("CARGO_MANIFEST_DIR").unwrap());
    let root = manifest.parent().unwrap();
    let mut files = vec![];
    source_files(&root.join("core/src"), &mut files);
    source_files(&root.join("server/src"), &mut files);
    files.extend(
        [
            "Cargo.toml",
            "Cargo.lock",
            "core/Cargo.toml",
            "server/Cargo.toml",
            "server/build.rs",
            "content.json",
        ]
        .map(|p| root.join(p)),
    );
    files.sort();
    let mut hash = blake3::Hasher::new();
    for file in files {
        println!("cargo:rerun-if-changed={}", file.display());
        let name = file
            .strip_prefix(root)
            .unwrap()
            .to_str()
            .unwrap()
            .replace('\\', "/");
        let text = fs::read_to_string(&file).unwrap().replace("\r\n", "\n");
        hash.update(&(name.len() as u64).to_le_bytes());
        hash.update(name.as_bytes());
        hash.update(&(text.len() as u64).to_le_bytes());
        hash.update(text.as_bytes());
    }
    println!("cargo:rustc-env=FRONTLINE_ENGINE_ID={}", hash.finalize());
}
