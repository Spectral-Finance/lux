defmodule Lux.Lenses.Curve.PoolsList do
  @moduledoc """
  Lens for fetching all available Curve Finance pools on the configured chain.

  Returns a list of pools with their APY, TVL, coin compositions, and reward structures.

  ## Examples

      # Get all pools on Ethereum mainnet
      Lux.Lenses.Curve.PoolsList.focus(%{})

      # Get pools on Polygon
      # Configure chain_id: "137" in Lux.Integrations.Curve
  """

  use Lux.Lens,
    name: "Curve.PoolsList",
    description: "Lists all available Curve Finance pools with APR and TVL data",
    url: Lux.Integrations.Curve.pools_list_url(),
    method: :get,
    headers: Lux.Integrations.Curve.headers(),
    schema: %{
      type: :object,
      properties: %{
        chain_name: %{
          type: :string,
          description: "Override the chain name (e.g., 'eth', 'polygon', 'arbitrum')"
        }
      },
      additionalProperties: false
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    chain_name = Map.get(params, :chain_name, Lux.Integrations.Curve.chain_name())
    url = Lux.Integrations.Curve.base_url(chain_name) <> "/pools/#{chain_name}/list"
    %{"url" => url}
  end

  @doc """
  Transforms the API response into a structured format.
  """
  @impl true
  def after_focus(response) do
    with %{"status" => "success", "result" => pools} <- response,
         is_list(pools) <- pools do
      {:ok,
       %{
         chain: Lux.Integrations.Curve.chain_name(),
         chain_id: Lux.Integrations.Curve.chain_id(),
         pool_count: length(pools),
         pools: Enum.map(pools, &sanitize_pool/1)
       }}
    else
      %{"status" => "error", "error" => error} ->
        {:error, "Curve API error: #{inspect(error)}"}

      %{"status" => "error"} ->
        {:error, "Curve API returned error status"}

      _ ->
        {:ok, %{chain: Lux.Integrations.Curve.chain_name(), pools: [], pool_count: 0}}
    end
  end

  defp sanitize_pool(pool) when is_map(pool) do
    %{
      name: Map.get(pool, "name", ""),
      coins: Map.get(pool, "coins", []),
      coin_addresses: Map.get(pool, "coin_addresses", []),
      usd_total: Map.get(pool, "usdTotal", 0),
      usd_total_formatted: Map.get(pool, "usdTotalFormatted", ""),
      apr: sanitize_apr(Map.get(pool, "apr", %)),
      type: Map.get(pool, "type", ""),
      pool_type: Map.get(pool, "poolType", ""),
      address: Map.get(pool, "address", ""),
      gauge_address: Map.get(pool, "gauge_address", ""),
      pool_id: Map.get(pool, "poolId", 0),
      meta: Map.get(pool, "meta", %{})
    }
  end

  defp sanitize_pool(_), do: %{}

  defp sanitize_apr(apr) when is_map(apr) do
    %{
      base: Map.get(apr, "base", 0),
      rewards: Map.get(apr, "rewards", 0),
      crv: Map.get(apr, "crv", 0),
      fee: Map.get(apr, "fee", 0),
      total: Map.get(apr, "total", 0)
    }
  end

  defp sanitize_apr(_), do: %{base: 0, rewards: 0, crv: 0, fee: 0, total: 0}
end
