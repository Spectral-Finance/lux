"""Pytest configuration and shared fixtures."""
import pytest

@pytest.fixture
def sample_struct_data():
    """Sample data for testing struct conversion."""
    return {
        "__class__": "user",
        "name": "Alice",
        "role": "admin",
        "metadata": {
            "last_login": "2023-01-01",
            "preferences": {"theme": "dark"}
        }
    }

@pytest.fixture
def sample_web3_data():
    """Sample Web3 data for testing crypto-related conversions."""
    return {
        "__class__": "transaction",
        "tx_hash": "0x123...",
        "from_address": "0xabc...",
        "to_address": "0xdef...",
        "value": 1_000_000_000_000_000_000,
        "gas_price": 20_000_000_000,
        "gas_limit": 21000,
        "nonce": 42,
        "status": "confirmed"
    }

@pytest.fixture
def complex_nested_data():
    """Complex nested data structure for testing deep conversions."""
    return {
        "__class__": "order",
        "id": "123",
        "customer": {
            "__class__": "user",
            "name": "Bob",
            "role": "customer"
        },
        "items": [
            {
                "__class__": "item",
                "id": 1,
                "quantity": 2,
                "metadata": {"color": "blue"}
            },
            {
                "__class__": "item",
                "id": 2,
                "quantity": 1,
                "metadata": {"size": "large"}
            }
        ]
    } 