defmodule Lux.Integrations.PancakeSwap do
  @moduledoc "PancakeSwap integration for BSC DEX."
  def pools, do: graph("/pairs", "{pairs(first:100){id token0{symbol} token1{symbol} reserveUSD volumeUSD}}")
  def tokens, do: graph("/tokens", "{tokens(first:100){id symbol name derivedUSD}}")
  defp graph(path, q) do
    case Req.post("https://api.thegraph.com/subgraphs/name/pancakeswap" <> path, json: %{"query" => "query " <> q}) do
      {:ok, %{status: 200, body: %{"data" => d}}} -> {:ok, d}
      {:ok, %{status: 200, body: b}} -> {:ok, b}
      {:error, e} -> {:error, inspect(e)}
    end
  end
end