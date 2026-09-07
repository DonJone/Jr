use std::env;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Language {
    En,
    Zh,
}

impl Language {
    pub fn detect() -> Self {
        let check_var = |var: &str| -> Option<bool> {
            env::var(var).ok().map(|val| {
                let lower = val.to_lowercase();
                lower.starts_with("en")
            })
        };

        if let Some(is_en) = check_var("LC_ALL") {
            if is_en { return Language::En; } else { return Language::Zh; }
        }
        if let Some(is_en) = check_var("LC_MESSAGES") {
            if is_en { return Language::En; } else { return Language::Zh; }
        }
        if let Some(is_en) = check_var("LANG") {
            if is_en { return Language::En; } else { return Language::Zh; }
        }

        Language::Zh
    }

    pub fn is_en(&self) -> bool {
        matches!(self, Language::En)
    }
}
