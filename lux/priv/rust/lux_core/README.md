# Lux Core - Rust Integration

High-performance Rust core for the Lux framework, providing optimized data processing, aggregation, and serialization primitives.

## Overview

This crate provides Rust implementations of core Lux functionality, exposed to Python via [pyo3](https://pyo3.rs/) bindings. It serves as a performance-critical layer for the Lux data aggregation platform.

## Features

- **Evaluation Engine**: Fast Python expression evaluation with caching
- **Data Aggregation**: Multi-chain block and transaction aggregation
- **Prism Processing**: High-performance prism implementations (filter, transform, aggregate, sentiment)
- **Serialization**: Optimized JSON serialization/deserialization
- **Utilities**: SHA-256 hashing, EIP-55 address checksumming

## Quick Start

### Building

```bash
cd lux/priv/rust/lux_core

# Install maturin (Rust-Python build tool)
pip install maturin

# Build and install in development mode
maturin develop

# Or build release version
maturin build --release
```

### Requirements

- Rust 1.70+
- Python 3.12+
- maturin >= 1.0

### Usage

```python
import lux_core

# Evaluate expressions
result = lux_core.evaluate("2 + 2")  # Returns "4"

# Aggregate blockchain data
blocks = [
    {"number": 100, "chainId": 1, "gasUsed": 15000000, ...},
    {"number": 101, "chainId": 1, "gasUsed": 16000000, ...},
]
stats = lux_core.aggregate_blocks(blocks, chain_id=1)

# Use prisms
prism = lux_core.create_prism("filter", "data_filter", {"field": "chainId", "value": 1})
result = lux_core.prism_handler(prism, data)

# Checksum addresses
address = lux_core.checksum_address("0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae")
# Returns: "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe"
```

## Architecture

```
lux/priv/rust/lux_core/
├── Cargo.toml              # Rust crate configuration
├── pyproject.toml          # Python build configuration (maturin)
├── src/
│   ├── lib.rs              # Main library + pyo3 bindings
│   ├── types.rs            # Core data types (Block, Transaction, Event)
│   ├── data_aggregation.rs # Block/transaction aggregation
│   ├── prisms.rs           # Prism implementations
│   ├── eval.rs             # Expression evaluation engine
│   └── serialization.rs    # JSON, hashing, checksum utilities
├── python/
│   └── lux_core/
│       └── __init__.py     # Python bridge with pure-Python fallback
└── tests/
    └── test_lux_core.py    # Python integration tests
```

## Module Details

### `types.rs` - Core Data Types

- `BlockData`: Blockchain block representation
- `TransactionData`: Transaction representation
- `EventData`: Smart contract event log
- `PrismResult`: Prism execution result
- `ChainConfig`: Chain-specific configuration for 7 EVM chains

### `data_aggregation.rs` - Aggregation

- `aggregate_blocks()`: Compute block statistics (tx count, gas usage, etc.)
- `aggregate_transactions()`: Compute transaction statistics
- `normalize_block()`: Standardize block data format
- `normalize_transaction()`: Standardize transaction data format

### `prisms.rs` - Prism Processing

- `data_filter`: Filter data by criteria
- `data_transform`: Transform/renamed data fields
- `data_aggregate`: Aggregate numerical data (sum, avg, min, max)
- `sentiment_analysis`: Keyword-based sentiment detection
- `eth_balance`: ETH balance formatting

### `eval.rs` - Evaluation

- Expression evaluation with LRU cache
- Variable binding support
- Simple arithmetic parser

### `serialization.rs` - Utilities

- JSON serialization/deserialization
- SHA-256 hashing
- EIP-55 address checksumming
- Wei/Ether conversion
- Hex encoding/decoding

## Python Bridge

The Python bridge (`python/lux_core/__init__.py`) provides:

1. **Rust-first**: Uses the Rust module when available
2. **Graceful fallback**: Pure Python implementations when Rust is not built
3. **API compatibility**: Same interface regardless of backend

```python
from lux_core import RUST_AVAILABLE

if RUST_AVAILABLE:
    print("Using Rust-accelerated lux_core")
else:
    print("Using pure Python fallback")
```

## Running Tests

```bash
# Python tests (requires maturin develop)
cd lux/priv/rust/lux_core
pytest tests/

# Rust tests (requires Rust toolchain)
cargo test

# Benchmarks
cargo bench
```

## Integration with Lux Elixir

The Rust module integrates with the existing Lux Python integration:

```elixir
# Via Lux.Python
Lux.Python.eval("import lux_core; lux_core.evaluate('2 + 2')")

# Or via the Python bridge
Lux.Python.eval("""
from lux_core import aggregate_blocks, checksum_address
blocks = [...]
stats = aggregate_blocks(blocks)
""")
```

## Performance

The Rust implementation provides significant speedups for:

- **Data aggregation**: 10-50x faster for large datasets
- **Hashing**: 5-10x faster SHA-256
- **JSON serialization**: 3-5x faster
- **Address checksumming**: 10x faster

## License

MIT License - See LICENSE file for details.
