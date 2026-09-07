use std::env;
use std::fs::{File, OpenOptions};
use std::os::unix::io::AsRawFd;
use std::path::PathBuf;

pub struct JrLock {
    _file: File,
    path: PathBuf,
}

impl JrLock {
    pub fn acquire() -> Result<Self, String> {
        let uid = unsafe { libc::getuid() };
        let lock_dir = dirs::runtime_dir().unwrap_or_else(env::temp_dir);
        let path = lock_dir.join(format!("jr-{}.lock", uid));

        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(&path)
            .map_err(|e| format!("Failed to open lockfile {}: {}", path.display(), e))?;

        let fd = file.as_raw_fd();
        let ret = unsafe { libc::flock(fd, libc::LOCK_EX | libc::LOCK_NB) };
        if ret != 0 {
            return Err("Another instance of jr is running.".to_string());
        }

        Ok(Self { _file: file, path })
    }
}

impl Drop for JrLock {
    fn drop(&mut self) {
        let fd = self._file.as_raw_fd();
        unsafe {
            libc::flock(fd, libc::LOCK_UN);
        }
        let _ = std::fs::remove_file(&self.path);
    }
}
