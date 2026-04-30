//! Lux Core - Rust integration for the Lux framework
//!
//! This module provides high-performance Rust implementations of core Lux
//! data processing primitives, exposed to Python via pyo3 bindings.
//!
//! # Features
//!
//! - **Data Aggregation**: Efficient multi-chain data aggregation primitives
//! - **Prism Processing**: High-performance prism implementations
//! - **Evaluation Engine**: Fast Python code execution with caching
//! - **Serialization**: Optimized JSON/serde-based data serialization
//!
//! # Python Integration
//!
//! This crate is designed to be used as a Python extension module via pyo3.
//! Import it in Python as:
//!
//! ```python
//! import lux_core
//! result = lux_core.evaluate("1 + 1")
//! ```

pub mod data_aggregation;
pub mod prisms;
pub mod eval;
pub mod types;
pub mod serialization;

use pyo3::prelude::*;
use pyo3::wrap_pyfunction;

// Re-export main types for Python
pub use types::*;
pub use serialization::*;

/// Lux Core Python module
#[pymodule]
fn lux_core(m: &Bound<'_, PyModule>) -> PyResult<()> {
    // Evaluation functions
    m.add_function(wrap_pyfunction!(evaluate, m)?)?;
    m.add_function(wrap_pyfunction!(evaluate_with_variables, m)?)?;
    m.add_function(wrap_pyfunction!(execute_code, m)?)?;

    // Data aggregation functions
    m.add_function(wrap_pyfunction!(aggregate_blocks, m)?)?;
    m.add_function(wrap_pyfunction!(aggregate_transactions, m)?)?;
    m.add_function(wrap_pyfunction!(normalize_block, m)?)?;
    m.add_function(wrap_pyfunction!(normalize_transaction, m)?)?;

    // Prism functions
    m.add_function(wrap_pyfunction!(create_prism, m)?)?;
    m.add_function(wrap_pyfunction!(prism_handler, m)?)?;

    // Serialization functions
    m.add_function(wrap_pyfunction!(to_json, m)?)?;
    m.add_function(wrap_pyfunction!(from_json, m)?)?;

    // Utility functions
    m.add_function(wrap_pyfunction!(version, m)?)?;
    m.add_function(wrap_pyfunction!(compute_hash, m)?)?;
    m.add_function(wrap_pyfunction!(checksum_address, m)?)?;

    // Register types
    m.add_class::<BlockData>()?;
    m.add_class::<TransactionData>()?;
    m.add_class::<EventData>()?;
    m.add_class::<PrismResult>()?;

    Ok(())
}

// ============================================================================
// Evaluation Functions
// ============================================================================

/// Evaluate a Python expression and return the result.
///
/// Args:
///     code: Python expression to evaluate
///
/// Returns:
///     Result of the evaluation as a string representation
///
/// # Example
/// ```python
/// >>> import lux_core
/// >>> lux_core.evaluate("2 + 2")
/// '4'
/// ```
#[pyfunction]
fn evaluate(code: &str) -> PyResult<String> {
    eval::evaluate(code).map_err(|e| PyErr::new::<pyo3::exceptions::PyRuntimeError, _>(
        format!("Evaluation error: {}", e)
    ))
}

/// Evaluate Python code with variable bindings.
///
/// Args:
///     code: Python code to evaluate
///     variables: Dictionary of variable bindings
///
/// Returns:
///     Result of the evaluation
///
/// # Example
/// ```python
/// >>> import lux_core
/// >>> lux_core.evaluate_with_variables("x + y", {"x": 40, "y": 2})
/// '42'
/// ```
#[pyfunction]
fn evaluate_with_variables(code: &str, variables: PyObject) -> PyResult<String> {
    Python::with_gil(|py| {
        let vars_dict: std::collections::HashMap<String, String> = variables.extract(py)?;
        eval::evaluate_with_variables(code, &vars_dict).map_err(|e| {
            PyErr::new::<pyo3::exceptions::PyRuntimeError, _>(
                format!("Evaluation error: {}", e)
            )
        })
    })
}

/// Execute Python code (multi-line) and return the last expression result.
///
/// Args:
///     code: Python code to execute
///
/// Returns:
///     Result of the last expression
#[pyfunction]
fn execute_code(code: &str) -> PyResult<String> {
    eval::execute_code(code).map_err(|e| PyErr::new::<pyo3::exceptions::PyRuntimeError, _>(
        format!("Execution error: {}", e)
    ))
}

// ============================================================================
// Data Aggregation Functions
// ============================================================================

/// Aggregate block data from multiple chains.
///
/// Args:
///     blocks: List of block data as JSON strings
///     chain_id: Optional chain ID filter
///
/// Returns:
///     Aggregated block statistics as JSON
#[pyfunction]
fn aggregate_blocks(blocks: Vec<String>, chain_id: Option<u64>) -> PyResult<String> {
    let parsed_blocks: Result<Vec<data_aggregation::BlockInfo>, _> = blocks
        .iter()
        .map(|b| serde_json::from_str(b))
        .collect();

    let blocks = parsed_blocks.map_err(|e| {
        PyErr::new::<pyo3::exceptions::PyValueError, _>(
            format!("Failed to parse block data: {}", e)
        )
    })?;

    let aggregated = data_aggregation::aggregate_blocks(&blocks, chain_id);
    serde_json::to_string(&aggregated).map_err(|e| {
        PyErr::new::<pyo3::exceptions::PyRuntimeError, _>(
            format!("Serialization error: {}", e)
        )
    })
}

/// Aggregate transaction data.
///
/// Args:
///     transactions: List of transaction data as JSON strings
///
/// Returns:
///     Aggregated transaction statistics as JSON
#[pyfunction]
fn aggregate_transactions(transactions: Vec<String>) -> PyResult<String> {
    let parsed_txs: Result<Vec<data_aggregation::TransactionInfo>, _> = transactions
        .iter()
        .map(|t| serde_json::from_str(t))
        .collect();

    let txs = parsed_txs.map_err(|e| {
        PyErr::new::<pyo3::exceptions::PyValueError, _>(
            format!("Failed to parse transaction data: {}", e)
        )
    })?;

    let aggregated = data_aggregation::aggregate_transactions(&txs);
    serde_json::to_string(&aggregated).map_err(|e| {
        PyErr::new::<pyo3::exceptions::PyRuntimeError, _>(
            format!("Serialization error: {}", e)
        )
    })
}

/// Normalize block data to a standard format.
///
/// Args:
///     block_json: Block data as JSON string
///     chain_id: Chain ID for chain-specific normalization
///
/// Returns:
///     Normalized block data as JSON
#[pyfunction]
fn normalize_block(block_json: &str, chain_id: u64) -> PyResult<String> {
    let block: data_aggregation::BlockInfo = serde_json::from_str(block_json).map_err(|e| {
        PyErr::new::<pyo3::exceptions::PyValueError, _>(
            format!("Failed to parse block data: {}", e)
        )
    })?;

    let normalized = data_aggregation::normalize_block(&block, chain_id);
    serde_json::to_string(&normalized).map_err(|e| {
        PyErr::new::<pyo3::exceptions::PyRuntimeError, _>(
            format!("Serialization error: {}", e)
        )
    })
}

/// Normalize transaction data to a standard format.
///
/// Args:
///     tx_json: Transaction data as JSON string
///     chain_id: Chain ID for chain-specific normalization
///
/// Returns:
///     Normalized transaction data as JSON
#[pyfunction]
fn normalize_transaction(tx_json: &str, chain_id: u64) -> PyResult<String> {
    let tx: data_aggregation::TransactionInfo = serde_json::from_str(tx_json).map_err(|e| {
        PyErr::new::<pyo3::exceptions::PyValueError, _>(
            format!("Failed to parse transaction data: {}", e)
        )
    })?;

    let normalized = data_aggregation::normalize_transaction(&tx, chain_id);
    serde_json::to_string(&normalized).map_err(|e| {
        PyErr::new::<pyo3::exceptions::PyRuntimeError, _>(
            format!("Serialization error: {}", e)
        )
    })
}

// ============================================================================
// Prism Functions
// ============================================================================

/// Create a new prism instance.
///
/// Args:
///     name: Prism name
///     prism_type: Prism type identifier
///     config: Optional configuration as JSON string
///
/// Returns:
///     Prism configuration as JSON
#[pyfunction]
fn create_prism(name: &str, prism_type: &str, config: Option<&str>) -> PyResult<String> {
    let cfg = config.map(|c| serde_json::from_str(c).unwrap_or_default());
    let prism = prisms::create_prism(name, prism_type, cfg);
    serde_json::to_string(&prism).map_err(|e| {
        PyErr::new::<pyo3::exceptions::PyRuntimeError, _>(
            format!("Serialization error: {}", e)
        )
    })
}

/// Handle prism input and return result.
///
/// Args:
///     prism_json: Prism configuration as JSON
///     input_json: Input data as JSON
///
/// Returns:
///     Prism result as JSON
#[pyfunction]
fn prism_handler(prism_json: &str, input_json: &str) -> PyResult<String> {
    let prism: prisms::PrismConfig = serde_json::from_str(prism_json).map_err(|e| {
        PyErr::new::<pyo3::exceptions::PyValueError, _>(
            format!("Failed to parse prism config: {}", e)
        )
    })?;

    let input: serde_json::Value = serde_json::from_str(input_json).map_err(|e| {
        PyErr::new::<pyo3::exceptions::PyValueError, _>(
            format!("Failed to parse input: {}", e)
        )
    })?;

    let result = prisms::handle_prism(&prism, &input);
    serde_json::to_string(&result).map_err(|e| {
        PyErr::new::<pyo3::exceptions::PyRuntimeError, _>(
            format!("Serialization error: {}", e)
        )
    })
}

// ============================================================================
// Serialization Functions
// ============================================================================

/// Convert a Python object to JSON string.
///
/// Args:
///     data: Python object to serialize
///
/// Returns:
///     JSON string
#[pyfunction]
fn to_json(data: PyObject) -> PyResult<String> {
    Python::with_gil(|py| {
        let json_str = serialization::to_json(data.bind(py))
            .map_err(|e| PyErr::new::<pyo3::exceptions::PyRuntimeError, _>(
                format!("Serialization error: {}", e)
            ))?;
        Ok(json_str)
    })
}

/// Parse a JSON string into a Python dictionary.
///
/// Args:
///     json_str: JSON string to parse
///
/// Returns:
///     Python dictionary
#[pyfunction]
fn from_json(json_str: &str) -> PyResult<PyObject> {
    Python::with_gil(|py| {
        let value: serde_json::Value = serde_json::from_str(json_str).map_err(|e| {
            PyErr::new::<pyo3::exceptions::PyValueError, _>(
                format!("JSON parse error: {}", e)
            )
        })?;
        serialization::json_to_python(py, &value)
    })
}

// ============================================================================
// Utility Functions
// ============================================================================

/// Get the version of lux_core.
///
/// Returns:
///     Version string
#[pyfunction]
fn version() -> &'static str {
    env!("CARGO_PKG_VERSION")
}

/// Compute SHA-256 hash of input data.
///
/// Args:
///     data: Input data as hex string
///
/// Returns:
///     SHA-256 hash as hex string
#[pyfunction]
fn compute_hash(data: &str) -> PyResult<String> {
    serialization::compute_sha256(data).map_err(|e| {
        PyErr::new::<pyo3::exceptions::PyValueError, _>(
            format!("Hash error: {}", e)
        )
    })
}

/// Compute EIP-55 checksummed address.
///
/// Args:
///     address: Ethereum address (with or without 0x prefix)
///
/// Returns:
///     Checksummed address
#[pyfunction]
fn checksum_address(address: &str) -> PyResult<String> {
    serialization::eip55_checksum(address).map_err(|e| {
        PyErr::new::<pyo3::exceptions::PyValueError, _>(
            format!("Address error: {}", e)
        )
    })
}
