//! Lux Rust Test Runner Binary
//! 
//! CLI tool for running Rust tests with coverage and mix integration.

use lux_rs::{TestSuiteConfig, run_tests, run_with_coverage, print_results, print_coverage_report};
use std::env;

fn main() {
    let args: Vec<String> = env::args().collect();
    
    let mut config = TestSuiteConfig::default();
    let mut run_coverage = false;
    
    // Parse arguments
    for arg in &args[1..] {
        match arg.as_str() {
            "--coverage" | "-c" => run_coverage = true,
            "--name" | "-n" => {
                if let Some(idx) = args.iter().position(|a| a == arg) {
                    if let Some(name) = args.get(idx + 1) {
                        config.name = name.clone();
                    }
                }
            },
            "--help" | "-h" => {
                print_usage();
                return;
            },
            _ => {}
        }
    }
    
    if run_coverage {
        let (results, coverage) = run_with_coverage(config);
        let summary = lux_rs::LuxTestRunner::new(config.clone()).summary();
        print_results(&results, &summary);
        print_coverage_report(&coverage);
    } else {
        let (results, summary) = run_tests(config);
        print_results(&results, &summary);
    }
}

fn print_usage() {
    println!("Lux Rust Test Runner");
    println!();
    println!("Usage: lux-rs-test [options]");
    println!();
    println!("Options:");
    println!("  --coverage, -c    Run with coverage reporting");
    println!("  --name, -n <name> Set test suite name");
    println!("  --help, -h        Show this help message");
}
