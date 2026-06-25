defmodule Lux.Lenses.UniswapV3.GetPoolData do
  @moduledoc "Lens for Uniswap V3 pool data via the subgraph."

  alias Lux.Integrations.UniswapV3
  @subgraph_url UniswapV3.subgraph_url()
  @headers      UniswapV3.subgraph_headers()

  @spec focus(%{pool_address: String.t()}) :: {:ok, map()} | {:error, term()}
  def focus(%{pool_address: addr}) do
    q = Jason.encode!(%{query: "{ pool(id: \\"#{String.downcase(addr)}\\") { id token0 { id symbol decimals } token1 { id symbol decimals } feeTier liquidity sqrtPrice tick token0Price token1Price volumeUSD totalValueLockedUSD feesUSD txCount } }"})
    case Req.post(@subgraph_url, body: q, headers: @headers) do
      {:ok, %{status: 200, body: %{"data" => %{"pool" => nil}}}} -> {:error, "Pool not found"}
      {:ok, %{status: 200, body: %{"data" => %{"pool" => pool}}}} -> {:ok, parse_pool(pool)}
      {:ok, %{status: 200, body: %{"errors" => e}}} -> {:error, e}
      {:ok, %{status: s}} -> {:error, "HTTP #{s}"}
      err -> err
    end
  end

  defp parse_pool(p) do
    %{address: p["id"], token0: p["token0"], token1: p["token1"],
      fee_tier: to_int(p["feeTier"]), liquidity: p["liquidity"],
      sqrt_price: p["sqrtPrice"], current_tick: to_int(p["tick"]),
      token0_price: to_float(p["token0Price"]), token1_price: to_float(p["token1Price"]),
      volume_usd: to_float(p["volumeUSD"]), tvl_usd: to_float(p["totalValueLockedUSD"]),
      fees_usd: to_float(p["feesUSD"]), tx_count: to_int(p["txCount"])}
  end

  defp to_int(nil), do: nil
  defp to_int(s) when is_binary(s), do: String.to_integer(s)
  defp to_int(n) when is_integer(n), do: n
  defp to_float(nil), do: nil
  defp to_float(s) when is_binary(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> nil
    end
  end
  defp to_float(n) when is_number(n), do: n / 1
end
