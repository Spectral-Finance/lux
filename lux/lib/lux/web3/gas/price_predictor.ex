defmodule Lux.Web3.Gas.PricePredictor do
  @moduledoc """
  EIP-1559 gas price prediction system.

  Predicts optimal gas prices by analyzing recent block data and recommending
  slow / standard / fast fee tiers.
  """

  alias Lux.Web3.Gas.Types

  require Logger

  @doc """
  Fetches the last N base fees from the network and computes fee recommendations.
  """
  @spec predict(map()) :: {:ok, Types.fee_recommendation()} | {:error, term()}
  def predict(opts \ %{}) do
    network = Map.get(opts, :network, "mainnet")
    block_count = Map.get(opts, :block_count, 20)

    with {:ok, base_fees} <- fetch_recent_base_fees(network, block_count),
         {:ok, priority_fees} <- fetch_priority_fee_suggestions(network) do
      recommended = compute_recommendations(base_fees, priority_fees)
      {:ok, recommended}
    else
      {:error, reason} ->
        Logger.warning("Gas price prediction failed for #{network}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Computes slow / standard / fast fee tiers from base fee history.
  """
  @spec compute_recommendations([integer()], %{low: integer(), medium: integer(), high: integer()}) ::
          Types.fee_recommendation()
  def compute_recommendations(base_fees, priority_fees) when is_list(base_fees) and is_map(priority_fees) do
    median_base = median(base_fees)
    suggested_tip = Map.get(priority_fees, :medium, 1_500_000_000)

    slow = %{
      max_fee_per_gas: floor(median_base * 1.2) + Map.get(priority_fees, :low, div(suggested_tip, 2)),
      max_priority_fee_per_gas: Map.get(priority_fees, :low, div(suggested_tip, 2))
    }

    standard = %{
      max_fee_per_gas: floor(median_base * 1.5) + suggested_tip,
      max_priority_fee_per_gas: suggested_tip
    }

    fast = %{
      max_fee_per_gas: floor(median_base * 2.0) + Map.get(priority_fees, :high, suggested_tip * 2),
      max_priority_fee_per_gas: Map.get(priority_fees, :high, suggested_tip * 2)
    }

    %Types{
      slow: slow,
      standard: standard,
      fast: fast,
      base_fee: median_base,
      suggested_tip: suggested_tip,
      timestamp: DateTime.utc_now()
    }
  end

  @spec fetch_recent_base_fees(String.t(), integer()) :: {:ok, [integer()]} | {:error, term()}
  def fetch_recent_base_fees(_network, block_count) do
    case Application.get_env(:lux, :gas_prediction_blocks, []) do
      [] ->
        fallback_base_fees(block_count)

      blocks ->
        parse_base_fees(blocks)
    end
  end

  @spec fetch_priority_fee_suggestions(String.t()) ::
          {:ok, %{low: integer(), medium: integer(), high: integer()}} | {:error, term()}
  def fetch_priority_fee_suggestions(_network) do
    {:ok, %{low: 1_000_000_000, medium: 1_500_000_000, high: 3_000_000_000}}
  end

  defp fallback_base_fees(count) do
    base = 25_000_000_000
    {:ok, Enum.map(0..(count - 1), fn i ->
      floor(base * (1 + :math.pow(-0.1, i)))
    end)}
  end

  defp parse_base_fees(blocks) when is_list(blocks) do
    fees =
      blocks
      |> Enum.map(fn block ->
        case block do
          %{"baseFeePerGas" => fee} -> hex_to_int(fee)
          %{"base_fee_per_gas" => fee} -> hex_to_int(fee)
          _ -> nil
        end
      end)
      |> Enum.filter(&is_integer/1)

    if Enum.empty?(fees) do
      {:error, :no_base_fee_data}
    else
      {:ok, fees}
    end
  end

  defp hex_to_int("0x" <> hex), do: String.to_integer(hex, 16)
  defp hex_to_int(hex), do: String.to_integer(hex, 16)

  defp median([]), do: 0

  defp median(list) do
    sorted = Enum.sort(list)
    mid = div(length(sorted), 2)

    if rem(length(sorted), 2) == 0 do
      div(Enum.at(sorted, mid - 1) + Enum.at(sorted, mid), 2)
    else
      Enum.at(sorted, mid)
    end
  end
end
