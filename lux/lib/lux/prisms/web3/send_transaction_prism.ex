defmodule Lux.Prisms.Web3.SendTransactionPrism do
  @moduledoc """
  Lux Prism to send a transaction using a managed wallet address and queue supervisor.
  Blocks execution until the transaction is mined on-chain and returns the transaction receipt.
  """

  use Lux.Prism,
    name: "Web3 Send Transaction",
    description: "Sends a transaction using a managed wallet address and transaction queue manager",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "The sender wallet address that is already managed"
        },
        to: %{
          type: :string,
          description: "The recipient Ethereum address"
        },
        data: %{
          type: :string,
          description: "Optional hex-encoded contract call data"
        },
        value: %{
          type: :string,
          description: "Optional value in Wei to transfer (as string to handle large numbers)"
        },
        gas_limit: %{
          type: :integer,
          description: "Optional gas limit override"
        }
      },
      required: ["address", "to"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        tx_hash: %{
          type: :string,
          description: "The hash of the transaction"
        },
        block_number: %{
          type: :integer,
          description: "The block number where transaction was included"
        },
        status: %{
          type: :integer,
          description: "Receipt status (1 for success, 0 for revert)"
        }
      },
      required: ["tx_hash", "block_number", "status"]
    }

  @impl true
  def handler(input, _ctx) do
    address = input.address
    to = input.to
    data = Map.get(input, :data)
    gas_limit = Map.get(input, :gas_limit)

    value =
      case Map.get(input, :value) do
        nil -> 0
        val when is_integer(val) -> val
        val when is_binary(val) -> String.to_integer(val)
      end

    tx_params = %{
      to: to,
      data: data,
      value: value,
      gas_limit: gas_limit
    }

    case Lux.Web3.TransactionManager.send_transaction(address, tx_params) do
      {:ok, receipt} ->
        status_int = hex_to_int(receipt["status"])
        block_num_int = hex_to_int(receipt["blockNumber"])

        {:ok,
         %{
           tx_hash: receipt["transactionHash"],
           block_number: block_num_int,
           status: status_int
         }}

      {:error, reason} ->
        {:error, "Transaction failed: #{inspect(reason)}"}
    end
  end

  defp hex_to_int("0x" <> hex), do: String.to_integer(hex, 16)
  defp hex_to_int(hex) when is_binary(hex), do: String.to_integer(hex, 16)
  defp hex_to_int(int) when is_integer(int), do: int
  defp hex_to_int(nil), do: 0
end
