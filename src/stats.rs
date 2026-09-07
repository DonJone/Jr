use chrono::{Local, NaiveDate};
use colored::*;
use std::collections::{BTreeMap, HashMap, HashSet};
use std::fs;

use crate::config::Config;
use crate::journal::{parse_file, Zone};
use crate::view::get_all_journal_files;

pub fn calculate_streak(dates: &HashSet<NaiveDate>) -> (usize, usize) {
    if dates.is_empty() {
        return (0, 0);
    }

    let mut sorted_dates: Vec<NaiveDate> = dates.iter().cloned().collect();
    sorted_dates.sort();

    // Longest streak
    let mut longest = 1;
    let mut current_run = 1;
    for i in 1..sorted_dates.len() {
        if sorted_dates[i] == sorted_dates[i - 1].succ_opt().unwrap_or(sorted_dates[i]) {
            current_run += 1;
            if current_run > longest {
                longest = current_run;
            }
        } else if sorted_dates[i] != sorted_dates[i - 1] {
            current_run = 1;
        }
    }

    // Current streak (ending today or yesterday)
    let today = Local::now().date_naive();
    let yesterday = today.pred_opt().unwrap_or(today);

    let mut current_streak = 0;
    let mut check_date = if dates.contains(&today) {
        today
    } else if dates.contains(&yesterday) {
        yesterday
    } else {
        return (0, longest);
    };

    while dates.contains(&check_date) {
        current_streak += 1;
        if let Some(prev) = check_date.pred_opt() {
            check_date = prev;
        } else {
            break;
        }
    }

    (current_streak, longest)
}

pub fn show_stats(config: &Config, is_en: bool) {
    let zones = [
        (Zone::Sync, &config.sync_dir),
        (Zone::Local, &config.local_dir),
        (Zone::Private, &config.private_dir),
    ];

    let mut all_dates: HashSet<NaiveDate> = HashSet::new();
    let mut total_entries = 0;
    let mut total_words = 0;
    let mut tag_counts: HashMap<String, usize> = HashMap::new();
    let mut monthly_counts: BTreeMap<String, usize> = BTreeMap::new();
    let mut total_size_bytes: u64 = 0;

    for (zone, base_dir) in &zones {
        let files = get_all_journal_files(base_dir, zone.suffix());
        for (date, path) in files {
            all_dates.insert(date);
            if let Ok(metadata) = fs::metadata(&path) {
                total_size_bytes += metadata.len();
            }
            if let Ok(entries) = parse_file(&path, date) {
                total_entries += entries.len();
                let month_key = date.format("%Y-%m").to_string();
                *monthly_counts.entry(month_key).or_insert(0) += entries.len();

                for entry in entries {
                    total_words += entry.content.split_whitespace().count();
                    for tag in entry.tags {
                        *tag_counts.entry(tag).or_insert(0) += 1;
                    }
                }
            }
        }
    }

    let (current_streak, longest_streak) = calculate_streak(&all_dates);

    println!();
    println!("{}", "┌─────────────────────────────────────────┐".cyan());
    println!(
        "{}  {}  {}",
        "│".cyan(),
        if is_en { "📊  jr Journal Dashboard & Statistics" } else { "📊  jr 日志看板与统计数据" }.bold(),
        "│".cyan()
    );
    println!("{}", "└─────────────────────────────────────────┘".cyan());
    println!();

    println!(
        "  {} {:<18} : {}",
        "📅".bold(),
        if is_en { "Active Days" } else { "活跃天数" },
        format!("{} 天", all_dates.len()).green().bold()
    );
    println!(
        "  {} {:<18} : {}",
        "📝".bold(),
        if is_en { "Total Entries" } else { "记录总数" },
        format!("{} 条", total_entries).green().bold()
    );
    println!(
        "  {} {:<18} : {}",
        "🔥".bold(),
        if is_en { "Current Streak" } else { "连续打卡" },
        format!("{} 天", current_streak).yellow().bold()
    );
    println!(
        "  {} {:<18} : {}",
        "🏆".bold(),
        if is_en { "Longest Streak" } else { "最长连续" },
        format!("{} 天", longest_streak).yellow().bold()
    );
    println!(
        "  {} {:<18} : {}",
        "📖".bold(),
        if is_en { "Estimated Words" } else { "估算词数" },
        format!("{} 词", total_words).blue().bold()
    );
    println!(
        "  {} {:<18} : {}",
        "💾".bold(),
        if is_en { "Storage Size" } else { "数据体积" },
        format!("{:.1} KB", total_size_bytes as f64 / 1024.0).dimmed()
    );

    // Top tags
    if !tag_counts.is_empty() {
        println!();
        println!(
            "  {}",
            if is_en { "🏷  Top Tags:" } else { "🏷  高频标签：" }.bold().cyan()
        );
        let mut sorted_tags: Vec<(String, usize)> = tag_counts.into_iter().collect();
        sorted_tags.sort_by(|a, b| b.1.cmp(&a.1));
        for (tag, count) in sorted_tags.into_iter().take(5) {
            println!("    #{:<15} x{}", tag.yellow(), count);
        }
    }

    // Monthly Activity
    if !monthly_counts.is_empty() {
        println!();
        println!(
            "  {}",
            if is_en { "📈 Monthly Activity:" } else { "📈 月度活跃走势：" }.bold().cyan()
        );
        let max_month_count = monthly_counts.values().cloned().max().unwrap_or(1);
        for (month, count) in monthly_counts.iter().rev().take(6) {
            let bar_len = ((count * 25) / max_month_count.max(1)).max(1);
            let bar = "█".repeat(bar_len).green();
            println!("    {} | {:<4} {}", month, count, bar);
        }
    }

    println!();
}
