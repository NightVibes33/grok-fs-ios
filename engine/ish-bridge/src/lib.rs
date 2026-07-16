use flate2::read::GzDecoder;
use ish_embed_host::IshInstance;
use std::collections::HashMap;
use std::ffi::{c_char, CStr};
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::OnceLock;
use tar::Archive;

static INSTANCE: OnceLock<IshInstance> = OnceLock::new();

#[repr(C)]
pub struct GrokFSIshResult {
    pub exit_code: i32,
    pub bytes: *mut u8,
    pub length: usize,
}

fn c_string(value: *const c_char) -> Result<String, String> {
    if value.is_null() {
        return Err("null string".into());
    }
    unsafe { CStr::from_ptr(value) }
        .to_str()
        .map(str::to_owned)
        .map_err(|error| error.to_string())
}

#[no_mangle]
pub extern "C" fn grokfs_ish_bootstrap(
    archive_path: *const c_char,
    support_path: *const c_char,
) -> i32 {
    if INSTANCE.get().is_some() {
        return 0;
    }

    let result = (|| -> Result<IshInstance, String> {
        let archive_path = PathBuf::from(c_string(archive_path)?);
        let support_path = PathBuf::from(c_string(support_path)?);
        let fs_root = support_path.join("fs");
        let data_root = fs_root.join("data");

        if !data_root.join("bin/sh").exists() || !data_root.join("usr/local/bin/grok").exists() {
            if fs_root.exists() {
                fs::remove_dir_all(&fs_root).map_err(|error| error.to_string())?;
            }
            fs::create_dir_all(&support_path).map_err(|error| error.to_string())?;
            let file = fs::File::open(archive_path).map_err(|error| error.to_string())?;
            let decoder = GzDecoder::new(file);
            Archive::new(decoder)
                .unpack(&support_path)
                .map_err(|error| error.to_string())?;
        }

        let instance = IshInstance::boot(&data_root, Some(Path::new("/root")))
            .map_err(|error| error.to_string())?;
        let setup = vec![
            "/bin/sh".to_string(),
            "-lc".to_string(),
            "mkdir -p /root /tmp /usr/local/bin; chmod 1777 /tmp; printf 'nameserver 1.1.1.1\\nnameserver 8.8.8.8\\n' > /etc/resolv.conf".to_string(),
        ];
        let (code, output) = instance.run_oneshot(
            &setup,
            Path::new("/root"),
            &HashMap::new(),
            Some(10_000),
        );
        if code != 0 {
            return Err(format!("runtime setup failed ({code}): {}", String::from_utf8_lossy(&output)));
        }
        Ok(instance)
    })();

    match result {
        Ok(instance) => INSTANCE.set(instance).map(|_| 0).unwrap_or(-2),
        Err(error) => {
            eprintln!("[grokfs-ish] bootstrap failed: {error}");
            -1
        }
    }
}

#[no_mangle]
pub extern "C" fn grokfs_ish_run(
    command: *const c_char,
    cwd: *const c_char,
    timeout_ms: u64,
) -> GrokFSIshResult {
    let Some(instance) = INSTANCE.get() else {
        return result(-6, b"iSH runtime is not ready\n".to_vec());
    };

    let command = match c_string(command) {
        Ok(value) => value,
        Err(error) => return result(-10, error.into_bytes()),
    };
    let cwd = c_string(cwd).unwrap_or_else(|_| "/root".into());
    let argv = vec!["/bin/sh".to_string(), "-lc".to_string(), command];
    let env = HashMap::from([
        ("HOME".to_string(), "/root".to_string()),
        (
            "PATH".to_string(),
            "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin".to_string(),
        ),
        ("TMPDIR".to_string(), "/tmp".to_string()),
        ("LANG".to_string(), "C.UTF-8".to_string()),
        ("NO_COLOR".to_string(), "1".to_string()),
    ]);
    let (code, output) = instance.run_oneshot(
        &argv,
        Path::new(&cwd),
        &env,
        Some(timeout_ms.max(1)),
    );
    result(code, output)
}

fn result(exit_code: i32, bytes: Vec<u8>) -> GrokFSIshResult {
    let mut bytes = bytes.into_boxed_slice();
    let result = GrokFSIshResult {
        exit_code,
        bytes: bytes.as_mut_ptr(),
        length: bytes.len(),
    };
    std::mem::forget(bytes);
    result
}

#[no_mangle]
pub extern "C" fn grokfs_ish_result_free(bytes: *mut u8, length: usize) {
    if bytes.is_null() {
        return;
    }
    unsafe {
        let slice = std::ptr::slice_from_raw_parts_mut(bytes, length);
        drop(Box::from_raw(slice));
    }
}
