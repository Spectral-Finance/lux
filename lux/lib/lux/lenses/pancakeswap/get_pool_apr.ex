defmodule Lux.Lenses.PancakeSwap.GetPoolAPR do
  @moduledoc """
  A lens for calculating the approximate APR of a PancakeSwap v3 pool.
  """

  alias Lux.Lenses.PancakeSwap.GetPoolInfo

  use Lux.Lens,
    name: "Get PancakeSwap Pool APR",
    description: "Calculates approximate APR based on volume and TVL",
    schema: %{
      type: :object,
      properties: %{
        chain: %{type: :string, enum: ["bsc", "ethereum", "arbitrum", "base"], default: "bsc"},
        pool_address: %{type: :string, description: "The contract address of the pool"}
      },
      required: ["pool_address"]
    }

  @impl true
  def focus(input \\ %{}, opts \\ []) do
    GetPoolInfo.focus(input, opts)
  end

  @impl true
  def after_focus({:ok, pool}) do
    volume_24h = parse_float(pool["volumeUSD"])
    tvl = parse_float(pool["totalValueLockedUSD"])
    fee_tier = parse_float(pool["feeTier"]) / 1_000_000 # feeTier is in hundredths of a bip

    apr = if tvl > 0 do
      (volume_24h * fee_tier * 365) / tvl * 100
    else
      0.0
    end

    {:ok, %{
      pool_id: pool["id"],
      tokens: "#{pool["token0"]["symbol"]}/#{pool["token1"]["symbol"]}",
      apr_estimate: apr,
      tvl: tvl,
      volume_24h: volume_24h
    }}
  end

  def after_focus(error), do: error

  defp parse_float(nil), do: 0.0
  defp parse_float(val) when is_binary(val), do: String.to_float(val)
  defp parse_float(val) when is_number(val), do: val / 1.0
end
