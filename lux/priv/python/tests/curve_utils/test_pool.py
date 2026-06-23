import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

import pytest
from unittest.mock import MagicMock
from curve_utils.pool import get_virtual_price, add_liquidity, remove_liquidity

def test_get_virtual_price_handles_rpc_failure():
    mock_web3 = MagicMock()
    mock_contract = mock_web3.eth.contract.return_value
    mock_contract.functions.get_virtual_price.return_value.call.side_effect = Exception("RPC Down")
    
    with pytest.raises(Exception, match="RPC Down"):
        get_virtual_price(mock_web3, "0xMockAddress")

def test_add_liquidity_dry_run_transaction_shape():
    mock_web3 = MagicMock()
    # Ensure web3.eth.get_transaction_count is NEVER called
    mock_web3.eth.get_transaction_count.side_effect = Exception("Live RPC forbidden in dry run")
    
    mock_contract = mock_web3.eth.contract.return_value
    func_mock = MagicMock()
    func_mock.encode_abi.return_value = "0xencodeddata"
    mock_contract.functions.add_liquidity.return_value = func_mock
    
    tx = add_liquidity(mock_web3, "0xMockAddress", [100, 100, 100], 0, "0xUser")
    
    assert tx["to"] == mock_web3.to_checksum_address.return_value
    assert tx["from"] == "0xUser"
    assert tx["data"] == "0xencodeddata"
    assert "nonce" not in tx
    mock_contract.functions.add_liquidity.assert_called_once_with([100, 100, 100], 0)

def test_remove_liquidity_dry_run_transaction_shape():
    mock_web3 = MagicMock()
    mock_web3.eth.get_transaction_count.side_effect = Exception("Live RPC forbidden in dry run")
    
    mock_contract = mock_web3.eth.contract.return_value
    func_mock = MagicMock()
    func_mock.encode_abi.return_value = "0xencodeddata"
    mock_contract.functions.remove_liquidity.return_value = func_mock
    
    tx = remove_liquidity(mock_web3, "0xMockAddress", 100, [0, 0, 0], "0xUser")
    
    assert tx["to"] == mock_web3.to_checksum_address.return_value
    assert tx["from"] == "0xUser"
    assert tx["data"] == "0xencodeddata"
    assert "nonce" not in tx
    mock_contract.functions.remove_liquidity.assert_called_once_with(100, [0, 0, 0])
