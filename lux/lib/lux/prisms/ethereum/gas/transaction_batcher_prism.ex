defmodule Lux.Prisms.Ethereum.Gas.TransactionBatcherPrism do
  @moduledoc """
  A prism that groups a list of Ethereum transactions into optimal batches.

  Two batching strategies are supported:

  * `:cost`  — minimise total gas cost by grouping transactions that share a
    recipient or similar data patterns, submitting them at the safest (lowest)
    gas price.
  * `:speed` — maximise throughput by packing as many transactions per block as
    possible and targeting the fast gas price tier.

  The prism returns the batched groups, an estimated gas savings percentage, and
  the recommended gas price for submission.

  ## Examples

      iex> Lux.Prisms.Ethereum.Gas.TransactionBatcherPrism.handler(%{
      ...>   transactions: [
      ...>     %{to: "0xAbc...", value: 0.1, data: "0x"},
      ...>     %{to: "0xDef...", value: 0.2, data: "0x"}
      ...>   ],
      ...>   strategy: :cost
      ...> }, %{})
      {:ok, %{
        batches: [[%{to: "0xAbc...", value: 0.1, data: "0x"}, %{to: "0xDef...", value: 0.2, data: "0x"}]],
        savings_pct: 15.0,
        recommended_gas_price: 20.0
      }}
  """

  use Lux.Prism,
    name: "Ethereum Transaction Batcher",
    description: "Groups transactions into optimal batches to reduce gas costs or maximise speed",
    input_schema: %{
      type: :object,
      properties: %{
        transactions: %{
          type: :array,
          description: "List of transactions to batch",
          items: %{
            type: :object,
            properties: %{
              to: %{type: :string, description: "Recipient address"},
              value: %{type: :number, description: "ETH value to send"},
              data: %{type: :string, description: "Hex-encoded calldata"}
            },
            required: ["to"]
          }
        },
        strategy: %{
          type: :string,
          enum: ["cost", "speed"],
          description: "Batching strategy: cost minimises fees, speed maximises throughput",
          default: "cost"
        }
      },
      required: ["transactions"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        batches: %{
          type: :array,
          description: "List of transaction batches, each batch is a list of transactions"
        },
        savings_pct: %{
          type: :number,
          description: "Estimated gas cost savings percentage compared to sending individually"
        },
        recommended_gas_price: %{
          type: :number,
          description: "Recommended gas price in Gwei for the chosen strategy"
        }
      },
      required: ["batches", "savings_pct", "recommended_gas_price"]
    }

  require Logger

  @rpc_url "https://eth.llamarpc.com"
  # Maximum transactions per batch before splitting into a new one.
  @max_batch_size 50

  @doc """
  Groups transactions and calculates batch parameters.
  """
  def handler(params, _ctx) do
    transactions = Map.get(params, :transactions, [])
    strategy = params |> Map.get(:strategy, :cost) |> normalize_strategy()
    req_opts = Application.get_env(:lux, __MODULE__, [])

    with {:ok, gas_price_gwei} <- fetch_gas_price(strategy, req_opts) do
      batches = build_batches(transactions, strategy)
      savings = estimate_savings(transactions, batches, strategy)

      {:ok,
       %{
         batches: batches,
         savings_pct: savings,
         recommended_gas_price: gas_price_gwei
       }}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_batches(transactions, :cost) do
    # Cost strategy: group by recipient to reuse warm storage slots.
    transactions
    |> Enum.group_by(fn tx -> Map.get(tx, :to, Map.get(tx, "to", "unknown")) end)
    |> Map.values()
    |> Enum.flat_map(&chunk_list(&1, @max_batch_size))
  end

  defp build_batches(transactions, :speed) do
    # Speed strategy: pack as many transactions as possible per batch.
    chunk_list(transactions, @max_batch_size)
  end

  defp chunk_list(list, size) do
    list
    |> Enum.chunk_every(size)
  end

  defp estimate_savings(_transactions, batches, :cost) do
    # Estimate: grouping by recipient saves ~15% due to warm account access.
    num_batches = length(batches)
    total_txns = batches |> List.flatten() |> length()

    if total_txns <= 1 or num_batches >= total_txns do
      0.0
    else
      savings_ratio = 1.0 - num_batches / total_txns
      Float.round(savings_ratio * 100.0 * 0.15, 2)
    end
  end

  defp estimate_savings(_transactions, batches, :speed) do
    # Speed strategy: minimal savings, focus is throughput.
    num_batches = length(batches)
    total_txns = batches |> List.flatten() |> length()

    if total_txns <= 1 or num_batches >= total_txns do
      0.0
    else
      Float.round((1.0 - num_batches / total_txns) * 100.0 * 0.05, 2)
    end
  end

  defp fetch_gas_price(strategy, req_opts) do
    body = %{
      jsonrpc: "2.0",
      method: "eth_gasPrice",
      params: [],
      id: 1
    }

    case Req.post(@rpc_url, [json: body] ++ req_opts) do
      {:ok, %{status: 200, body: %{"result" => hex}}} when is_binary(hex) ->
        base_gwei = hex_to_integer(hex) / 1.0e9

        price =
          case strategy do
            :cost -> Float.round(base_gwei * 0.85, 2)
            :speed -> Float.round(base_gwei * 1.25, 2)
            _ -> Float.round(base_gwei, 2)
          end

        {:ok, price}

      {:ok, %{status: 200, body: %{"error" => %{"message" => msg}}}} ->
        {:error, "eth_gasPrice RPC error: #{msg}"}

      {:ok, response} ->
        {:error, "Unexpected RPC response: #{inspect(response.body)}"}

      {:error, reason} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end

  defp normalize_strategy(:cost), do: :cost
  defp normalize_strategy(:speed), do: :speed
  defp normalize_strategy("cost"), do: :cost
  defp normalize_strategy("speed"), do: :speed
  defp normalize_strategy(_), do: :cost

  defp hex_to_integer("0x" <> hex), do: String.to_integer(hex, 16)
  defp hex_to_integer(hex) when is_binary(hex), do: String.to_integer(hex, 16)
end
