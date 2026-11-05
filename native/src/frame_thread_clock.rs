use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct FrameThreadClock;

#[godot_api]
impl FrameThreadClock {
    /// Optional profiling of this thread only; no counter enters gameplay state.
    #[func]
    fn sample(&self) -> PackedInt64Array {
        #[cfg(target_os = "windows")]
        if let Some(sample) = windows::sample() {
            return PackedInt64Array::from(sample.as_slice());
        }
        PackedInt64Array::new()
    }
}

#[cfg(target_os = "windows")]
mod windows {
    use std::ffi::c_void;

    #[derive(Default)]
    #[repr(C)]
    struct FileTime {
        low: u32,
        high: u32,
    }
    impl FileTime {
        fn ticks(&self) -> u64 {
            (u64::from(self.high) << 32) | u64::from(self.low)
        }
    }

    #[link(name = "kernel32")]
    unsafe extern "system" {
        fn GetCurrentThread() -> *mut c_void;
        fn GetThreadTimes(
            thread: *mut c_void,
            creation: *mut FileTime,
            exit: *mut FileTime,
            kernel: *mut FileTime,
            user: *mut FileTime,
        ) -> i32;
        fn QueryThreadCycleTime(thread: *mut c_void, cycles: *mut u64) -> i32;
    }

    pub fn sample() -> Option<[i64; 2]> {
        let mut creation = FileTime::default();
        let mut exit = FileTime::default();
        let mut kernel = FileTime::default();
        let mut user = FileTime::default();
        let mut cycles = 0;
        // The pseudo-handle names the calling thread and must not be closed.
        let ok = unsafe {
            let thread = GetCurrentThread();
            GetThreadTimes(thread, &mut creation, &mut exit, &mut kernel, &mut user) != 0
                && QueryThreadCycleTime(thread, &mut cycles) != 0
        };
        if !ok {
            return None;
        }
        Some([
            i64::try_from(kernel.ticks().checked_add(user.ticks())?).ok()?,
            i64::try_from(cycles).ok()?,
        ])
    }

    #[test]
    fn calling_thread_counters_are_monotonic() {
        let before = sample().unwrap();
        let mut value = 1u64;
        for i in 0..100_000u64 {
            value = std::hint::black_box(value.wrapping_mul(31).wrapping_add(i));
        }
        std::hint::black_box(value);
        let after = sample().unwrap();
        assert!(after[0] >= before[0]);
        assert!(after[1] > before[1]);
    }
}
