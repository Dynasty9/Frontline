use frontline_server::compression::{decode, encode, CHUNK};

#[test]
fn compressed_blocks_preserve_exact_bytes_at_each_boundary() {
    for size in [0, 1, CHUNK - 1, CHUNK, CHUNK + 1, CHUNK * 3 + 57] {
        let bytes: Vec<_> = (0..size)
            .map(|i| (i.wrapping_mul(137) >> 3) as u8)
            .collect();
        let encoded = encode(&bytes).unwrap();
        assert_eq!(decode(&encoded, size).unwrap(), bytes);
        assert_eq!(encode(&bytes).unwrap(), encoded);
        if size > 0 {
            assert!(decode(&encoded, size - 1).is_err());
            for cut in [12, 16, encoded.len() - 1] {
                assert!(decode(&encoded[..cut], size).is_err());
            }
        }
        let mut extra = encoded.clone();
        extra.push(0);
        assert!(decode(&extra, size).is_err());
    }
}

#[test]
fn malformed_blocks_cannot_expand_past_the_declared_size_or_hide_trailing_bytes() {
    let bytes = vec![7; CHUNK];
    let encoded = encode(&bytes).unwrap();
    for size in [0u32, 1, CHUNK as u32 - 1, CHUNK as u32 + 1, u32::MAX] {
        let mut wrong = encoded.clone();
        wrong[8..12].copy_from_slice(&size.to_le_bytes());
        assert!(decode(&wrong, CHUNK * 2).is_err());
    }
    let mut wrong = encoded.clone();
    *wrong.last_mut().unwrap() ^= 1;
    assert!(decode(&wrong, CHUNK).is_err());
    let mut extra = encoded.clone();
    let length = u32::from_le_bytes(extra[12..16].try_into().unwrap()) + 1;
    extra[12..16].copy_from_slice(&length.to_le_bytes());
    extra.push(0);
    assert!(decode(&extra, CHUNK).is_err());
}
