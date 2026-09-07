use chrono::{Local, NaiveDate};
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::Shell;
use colored::*;
use std::io::{self, IsTerminal, Read};
use std::process;

use jr::completions;
use jr::config::Config;
use jr::editor::{self, EditorFlag};
use jr::git::{self, SyncStatus};
use jr::i18n::Language;
use jr::journal::{self, get_file_path, write_entry, Zone};
use jr::lock::JrLock;
use jr::search;
use jr::stats;
use jr::view;

const VERSION: &str = env!("CARGO_PKG_VERSION");

#[derive(Parser, Debug)]
#[command(
    name = "jr",
    version = VERSION,
    about = "A minimalist terminal journal for developers who think in the terminal.",
    long_about = "jr is a minimalist terminal journal following the Unix philosophy: do one thing and do it well.\nMarkdown is the format, Git is the sync engine, physical isolation is privacy."
)]
struct Cli {
    /// Journal entry content to record (or read from stdin)
    #[arg(value_name = "CONTENT")]
    content: Vec<String>,

    /// Subcommands for viewing, searching, and managing journals
    #[command(subcommand)]
    command: Option<Commands>,

    /// Record to local backup only
    #[arg(short = 'l', long = "local", global = true)]
    local: bool,

    /// Record to private zone (never synced)
    #[arg(short = 'p', long = "private", global = true)]
    private: bool,

    /// Open today's journal in VS Code
    #[arg(short = 'c', long = "code")]
    code: bool,

    /// Open today's journal in GNOME Text Editor / gedit
    #[arg(short = 'g', long = "gnome")]
    gnome: bool,

    /// Open today's journal in Kate
    #[arg(short = 'k', long = "kde")]
    kde: bool,

    /// Open today's journal in macOS TextEdit
    #[arg(short = 'm', long = "macos")]
    macos: bool,

    /// Open today's journal in $EDITOR or system default
    #[arg(short = 'e', long = "edit")]
    edit: bool,

    /// Open today's journal with xdg-open (Linux)
    #[arg(short = 'x', long = "xdg")]
    xdg: bool,

    /// Show current status
    #[arg(long = "status")]
    status: bool,

    /// Login to GitHub CLI
    #[arg(long = "login")]
    login: bool,

    /// Quiet mode (suppress unnecessary output)
    #[arg(short = 'q', long = "quiet", global = true)]
    quiet: bool,

    /// Verbose / debug mode
    #[arg(short = 'v', long = "verbose", global = true)]
    verbose: bool,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// View today's journal entries in terminal
    #[command(alias = "today", alias = "t")]
    View {
        /// Date to view (format: YYYY-MM-DD, defaults to today)
        #[arg(value_name = "DATE")]
        date: Option<String>,
    },

    /// View yesterday's journal entries
    #[command(alias = "y")]
    Yesterday,

    /// View journal entries for a specific date
    Date {
        /// Date string in YYYY-MM-DD format
        date: String,
    },

    /// Show the last N journal entries (default: 5)
    Tail {
        /// Number of entries to show
        #[arg(default_value = "5")]
        count: usize,
    },

    /// List recent journal files and summaries
    #[command(alias = "ls")]
    List {
        /// Maximum number of journals to list
        #[arg(default_value = "10")]
        limit: usize,
    },

    /// Search journal entries across all files
    #[command(alias = "grep", alias = "f")]
    Search {
        /// Search query or regex
        query: String,
    },

    /// List all hashtags used in journals
    Tags,

    /// Search entries by hashtag
    Tag {
        /// Hashtag name (without #)
        name: String,
    },

    /// Display journal statistics, streaks, and heatmap
    Stats,

    /// Perform full bidirectional Git sync
    Sync,

    /// Interactive GitHub CLI login
    Login,

    /// Show status of journals, repositories, and config
    Status,

    /// Generate shell completion script
    Completions {
        /// Shell type: bash, zsh, fish, elvish, powershell
        shell: Shell,
    },

    /// Check and upgrade jr to the latest release
    #[command(alias = "update")]
    Upgrade,
}

fn determine_zone(local: bool, private: bool) -> Result<Zone, &'static str> {
    if local && private {
        Err("Error: -l/--local and -p/--private are mutually exclusive.")
    } else if private {
        Ok(Zone::Private)
    } else if local {
        Ok(Zone::Local)
    } else {
        Ok(Zone::Sync)
    }
}

fn determine_editor_flag(cli: &Cli) -> Result<Option<EditorFlag>, &'static str> {
    let mut flags = Vec::new();
    if cli.code { flags.push(EditorFlag::Code); }
    if cli.gnome { flags.push(EditorFlag::Gnome); }
    if cli.kde { flags.push(EditorFlag::Kde); }
    if cli.macos { flags.push(EditorFlag::Macos); }
    if cli.edit { flags.push(EditorFlag::Edit); }
    if cli.xdg { flags.push(EditorFlag::Xdg); }

    if flags.len() > 1 {
        Err("Error: Only one editor option can be selected.")
    } else {
        Ok(flags.into_iter().next())
    }
}

fn show_status(config: &Config, lang: Language) {
    let is_en = lang.is_en();
    let title = if is_en { "jr Status" } else { "jr 状态" };
    println!("\n{}", title.bold());
    println!("{}", "─────────────────────────────────────────".dimmed());
    println!("{}: {}", if is_en { "Version" } else { "版本" }, VERSION.green().bold());
    println!("OS: {} ({})", std::env::consts::OS, std::env::consts::ARCH);
    println!("{}: {}", if is_en { "Config file" } else { "配置文件" }, Config::toml_path().display().to_string().dimmed());
    println!();

    // Git & GitHub CLI status
    let git_installed = git::check_git_installed();
    println!(
        "Git: {}",
        if git_installed {
            if is_en { "Installed" } else { "已安装" }.green()
        } else {
            if is_en { "Not installed" } else { "未安装" }.red()
        }
    );

    let gh_installed = git::check_gh_installed();
    if gh_installed {
        let auth_ok = git::check_gh_auth();
        println!(
            "{}: {} | {}: {}",
            if is_en { "GitHub CLI" } else { "GitHub CLI" },
            if is_en { "Installed" } else { "已安装" }.green(),
            if is_en { "Auth" } else { "认证状态" },
            if auth_ok {
                if is_en { "Authenticated" } else { "已认证" }.green()
            } else {
                if is_en { "Not Authenticated" } else { "未认证" }.red()
            }
        );
    } else {
        println!(
            "{}: {}",
            if is_en { "GitHub CLI" } else { "GitHub CLI" },
            if is_en { "Not installed (install gh for cloud sync)" } else { "未安装（云端同步需要 gh）" }.yellow()
        );
    }
    println!();

    // Directories and Git status
    println!("{}:", if is_en { "Directories & Sync" } else { "目录与同步状态" });
    let dirs = [
        (Zone::Sync, &config.sync_dir),
        (Zone::Local, &config.local_dir),
        (Zone::Private, &config.private_dir),
    ];

    for (zone, dir) in &dirs {
        let label = if is_en { zone.name_en() } else { zone.name_zh() };
        if dir.exists() {
            let files = view::get_all_journal_files(dir, zone.suffix());
            let count = files.len();
            let mut sync_info = String::new();
            if git::is_git_repo(dir) {
                let unpushed = git::get_unpushed_count(dir);
                if unpushed > 0 {
                    sync_info = format!(" (Git: {} pending push)", unpushed).yellow().to_string();
                } else {
                    sync_info = " (Git: synced)".green().to_string();
                }
            }
            println!(
                "  {}: {} {} ({} files){}",
                label,
                "✓".green(),
                dir.display().to_string().dimmed(),
                count,
                sync_info
            );
        } else {
            println!(
                "  {}: {} {} ({})",
                label,
                "○".yellow(),
                dir.display().to_string().dimmed(),
                if is_en { "not created" } else { "未创建" }
            );
        }
    }
    println!();
}

fn main() {
    let cli = Cli::parse();
    let lang = Language::detect();
    let is_en = lang.is_en();
    let config = Config::load();
    let _ = Config::ensure_config_exists();

    // Handle --status
    if cli.status {
        show_status(&config, lang);
        process::exit(0);
    }

    // Handle --login
    if cli.login {
        if !git::check_gh_installed() {
            eprintln!(
                "{}",
                if is_en {
                    "GitHub CLI (gh) is not installed. Visit https://cli.github.com/"
                } else {
                    "未安装 GitHub CLI (gh)。请访问 https://cli.github.com/ 进行安装。"
                }
                .red()
            );
            process::exit(69);
        }
        if git::do_gh_login() {
            println!("{}", if is_en { "GitHub login successful!" } else { "GitHub 登录成功！" }.green());
            process::exit(0);
        } else {
            eprintln!("{}", if is_en { "Login failed." } else { "登录失败。" }.red());
            process::exit(1);
        }
    }

    // Determine Zone
    let zone = match determine_zone(cli.local, cli.private) {
        Ok(z) => z,
        Err(e) => {
            eprintln!("{}", e.red());
            process::exit(64);
        }
    };

    // Subcommands handling
    if let Some(cmd) = cli.command {
        match cmd {
            Commands::View { date } => {
                let target_date = if let Some(d) = date {
                    match NaiveDate::parse_from_str(&d, "%Y-%m-%d") {
                        Ok(parsed) => parsed,
                        Err(_) => {
                            eprintln!("{}", if is_en { "Invalid date format. Use YYYY-MM-DD." } else { "日期格式错误，请使用 YYYY-MM-DD。" }.red());
                            process::exit(64);
                        }
                    }
                } else {
                    Local::now().date_naive()
                };
                view::view_date(target_date, zone, &config, is_en);
                return;
            }
            Commands::Yesterday => {
                let yesterday = Local::now().date_naive().pred_opt().unwrap();
                view::view_date(yesterday, zone, &config, is_en);
                return;
            }
            Commands::Date { date } => {
                match NaiveDate::parse_from_str(&date, "%Y-%m-%d") {
                    Ok(parsed) => view::view_date(parsed, zone, &config, is_en),
                    Err(_) => {
                        eprintln!("{}", if is_en { "Invalid date format. Use YYYY-MM-DD." } else { "日期格式错误，请使用 YYYY-MM-DD。" }.red());
                        process::exit(64);
                    }
                }
                return;
            }
            Commands::Tail { count } => {
                view::view_tail(count, zone, &config, is_en);
                return;
            }
            Commands::List { limit } => {
                view::list_journals(limit, zone, &config, is_en);
                return;
            }
            Commands::Search { query } => {
                search::search(&query, zone, &config, false, is_en);
                return;
            }
            Commands::Tags => {
                search::list_tags(zone, &config, is_en);
                return;
            }
            Commands::Tag { name } => {
                search::search(&name, zone, &config, true, is_en);
                return;
            }
            Commands::Stats => {
                stats::show_stats(&config, is_en);
                return;
            }
            Commands::Sync => {
                println!("{}", if is_en { "Starting journal sync..." } else { "正在同步日志仓库..." }.cyan());
                if git::is_git_repo(&config.sync_dir) {
                    match git::sync_repo(&config.sync_dir) {
                        SyncStatus::Synced => {
                            println!("  {} {}", "✓".green(), if is_en { "Sync completed." } else { "云端同步完成。" });
                        }
                        SyncStatus::OfflinePending => {
                            println!("  {} {}", "⚠".yellow(), if is_en { "Offline mode: local changes committed, pending push." } else { "离线模式：本地已提交，待连网后补推。" });
                        }
                        SyncStatus::NoChanges => {
                            println!("  {}", if is_en { "Already up to date." } else { "所有日志已是最新。" }.dimmed());
                        }
                        SyncStatus::GitNotConfigured => {
                            eprintln!("  {} {}", "✗".red(), if is_en { "git user.name or email not configured." } else { "未配置 git user.name 或 user.email。" });
                        }
                        SyncStatus::Error(e) => {
                            eprintln!("  {} {}: {}", "✗".red(), if is_en { "Sync error" } else { "同步错误" }, e);
                        }
                    }
                }
                return;
            }
            Commands::Login => {
                if git::do_gh_login() {
                    println!("{}", if is_en { "GitHub login successful!" } else { "GitHub 登录成功！" }.green());
                } else {
                    eprintln!("{}", if is_en { "Login failed." } else { "登录失败。" }.red());
                    process::exit(1);
                }
                return;
            }
            Commands::Status => {
                show_status(&config, lang);
                return;
            }
            Commands::Completions { shell } => {
                completions::generate_completions(shell, Cli::command());
                return;
            }
            Commands::Upgrade => {
                println!("{}", if is_en { "Checking for updates..." } else { "正在检查更新..." }.cyan());
                println!("{}", if is_en { "Run: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/DonJone/jr/main/install.sh)\"" } else { "升级命令：/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/DonJone/jr/main/install.sh)\"" }.bold());
                return;
            }
        }
    }

    // Check editor options
    let editor_flag = match determine_editor_flag(&cli) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("{}", e.red());
            process::exit(64);
        }
    };

    // If editor option specified, open today's file in editor
    if let Some(flag) = editor_flag {
        let today = Local::now().date_naive();
        let target_dir = match zone {
            Zone::Sync => &config.sync_dir,
            Zone::Local => &config.local_dir,
            Zone::Private => &config.private_dir,
        };
        let file_path = get_file_path(target_dir, today, zone.suffix());
        let _ = journal::ensure_journal_file(&file_path, today, is_en);

        if let Err(err) = editor::open_in_editor(&file_path, Some(flag), &config, is_en) {
            eprintln!("{}", err.red());
            process::exit(69);
        }
        return;
    }

    // Acquire lock for recording / sync operations
    let _lock = match JrLock::acquire() {
        Ok(l) => l,
        Err(e) => {
            eprintln!("{}", e.red());
            process::exit(75);
        }
    };

    // Read content from args or stdin
    let mut text_to_record = cli.content.join(" ");
    if text_to_record.is_empty() && !io::stdin().is_terminal() {
        let mut buffer = String::new();
        if io::stdin().read_to_string(&mut buffer).is_ok() && !buffer.trim().is_empty() {
            text_to_record = buffer.trim_end().to_string();
        }
    }

    if text_to_record.is_empty() {
        // No content and no editor flag -> show help
        let mut cmd = Cli::command();
        let _ = cmd.print_help();
        println!();
        process::exit(0);
    }

    // Ensure sync repo setup if recording to sync
    if zone == Zone::Sync {
        let _ = git::init_sync_repo(&config.sync_dir);
    }

    // Record entry
    match write_entry(&text_to_record, zone, &config, is_en) {
        Ok(saved_path) => {
            if !cli.quiet {
                let zone_name = if is_en { zone.name_en() } else { zone.name_zh() };
                let success_msg = if is_en {
                    format!("Saved to {}.", zone_name)
                } else {
                    format!("已保存至 {}。", zone_name)
                };
                println!("{}", success_msg.green());
                if cli.verbose {
                    println!("{} {}", "File:".dimmed(), saved_path.display());
                }
            }
        }
        Err(e) => {
            eprintln!("{}: {}", if is_en { "Failed to write journal" } else { "写入日志失败" }.red(), e);
            process::exit(73);
        }
    }

    // Auto sync
    if zone == Zone::Sync && config.auto_sync {
        let sync_res = git::sync_repo(&config.sync_dir);
        if cli.verbose {
            println!("{:?}", sync_res);
        }
    }
}
