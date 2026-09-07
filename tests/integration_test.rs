use chrono::{Local, NaiveDate};
use jr::config::Config;
use jr::journal::{
    extract_tags, parse_date_from_filename, parse_file, write_entry, Zone,
};
use jr::lock::JrLock;
use jr::stats::calculate_streak;
use std::collections::HashSet;
use tempfile::tempdir;

#[test]
fn test_tag_extraction() {
    let sample = "Working on #rust and #performance today. Met with #team_core and #日常.";
    let tags = extract_tags(sample);
    assert_eq!(tags, vec!["rust", "performance", "team_core", "日常"]);

    let no_tags = "Just a regular note without any hashtags.";
    assert!(extract_tags(no_tags).is_empty());
}

#[test]
fn test_parse_date_from_filename() {
    assert_eq!(
        parse_date_from_filename("2026-05-04.md"),
        Some(NaiveDate::from_ymd_opt(2026, 5, 4).unwrap())
    );
    assert_eq!(
        parse_date_from_filename("2026-05-04_local.md"),
        Some(NaiveDate::from_ymd_opt(2026, 5, 4).unwrap())
    );
    assert_eq!(
        parse_date_from_filename("2026-05-04_private.md"),
        Some(NaiveDate::from_ymd_opt(2026, 5, 4).unwrap())
    );
    assert_eq!(parse_date_from_filename("notes.txt"), None);
}

#[test]
fn test_write_and_parse_journal_entries() {
    let tmp = tempdir().unwrap();
    let config = Config {
        sync_dir: tmp.path().join("Journal"),
        local_dir: tmp.path().join("Journal_local"),
        private_dir: tmp.path().join("Journal_private"),
        editor: None,
        auto_sync: false,
    };

    let note1 = "First entry for the day #test";
    let file1 = write_entry(note1, Zone::Sync, &config, true).unwrap();
    assert!(file1.exists());

    // In Sync zone, local_dir should also have a copy
    let today = Local::now().date_naive();
    let local_copy = jr::journal::get_file_path(&config.local_dir, today, "_local");
    assert!(local_copy.exists());

    let note2 = "Second entry with #rust and multiple lines\nLine two.";
    write_entry(note2, Zone::Sync, &config, true).unwrap();

    let entries = parse_file(&file1, today).unwrap();
    assert_eq!(entries.len(), 2);
    assert_eq!(entries[0].tags, vec!["test"]);
    assert!(entries[0].content.contains("First entry for the day #test"));
    assert_eq!(entries[1].tags, vec!["rust"]);
    assert!(entries[1].content.contains("Line two."));
}

#[test]
fn test_private_isolation() {
    let tmp = tempdir().unwrap();
    let config = Config {
        sync_dir: tmp.path().join("Journal"),
        local_dir: tmp.path().join("Journal_local"),
        private_dir: tmp.path().join("Journal_private"),
        editor: None,
        auto_sync: false,
    };

    let secret = "Super secret password: 123456";
    let private_file = write_entry(secret, Zone::Private, &config, true).unwrap();

    assert!(private_file.exists());
    // Should NOT exist in sync or local
    assert!(!config.sync_dir.exists());
    assert!(!config.local_dir.exists());
}

#[test]
fn test_streak_calculation() {
    let today = Local::now().date_naive();
    let yesterday = today.pred_opt().unwrap();
    let day_before = yesterday.pred_opt().unwrap();

    let mut dates = HashSet::new();
    dates.insert(today);
    dates.insert(yesterday);
    dates.insert(day_before);

    let (current, longest) = calculate_streak(&dates);
    assert_eq!(current, 3);
    assert_eq!(longest, 3);

    // Add a gap
    let old_date = NaiveDate::from_ymd_opt(2025, 1, 1).unwrap();
    dates.insert(old_date);
    let (current2, longest2) = calculate_streak(&dates);
    assert_eq!(current2, 3);
    assert_eq!(longest2, 3);
}

#[test]
fn test_lock_acquire_and_release() {
    let lock1 = JrLock::acquire();
    assert!(lock1.is_ok(), "First lock should be acquired");

    let lock2 = JrLock::acquire();
    assert!(lock2.is_err(), "Second lock should fail while first is held");

    drop(lock1);

    let lock3 = JrLock::acquire();
    assert!(lock3.is_ok(), "Lock should be re-acquirable after drop");
}
