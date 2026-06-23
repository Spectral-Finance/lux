import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

import pytest
from unittest.mock import MagicMock
from curve_utils.gauge import deposit, withdraw, claim_rewards

def test_deposit_dry_run_shape():
    mock_web3 = MagicMock()
    mock_web3.eth.get_transaction_count.side_effect = Exception("Live RPC forbidden in dry run")
    
    mock_contract = mock_web3.eth.contract.return_value
    func_mock = MagicMock()
    func_mock.encode_abi.return_value = "0xdeposit"
    mock_contract.functions.deposit.return_value = func_mock
    
    tx = deposit(mock_web3, "0xGauge", 1000, "0xUser")
    
    assert tx["to"] == mock_web3.to_checksum_address.return_value
    assert tx["from"] == "0xUser"
    assert tx["data"] == "0xdeposit"
    assert "nonce" not in tx
    mock_contract.functions.deposit.assert_called_once_with(1000)

def test_withdraw_dry_run_shape():
    mock_web3 = MagicMock()
    mock_web3.eth.get_transaction_count.side_effect = Exception("Live RPC forbidden in dry run")
    
    mock_contract = mock_web3.eth.contract.return_value
    func_mock = MagicMock()
    func_mock.encode_abi.return_value = "0xwithdraw"
    mock_contract.functions.withdraw.return_value = func_mock
    
    tx = withdraw(mock_web3, "0xGauge", 500, "0xUser")
    
    assert tx["to"] == mock_web3.to_checksum_address.return_value
    assert tx["from"] == "0xUser"
    assert tx["data"] == "0xwithdraw"
    assert "nonce" not in tx
    mock_contract.functions.withdraw.assert_called_once_with(500)

def test_claim_rewards_dry_run_shape():
    mock_web3 = MagicMock()
    mock_web3.eth.get_transaction_count.side_effect = Exception("Live RPC forbidden in dry run")
    
    mock_contract = mock_web3.eth.contract.return_value
    func_mock = MagicMock()
    func_mock.encode_abi.return_value = "0xclaim"
    mock_contract.functions.claim_rewards.return_value = func_mock
    
    tx = claim_rewards(mock_web3, "0xGauge", "0xUser")
    
    assert tx["to"] == mock_web3.to_checksum_address.return_value
    assert tx["from"] == "0xUser"
    assert tx["data"] == "0xclaim"
    assert "nonce" not in tx
    mock_contract.functions.claim_rewards.assert_called_once()
