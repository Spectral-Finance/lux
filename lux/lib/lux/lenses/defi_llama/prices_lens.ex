defmodule Lux.Lenses.DeFiLlama.PricesLens do
  @moduledoc """
  Lens for fetching current token prices from the DeFiLlama API.

  ## Examples

      iex> Lux.Lenses.DeFiLlama.PricesLens.focus(%{coins: "ethereum:0x...coingecko:bitcoin"})
      {:ok, %{
        coins: %{
          "ethereum:0x..." => %{price: 1234.56, symbol: "UNI", timestamp: 1234567890},
          "coingecko:bitcoin" => %{price: 56789.01, symbol: "BTC", timestamp: 1234567890}
        }
      }}

  The `coins` parameter is a comma-separated list of coin identifiers in the format `{chain}:{address}` or `coingecko:{id}`.
  """

  alias Lux.Integrations.DeFiLlama

  use Lux.Lens,
    name: "DeFiLlama Prices",
    description: "Fetches current token prices from DeFiLlama",
    url: "#{DeFiLlama.base_url()}/prices/current/:coins",
    method: :get,
    headers: [{"accept", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        coins: %{
          type: :string,
          description: "Comma-separated list of coin identifiers (e.g. 'ethereum:0x...' or 'coingecko:bitcoin')"
        }
      },
      required: ["coins"]
    }

  @impl true
  def after_focus(%{"coins" => coins}) when is_map(coins) do
    transformed =
      Map.new(coins, fn {key, info} ->
        {key,
         %{
           price: info["price"],
           symbol: info["symbol"],
           timestamp: info["timestamp"],
           confidence: info["confidence"]
         }}
      end)

    {:ok, %{coins: transformed}}
  end

  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end
end
