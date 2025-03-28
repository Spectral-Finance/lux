defmodule Lux.Lenses.Etherscan.TokenNftContractTxTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Lux.Lenses.Etherscan.TokenNftContractTx

  describe "before_focus/1" do
    test "sets module and action" do
      params = %{contractaddress: "0x123"}
      result = TokenNftContractTx.before_focus(params)

      assert result.module == "account"
      assert result.action == "tokennfttx"
      assert result.contractaddress == "0x123"
    end
  end

  describe "after_focus/1" do
    test "processes successful response" do
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => [
          %{
            "blockNumber" => "14422621",
            "timeStamp" => "1647089666",
            "hash" => "0x123",
            "nonce" => "123",
            "blockHash" => "0xabc",
            "from" => "0xfrom",
            "contractAddress" => "0xcontract",
            "to" => "0xto",
            "tokenID" => "123",
            "tokenName" => "Test NFT",
            "tokenSymbol" => "TNFT",
            "tokenDecimal" => "0",
            "transactionIndex" => "123",
            "gas" => "123",
            "gasPrice" => "123",
            "gasUsed" => "123",
            "cumulativeGasUsed" => "123",
            "input" => "0x",
            "confirmations" => "123"
          }
        ]
      }

      assert {:ok, %{result: [first_transfer | _]}} = TokenNftContractTx.after_focus(response)
      assert first_transfer["blockNumber"] == "14422621"
      assert first_transfer["tokenName"] == "Test NFT"
    end

    test "handles empty transfer list" do
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => []
      }

      assert {:ok, %{result: []}} = TokenNftContractTx.after_focus(response)
    end

    test "handles error response" do
      response = %{
        "status" => "0",
        "message" => "NOTOK",
        "result" => "Error! Invalid contract address format"
      }

      assert {:error, %{message: "NOTOK", result: "Error! Invalid contract address format"}} = TokenNftContractTx.after_focus(response)
    end
  end
end 