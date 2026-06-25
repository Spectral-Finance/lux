defmodule Lux.Lenses.Curve.PoolAnalytics do
  @moduledoc """
  Lens for fetching Curve Finance pool analytics and yield optimization data.

  Provides pool performance metrics, revenue analysis, and yield comparison
  across pools to support automated rebalancing decisions.

  ## Examples

      # Get analytics for all pools
      Lux.Lenses.Curve.PoolAnalytics.focus(%{})

      # Get analytics for a specific pool
      Lux.Lenses.Curve.PoolAnalytics.focus(%{pool_name: "3crypto"})
  """

  use Lux.Lens,
    name: "Curve.PoolAnalytics",
    description: "Fetches pool analytics data including revenue, volume trends, and yield comparisons",
    url: Lux.Integrations.Curve.pool_analytics_url(),
    method: :get,
    headers: Lux.Integrations.Curve.headers(),
    schema: %{
      type: :object,
      properties: %{
        pool_name: %{
          type: :string,
          description: "Optional pool name filter. If empty, returns analytics for all pools."
        },
        days: %{
          type: :integer,
          description: "Number of days of historical data to include",
          default: 30
        }
      },
      additionalProperties: false
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    chain_name = Map.get(params, :chain_name, Lux.Integrations.Curve.chain_name())
    url = Lux.Integrations.Curve.base_url(chain_name) <> "/pools/#{chain_name}/analytics"
    %{"url" => url}
  end

  @doc """
  Transforms the API response into a structured format.
  """
  @impl true
  def after_focus(response) do
    with %{"status" => "success", "result" => result} <- response do
      {:ok,
       %{
         chain: Lux.Integrations.Curve.chain_name(),
         analytics: sanitize_analytics(result)
       }}
    else
      %{"status" => "error", "error" => error} ->
        {:error, "Curve API error: #{inspect(error)}"}

      %{"status" => "error"} ->
        {:error, "Curve API returned error status"}

      _ ->
        {:ok, %{chain: Lux.Integrations.Curve.chain_name(), analytics: []}}
    end
  end

  defp sanitize_analytics(analytics) when is_list(analytics) do
    Enum.map(analytics, &sanitize_single_analytics/1)
  end

  defp sanitize_analytics(_), do: []

  defp sanitize_single_analytics(data) when is_map(data) do
    %{
      pool_name: Map.get(data, "pool_name", ""),
      pool_address: Map.get(data, "pool_address", ""),
      tvl: Map.get(data, "tvl", %{}),
      volume: Map.get(data, "volume", %{}),
      revenue: Map.get(data, "revenue", %{}),
      fee_apr: Map.get(data, "feeApr", 0),
      reward_apr: Map.get(data, "rewardApr", 0),
      total_apr: Map.get(data, "totalApr", 0),
      utilization: Map.get(data, "utilization", 0),
      price_impact: Map.get(data, "priceImpact", %{})
    }
  end

  defp sanitize_single_analytics(_), do: %{}
end
