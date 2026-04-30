"""
Integration examples for lux_core with the existing Lux framework.

This module demonstrates how to use the Rust-accelerated lux_core module
alongside the existing Lux Python components.
"""

# Example 1: Using lux_core with Lux.Python (Elixir integration)
#
# In Elixir:
# ```elixir
# # Use lux_core via Lux.Python
# Lux.Python.eval("""
# from lux_core import aggregate_blocks, normalize_block
#
# blocks = [
#     {"number": 100, "chainId": 1, "gasUsed": 15000000, ...},
#     {"number": 101, "chainId": 1, "gasUsed": 16000000, ...},
# ]
# stats = aggregate_blocks(blocks)
# """)
# ```

# Example 2: Using lux_core in Python prisms
#
# ```python
# from lux.prism import Prism
# from lux_core import aggregate_blocks, normalize_block
#
# class AggregationPrism(Prism):
#     """A prism that uses Rust-accelerated aggregation."""
#
#     def __init__(self):
#         super().__init__(
#             name="aggregation_prism",
#             description="Aggregates blockchain data using Rust core",
#             input_schema={"blocks": "list"},
#             output_schema={"stats": "dict"}
#         )
#
#     def handler(self, input, context):
#         blocks = input.get("blocks", [])
#         stats = aggregate_blocks(blocks)
#         return {"__class__": "aggregation_result", "stats": stats}
#
#     @staticmethod
#     def new():
#         return AggregationPrism()
# ```

# Example 3: Multi-chain data aggregation pipeline
#
# ```python
# from lux_core import (
#     aggregate_blocks,
#     aggregate_transactions,
#     normalize_block,
#     normalize_transaction,
#     checksum_address,
#     compute_hash,
# )
#
# def process_chain_data(blocks, transactions, chain_id):
#     """Process and normalize multi-chain data."""
#
#     # Aggregate blocks
#     block_stats = aggregate_blocks(blocks, chain_id=chain_id)
#
#     # Aggregate transactions
#     tx_stats = aggregate_transactions(transactions)
#
#     # Normalize first block and transaction
#     if blocks:
#         normalized_block = normalize_block(blocks[0], chain_id)
#
#     if transactions:
#         normalized_tx = normalize_transaction(transactions[0], chain_id)
#
#     # Compute block hash
#     if blocks:
#         block_hash = compute_hash(str(blocks[0]["number"]))
#
#     return {
#         "block_stats": block_stats,
#         "tx_stats": tx_stats,
#         "normalized_block": normalized_block if blocks else None,
#         "normalized_tx": normalized_tx if transactions else None,
#         "block_hash": block_hash if blocks else None,
#     }
# ```

# Example 4: Sentiment analysis with Rust prisms
#
# ```python
# from lux_core import create_prism, prism_handler
#
# # Create a sentiment analysis prism
# sentiment_prism = create_prism("market_sentiment", "sentiment_analysis")
#
# # Analyze market sentiment
# messages = [
#     "Bitcoin is going to the moon! Bullish!",
#     "The market crashed hard today, massive losses",
#     "Neutral market conditions, waiting for direction",
# ]
#
# for msg in messages:
#     result = prism_handler(sentiment_prism, msg)
#     print(f"Message: {msg}")
#     print(f"Sentiment: {result['output']['sentiment']}")
#     print(f"Score: {result['output']['score']}")
#     print("---")
# ```

# Example 5: Address utilities
#
# ```python
# from lux_core import checksum_address, compute_hash
#
# # EIP-55 checksum
# address = "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae"
# checksummed = checksum_address(address)
# print(f"Checksummed: {checksummed}")
# # Output: 0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe
#
# # Compute transaction hash
# tx_data = '{"from": "0x...", "to": "0x...", "value": "1000"}'
# tx_hash = compute_hash(tx_data)
# print(f"TX Hash: {tx_hash}")
# ```

# Example 6: Checking Rust availability and fallback behavior
#
# ```python
# from lux_core import RUST_AVAILABLE, version
#
# if RUST_AVAILABLE:
#     print(f"Using Rust-accelerated lux_core v{version()}")
# else:
#     print(f"Using pure Python fallback v{version()}")
#     print("To enable Rust acceleration:")
#     print("  cd lux/priv/rust/lux_core")
#     print("  pip install maturin")
#     print("  maturin develop")
# ```

# Example 7: Integration with existing eval module
#
# ```python
# # Both modules can coexist
# from lux.eval import execute  # Existing Erlport-based eval
# from lux_core import evaluate  # Rust-accelerated eval
#
# # Use Rust version for simple expressions (faster)
# result = evaluate("2 + 2")
#
# # Use Erlport version for complex Python code (full Python support)
# result = execute("import json; json.dumps({'key': 'value'})", {})
# ```

# Example 8: Performance comparison
#
# ```python
# import time
# from lux_core import RUST_AVAILABLE, aggregate_blocks
#
# # Generate test data
# blocks = [
#     {
#         "number": i,
#         "chainId": 1 if i % 2 == 0 else 137,
#         "gasUsed": 15000000 + i,
#         "gasLimit": 30000000,
#         "transactionCount": 100 + i,
#         "miner": f"0xminer{i % 10}",
#     }
#     for i in range(10000)
# ]
#
# # Benchmark
# start = time.perf_counter()
# for _ in range(100):
#     aggregate_blocks(blocks)
# elapsed = time.perf_counter() - start
#
# backend = "Rust" if RUST_AVAILABLE else "Python"
# print(f"{backend} backend: {elapsed:.3f}s for 100 iterations")
# ```
