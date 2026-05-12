defmodule Lux.Lenses.DeFiLlama.YieldsLens do
  @moduledoc """
  Lens for fetching yield pool data from the DeFiLlama yields API.

  ## Examples

      iex> Lux.Lenses.DeFiLlama.YieldsLens.focus(%{})
      {:ok, %{pools: [%{pool: "0x...", apy: 15.5, tvl_usd: 1000000.0, ...}, ...]}}

  The response includes for each pool:
  - `pool`: Pool contract address or identifier
  - `apy`: Current APY percentage
  - `tvl_usd`: Total value locked in USD
  - `chain`: Blockchain network
  - `project`: DeFi project name
  - `symbol`: Underlying token symbols
  - And additional metadata
  """

  alias Lux.Integrations.DeFiLlama

  use Lux.Lens,
    name: "DeFiLlama Yields",
    description: "Fetches yield pool data from DeFiLlama yields API",
    url: "#{DeFiLlama.yields_base_url()}/pools",
    method: :get,
    headers: [{"accept", "application/json"}],
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  @impl true
  def after_focus(%{"data" => pools}) when is_list(pools) do
    transformed =
      Enum.map(pools, fn p ->
        %{
          pool: p["pool"],
          chain: p["chain"],
          project: p["project"],
          symbol: p["symbol"],
          tvl_usd: p["tvlUsd"],
          apy: p["apy"],
          apy_base: p["apyBase"],
          apy_reward: p["apyReward"],
          reward_tokens: p["rewardTokens"],
          underlying_tokens: p["underlyingTokens"],
          pool_meta: p["poolMeta"],
          il_risk: p["ilRisk"],
          exposure: p["exposure"],
          stablecoin: p["stablecoin"],
          predictions: p["predictions"],
          count: p["count"],
          mu: p["mu"],
          sigma: p["sigma"],
          outlier: p["outlier"],
          apy_pct_1d: p["apyPct1D"],
          apy_pct_7d: p["apyPct7D"],
          apy_pct_30d: p["apyPct30D"],
          volume_usd_1d: p["volumeUsd1D"],
          volume_usd_7d: p["volumeUsd7D"]
        }
      end)

    {:ok, %{pools: transformed}}
  end

  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end
end
