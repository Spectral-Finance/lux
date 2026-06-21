defmodule Lux.Integrations.Web3.WalletManagerTest do
  use ExUnit.Case, async: false
  import Mock

  alias Lux.Integrations.Web3.WalletManager
  alias Lux.Integrations.Web3.Wallet.TransactionQueue

  setup do
    case WalletManager.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
    # Ensure queue is clear
    TransactionQueue.clear("test_wallet")
    :ok
  end

  test "imports wallet and derives hd account" do
    assert {:ok, _addr} = WalletManager.import_wallet("test_import", "0xabc123")
    assert {:ok, _addr2} = WalletManager.derive_hd_account("test_hd", "test test", "m/44'/60'/0'/0/0")
  end

  test "gets balance" do
    WalletManager.import_wallet("test_balance", "0xabc123")
    
    mock_response = %Req.Response{
      status: 200,
      body: %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => "0x1234"
      }
    }

    with_mock Req, [post: fn _url, _opts -> {:ok, mock_response} end] do
      assert {:ok, "0x1234"} = WalletManager.get_balance("test_balance", "https://mock.rpc")
    end
  end

  test "queues and processes transaction" do
    WalletManager.import_wallet("test_tx", "0x0000000000000000000000000000000000000000000000000000000000000001")
    
    tx_data = %{to: "0xabc", value: "0x10"}
    assert :ok = WalletManager.queue_transaction("test_tx", tx_data)
    
    mock_response = %Req.Response{
      status: 200,
      body: %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => "0xabcdefhash"
      }
    }

    # Ethers sign_transaction needs a mock too if local ethers module behaves badly, 
    # but let's mock Req.post to intercept broadcast.
    with_mocks [
      {Req, [], [post: fn _url, _opts -> {:ok, mock_response} end]},
      {Ethers, [], [sign_transaction: fn _tx, _opts -> {:ok, "0x_signed_tx"} end]}
    ] do
      assert {:ok, "0xabcdefhash"} = WalletManager.process_next_transaction("test_tx", "https://mock.rpc")
    end
  end
end
