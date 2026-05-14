defmodule Lux.Prisms.Web3.WalletOperation do
  @moduledoc """
  Prism wrapper around `Lux.Web3.WalletInfrastructure`.
  """

  use Lux.Prism,
    name: "Web3 Wallet Operation",
    description: "Registers wallets, builds transactions, and manages offline transaction queues",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: [
            "register_wallet",
            "create_wallet",
            "build_transaction",
            "enqueue_transaction",
            "monitor_transactions"
          ]
        },
        wallet: %{type: :object},
        transaction: %{type: :object},
        queue: %{type: :object},
        receipts: %{type: :object}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        result: %{type: :object}
      },
      required: ["status", "result"]
    }

  alias Lux.Web3.WalletInfrastructure

  def handler(%{action: "create_wallet"} = input, _ctx) do
    input
    |> Map.get(:wallet, %{})
    |> WalletInfrastructure.create_wallet()
    |> normalize_result()
  end

  def handler(%{action: "register_wallet"} = input, _ctx) do
    input
    |> Map.get(:wallet, %{})
    |> WalletInfrastructure.register_wallet()
    |> normalize_result()
  end

  def handler(%{action: "build_transaction"} = input, _ctx) do
    input
    |> Map.get(:transaction, %{})
    |> WalletInfrastructure.build_transaction()
    |> normalize_result()
  end

  def handler(%{action: "enqueue_transaction"} = input, _ctx) do
    queue = Map.get(input, :queue, WalletInfrastructure.new_queue())

    input
    |> Map.fetch(:transaction)
    |> case do
      {:ok, transaction} -> WalletInfrastructure.enqueue_transaction(queue, transaction)
      :error -> {:error, :missing_transaction}
    end
    |> normalize_result()
  end

  def handler(%{action: "monitor_transactions"} = input, _ctx) do
    queue = Map.get(input, :queue, WalletInfrastructure.new_queue())
    receipts = Map.get(input, :receipts, %{})

    WalletInfrastructure.monitor_transactions(queue, receipts)
    |> normalize_result()
  end

  def handler(_input, _ctx), do: {:error, "Unsupported wallet operation"}

  defp normalize_result({:ok, result}), do: {:ok, %{status: "success", result: result}}
  defp normalize_result({:error, reason}), do: {:error, reason}
end
