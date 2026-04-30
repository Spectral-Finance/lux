//! Serialization utilities for Lux framework
//!
//! This module provides optimized JSON serialization/deserialization,
//! hashing, and EIP-55 address checksumming.

use pyo3::prelude::*;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use thiserror::Error;

/// Serialization errors
#[derive(Debug, Error)]
pub enum SerializationError {
    #[error("JSON error: {0}")]
    JsonError(String),
    #[error("Hex decode error: {0}")]
    HexError(String),
    #[error("Invalid address: {0}")]
    InvalidAddress(String),
}

/// Convert a Python object to a JSON string
pub fn to_json(obj: &Bound<'_, PyAny>) -> Result<String, SerializationError> {
    let py = obj.py();

    // Use Python's json module for serialization
    let json_module = py
        .import("json")
        .map_err(|e| SerializationError::JsonError(e.to_string()))?;

    let dumps = json_module
        .getattr("dumps")
        .map_err(|e| SerializationError::JsonError(e.to_string()))?;

    let result = dumps
        .call1((obj,))
        .map_err(|e| SerializationError::JsonError(e.to_string()))?;

    result
        .extract::<String>()
        .map_err(|e| SerializationError::JsonError(e.to_string()))
}

/// Convert a JSON value to a Python object
pub fn json_to_python<'py>(
    py: Python<'py>,
    value: &serde_json::Value,
) -> Result<PyObject, SerializationError> {
    match value {
        serde_json::Value::Null => Ok(py.None()),
        serde_json::Value::Bool(b) => Ok((*b).into_py(py)),
        serde_json::Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                Ok(i.into_py(py))
            } else if let Some(f) = n.as_f64() {
                Ok(f.into_py(py))
            } else {
                Err(SerializationError::JsonError("Invalid number".to_string()))
            }
        }
        serde_json::Value::String(s) => Ok(s.clone().into_py(py)),
        serde_json::Value::Array(arr) => {
            let list: Vec<PyObject> = arr
                .iter()
                .map(|v| json_to_python(py, v))
                .collect::<Result<Vec<_>, _>>()?;
            Ok(list.into_py(py))
        }
        serde_json::Value::Object(map) => {
            let dict = pyo3::types::PyDict::new(py);
            for (k, v) in map {
                let key: PyObject = k.clone().into_py(py);
                let val = json_to_python(py, v)?;
                dict.set_item(key, val)
                    .map_err(|e| SerializationError::JsonError(e.to_string()))?;
            }
            Ok(dict.into())
        }
    }
}

/// Compute SHA-256 hash of input data
pub fn compute_sha256(data: &str) -> Result<String, SerializationError> {
    let mut hasher = Sha256::new();
    hasher.update(data.as_bytes());
    let result = hasher.finalize();
    Ok(hex::encode(result))
}

/// Compute EIP-55 checksummed address
pub fn eip55_checksum(address: &str) -> Result<String, SerializationError> {
    // Remove 0x prefix if present
    let addr = address.strip_prefix("0x").unwrap_or(address);

    // Validate address length
    if addr.len() != 40 {
        return Err(SerializationError::InvalidAddress(
            "Address must be 40 hex characters (excluding 0x prefix)".to_string(),
        ));
    }

    // Validate hex characters
    let lower = addr.to_lowercase();
    hex::decode(&lower)
        .map_err(|_| SerializationError::InvalidAddress("Invalid hex characters".to_string()))?;

    // Hash the lowercase address
    let mut hasher = Sha256::new();
    hasher.update(lower.as_bytes());
    let hash = hasher.finalize();
    let hash_hex = hex::encode(hash);

    // Apply checksum
    let mut result = String::with_capacity(42);
    result.push_str("0x");

    for (i, c) in lower.chars().enumerate() {
        let hash_char = hash_hex
            .chars()
            .nth(i)
            .unwrap_or('0');

        if hash_char.to_digit(16).unwrap_or(0) >= 8 {
            result.push(c.to_ascii_uppercase());
        } else {
            result.push(c);
        }
    }

    Ok(result)
}

/// Convert wei to ether
pub fn wei_to_ether(wei: &str) -> Result<String, SerializationError> {
    let wei_value: u128 = wei
        .parse()
        .map_err(|_| SerializationError::InvalidAddress("Invalid wei value".to_string()))?;

    // Format with 18 decimal places
    let whole = wei_value / 1_000_000_000_000_000_000;
    let fraction = wei_value % 1_000_000_000_000_000_000;

    Ok(format!("{}.{}", whole, format!("{:018}", fraction)))
}

/// Convert ether to wei
pub fn ether_to_ether(ether: &str) -> Result<String, SerializationError> {
    let parts: Vec<&str> = ether.split('.').collect();

    let whole: u128 = parts[0]
        .parse()
        .map_err(|_| SerializationError::InvalidAddress("Invalid ether value".to_string()))?;

    let fraction = if parts.len() > 1 {
        let frac_str = parts[1];
        let padded = format!("{:0<18}", frac_str);
        let truncated = &padded[..padded.len().min(18)];
        truncated.parse::<u128>().unwrap_or(0)
    } else {
        0
    };

    Ok((whole * 1_000_000_000_000_000_000 + fraction).to_string())
}

/// Format gas price to Gwei
pub fn gas_to_gwei(gas_price: u64) -> String {
    format!("{:.9}", gas_price as f64 / 1_000_000_000.0)
}

/// Parse hex string to bytes
pub fn hex_to_bytes(hex_str: &str) -> Result<Vec<u8>, SerializationError> {
    let hex = hex_str.strip_prefix("0x").unwrap_or(hex_str);
    hex::decode(hex).map_err(|e| SerializationError::HexError(e.to_string()))
}

/// Convert bytes to hex string
pub fn bytes_to_hex(bytes: &[u8], with_prefix: bool) -> String {
    if with_prefix {
        format!("0x{}", hex::encode(bytes))
    } else {
        hex::encode(bytes)
    }
}

/// Truncate an address for display
pub fn truncate_address(address: &str, chars: usize) -> String {
    let addr = address.strip_prefix("0x").unwrap_or(address);
    if addr.len() <= chars * 2 + 1 {
        return format!("0x{}", addr);
    }
    format!(
        "0x{}...{}",
        &addr[..chars],
        &addr[addr.len() - chars..]
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sha256() {
        let hash = compute_sha256("hello").unwrap();
        assert_eq!(
            hash,
            "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        );
    }

    #[test]
    fn test_eip55_checksum() {
        // Known test vectors from EIP-55
        let addr = "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae";
        let checksummed = eip55_checksum(addr).unwrap();
        assert_eq!(checksummed, "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe");

        // Without prefix
        let addr_no_prefix = "de0b295669a9fd93d5f28d9ec85e40f4cb697bae";
        let checksummed2 = eip55_checksum(addr_no_prefix).unwrap();
        assert_eq!(checksummed2, "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe");
    }

    #[test]
    fn test_eip55_checksum_vitalik() {
        let addr = "0x82a1caf6b9e27437f5417ed1c7c29876162467db";
        let checksummed = eip55_checksum(addr).unwrap();
        assert_eq!(checksummed, "0x82A1CaF6b9e27437f5417ed1C7C29876162467dB");
    }

    #[test]
    fn test_wei_to_ether() {
        assert_eq!(wei_to_ether("1000000000000000000").unwrap(), "1.000000000000000000");
        assert_eq!(wei_to_ether("0").unwrap(), "0.000000000000000000");
        assert_eq!(wei_to_ether("1").unwrap(), "0.000000000000000001");
    }

    #[test]
    fn test_gas_to_gwei() {
        assert_eq!(gas_to_gwei(50_000_000_000), "50.000000000");
        assert_eq!(gas_to_gwei(1_000_000_000), "1.000000000");
    }

    #[test]
    fn test_hex_to_bytes() {
        let bytes = hex_to_bytes("0x48656c6c6f").unwrap();
        assert_eq!(bytes, vec![72, 101, 108, 108, 111]); // "Hello"
    }

    #[test]
    fn test_bytes_to_hex() {
        let hex = bytes_to_hex(&[72, 101, 108, 108, 111], true);
        assert_eq!(hex, "0x48656c6c6f");
    }

    #[test]
    fn test_truncate_address() {
        let addr = "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae";
        let truncated = truncate_address(addr, 4);
        assert_eq!(truncated, "0xde0b...7bae");
    }

    #[test]
    fn test_invalid_address() {
        assert!(eip55_checksum("invalid").is_err());
        assert!(eip55_checksum("0xshort").is_err());
    }
}
