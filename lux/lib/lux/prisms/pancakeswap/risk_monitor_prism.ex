defmodule Lux.Prisms.PancakeSwap.RiskMonitorPrism do
  @moduledoc """
  Scores the risk of a PancakeSwap farming position.

  All inputs are optional; only the checks whose inputs are present are run:

    * **Impermanent loss** - from `entry_price_ratio` and `current_price_ratio` (the
      price of token A in token B at entry and now). With `r = current / entry` the loss
      versus holding is `2 * sqrt(r) / (1 + r) - 1` (a negative fraction).
    * **Low TVL** - `pool_tvl_usd` below `min_tvl_usd` (default 1,000,000).
    * **Pool share** - `position_usd / pool_tvl_usd` above `max_pool_share` (default 10%),
      which makes exiting the position move the pool.
    * **Emissions** - `cake_per_block` of `0` means the farm no longer pays rewards.

  `risk_level` is `"high"` when any alert is high, `"medium"` when there are only medium
  alerts and `"low"` otherwise.

  ## Example

      iex> Lux.Prisms.PancakeSwap.RiskMonitorPrism.run(%{
      ...>   entry_price_ratio: 100,
      ...>   current_price_ratio: 400,
      ...>   pool_tvl_usd: 250_000
      ...> })
      {:ok,
       %{
         risk_level: "high",
         impermanent_loss: -0.2,
         alerts: [%{code: "impermanent_loss", severity: "high", message: "..."}, ...]
       }}
  """

  use Lux.Prism,
    name: "PancakeSwap Risk Monitor",
    description:
      "Flags impermanent loss, low TVL, concentration and stopped emissions for a farm position",
    input_schema: %{
      type: :object,
      properties: %{
        entry_price_ratio: %{type: :number, description: "Token A / token B price at entry"},
        current_price_ratio: %{type: :number, description: "Token A / token B price now"},
        pool_tvl_usd: %{type: :number, description: "Pool TVL in USD"},
        position_usd: %{type: :number, description: "Position value in USD"},
        cake_per_block: %{
          type: [:string, :integer],
          description: "Pool CAKE emission per block (wei)"
        },
        min_tvl_usd: %{type: :number, default: 1_000_000},
        max_impermanent_loss: %{type: :number, default: 0.05, description: "Fraction, 0.05 = 5%"},
        max_pool_share: %{type: :number, default: 0.1, description: "Fraction of pool TVL"}
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        risk_level: %{type: :string, enum: ["low", "medium", "high"]},
        impermanent_loss: %{type: :number},
        pool_share: %{type: :number},
        alerts: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              code: %{type: :string},
              severity: %{type: :string, enum: ["medium", "high"]},
              message: %{type: :string}
            }
          }
        }
      },
      required: ["risk_level", "alerts"]
    }

  alias Lux.Integrations.PancakeSwap

  @doc """
  Impermanent loss (a negative fraction, `0` when the price ratio is unchanged) for the
  price ratio change `r = current / entry`.

  ## Examples

      iex> Lux.Prisms.PancakeSwap.RiskMonitorPrism.impermanent_loss(1)
      0.0
  """
  @spec impermanent_loss(number()) :: float()
  def impermanent_loss(r) when is_number(r) and r > 0 do
    2 * :math.sqrt(r) / (1 + r) - 1
  end

  def handler(input, _ctx) do
    with {:ok, params} <- parse(input) do
      il = il(params)
      share = pool_share(params)

      alerts =
        Enum.reject(
          [
            il_alert(il, params.max_impermanent_loss),
            tvl_alert(params.pool_tvl_usd, params.min_tvl_usd),
            share_alert(share, params.max_pool_share),
            emission_alert(params.cake_per_block)
          ],
          &is_nil/1
        )

      result = %{risk_level: risk_level(alerts), alerts: alerts}
      result = if il, do: Map.put(result, :impermanent_loss, il), else: result
      {:ok, if(share, do: Map.put(result, :pool_share, share), else: result)}
    end
  end

  defp parse(input) do
    fields = [
      entry_price_ratio: {nil, :positive},
      current_price_ratio: {nil, :positive},
      pool_tvl_usd: {nil, :positive},
      position_usd: {nil, :positive},
      min_tvl_usd: {1_000_000, :non_negative},
      max_impermanent_loss: {0.05, :non_negative},
      max_pool_share: {0.1, :non_negative}
    ]

    fields
    |> Enum.reduce_while({:ok, %{}}, fn {key, {default, kind}}, {:ok, acc} ->
      value = PancakeSwap.field(input, key) || default

      if valid?(value, kind) do
        {:cont, {:ok, Map.put(acc, key, value)}}
      else
        {:halt, {:error, "#{key} must be a #{String.replace(to_string(kind), "_", "-")} number"}}
      end
    end)
    |> with_emission(input)
    |> check_ratios()
  end

  defp valid?(nil, _kind), do: true
  defp valid?(value, :positive), do: is_number(value) and value > 0
  defp valid?(value, :non_negative), do: is_number(value) and value >= 0

  defp with_emission({:ok, params}, input) do
    case PancakeSwap.field(input, :cake_per_block) do
      nil ->
        {:ok, Map.put(params, :cake_per_block, nil)}

      value ->
        case PancakeSwap.parse_amount(value) do
          {:ok, amount} -> {:ok, Map.put(params, :cake_per_block, amount)}
          :error -> {:error, "cake_per_block must be a non-negative integer (wei)"}
        end
    end
  end

  defp with_emission(error, _input), do: error

  defp check_ratios({:ok, %{entry_price_ratio: entry, current_price_ratio: current}})
       when is_nil(entry) != is_nil(current) do
    {:error, "entry_price_ratio and current_price_ratio must be provided together"}
  end

  defp check_ratios(result), do: result

  defp il(%{entry_price_ratio: entry, current_price_ratio: current}) when not is_nil(entry) do
    impermanent_loss(current / entry)
  end

  defp il(_params), do: nil

  defp pool_share(%{position_usd: position, pool_tvl_usd: tvl})
       when not is_nil(position) and not is_nil(tvl),
       do: position / tvl

  defp pool_share(_params), do: nil

  defp il_alert(nil, _max), do: nil

  defp il_alert(il, max) do
    loss = abs(il)

    cond do
      loss > 2 * max -> alert("impermanent_loss", "high", "Impermanent loss is #{percent(loss)}")
      loss > max -> alert("impermanent_loss", "medium", "Impermanent loss is #{percent(loss)}")
      true -> nil
    end
  end

  defp tvl_alert(nil, _min), do: nil

  defp tvl_alert(tvl, min) do
    cond do
      tvl < min / 10 ->
        alert("low_tvl", "high", "Pool TVL ($#{round(tvl)}) is far below $#{round(min)}")

      tvl < min ->
        alert("low_tvl", "medium", "Pool TVL ($#{round(tvl)}) is below $#{round(min)}")

      true ->
        nil
    end
  end

  defp share_alert(nil, _max), do: nil

  defp share_alert(share, max) when share > max,
    do: alert("pool_concentration", "medium", "Position is #{percent(share)} of the pool")

  defp share_alert(_share, _max), do: nil

  defp emission_alert(0),
    do: alert("emissions_stopped", "high", "The pool receives no CAKE emissions")

  defp emission_alert(_), do: nil

  defp alert(code, severity, message), do: %{code: code, severity: severity, message: message}

  defp percent(fraction), do: "#{Float.round(fraction * 100, 2)}%"

  defp risk_level(alerts) do
    cond do
      Enum.any?(alerts, &(&1.severity == "high")) -> "high"
      alerts != [] -> "medium"
      true -> "low"
    end
  end
end
