use chrono::NaiveDate;
use colored::*;
use std::fs;
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

use crate::config::Config;
use crate::journal::{get_file_path, parse_date_from_filename, parse_file, JournalEntry, Zone};

pub fn highlight_tags(text: &str) -> String {
    let re = regex::Regex::new(r"(#[\p{L}\p{N}_]+)").unwrap();
    re.replace_all(text, |caps: &regex::Captures| {
        caps[1].yellow().bold().to_string()
    })
    .to_string()
}

pub fn render_entry(entry: &JournalEntry) {
    let time_badge = format!(" 🕒 {} ", entry.time).bold().on_blue().white();
    println!("{}", time_badge);
    println!("{}", "─".repeat(50).dimmed());

    for line in entry.content.lines() {
        if line.starts_with("# ") || line.starts_with("## ") || line.starts_with("### ") {
            println!("{}", line.bold().cyan());
        } else if line.starts_with("- ") || line.starts_with("* ") {
            let item = &line[2..];
            println!("  {} {}", "•".green(), highlight_tags(item));
        } else {
            println!("{}", highlight_tags(line));
        }
    }

    if !entry.tags.is_empty() {
        let tags_formatted: Vec<String> = entry
            .tags
            .iter()
            .map(|t| format!("#{}", t).bold().yellow().to_string())
            .collect();
        println!("\n  {} {}", "🏷 ".dimmed(), tags_formatted.join(" "));
    }
    println!();
}

pub fn view_date(date: NaiveDate, zone: Zone, config: &Config, is_en: bool) {
    let base_dir = match zone {
        Zone::Sync => &config.sync_dir,
        Zone::Local => &config.local_dir,
        Zone::Private => &config.private_dir,
    };

    let path = get_file_path(base_dir, date, zone.suffix());

    if !path.exists() {
        let msg = if is_en {
            format!("No journal found for {} in {}.", date.format("%Y-%m-%d"), zone.name_en())
        } else {
            format!("未找到 {} 的日志（{}）。", date.format("%Y-%m-%d"), zone.name_zh())
        };
        println!("{}", msg.yellow());
        return;
    }

    let zone_label = if is_en { zone.name_en() } else { zone.name_zh() };
    println!();
    println!(
        "{} {} {}",
        "📅".bold(),
        date.format("%Y-%m-%d").to_string().bold().green(),
        format!("({})", zone_label).dimmed()
    );
    println!("{}", "═".repeat(50).dimmed());
    println!();

    match parse_file(&path, date) {
        Ok(entries) => {
            if entries.is_empty() {
                let msg = if is_en { "No entries for this day." } else { "本日暂无记录。" };
                println!("{}", msg.dimmed());
            } else {
                for entry in entries {
                    render_entry(&entry);
                }
            }
        }
        Err(e) => {
            eprintln!("{}: {}", if is_en { "Error reading file" } else { "读取文件失败" }.red(), e);
        }
    }
}

pub fn get_all_journal_files(base_dir: &Path, suffix: &str) -> Vec<(NaiveDate, PathBuf)> {
    let mut files = Vec::new();
    if !base_dir.exists() {
        return files;
    }

    for entry in WalkDir::new(base_dir).into_iter().filter_map(|e| e.ok()) {
        if entry.file_type().is_file() {
            let path = entry.path();
            if path.extension().and_then(|s| s.to_str()) == Some("md") {
                let filename = path.file_name().and_then(|s| s.to_str()).unwrap_or("");
                if filename.ends_with(&format!("{}.md", suffix)) {
                    if let Some(date) = parse_date_from_filename(filename) {
                        files.push((date, path.to_path_buf()));
                    }
                }
            }
        }
    }

    files.sort_by(|a, b| b.0.cmp(&a.0)); // Descending by date
    files
}

pub fn view_tail(n: usize, zone: Zone, config: &Config, is_en: bool) {
    let base_dir = match zone {
        Zone::Sync => &config.sync_dir,
        Zone::Local => &config.local_dir,
        Zone::Private => &config.private_dir,
    };

    let files = get_all_journal_files(base_dir, zone.suffix());
    if files.is_empty() {
        let msg = if is_en { "No journal entries found." } else { "未找到任何日志记录。" };
        println!("{}", msg.yellow());
        return;
    }

    let mut collected_entries = Vec::new();
    for (date, path) in &files {
        if let Ok(entries) = parse_file(path, *date) {
            for entry in entries.into_iter().rev() {
                collected_entries.push(entry);
                if collected_entries.len() >= n {
                    break;
                }
            }
        }
        if collected_entries.len() >= n {
            break;
        }
    }

    collected_entries.reverse();

    println!();
    let header_text = if is_en {
        format!("Showing last {} journal entries:", collected_entries.len())
    } else {
        format!("展示最近 {} 条日志记录：", collected_entries.len())
    };
    println!("{}", header_text.bold().cyan());
    println!("{}", "═".repeat(50).dimmed());
    println!();

    for entry in &collected_entries {
        println!("{} {}", "📅".dimmed(), entry.date.format("%Y-%m-%d").to_string().bold());
        render_entry(entry);
    }
}

pub fn list_journals(limit: usize, zone: Zone, config: &Config, is_en: bool) {
    let base_dir = match zone {
        Zone::Sync => &config.sync_dir,
        Zone::Local => &config.local_dir,
        Zone::Private => &config.private_dir,
    };

    let files = get_all_journal_files(base_dir, zone.suffix());
    if files.is_empty() {
        let msg = if is_en { "No journals found." } else { "未找到任何日志。" };
        println!("{}", msg.yellow());
        return;
    }

    println!();
    let title = if is_en {
        format!("Recent Journals ({}, limit {})", zone.name_en(), limit)
    } else {
        format!("近期日志列表（{}，上限 {} 篇）", zone.name_zh(), limit)
    };
    println!("{}", title.bold().cyan());
    println!("{:<14} {:<10} {:<10} {}", "Date", "Entries", "Size", "First entry preview");
    println!("{}", "─".repeat(65).dimmed());

    for (date, path) in files.iter().take(limit) {
        let entries = parse_file(path, *date).unwrap_or_default();
        let size = fs::metadata(path).map(|m| m.len()).unwrap_or(0);
        let preview = entries
            .first()
            .map(|e| {
                let first_line = e.content.lines().next().unwrap_or("");
                if first_line.chars().count() > 30 {
                    format!("{}...", first_line.chars().take(30).collect::<String>())
                } else {
                    first_line.to_string()
                }
            })
            .unwrap_or_else(|| "-".to_string());

        let size_str = if size > 1024 {
            format!("{:.1} KB", size as f64 / 1024.0)
        } else {
            format!("{} B", size)
        };

        println!(
            "{:<14} {:<10} {:<10} {}",
            date.format("%Y-%m-%d").to_string().bold(),
            format!("{} 条", entries.len()).green(),
            size_str.dimmed(),
            preview.dimmed()
        );
    }
    println!();
}
