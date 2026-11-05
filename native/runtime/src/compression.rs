//! Bounded zlib blocks shared with Godot's DEFLATE mode for large map handoffs.
use flate2::{write::ZlibEncoder, Compression, Decompress, FlushDecompress, Status};
use frontline_core::state_codec::{Reader, Writer};
use std::io::Write;

pub const CHUNK: usize = 64 * 1024;

pub fn encode(data: &[u8]) -> Result<Vec<u8>, &'static str> {
    let size = u32::try_from(data.len()).map_err(|_| "compressed state exceeds limit")?;
    let mut w = Writer::new(b"FLZB\x01\0\0\0");
    w.u32(size);
    for part in data.chunks(CHUNK) {
        let mut block = ZlibEncoder::new(Vec::new(), Compression::fast());
        block
            .write_all(part)
            .map_err(|_| "state compression failed")?;
        w.bytes(&block.finish().map_err(|_| "state compression failed")?);
    }
    Ok(w.0)
}

pub fn decode(data: &[u8], limit: usize) -> Result<Vec<u8>, &'static str> {
    let mut r = Reader::new(data, b"FLZB\x01\0\0\0")?;
    let size = r.u32()? as usize;
    if size > limit {
        return Err("expanded state exceeds limit");
    }
    // Grow only after a block validates, rather than allocating a claimed map size.
    let mut out = Vec::new();
    while out.len() < size {
        let count = CHUNK.min(size - out.len());
        let compressed = r.bytes(CHUNK + 1024)?;
        let mut block = vec![0; count];
        let mut decoder = Decompress::new(true);
        if decoder
            .decompress(compressed, &mut block, FlushDecompress::Finish)
            .map_err(|_| "invalid compressed state")?
            != Status::StreamEnd
            || decoder.total_in() as usize != compressed.len()
            || decoder.total_out() as usize != count
        {
            return Err("compressed state length differs");
        }
        out.extend_from_slice(&block);
    }
    r.finish()?;
    Ok(out)
}
