//! Coverage Reporting Module
//! 
//! Provides coverage tracking and reporting for Rust tests in Lux.

use std::collections::HashSet;
use serde::{Deserialize, Serialize};

/// Coverage report for a test run
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CoverageReport {
    pub total_lines: usize,
    pub covered_lines: usize,
    pub coverage_percentage: f64,
    pub uncovered_lines: Vec<usize>,
    pub file_coverage: HashMap<String, FileCoverage>,
}

/// Coverage for a single file
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileCoverage {
    pub path: String,
    pub total_lines: usize,
    pub covered_lines: usize,
    pub coverage_percentage: f64,
}

/// Coverage tracker
pub struct CoverageTracker {
    covered_lines: HashSet<(String, usize)>,
    all_lines: HashSet<(String, usize)>,
}

impl Default for CoverageTracker {
    fn default() -> Self {
        Self::new()
    }
}

impl CoverageTracker {
    pub fn new() -> Self {
        Self {
            covered_lines: HashSet::new(),
            all_lines: HashSet::new(),
        }
    }
    
    /// Record that a line was executed
    pub fn record_execution(&mut self, file: &str, line: usize) {
        self.covered_lines.insert((file.to_string(), line));
        self.all_lines.insert((file.to_string(), line));
    }
    
    /// Record all lines in a file
    pub fn record_file(&mut self, file: &str, lines: &[usize]) {
        for &line in lines {
            self.all_lines.insert((file.to_string(), line));
        }
    }
    
    /// Generate coverage report
    pub fn report(&self) -> CoverageReport {
        let total_lines = self.all_lines.len();
        let covered_lines = self.covered_lines.len();
        let coverage_percentage = if total_lines > 0 {
            (covered_lines as f64 / total_lines as f64) * 100.0
        } else {
            100.0
        };
        
        let uncovered_lines: Vec<usize> = self.all_lines
            .difference(&self.covered_lines)
            .map(|(_, line)| *line)
            .collect();
        
        // Calculate per-file coverage
        let mut file_coverage = HashMap::new();
        let mut files: HashSet<String> = HashSet::new();
        for (file, _) in &self.all_lines {
            files.insert(file.clone());
        }
        
        for file in files {
            let file_all: HashSet<usize> = self.all_lines
                .iter()
                .filter(|(f, _)| f == &file)
                .map(|(_, line)| *line)
                .collect();
            let file_covered: HashSet<usize> = self.covered_lines
                .iter()
                .filter(|(f, _)| f == &file)
                .map(|(_, line)| *line)
                .collect();
            
            let file_total = file_all.len();
            let file_covered_count = file_covered.len();
            let file_pct = if file_total > 0 {
                (file_covered_count as f64 / file_total as f64) * 100.0
            } else {
                100.0
            };
            
            file_coverage.insert(file.clone(), FileCoverage {
                path: file,
                total_lines: file_total,
                covered_lines: file_covered_count,
                coverage_percentage: file_pct,
            });
        }
        
        CoverageReport {
            total_lines,
            covered_lines,
            coverage_percentage,
            uncovered_lines,
            file_coverage,
        }
    }
    
    /// Export report as JSON
    pub fn to_json(&self) -> String {
        serde_json::to_string_pretty(&self.report()).unwrap_or_default()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_coverage_tracking() {
        let mut tracker = CoverageTracker::new();
        
        tracker.record_file("test.rs", &[1, 2, 3, 4, 5]);
        tracker.record_execution("test.rs", 1);
        tracker.record_execution("test.rs", 2);
        tracker.record_execution("test.rs", 4);
        
        let report = tracker.report();
        assert_eq!(report.total_lines, 5);
        assert_eq!(report.covered_lines, 3);
        assert!((report.coverage_percentage - 60.0).abs() < 0.1);
    }
    
    #[test]
    fn test_json_export() {
        let tracker = CoverageTracker::new();
        let json = tracker.to_json();
        assert!(json.contains("coverage_percentage"));
    }
}
