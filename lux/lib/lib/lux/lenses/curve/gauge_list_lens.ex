defmodule Lux.Lenses.Curve.GaugeList do
  @moduledoc """
  Lens for fetching all Curve Finance gauges with voting and emission data.

  Gauges determine CRV emission distribution across pools. This lens helps
  identify the most rewarding pools for liquidity provision and gauge staking.

  ## Examples

      # Get all gauges on Ethereum mainnet
      Lux.Lenses.Curve.GaugeList.focus(%{})

      # Get gauges for a specific chain
      Lux.Lenses.Curve.GaugeList.focus(%{chain_name: "polygon"})
  """

  use Lux.Lens,
    name: "Curve.GaugeList",
    description: "Lists all Curve gauges with voting weight, emission rates, and CPI data",
    url: "https://api.curve.fi/v1/getAllGauges",
    method: :get,
    headers: Lux.Integrations.Curve.headers(),
    schema: %{
      type: :object,
      properties: %{
        chain_name: %{
          type: :string,
          description: "Chain name filter (e.g., 'eth', 'polygon', 'arbitrum', 'all')"
        }
      },
      additionalProperties: false
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    chain_name = Map.get(params, :chain_name, "all")
    url = "https://api.curve.fi/v1/getAllGauges"
    %{"url" => url, "chain_name" => chain_name}
  end

  @doc """
  Transforms the API response into a structured format.
  """
  @impl true
  def after_focus(response) do
    with %{"status" => "success", "result" => result} <- response,
         %{"gauges" => gauges} <- result,
         is_list(gauges) <- gauges do
      {:ok,
       %{
         chain: Lux.Integrations.Curve.chain_name(),
         gauge_count: length(gauges),
         gauges: Enum.map(gauges, &sanitize_gauge/1)
       }}
    else
      %{"status" => "error", "error" => error} ->
        {:error, "Curve API error: #{inspect(error)}"}

      %{"status" => "error"} ->
        {:error, "Curve API returned error status"}

      _ ->
        {:error, "Unexpected response format: missing 'gauges' key"}
    end
  end

  defp sanitize_gauge(gauge) when is_map(gauge) do
    %{
      id: Map.get(gauge, "id", ""),
      address: Map.get(gauge, "address", ""),
      pool_id: Map.get(gauge, "poolId", 0),
      pool_name: Map.get(gauge, "poolName", ""),
      chain: Map.get(gauge, "chain", ""),
      symbol: Map.get(gauge, "symbol", ""),
      creator: Map.get(gauge, "creator", ""),
      vote: Map.get(gauge, "vote", 0),
      supply: Map.get(gauge, "supply", 0),
      relative_weight_target: Map.get(gauge, "relativeWeightTarget", 0),
      absolute_weight: Map.get(gauge, "absoluteWeight", 0),
      virtual_price: Map.get(gauge, "virtualPrice", 0),
      gauge_type: Map.get(gauge, "gaugeType", %{}),
      cpi: Map.get(gauge, "cpi", 0),
      api_cpi: Map.get(gauge, "apiCpi", 0),
      inflator_cpi: Map.get(gauge, "inflatorCpi", 0),
      pool: sanitize_pool_ref(Map.get(gauge, "pool", %{})),
      is_killed: Map.get(gauge, "isKilled", false)
    }
  end

  defp sanitize_gauge(_), do: %{}

  defp sanitize_pool_ref(pool) when is_map(pool) do
    %{
      name: Map.get(pool, "name", ""),
      symbol: Map.get(pool, "symbol", ""),
      address: Map.get(pool, "address", ""),
      gauge_address: Map.get(pool, "gauge_address", "")
    }
  end

  defp sanitize_pool_ref(_), do: %{}
end
