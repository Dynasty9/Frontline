//! Browser workers run the desktop simulation and verifier without a socket or filesystem.
pub mod session;
use frontline_runtime::{content::Content, replay, simulation::MAX_STATE};
use session::Session;
use std::cell::RefCell;

#[derive(Default)]
struct Boundary {
    input: Vec<u8>,
    output: Vec<u8>,
    session: Option<Session>,
}
thread_local! { static BOUNDARY: RefCell<Boundary> = RefCell::new(Boundary::default()); }

// JavaScript writes only into this owned buffer; no caller-provided pointer is dereferenced.
#[no_mangle]
pub extern "C" fn input_resize(length: u32) -> *mut u8 {
    BOUNDARY.with_borrow_mut(|b| {
        if length as usize > MAX_STATE {
            return std::ptr::null_mut();
        }
        b.input.resize(length as usize, 0);
        b.input.as_mut_ptr()
    })
}
#[no_mangle]
pub extern "C" fn output_pointer() -> *const u8 {
    BOUNDARY.with_borrow(|b| b.output.as_ptr())
}
#[no_mangle]
pub extern "C" fn output_length() -> u32 {
    BOUNDARY.with_borrow(|b| b.output.len() as u32)
}

#[no_mangle]
pub extern "C" fn run(operation: u32, argument: u32) -> u32 {
    BOUNDARY.with_borrow_mut(|b| {
        let input = std::mem::take(&mut b.input);
        let result = (|| -> Result<Vec<u8>, String> {
            if operation == 0 || operation == 7 {
                b.session = None;
                let session = Session::new(input, operation == 7)?;
                let metadata = serde_json::to_vec(&session.metadata()).map_err(|e|e.to_string())?;
                b.session = Some(session);
                return Ok(metadata);
            }
            if operation == 1 {
                let content = Content::bundled()?;
                let verified = replay::verify(input.as_slice(), &content)?;
                return serde_json::to_vec(&serde_json::json!({"engine":frontline_runtime::ENGINE_ID,
                    "frames":verified.frames,"winner":verified.simulation.state.victory.winner,
                    "state_hash":verified.state_hash.iter().map(|v|format!("{v:02x}")).collect::<String>()}))
                    .map_err(|e|e.to_string());
            }
            if operation == 6 {
                return b.session.take().ok_or("No simulation is running")?.finish();
            }
            let session = b.session.as_mut().ok_or("No simulation is running")?;
            match operation {
                2 => session.step(argument)?,
                3 => session.receive(&input)?,
                4 => session.open()?,
                5 => return Ok(session.take_packets()),
                8 => {
                    session.seek(argument)?;
                    return serde_json::to_vec(&session.metadata()).map_err(|e|e.to_string());
                }
                _ => return Err("Unknown worker operation".into()),
            }
            Ok(vec![])
        })();
        let failed = result.is_err();
        b.output = result.unwrap_or_else(|e| e.into_bytes());
        failed as u32
    })
}
