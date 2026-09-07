use clap::Command;
use clap_complete::{generate, Shell};
use std::io;
use std::panic::{self, AssertUnwindSafe};

pub fn generate_completions(shell: Shell, mut cmd: Command) {
    let _ = panic::catch_unwind(AssertUnwindSafe(|| {
        let mut stdout = io::stdout();
        generate(shell, &mut cmd, "jr", &mut stdout);
    }));
}
