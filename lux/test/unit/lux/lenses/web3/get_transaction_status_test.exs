defmodule Lux.Lenses.Web3.GetTransactionStatusTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Web3.GetTransactionStatus

  describe "focus/2 with confirmed transaction" do
    setup do
      Req.Test.stub(Lux.Web3.TxMock, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "result" => %{
            "status" => "0x1",
            "blockNumber" => "0x1234",
            "gasUsed" => "0x5208",
            "from" => "0xabc123",
            "to" => "0xdef456",
            "contractAddress" => nil
          }
        })
      end)

      :ok
    end

    test "returns confirmed status" do
      assert {:ok, result} =
               GetTransactionStatus.focus(%{
                 tx_hash: "0xabc123",
                 chain: "ethereum",
                 plug: {Req.Test, Lux.Web3.TxMock}
               })

      assert result.status == :confirmed
      assert result.block_number == 0x1234
      assert result.gas_used == 21_000
    end
  end

  describe "focus/2 with pending transaction" do
    setup do
      Req.Test.stub(Lux.Web3.TxPendingMock, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "result" => nil
        })
      end)

      :ok
    end

    test "returns pending status" do
      assert {:ok, result} =
               GetTransactionStatus.focus(%{
                 tx_hash: "0xpending",
                 chain: "ethereum",
                 plug: {Req.Test, Lux.Web3.TxPendingMock}
               })

      assert result.status == :pending
    end
  end
end
