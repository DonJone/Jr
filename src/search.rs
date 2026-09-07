use colored::*;
use std::collections::HashMap;

use crate::config::Config;
use crate::journal::{parse_file, Zone};
use crate::view::get_all_journal_files;

pub fn highlight_match(text: &str, query: &str) -> String {
    let re = match regex::RegexBuilder::new(&regex::escape(query))
        .case_insensitive(true)
        .build()
    {
        Ok(r) => r,
        Err(_) => return text.to_string(),
    };

    re.replace_all(text, |caps: &regex::Captures| {
        caps[0].bold().black().on_yellow().to_string()
    })
    .to_string()
}

pub fn search(query: &str, zone: Zone, config: &Config, is_tag: bool, is_en: bool) {
    let base_dir = match zone {
        Zone::Sync => &config.sync_dir,
        Zone::Local => &config.local_dir,
        Zone::Private => &config.private_dir,
    };

    let files = get_all_journal_files(base_dir, zone.suffix());
    if files.is_empty() {
        let msg = if is_en { "No journal files found." } else { "未找到任何日志文件。" };
        println!("{}", msg.yellow());
        return;
    }

    let search_target = if is_tag && !query.starts_with('#') {
        format!("#{}", query)
    } else {
        query.to_string()
    };

    let query_lower = search_target.to_lowercase();
    let mut total_matches = 0;
    let mut matched_days = 0;

    println!();
    let banner = if is_en {
        format!("Search results for '{}' in {}:", search_target, zone.name_en())
    } else {
        format!("在{}中搜索 '{}' 的结果：", zone.name_zh(), search_target)
    };
    println!("{}", banner.bold().cyan());
    println!("{}", "═".repeat(50).dimmed());

    for (date, path) in files {
        if let Ok(entries) = parse_file(&path, date) {
            let mut day_has_match = false;

            for entry in entries {
                let matches_content = entry.content.to_lowercase().contains(&query_lower);
                let matches_tags = is_tag && entry.tags.iter().any(|t| {
                    format!("#{}", t.to_lowercase()) == query_lower || t.to_lowercase() == query_lower
                });

                if matches_content || matches_tags {
                    if !day_has_match {
                        day_has_match = true;
                        matched_days += 1;
                        println!(
                            "\n{} {}",
                            "📅".green(),
                            date.format("%Y-%m-%d").to_string().bold()
                        );
                    }
                    total_matches += 1;

                    println!("   {} {}", "🕒".blue(), entry.time.bold().dimmed());
                    for line in entry.content.lines() {
                        if line.to_lowercase().contains(&query_lower) {
                            println!("     {}", highlight_match(line, &search_target));
                        }
                    }
                    if !entry.tags.is_empty() {
                        let tags_str: Vec<String> = entry
                            .tags
                            .iter()
                            .map(|t| {
                                if is_tag && t.to_lowercase() == query_lower.trim_start_matches('#') {
                                    format!("#{}", t).bold().yellow().to_string()
                                } else {
                                    format!("#{}", t).dimmed().to_string()
                                }
                            })
                            .collect();
                        println!("     {} {}", "🏷 ".dimmed(), tags_str.join(" "));
                    }
                }
            }
        }
    }

    println!();
    println!("{}", "─".repeat(50).dimmed());
    let summary = if is_en {
        format!("Found {} matching entries across {} days.", total_matches, matched_days)
    } else {
        format!("共找到 {} 条匹配记录，分布在 {} 天中。", total_matches, matched_days)
    };
    println!("{}", summary.bold().green());
    println!();
}

pub fn list_tags(zone: Zone, config: &Config, is_en: bool) {
    let base_dir = match zone {
        Zone::Sync => &config.sync_dir,
        Zone::Local => &config.local_dir,
        Zone::Private => &config.private_dir,
    };

    let files = get_all_journal_files(base_dir, zone.suffix());
    let mut tag_counts: HashMap<String, usize> = HashMap::new();

    for (date, path) in files {
        if let Ok(entries) = parse_file(&path, date) {
            for entry in entries {
                for tag in entry.tags {
                    *tag_counts.entry(tag).or_insert(0) += 1;
                }
            }
        }
    }

    if tag_counts.is_empty() {
        let msg = if is_en { "No tags found in journals." } else { "未在日志中发现任何标签（如 #tag）。" };
        println!("{}", msg.yellow());
        return;
    }

    let mut sorted_tags: Vec<(String, usize)> = tag_counts.into_iter().collect();
    sorted_tags.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));

    println!();
    let title = if is_en {
        format!("All Tags in {} (Total: {})", zone.name_en(), sorted_tags.len())
    } else {
        format!("{}标签汇总 (共 {} 个标签)", zone.name_zh(), sorted_tags.len())
    };
    println!("{}", title.bold().cyan());
    println!("{}", "═".repeat(50).dimmed());
    println!();

    for (tag, count) in sorted_tags {
        let count_str = format!("x{}", count).dimmed();
        let bar = "■".repeat((count.min(20)).max(1)).green();
        println!("  #{:<18} {:<6} {}", tag.bold().yellow(), count_str, bar);
    }
    println!();
}
