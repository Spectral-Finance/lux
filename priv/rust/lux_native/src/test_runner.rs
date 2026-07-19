use std::process::Command;

pub fn run_test(test_code: &str) -> Result<String, String> {
    let temp_dir = tempfile::tempdir().map_err(|e| e.to_string())?;
    let test_path = temp_dir.path().join("test.rs");
    std::fs::write(&test_path, test_code).map_err(|e| e.to_string())?;

    let output = Command::new("rustc")
        .arg("--test")
        .arg(&test_path)
        .arg("-o")
        .arg(temp_dir.path().join("test_bin"))
        .output()
        .map_err(|e| e.to_string())?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("Compilation failed:\n{stderr}"));
    }

    let test_output = Command::new(temp_dir.path().join("test_bin"))
        .output()
        .map_err(|e| e.to_string())?;

    let stdout = String::from_utf8_lossy(&test_output.stdout);
    let stderr = String::from_utf8_lossy(&test_output.stderr);

    if test_output.status.success() {
        Ok(format!("PASSED\n{stdout}"))
    } else {
        Ok(format!("FAILED\n{stdout}\n{stderr}"))
    }
}

pub fn generate_fixture(name: &str, data: &str) -> Result<String, String> {
    Ok(format!(
        "// Fixture: {name}\n// Auto-generated test data\n{}\n",
        data
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn test_generate_fixture() {
        let f = generate_fixture("test", "data").unwrap();
        assert!(f.contains("Fixture: test"));
    }
}
