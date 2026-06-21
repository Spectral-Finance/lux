defmodule Lux.Prisms.Web3.SendTransactionPrismTest do
  use ExUnit.Case, async: false

  import Mock

  alias Lux.Prisms.Web3.SendTransactionPrism
  alias Lux.Web3.TransactionManager

  test "successfully sends transaction and returns formatted output" do
    mock_receipt = %{
      "transactionHash" => "0xmocktxhash",
      "blockNumber" => "0xa", # Hex for 10
      "status" => "0x1"
    }

    with_mock TransactionManager, [
      send_transaction: fn "0xsender", %{to: "0xrecipient", value: 1000, data: "0xdata", gas_limit: nil} ->
        {:ok, mock_receipt}
      end
    ] do
      input = %{
        address: "0xsender",
        to: "0xrecipient",
        value: "1000",
        data: "0xdata"
      }

      assert {:ok, result} = SendTransactionPrism.handler(input, %{})
      assert result.tx_hash == "0xmocktxhash"
      assert result.block_number == 10
      assert result.status == 1
    end
  end

  test "handles transaction manager errors gracefully" do
    with_mock TransactionManager, [
      send_transaction: fn _addr, _params ->
        {:error, "Insufficient funds"}
      end
    ] do
      input = %{
        address: "0xsender",
        to: "0xrecipient",
        value: "1000"
      }

      assert {:error, "Transaction failed: \"Insufficient funds\""} = SendTransactionPrism.handler(input, %{})
    end
  end
end
