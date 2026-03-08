defmodule Lux.Lenses.Web3.Chain.GetTransactionTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Web3.Chain.GetTransaction

  setup do
    Req.Test.stub(Lux.Web3.TxDetailMock, fn conn ->
      {:ok, body, _} = Plug.Conn.read_body(conn)
      req = Jason.decode!(body)

      result = case req["method"] do
        "eth_getTransactionByHash" ->
          %{
            "hash" => "0xabc", "from" => "0xsender", "to" => "0xreceiver",
            "value" => "0xDE0B6B3A7640000", "gas" => "0x5208",
            "gasPrice" => "0x3B9ACA00", "nonce" => "0x5",
            "blockNumber" => "0xF4240", "input" => "0x", "type" => "0x2"
          }

        "eth_getTransactionReceipt" ->
          %{
            "status" => "0x1", "blockNumber" => "0xF4240",
            "gasUsed" => "0x5208", "effectiveGasPrice" => "0x3B9ACA00",
            "logs" => [%{"address" => "0xcontract", "topics" => ["0xtopic"], "data" => "0x", "logIndex" => "0x0", "blockNumber" => "0xF4240", "blockHash" => "0x", "transactionHash" => "0x"}],
            "contractAddress" => nil
          }
      end

      Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => result})
    end)
    :ok
  end

  test "fetches transaction details" do
    assert {:ok, tx} = GetTransaction.focus(%{
      tx_hash: "0xabc", rpc_url: "https://test",
      plug: {Req.Test, Lux.Web3.TxDetailMock}
    })
    assert tx.from == "0xsender"
    assert tx.value == 1_000_000_000_000_000_000
  end

  test "fetches receipt" do
    assert {:ok, receipt} = GetTransaction.focus(%{
      tx_hash: "0xabc", action: "receipt", rpc_url: "https://test",
      plug: {Req.Test, Lux.Web3.TxDetailMock}
    })
    assert receipt.status == :confirmed
    assert receipt.gas_used == 21_000
    assert length(receipt.logs) == 1
  end

  test "fetches both" do
    assert {:ok, result} = GetTransaction.focus(%{
      tx_hash: "0xabc", action: "both", rpc_url: "https://test",
      plug: {Req.Test, Lux.Web3.TxDetailMock}
    })
    assert result.from == "0xsender"
    assert result.receipt.status == :confirmed
  end
end
