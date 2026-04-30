"""Pytest configuration for lux_core tests."""
import pytest


@pytest.fixture
def sample_blocks():
    """Sample block data for testing aggregation."""
    return [
        {
            "number": 100,
            "hash": "0xblock100",
            "parentHash": "0xblock99",
            "timestamp": 1700000000,
            "chainId": 1,
            "transactionCount": 150,
            "gasUsed": 15000000,
            "gasLimit": 30000000,
            "miner": "0xminer1",
            "baseFeePerGas": 30000000000,
        },
        {
            "number": 101,
            "hash": "0xblock101",
            "parentHash": "0xblock100",
            "timestamp": 1700000012,
            "chainId": 1,
            "transactionCount": 160,
            "gasUsed": 16000000,
            "gasLimit": 30000000,
            "miner": "0xminer2",
            "baseFeePerGas": 31000000000,
        },
        {
            "number": 50000,
            "hash": "0xpolygon1",
            "parentHash": "0xpolygon0",
            "timestamp": 1700000000,
            "chainId": 137,
            "transactionCount": 100,
            "gasUsed": 10000000,
            "gasLimit": 20000000,
            "miner": "0xpolyminer",
        },
    ]


@pytest.fixture
def sample_transactions():
    """Sample transaction data for testing aggregation."""
    return [
        {
            "hash": "0xtx1",
            "blockNumber": 100,
            "from": "0xsender1",
            "to": "0xreceiver1",
            "value": "1000000000000000000",
            "gas": 21000,
            "gasPrice": 50000000000,
            "nonce": 1,
            "chainId": 1,
        },
        {
            "hash": "0xtx2",
            "blockNumber": 100,
            "from": "0xsender1",
            "to": "0xreceiver2",
            "value": "2000000000000000000",
            "gas": 21000,
            "gasPrice": 50000000000,
            "nonce": 2,
            "chainId": 1,
        },
        {
            "hash": "0xtx3",
            "blockNumber": 101,
            "from": "0xsender2",
            "to": None,  # Contract creation
            "value": "0",
            "gas": 50000,
            "gasPrice": 55000000000,
            "nonce": 1,
            "chainId": 1,
        },
    ]


@pytest.fixture
def sample_prism_configs():
    """Sample prism configurations for testing."""
    return {
        "filter": {
            "name": "eth_filter",
            "type": "data_filter",
            "config": {"field": "chainId", "value": 1},
        },
        "aggregate": {
            "name": "gas_aggregator",
            "type": "data_aggregate",
            "config": {"field": "gasUsed", "operation": "sum"},
        },
        "sentiment": {
            "name": "market_sentiment",
            "type": "sentiment_analysis",
            "config": None,
        },
    }


@pytest.fixture
def sample_addresses():
    """Sample Ethereum addresses for testing."""
    return {
        "lowercase": "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae",
        "uppercase": "0xDE0B295669A9FD93D5F28D9EC85E40F4CB697BAE",
        "checksummed": "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe",
        "no_prefix": "de0b295669a9fd93d5f28d9ec85e40f4cb697bae",
    }
