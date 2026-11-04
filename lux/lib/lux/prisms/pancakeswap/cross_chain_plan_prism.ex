defmodule Lux.Prisms.PancakeSwap.CrossChainPlanPrism do
  @moduledoc """
  Plans cross-chain moves of farming capital to the chain with the best APR.

  Input is one entry per chain with the current `apr` of the pool you farm there
  (a fraction, `0.3` = 30%) and the `position_usd` held on that chain. The chain with the
  highest APR is the destination. For every other chain holding a position the prism
  estimates the gain over `horizon_days`:

      gross_gain = position_usd * (best_apr - apr) * horizon_days / 365
      net_gain   = gross_gain - bridge_fee_usd

  and recommends a move only when `net_gain` is positive and at least `min_gain_usd`.

  The prism does **not** bridge anything. Each move carries a `bridge` descriptor step
  (source chain, destination chain, USD amount, optional token label) that tells the
  caller what to execute with a bridge such as the PancakeSwap bridge or Stargate;
  after the funds arrive use `Lux.Prisms.PancakeSwap.FarmTransactionPrism` and
  `Lux.Prisms.PancakeSwap.LiquidityTransactionPrism` on the destination chain. Combine it
  with `Lux.Prisms.PancakeSwap.PositionsPrism` to gather the per-chain positions.

  ## Example

      iex> Lux.Prisms.PancakeSwap.CrossChainPlanPrism.run(%{
      ...>   chains: [
      ...>     %{chain: "bsc", apr: 0.12, position_usd: 20_000},
      ...>     %{chain: "arbitrum", apr: 0.35, position_usd: 0}
      ...>   ],
      ...>   bridge_fee_usd: 15
      ...> })
      {:ok,
       %{
         recommended: true,
         best_chain: "arbitrum",
         moves: [%{from_chain: "bsc", to_chain: "arbitrum", net_gain_usd: 4585.0, ...}]
       }}
  """

  use Lux.Prism,
    name: "PancakeSwap Cross-chain Plan",
    description: "Recommends which chain to move farming capital to, net of bridge fees",
    input_schema: %{
      type: :object,
      properties: %{
        chains: %{
          type: :array,
          description: "Per-chain APR and position size",
          items: %{
            type: :object,
            properties: %{
              chain: %{type: :string, description: "Chain name or id"},
              apr: %{type: :number, minimum: 0, description: "Farm APR as a fraction"},
              position_usd: %{
                type: :number,
                minimum: 0,
                description: "Capital on this chain in USD"
              }
            },
            required: ["chain", "apr", "position_usd"]
          }
        },
        bridge_fee_usd: %{
          type: :number,
          minimum: 0,
          default: 0,
          description: "Cost of one bridge"
        },
        min_gain_usd: %{type: :number, minimum: 0, default: 0, description: "Minimum net gain"},
        horizon_days: %{type: :integer, minimum: 1, default: 365, description: "Holding period"},
        token: %{type: :string, description: "Label of the asset to bridge (for the bridge step)"}
      },
      required: ["chains"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        recommended: %{type: :boolean},
        best_chain: %{type: :string},
        horizon_days: %{type: :integer},
        reason: %{type: :string},
        moves: %{type: :array}
      },
      required: ["recommended", "best_chain", "moves"]
    }

  alias Lux.Integrations.PancakeSwap

  def handler(input, _ctx) do
    bridge_fee = PancakeSwap.field(input, :bridge_fee_usd, 0)
    min_gain = PancakeSwap.field(input, :min_gain_usd, 0)
    horizon = PancakeSwap.field(input, :horizon_days, 365)

    with {:ok, entries} <- parse_entries(PancakeSwap.field(input, :chains)),
         :ok <- validate_number(:bridge_fee_usd, bridge_fee),
         :ok <- validate_number(:min_gain_usd, min_gain),
         :ok <- validate_horizon(horizon) do
      best = Enum.max_by(entries, & &1.apr)
      token = PancakeSwap.field(input, :token)

      moves =
        entries
        |> Enum.reject(&(&1.chain.id == best.chain.id))
        |> Enum.filter(&(&1.position_usd > 0 and &1.apr < best.apr))
        |> Enum.map(&build_move(&1, best, bridge_fee, horizon, token))
        |> Enum.filter(&(&1.net_gain_usd > 0 and &1.net_gain_usd >= min_gain))
        |> Enum.sort_by(& &1.net_gain_usd, :desc)

      {:ok,
       %{
         recommended: moves != [],
         best_chain: best.chain.name,
         horizon_days: horizon,
         reason: reason(moves, best),
         moves: moves
       }}
    end
  end

  defp parse_entries([_ | _] = raw) do
    raw
    |> Enum.reduce_while({:ok, []}, fn entry, {:ok, acc} ->
      case parse_entry(entry) do
        {:ok, parsed} -> {:cont, {:ok, [parsed | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, entries} -> check_duplicates(Enum.reverse(entries))
      error -> error
    end
  end

  defp parse_entries(_), do: {:error, "chains must be a non-empty list"}

  defp parse_entry(entry) when is_map(entry) do
    apr = PancakeSwap.field(entry, :apr)
    position = PancakeSwap.field(entry, :position_usd)

    with {:ok, chain} <- PancakeSwap.fetch_chain(PancakeSwap.field(entry, :chain)),
         true <- (is_number(apr) and apr >= 0) || {:error, "apr must be a non-negative number"},
         true <-
           (is_number(position) and position >= 0) ||
             {:error, "position_usd must be a non-negative number"} do
      {:ok, %{chain: chain, apr: apr, position_usd: position}}
    end
  end

  defp parse_entry(entry), do: {:error, "invalid chain entry: #{inspect(entry)}"}

  defp check_duplicates(entries) do
    ids = Enum.map(entries, & &1.chain.id)

    if length(ids) == length(Enum.uniq(ids)),
      do: {:ok, entries},
      else: {:error, "each chain may only appear once"}
  end

  defp validate_number(_name, value) when is_number(value) and value >= 0, do: :ok
  defp validate_number(name, _value), do: {:error, "#{name} must be a non-negative number"}

  defp validate_horizon(days) when is_integer(days) and days >= 1, do: :ok
  defp validate_horizon(_), do: {:error, "horizon_days must be an integer >= 1"}

  defp build_move(from, to, bridge_fee, horizon, token) do
    gross = from.position_usd * (to.apr - from.apr) * horizon / 365

    %{
      from_chain: from.chain.name,
      to_chain: to.chain.name,
      from_chain_id: from.chain.id,
      to_chain_id: to.chain.id,
      amount_usd: from.position_usd,
      apr_from: from.apr,
      apr_to: to.apr,
      gross_gain_usd: gross,
      bridge_fee_usd: bridge_fee,
      net_gain_usd: gross - bridge_fee,
      steps: [bridge_step(from, to, token)]
    }
  end

  defp bridge_step(from, to, token) do
    step = %{
      name: "bridge",
      type: "bridge",
      from_chain_id: from.chain.id,
      to_chain_id: to.chain.id,
      amount_usd: from.position_usd,
      note:
        "Execute with the PancakeSwap bridge or Stargate; this prism does not build bridge calldata"
    }

    if token, do: Map.put(step, :token, token), else: step
  end

  defp reason([], best), do: "No move beats the bridge cost; best APR is on #{best.chain.name}"

  defp reason(moves, best),
    do: "Move #{length(moves)} position(s) to #{best.chain.name}, the chain with the best APR"
end
