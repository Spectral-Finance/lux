defmodule Lux.Integrations.SushiSwap do
  @moduledoc "SushiSwap DEX integration for cross-chain swaps."
  @graph_url "https://api.thegraph.com/subgraphs/name/sushiswap"
  def pools, do: graph("sushiswap-ethereum", "{pools(first:50){id token0{id symbol} token1{id symbol} liquidity}}")
  def pairs, do: graph("sushiswap-ethereum", "{pairs(first:50){id token0{symbol} token1{symbol} reserveUSD volumeUSD}}")
  defp graph(sub, q) do
    case Req.post(@graph_url <> "/" <> sub, json: %{"query" => "query " <> q}) do
      {:ok, %{status: 200, body: %{"data" => d}}} -> {:ok, d}
      {:ok, %{status: 200, body: b}} -> {:ok, b}
      {:error, e} -> {:error, inspect(e)}
    end
  end
end