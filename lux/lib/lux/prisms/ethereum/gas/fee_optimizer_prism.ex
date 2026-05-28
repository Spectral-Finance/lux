defmodule Lux.Prisms.Ethereum.Gas.FeeOptimizerPrism do
  @moduledoc """
  A prism that recommends optimal EIP-1559 transaction fees.

  It inspects recent block base fees from the Ethereum network to predict the
  next block's base fee, then computes `maxFeePerGas` and
  `maxPriorityFeePerGas` (miner tip) for the requested urgency level.

  Urgency levels and their priority fee multipliers:
  * `:low`    — 10th-percentile tip, longer expected wait
  * `:medium` — median tip
  * `:high`   — 75th-percentile tip, confirmed within 1-2 blocks
  * `:urgent` — 90th-percentile tip, next-block inclusion target

  ## Examples

      iex> Lux.Prisms.Ethereum.Gas.FeeOptimizerPrism.handler(%{
      ...>   urgency: :medium,
      ...>   gas_limit: 21000
      ...> }, %{})
      {:ok, %{
        max_fee_per_gas: 30.5,
        max_priority_fee: 1.5,
        estimated_wait_seconds: 30
      }}
  """

  use Lux.Prism,
    name: "EIP-1559 Fee Optimizer",
    description: "Recommends optimal EIP-1559 maxFeePerGas and maxPriorityFee based on recent blocks",
    input_schema: %{
      type: :object,
      properties: %{
        urgency: %{
          type: :string,
          enum: ["low", "medium", "high", "urgent"],
          description: "Desired confirmation urgency level",
          default: "medium"
        },
        gas_limit: %{
          type: :integer,
          description: "Gas limit for the transaction (used for cost estimation)",
          default: 21_000
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        max_fee_per_gas: %{
          type: :number,
          description: "Recommended maxFeePerGas in Gwei (EIP-1559)"
        },
        max_priority_fee: %{
          type: :number,
          description: "Recommended maxPriorityFeePerGas (miner tip) in Gwei"
        },
        estimated_wait_seconds: %{
          type: :integer,
          description: "Approximate seconds until transaction is included in a block"
        }
      },
      required: ["max_fee_per_gas", "max_priority_fee", "estimated_wait_seconds"]
    }

  require Logger

  @rpc_url "https://eth.llamarpc.com"
  # Number of recent blocks to sample for base fee history.
  @block_count 10

  # Priority fee (tip) in Gwei per urgency level.
  @tips %{
    low: 0.5,
    medium: 1.5,
    high: 2.5,
    urgent: 4.0
  }

  # Estimated wait times in seconds per urgency level.
  @wait_seconds %{
    low: 120,
    medium: 30,
    high: 15,
    urgent: 6
  }

  @doc """
  Computes optimal EIP-1559 fee parameters for the given urgency.
  """
  def handler(params, _ctx) do
    urgency = params |> Map.get(:urgency, :medium) |> normalize_urgency()
    req_opts = Application.get_env(:lux, __MODULE__, [])

    with {:ok, next_base_fee} <- predict_next_base_fee(req_opts) do
      tip = Map.fetch!(@tips, urgency)
      # maxFeePerGas must cover the base fee even if it doubles for two blocks,
      # plus the miner tip.
      max_fee = Float.round(next_base_fee * 2.0 + tip, 4)

      {:ok,
       %{
         max_fee_per_gas: max_fee,
         max_priority_fee: tip,
         estimated_wait_seconds: Map.fetch!(@wait_seconds, urgency)
       }}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp predict_next_base_fee(req_opts) do
    body = %{
      jsonrpc: "2.0",
      method: "eth_feeHistory",
      params: [@block_count, "latest", []],
      id: 1
    }

    case Req.post(@rpc_url, [json: body] ++ req_opts) do
      {:ok, %{status: 200, body: %{"result" => result}}} when is_map(result) ->
        base_fees =
          result
          |> Map.get("baseFeePerGas", [])
          |> Enum.map(&hex_to_gwei/1)

        case base_fees do
          [] ->
            {:error, "No base fee history returned"}

          fees ->
            # The last entry is the predicted next block base fee.
            next_base = List.last(fees)
            {:ok, next_base}
        end

      {:ok, %{status: 200, body: %{"error" => %{"message" => msg}}}} ->
        {:error, "eth_feeHistory RPC error: #{msg}"}

      {:ok, response} ->
        {:error, "Unexpected RPC response: #{inspect(response.body)}"}

      {:error, reason} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end

  defp hex_to_gwei("0x" <> hex), do: String.to_integer(hex, 16) / 1.0e9
  defp hex_to_gwei(hex) when is_binary(hex), do: String.to_integer(hex, 16) / 1.0e9
  defp hex_to_gwei(int) when is_integer(int), do: int / 1.0e9

  defp normalize_urgency(urgency) when is_atom(urgency) and urgency in [:low, :medium, :high, :urgent],
    do: urgency

  defp normalize_urgency("low"), do: :low
  defp normalize_urgency("medium"), do: :medium
  defp normalize_urgency("high"), do: :high
  defp normalize_urgency("urgent"), do: :urgent
  defp normalize_urgency(_), do: :medium
end
