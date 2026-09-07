use chrono::{Local, NaiveDate};
use regex::Regex;
use std::fs::{self, OpenOptions};
use std::io::{self, Write};
use std::path::{Path, PathBuf};

use crate::config::Config;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Zone {
    Sync,
    Local,
    Private,
}

impl Zone {
    pub fn name_en(&self) -> &'static str {
        match self {
            Zone::Sync => "Sync + Local",
            Zone::Local => "Local Backup",
            Zone::Private => "Private Zone",
        }
    }

    pub fn name_zh(&self) -> &'static str {
        match self {
            Zone::Sync => "同步区 + 本地备份",
            Zone::Local => "本地备份",
            Zone::Private => "隔离区",
        }
    }

    pub fn suffix(&self) -> &'static str {
        match self {
            Zone::Sync => "",
            Zone::Local => "_local",
            Zone::Private => "_private",
        }
    }
}

#[derive(Debug, Clone)]
pub struct JournalEntry {
    pub date: NaiveDate,
    pub time: String,
    pub content: String,
    pub tags: Vec<String>,
}

pub fn extract_tags(text: &str) -> Vec<String> {
    let re = Regex::new(r"#([\p{L}\p{N}_]+)").unwrap();
    let mut tags = Vec::new();
    for cap in re.captures_iter(text) {
        if let Some(m) = cap.get(1) {
            let tag = m.as_str().to_string();
            if !tags.contains(&tag) {
                tags.push(tag);
            }
        }
    }
    tags
}

pub fn get_file_path(base_dir: &Path, date: NaiveDate, suffix: &str) -> PathBuf {
    let year = date.format("%Y").to_string();
    let month = date.format("%m").to_string();
    let day_str = date.format("%Y-%m-%d").to_string();
    let file_name = format!("{}{}.md", day_str, suffix);
    base_dir.join(year).join(month).join(file_name)
}

pub fn ensure_journal_file(path: &Path, date: NaiveDate, is_en: bool) -> io::Result<()> {
    if !path.exists() {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        let title_word = if is_en { "Journal" } else { "日志" };
        let header = format!("# {} {}\n\n", date.format("%Y-%m-%d"), title_word);
        fs::write(path, header)?;
    }
    Ok(())
}

pub fn append_entry(path: &Path, content: &str, time_str: &str) -> io::Result<()> {
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)?;
    let entry_text = format!("## {}\n{}\n\n", time_str, content.trim_end());
    file.write_all(entry_text.as_bytes())?;
    Ok(())
}

pub fn write_entry(
    content: &str,
    zone: Zone,
    config: &Config,
    is_en: bool,
) -> io::Result<PathBuf> {
    let now = Local::now();
    let date = now.date_naive();
    let time_str = now.format("%H:%M:%S").to_string();

    let primary_file = match zone {
        Zone::Sync => {
            let sync_file = get_file_path(&config.sync_dir, date, "");
            ensure_journal_file(&sync_file, date, is_en)?;
            append_entry(&sync_file, content, &time_str)?;

            let local_file = get_file_path(&config.local_dir, date, "_local");
            ensure_journal_file(&local_file, date, is_en)?;
            append_entry(&local_file, content, &time_str)?;

            sync_file
        }
        Zone::Local => {
            let local_file = get_file_path(&config.local_dir, date, "_local");
            ensure_journal_file(&local_file, date, is_en)?;
            append_entry(&local_file, content, &time_str)?;
            local_file
        }
        Zone::Private => {
            let private_file = get_file_path(&config.private_dir, date, "_private");
            ensure_journal_file(&private_file, date, is_en)?;
            append_entry(&private_file, content, &time_str)?;
            private_file
        }
    };

    Ok(primary_file)
}

pub fn parse_file(path: &Path, date: NaiveDate) -> io::Result<Vec<JournalEntry>> {
    if !path.exists() {
        return Ok(Vec::new());
    }
    let content = fs::read_to_string(path)?;
    let mut entries = Vec::new();

    let mut current_time = String::new();
    let mut current_content = Vec::new();

    for line in content.lines() {
        if line.starts_with("## ") {
            if !current_time.is_empty() {
                let text = current_content.join("\n").trim().to_string();
                let tags = extract_tags(&text);
                entries.push(JournalEntry {
                    date,
                    time: current_time.clone(),
                    content: text,
                    tags,
                });
                current_content.clear();
            }
            current_time = line.trim_start_matches('#').trim().to_string();
        } else if !current_time.is_empty() {
            current_content.push(line);
        }
    }

    if !current_time.is_empty() {
        let text = current_content.join("\n").trim().to_string();
        let tags = extract_tags(&text);
        entries.push(JournalEntry {
            date,
            time: current_time,
            content: text,
            tags,
        });
    }

    Ok(entries)
}

pub fn parse_date_from_filename(filename: &str) -> Option<NaiveDate> {
    // Expects format YYYY-MM-DD or YYYY-MM-DD_local or YYYY-MM-DD_private
    let prefix = filename.strip_suffix(".md")?;
    let date_str = prefix.split('_').next()?;
    NaiveDate::parse_from_str(date_str, "%Y-%m-%d").ok()
}
