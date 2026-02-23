defmodule Lux.Lenses.Ethereum.Wallet.GetTransactionHistoryTest do
  @moduledoc """
  Test suite for the GetTransactionHistory lens.
  Verifies transaction history retrieval via the Etherscan API.
  """

  use UnitAPICase, async: true

  alias Lux.Lenses.Ethereum.Wallet.GetTransactionHistory

  @agent_ctx %{agent: %{name: "TestAgent"}}
  @test_address "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "returns formatted transaction history" do
      Req.Test.stub(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "hash" => "0xabc123",
              "from" => "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
              "to" => "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
              "value" => "1000000000000000000",
              "timeStamp" => "1700000000",
              "blockNumber" => "19000000",
              "txreceipt_status" => "1",
              "gasUsed" => "21000"
            }
          ]
        }))
      end)

      assert {:ok, result} = GetTransactionHistory.focus(%{
        address: @test_address,
        network: "mainnet",
        plug: {Req.Test, Lux.Lens}
      }, @agent_ctx)

      assert result.address == @test_address
      assert result.network == "mainnet"
      assert length(result.transactions) == 1
      assert result.total == 1

      [tx] = result.transactions
      assert tx.hash == "0xabc123"
      assert tx.status == "success"
      assert tx.gas_used == 21_000
    end

    test "handles empty transaction history" do
      Req.Test.stub(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "status" => "0",
          "message" => "No transactions found",
          "result" => []
        }))
      end)

      assert {:ok, result} = GetTransactionHistory.focus(%{
        address: @test_address,
        network: "mainnet",
        plug: {Req.Test, Lux.Lens}
      }, @agent_ctx)

      assert result.transactions == []
      assert result.total == 0
    end

    test "handles Etherscan API error" do
      Req.Test.stub(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "status" => "0",
          "message" => "NOTOK",
          "result" => "Invalid API key"
        }))
      end)

      assert {:error, _} = GetTransactionHistory.focus(%{
        address: @test_address,
        network: "mainnet",
        plug: {Req.Test, Lux.Lens}
      }, @agent_ctx)
    end

    test "formats failed transaction status correctly" do
      Req.Test.stub(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "hash" => "0xfailed",
              "from" => "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
              "to" => "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
              "value" => "0",
              "timeStamp" => "1700000001",
              "blockNumber" => "19000001",
              "txreceipt_status" => "0",
              "gasUsed" => "50000"
            }
          ]
        }))
      end)

      assert {:ok, result} = GetTransactionHistory.focus(%{
        address: @test_address,
        network: "mainnet",
        plug: {Req.Test, Lux.Lens}
      }, @agent_ctx)

      [tx] = result.transactions
      assert tx.status == "failed"
    end
  end
end
