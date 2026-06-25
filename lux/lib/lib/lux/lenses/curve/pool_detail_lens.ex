defmodule Lux.Lenses.Curve.PoolDetail do
  @moduledoc """
  Lens for fetching detailed information about a specific Curve Finance pool.

  Returns pool metrics including reserves, prices, fees, swap data, and APR breakdown.

  ## Examples

      # Get details for the main 3CRV pool
      Lux.Lenses.Curve.PoolDetail.focus(%{pool_name: "3crypto"})

      # Get details for the FRAX-USDC pool
      Lux.Lenses.Curve.PoolDetail.focus(%{pool_name: "fraxswap"})

      # Get details for the yearn pool
      Lux.Lenses.Curve.PoolDetail.focus(%{pool_name: "yearn"})
  """

  use Lux.Lens,
    name: "Curve.PoolDetail",
    description: "Gets detailed information about a specific Curve pool including reserves and APR",
    url: Lux.Integrations.Curve.pool_detail_url("3crypto"),
    method: :get,
    headers: Lux.Integrations.Curve.headers(),
    schema: %{
      type: :object,
      properties: %{
        pool_name: %{
          type: :string,
          description: "The name of the Curve pool (e.g., '3crypto', 'fraxswap', 'yearn', 'cvxcrv', 'compound', 'aave', 'skyv2')"
        },
        chain_name: %{
          type: :string,
          description: "Override the chain name (e.g., 'eth', 'polygon', 'arbitrum')"
        }
      },
      required: ["pool_name"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    pool_name = Map.get(params, :pool_name, "3crypto")
    chain_name = Map.get(params, :chain_name, Lux.Integrations.Curve.chain_name())
    url = Lux.Integrations.Curve.base_url(chain_name) <> "/pools/#{pool_name}"
    %{"url" => url, "pool_name" => pool_name}
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
         pool_name: Map.get(result, "pool_name", ""),
         pool_symbol: Map.get(result, "pool_symbol", ""),
         pool_type: Map.get(result, "pool_type", ""),
         pool_address: Map.get(result, "pool_address", ""),
         gauge_address: Map.get(result, "gauge_address", ""),
         tvl_usd: Map.get(result, "tvl_usd", 0),
         volumes_24h: Map.get(result, "volumes_24h", 0),
         fee_24h: Map.get(result, "fee_24h", 0),
         apy: Map.get(result, "apy", %{}),
         reserves: sanitize_reserves(Map.get(result, "reserves", %{})),
         coins: sanitize_coins(Map.get(result, "coins", [])),
         swap_data: Map.get(result, "swapData", %{}),
         reward_tokens: Map.get(result, "rewardTokens", []),
         reward_tickers: Map.get(result, "rewardTickers", []),
         pool_id: Map.get(result, "poolId", 0)
       }}
    else
      %{"status" => "error", "error" => error} ->
        {:error, "Curve API error: #{inspect(error)}"}

      %{"status" => "error"} ->
        {:error, "Curve API returned error status"}

      _ ->
        {:error, "Unexpected response format"}
    end
  end

  defp sanitize_reserves(reserves) when is_map(reserves) do
    Map.new(reserves, fn {key, val} ->
      {key,
       %{
         balance: Map.get(val, "balance", 0),
         balance_formatted: Map.get(val, "balanceFormatted", ""),
         weight: Map.get(val, "weight", 0),
         decimals: Map.get(val, "decimals", 18)
       }}
    end)
  end

  defp sanitize_reserves(_), do: %{}

  defp sanitize_coins(coins) when is_list(coins) do
    Enum.map(coins, fn coin ->
      %{
        name: Map.get(coin, "name", ""),
        symbol: Map.get(coin, "symbol", ""),
        address: Map.get(coin, "address", ""),
        balance: Map.get(coin, "balance", 0),
        balance_formatted: Map.get(coin, "balanceFormatted", ""),
        weight: Map.get(coin, "weight", 0),
        decimals: Map.get(coin, "decimals", 18)
      }
    end)
  end

  defp sanitize_coins(_), do: []
end
