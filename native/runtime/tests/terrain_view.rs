use frontline_core::{
    state_codec::Reader,
    terrain::{Terrain, BASE, CRATER, DRES},
    vector::Vector3,
};
use frontline_runtime::terrain_view::{self, Surface};

fn apply(bytes: &[u8], t: &mut Terrain) {
    let mut r = Reader::new(bytes, b"FLVT\x01\0\0\0").unwrap();
    let [x, z, width, height] = std::array::from_fn(|_| r.u32().unwrap() as usize);
    for layer in [BASE, CRATER] {
        let data = r.bytes(width * height).unwrap();
        assert_eq!(data.len(), width * height);
        for row in 0..height {
            t.layers[layer][(z + row) * t.n + x..(z + row) * t.n + x + width]
                .copy_from_slice(&data[row * width..(row + 1) * width]);
        }
    }
    let data = r.bytes(width * height * DRES * DRES * 4).unwrap();
    for row in 0..height * DRES {
        for col in 0..width * DRES {
            let i = (row * width * DRES + col) * 4;
            t.heights[(z * DRES + row) * t.n * DRES + x * DRES + col] =
                f32::from_le_bytes(data[i..i + 4].try_into().unwrap());
        }
    }
    r.finish().unwrap();
}

#[test]
fn current_tiles_reproduce_overlapping_craters_and_small_craters_without_cover() {
    let mut server = Terrain::blank(70).unwrap();
    let mut early = server.clone();
    let mut late = server.clone();
    let mut view = Surface::default();
    for (p, size) in [
        (Vector3::ZERO, 0.7),
        (Vector3::new(-3., 0., -3.), 4.),
        (Vector3::new(34., 0., 34.), 2.),
    ] {
        server.crater(p, size);
        let before = server.checkpoint();
        for bytes in view.update(&server, &[(p, size), (p, size)]).unwrap() {
            assert!(bytes.len() < 48 * 1024);
            apply(&bytes, &mut early);
            apply(&bytes, &mut early);
        }
        assert_eq!(
            before,
            server.checkpoint(),
            "observations must not modify the ground"
        );
        assert_eq!(early.heights, server.heights);
        assert_eq!(early.layers[CRATER], server.layers[CRATER]);
    }
    for bytes in view.tiles.values() {
        apply(bytes, &mut late);
    }
    assert_eq!(early.heights, late.heights);
    assert_eq!(early.layers[CRATER], late.layers[CRATER]);
    assert!(terrain_view::tile(&server, 1, 0).is_err());
    assert!(terrain_view::tile(&server, 96, 0).is_err());
}
