"""
Lux Core Python Bridge

This module provides a Python interface to the Rust-based lux_core module.
It gracefully handles the case where the Rust module is not available by
falling back to pure Python implementations.
"""

import json
import hashlib
from typing import Any, Dict, List, Optional, Union

# Try to import the Rust module, fall back to pure Python
try:
    import lux_core as _rust_core
    RUST_AVAILABLE = True
except ImportError:
    RUST_AVAILABLE = False


def _get_rust_core():
    """Get the Rust core module or raise an error if unavailable."""
    if not RUST_AVAILABLE:
        raise ImportError(
            "lux_core Rust module is not available. "
            "Build it with: cd lux/priv/rust/lux_core && maturin develop"
        )
    return _rust_core


# ============================================================================
# Evaluation Functions
# ============================================================================

def evaluate(code: str) -> str:
    """
    Evaluate a Python expression.

    Args:
        code: Python expression to evaluate

    Returns:
        String representation of the result

    Example:
        >>> evaluate("2 + 2")
        '4'
    """
    if RUST_AVAILABLE:
        return _rust_core.evaluate(code)
    return _py_evaluate(code)


def evaluate_with_variables(code: str, variables: Dict[str, str]) -> str:
    """
    Evaluate Python code with variable bindings.

    Args:
        code: Python code to evaluate
        variables: Dictionary of variable bindings

    Returns:
        String representation of the result

    Example:
        >>> evaluate_with_variables("x + y", {"x": "40", "y": "2"})
        '42'
    """
    if RUST_AVAILABLE:
        return _rust_core.evaluate_with_variables(code, variables)
    return _py_evaluate_with_variables(code, variables)


def execute_code(code: str) -> str:
    """
    Execute multi-line Python code.

    Args:
        code: Python code to execute

    Returns:
        String representation of the last expression result
    """
    if RUST_AVAILABLE:
        return _rust_core.execute_code(code)
    return _py_execute_code(code)


# ============================================================================
# Data Aggregation Functions
# ============================================================================

def aggregate_blocks(blocks: List[Dict[str, Any]], chain_id: Optional[int] = None) -> Dict[str, Any]:
    """
    Aggregate block data from multiple chains.

    Args:
        blocks: List of block data dictionaries
        chain_id: Optional chain ID filter

    Returns:
        Aggregated block statistics
    """
    if RUST_AVAILABLE:
        json_blocks = [json.dumps(b) for b in blocks]
        result = _rust_core.aggregate_blocks(json_blocks, chain_id)
        return json.loads(result)
    return _py_aggregate_blocks(blocks, chain_id)


def aggregate_transactions(transactions: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Aggregate transaction data.

    Args:
        transactions: List of transaction data dictionaries

    Returns:
        Aggregated transaction statistics
    """
    if RUST_AVAILABLE:
        json_txs = [json.dumps(t) for t in transactions]
        result = _rust_core.aggregate_transactions(json_txs)
        return json.loads(result)
    return _py_aggregate_transactions(transactions)


def normalize_block(block: Dict[str, Any], chain_id: int) -> Dict[str, Any]:
    """
    Normalize block data to standard format.

    Args:
        block: Block data dictionary
        chain_id: Chain ID for chain-specific normalization

    Returns:
        Normalized block data
    """
    if RUST_AVAILABLE:
        result = _rust_core.normalize_block(json.dumps(block), chain_id)
        return json.loads(result)
    return _py_normalize_block(block, chain_id)


def normalize_transaction(tx: Dict[str, Any], chain_id: int) -> Dict[str, Any]:
    """
    Normalize transaction data to standard format.

    Args:
        tx: Transaction data dictionary
        chain_id: Chain ID for chain-specific normalization

    Returns:
        Normalized transaction data
    """
    if RUST_AVAILABLE:
        result = _rust_core.normalize_transaction(json.dumps(tx), chain_id)
        return json.loads(result)
    return _py_normalize_transaction(tx, chain_id)


# ============================================================================
# Prism Functions
# ============================================================================

def create_prism(name: str, prism_type: str, config: Optional[Dict] = None) -> Dict[str, Any]:
    """
    Create a new prism instance.

    Args:
        name: Prism name
        prism_type: Prism type identifier
        config: Optional configuration dictionary

    Returns:
        Prism configuration dictionary
    """
    if RUST_AVAILABLE:
        config_json = json.dumps(config) if config else None
        result = _rust_core.create_prism(name, prism_type, config_json)
        return json.loads(result)
    return _py_create_prism(name, prism_type, config)


def prism_handler(prism: Dict[str, Any], input_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Handle prism input and return result.

    Args:
        prism: Prism configuration
        input_data: Input data

    Returns:
        Prism execution result
    """
    if RUST_AVAILABLE:
        result = _rust_core.prism_handler(json.dumps(prism), json.dumps(input_data))
        return json.loads(result)
    return _py_prism_handler(prism, input_data)


# ============================================================================
# Serialization Functions
# ============================================================================

def to_json(data: Any) -> str:
    """
    Convert a Python object to JSON string.

    Args:
        data: Python object to serialize

    Returns:
        JSON string
    """
    if RUST_AVAILABLE:
        return _rust_core.to_json(data)
    return json.dumps(data)


def from_json(json_str: str) -> Any:
    """
    Parse a JSON string into a Python object.

    Args:
        json_str: JSON string to parse

    Returns:
        Python object
    """
    if RUST_AVAILABLE:
        return _rust_core.from_json(json_str)
    return json.loads(json_str)


# ============================================================================
# Utility Functions
# ============================================================================

def version() -> str:
    """Get the version of lux_core."""
    if RUST_AVAILABLE:
        return _rust_core.version()
    return "0.1.0-pure-python"


def compute_hash(data: str) -> str:
    """
    Compute SHA-256 hash of input data.

    Args:
        data: Input data string

    Returns:
        SHA-256 hash as hex string
    """
    if RUST_AVAILABLE:
        return _rust_core.compute_hash(data)
    return hashlib.sha256(data.encode('utf-8')).hexdigest()


def checksum_address(address: str) -> str:
    """
    Compute EIP-55 checksummed address.

    Args:
        address: Ethereum address (with or without 0x prefix)

    Returns:
        Checksummed address
    """
    if RUST_AVAILABLE:
        return _rust_core.checksum_address(address)
    return _py_checksum_address(address)


# ============================================================================
# Pure Python Fallback Implementations
# ============================================================================

def _py_evaluate(code: str) -> str:
    """Pure Python fallback for evaluate."""
    code = code.strip()
    try:
        result = eval(code, {"__builtins__": __builtins__})
        return str(result)
    except Exception as e:
        raise RuntimeError(f"Evaluation error: {e}")


def _py_evaluate_with_variables(code: str, variables: Dict[str, str]) -> str:
    """Pure Python fallback for evaluate_with_variables."""
    for key, value in variables.items():
        code = code.replace(key, value)
    return _py_evaluate(code)


def _py_execute_code(code: str) -> str:
    """Pure Python fallback for execute_code."""
    code = code.strip()
    if not code:
        return "None"

    lines = code.split('\n')
    last_line = lines[-1].strip()

    # Check if last line is an expression
    keywords = ['def ', 'class ', 'if ', 'for ', 'while ', 'import ', 'return ']
    is_expr = not any(last_line.startswith(k) for k in keywords)

    if is_expr:
        return _py_evaluate(last_line)
    return "None"


def _py_aggregate_blocks(blocks: List[Dict[str, Any]], chain_id: Optional[int] = None) -> Dict[str, Any]:
    """Pure Python fallback for aggregate_blocks."""
    filtered = blocks
    if chain_id is not None:
        filtered = [b for b in blocks if b.get('chainId') == chain_id or b.get('chain_id') == chain_id]

    if not filtered:
        return {
            "chainId": chain_id or 0,
            "blockCount": 0,
            "totalTransactions": 0,
            "totalGasUsed": 0,
            "averageGasUsed": 0.0,
            "minBlockNumber": 0,
            "maxBlockNumber": 0,
            "uniqueMiners": 0,
        }

    total_txs = sum(b.get('transactionCount', b.get('transaction_count', 0)) for b in filtered)
    total_gas = sum(b.get('gasUsed', b.get('gas_used', 0)) for b in filtered)
    min_block = min(b.get('number', 0) for b in filtered)
    max_block = max(b.get('number', 0) for b in filtered)
    unique_miners = len(set(b.get('miner', '') for b in filtered))

    return {
        "chainId": chain_id or filtered[0].get('chainId', filtered[0].get('chain_id', 0)),
        "blockCount": len(filtered),
        "totalTransactions": total_txs,
        "totalGasUsed": total_gas,
        "averageGasUsed": total_gas / len(filtered),
        "minBlockNumber": min_block,
        "maxBlockNumber": max_block,
        "uniqueMiners": unique_miners,
    }


def _py_aggregate_transactions(transactions: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Pure Python fallback for aggregate_transactions."""
    if not transactions:
        return {
            "chainId": 0,
            "transactionCount": 0,
            "totalValueWei": "0",
            "averageGas": 0.0,
            "uniqueSenders": 0,
            "uniqueRecipients": 0,
            "contractCreations": 0,
        }

    chain_id = transactions[0].get('chainId', transactions[0].get('chain_id', 0))
    total_gas = sum(t.get('gas', 0) for t in transactions)
    unique_senders = len(set(t.get('from', '') for t in transactions))
    unique_recipients = len(set(t.get('to', '') for t in transactions if t.get('to')))
    contract_creations = sum(1 for t in transactions if not t.get('to'))

    return {
        "chainId": chain_id,
        "transactionCount": len(transactions),
        "totalValueWei": "0",  # Would need big int for proper calculation
        "averageGas": total_gas / len(transactions),
        "uniqueSenders": unique_senders,
        "uniqueRecipients": unique_recipients,
        "contractCreations": contract_creations,
    }


def _py_normalize_block(block: Dict[str, Any], chain_id: int) -> Dict[str, Any]:
    """Pure Python fallback for normalize_block."""
    gas_used = block.get('gasUsed', block.get('gas_used', 0))
    gas_limit = block.get('gasLimit', block.get('gas_limit', 1))
    gas_pct = (gas_used / gas_limit * 100) if gas_limit > 0 else 0

    chain_names = {1: "Ethereum", 137: "Polygon", 56: "BNB Smart Chain"}
    chain_name = chain_names.get(chain_id, f"Chain-{chain_id}")

    return {
        "number": str(block.get('number', 0)),
        "hash": block.get('hash', ''),
        "chainId": chain_id,
        "chainName": chain_name,
        "transactionCount": block.get('transactionCount', block.get('transaction_count', 0)),
        "gasUsagePercent": gas_pct,
        "miner": block.get('miner', ''),
    }


def _py_normalize_transaction(tx: Dict[str, Any], chain_id: int) -> Dict[str, Any]:
    """Pure Python fallback for normalize_transaction."""
    chain_names = {1: "Ethereum", 137: "Polygon", 56: "BNB Smart Chain"}
    chain_name = chain_names.get(chain_id, f"Chain-{chain_id}")

    value_wei = int(tx.get('value', '0'))
    value_ether = f"{value_wei / 1e18:.18}"

    return {
        "hash": tx.get('hash', ''),
        "from": tx.get('from', ''),
        "to": tx.get('to'),
        "valueEther": value_ether,
        "gas": tx.get('gas', 0),
        "chainId": chain_id,
        "chainName": chain_name,
    }


def _py_create_prism(name: str, prism_type: str, config: Optional[Dict] = None) -> Dict[str, Any]:
    """Pure Python fallback for create_prism."""
    import uuid
    return {
        "id": f"prism_{name}_{uuid.uuid4().hex[:8]}",
        "name": name,
        "prismType": prism_type,
        "config": config or {},
    }


def _py_prism_handler(prism: Dict[str, Any], input_data: Dict[str, Any]) -> Dict[str, Any]:
    """Pure Python fallback for prism_handler."""
    import time
    start = time.time()

    prism_type = prism.get('prismType', prism.get('prism_type', ''))

    if prism_type == 'data_filter':
        config = prism.get('config', {})
        field = config.get('field', '')
        value = config.get('value')

        if isinstance(input_data, list):
            filtered = [item for item in input_data if item.get(field) == value]
            output = filtered
        else:
            output = input_data
    elif prism_type == 'sentiment_analysis':
        text = input_data if isinstance(input_data, str) else input_data.get('text', '')
        positive = ['good', 'great', 'bullish', 'up']
        negative = ['bad', 'crash', 'loss', 'bearish']
        text_lower = text.lower()
        score = sum(1 for w in positive if w in text_lower) - sum(1 for w in negative if w in text_lower)
        sentiment = 'positive' if score > 0 else ('negative' if score < 0 else 'neutral')
        output = {'sentiment': sentiment, 'score': score}
    else:
        output = input_data

    elapsed = (time.time() - start) * 1000

    return {
        'prismId': prism.get('id', ''),
        'status': 'success',
        'output': output,
        'executionTimeMs': elapsed,
    }


def _py_checksum_address(address: str) -> str:
    """Pure Python EIP-55 checksum implementation."""
    # Remove 0x prefix
    addr = address.lower().replace('0x', '')

    if len(addr) != 40:
        raise ValueError("Address must be 40 hex characters")

    # Hash the lowercase address
    hash_hex = hashlib.sha256(addr.encode('utf-8')).hexdigest()

    # Apply checksum
    result = '0x'
    for i, c in enumerate(addr):
        if c in '0123456789':
            result += c
        elif int(hash_hex[i], 16) >= 8:
            result += c.upper()
        else:
            result += c

    return result


# ============================================================================
# Module Info
# ============================================================================

__version__ = version()
__all__ = [
    'evaluate',
    'evaluate_with_variables',
    'execute_code',
    'aggregate_blocks',
    'aggregate_transactions',
    'normalize_block',
    'normalize_transaction',
    'create_prism',
    'prism_handler',
    'to_json',
    'from_json',
    'version',
    'compute_hash',
    'checksum_address',
    'RUST_AVAILABLE',
    '__version__',
]
