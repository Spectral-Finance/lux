"""Tests for lux_core Rust integration."""
import json
import pytest


class TestEvaluation:
    """Tests for evaluation functions."""

    def test_evaluate_simple(self):
        """Test basic evaluation."""
        from lux_core import evaluate
        assert evaluate("2 + 2") == "4"

    def test_evaluate_with_variables(self):
        """Test evaluation with variable bindings."""
        from lux_core import evaluate_with_variables
        result = evaluate_with_variables("x * y", {"x": "5", "y": "6"})
        assert result == "30"

    def test_evaluate_complex(self):
        """Test complex expression evaluation."""
        from lux_core import evaluate
        assert evaluate("2 + 3 * 4") == "14"
        assert evaluate("(2 + 3) * 4") == "20"

    def test_evaluate_special_values(self):
        """Test special value evaluation."""
        from lux_core import evaluate
        assert evaluate("True") == "True"
        assert evaluate("False") == "False"
        assert evaluate("None") == "None"

    def test_execute_code(self):
        """Test multi-line code execution."""
        from lux_core import execute_code
        assert execute_code("42") == "42"
        assert execute_code("") == "None"


class TestDataAggregation:
    """Tests for data aggregation functions."""

    def test_aggregate_blocks(self):
        """Test block aggregation."""
        from lux_core import aggregate_blocks

        blocks = [
            {"number": 100, "chainId": 1, "gasUsed": 15000000, "gasLimit": 30000000,
             "transactionCount": 150, "miner": "0xminer1"},
            {"number": 101, "chainId": 1, "gasUsed": 16000000, "gasLimit": 30000000,
             "transactionCount": 160, "miner": "0xminer2"},
            {"number": 100, "chainId": 137, "gasUsed": 10000000, "gasLimit": 20000000,
             "transactionCount": 100, "miner": "0xminer1"},
        ]

        # Aggregate all blocks
        stats = aggregate_blocks(blocks)
        assert stats["blockCount"] == 3
        assert stats["totalTransactions"] == 410

        # Filter by chain
        eth_stats = aggregate_blocks(blocks, chain_id=1)
        assert eth_stats["blockCount"] == 2
        assert eth_stats["chainId"] == 1

        poly_stats = aggregate_blocks(blocks, chain_id=137)
        assert poly_stats["blockCount"] == 1

    def test_aggregate_transactions(self):
        """Test transaction aggregation."""
        from lux_core import aggregate_transactions

        txs = [
            {"hash": "0xtx1", "from": "0xsender1", "to": "0xreceiver1",
             "value": "1000000000000000000", "gas": 21000, "chainId": 1},
            {"hash": "0xtx2", "from": "0xsender1", "to": "0xreceiver2",
             "value": "2000000000000000000", "gas": 21000, "chainId": 1},
            {"hash": "0xtx3", "from": "0xsender2", "to": None,
             "value": "0", "gas": 50000, "chainId": 1},
        ]

        stats = aggregate_transactions(txs)
        assert stats["transactionCount"] == 3
        assert stats["uniqueSenders"] == 2
        assert stats["contractCreations"] == 1

    def test_aggregate_empty(self):
        """Test aggregation with empty data."""
        from lux_core import aggregate_blocks, aggregate_transactions

        blocks_stats = aggregate_blocks([])
        assert blocks_stats["blockCount"] == 0

        tx_stats = aggregate_transactions([])
        assert tx_stats["transactionCount"] == 0

    def test_normalize_block(self):
        """Test block normalization."""
        from lux_core import normalize_block

        block = {
            "number": 19000000,
            "hash": "0x1234",
            "gasUsed": 15000000,
            "gasLimit": 30000000,
            "transactionCount": 150,
            "miner": "0xminer",
        }

        normalized = normalize_block(block, 1)
        assert normalized["chainName"] == "Ethereum"
        assert normalized["gasUsagePercent"] == 50.0

    def test_normalize_transaction(self):
        """Test transaction normalization."""
        from lux_core import normalize_transaction

        tx = {
            "hash": "0xtx1",
            "from": "0xsender",
            "to": "0xreceiver",
            "value": "1000000000000000000",
            "gas": 21000,
        }

        normalized = normalize_transaction(tx, 1)
        assert normalized["chainName"] == "Ethereum"
        assert "1.0" in normalized["valueEther"]


class TestPrisms:
    """Tests for prism functions."""

    def test_create_prism(self):
        """Test prism creation."""
        from lux_core import create_prism

        prism = create_prism("test", "data_filter", {"field": "chainId", "value": 1})
        assert prism["name"] == "test"
        assert prism["prismType"] in ("data_filter", "dataFilter")

    def test_prism_handler_filter(self):
        """Test filter prism handler."""
        from lux_core import create_prism, prism_handler

        prism = create_prism("filter", "data_filter", {"field": "chainId", "value": 1})

        input_data = [
            {"chainId": 1, "name": "eth"},
            {"chainId": 137, "name": "polygon"},
            {"chainId": 1, "name": "eth2"},
        ]

        result = prism_handler(prism, input_data)
        assert result["status"] == "success"

    def test_prism_handler_sentiment(self):
        """Test sentiment analysis prism."""
        from lux_core import create_prism, prism_handler

        prism = create_prism("sentiment", "sentiment_analysis")

        # Positive sentiment
        result = prism_handler(prism, "The market is great and bullish!")
        assert result["status"] == "success"
        output = result.get("output", {})
        assert output.get("sentiment") == "positive"

        # Negative sentiment
        result = prism_handler(prism, "There was a crash and massive losses")
        output = result.get("output", {})
        assert output.get("sentiment") == "negative"


class TestSerialization:
    """Tests for serialization functions."""

    def test_to_json(self):
        """Test JSON serialization."""
        from lux_core import to_json

        data = {"key": "value", "number": 42, "list": [1, 2, 3]}
        result = to_json(data)
        parsed = json.loads(result)
        assert parsed["key"] == "value"
        assert parsed["number"] == 42

    def test_from_json(self):
        """Test JSON deserialization."""
        from lux_core import from_json

        json_str = '{"key": "value", "number": 42}'
        result = from_json(json_str)
        assert result["key"] == "value"
        assert result["number"] == 42

    def test_roundtrip(self):
        """Test JSON roundtrip."""
        from lux_core import to_json, from_json

        original = {"test": [1, 2, 3], "nested": {"a": 1}}
        json_str = to_json(original)
        result = from_json(json_str)
        assert result["test"] == [1, 2, 3]
        assert result["nested"]["a"] == 1


class TestUtilities:
    """Tests for utility functions."""

    def test_version(self):
        """Test version function."""
        from lux_core import version
        v = version()
        assert isinstance(v, str)
        assert len(v) > 0

    def test_compute_hash(self):
        """Test SHA-256 hash computation."""
        from lux_core import compute_hash

        hash1 = compute_hash("hello")
        hash2 = compute_hash("hello")
        hash3 = compute_hash("world")

        # Same input should produce same hash
        assert hash1 == hash2
        # Different input should produce different hash
        assert hash1 != hash3
        # Hash should be 64 hex characters
        assert len(hash1) == 64

    def test_checksum_address(self):
        """Test EIP-55 checksum."""
        from lux_core import checksum_address

        # Known test vector
        addr = "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae"
        checksummed = checksum_address(addr)
        assert checksummed == "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe"

        # Without prefix
        addr_no_prefix = "de0b295669a9fd93d5f28d9ec85e40f4cb697bae"
        checksummed2 = checksum_address(addr_no_prefix)
        assert checksummed2 == checksummed

    def test_checksum_address_invalid(self):
        """Test checksum with invalid address."""
        from lux_core import checksum_address

        with pytest.raises((ValueError, Exception)):
            checksum_address("invalid")


class TestRustAvailability:
    """Tests for Rust module availability."""

    def test_rust_available_flag(self):
        """Test that RUST_AVAILABLE flag is set correctly."""
        from lux_core import RUST_AVAILABLE
        assert isinstance(RUST_AVAILABLE, bool)

    def test_version_reflects_rust(self):
        """Test that version reflects Rust availability."""
        from lux_core import version, RUST_AVAILABLE

        v = version()
        if RUST_AVAILABLE:
            assert "-pure-python" not in v
        else:
            assert "-pure-python" in v


class TestIntegrationWithExistingCode:
    """Tests for integration with existing Lux Python code."""

    def test_compatible_with_eval_module(self):
        """Test that lux_core is compatible with existing eval module."""
        from lux_core import evaluate

        # Should produce same results as existing eval module
        assert evaluate("1 + 1") == "2"
        assert evaluate("'hello' + ' world'") in ("b'hello world'", "hello world")

    def test_json_compatible_with_erlport(self):
        """Test that JSON output is compatible with Erlport."""
        from lux_core import to_json, from_json

        # Test data that would be sent to Elixir
        data = {
            "class": "user",
            "name": "Alice",
            "role": "admin",
            "numbers": [1, 2, 3],
        }

        json_str = to_json(data)
        result = from_json(json_str)
        assert result["name"] == "Alice"
        assert result["numbers"] == [1, 2, 3]
