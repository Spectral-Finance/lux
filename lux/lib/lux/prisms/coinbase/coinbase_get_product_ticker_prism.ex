defmodule Lux.Prisms.Coinbase.GetProductTickerPrism do
  @moduledoc """
  A prism for retrieving real-time ticker data from Coinbase Advanced Trade API.

  ## Examples

      iex> Lux.Prisms.Coinbase.GetProductTickerPrism.handler(%{product_id: "BTC-USD"}, %{name: "Agent"})
      {:ok, %{
        product_id: "BTC-USD",
        price: "65432.10",
        volume_24h: "28765.432",
        low_52w: "25000.00",
        high_52w: "73000.00",
        price_change_24h: "1.92"
      }}
  """

  use Lux.Prism,
    name: "Coinbase Get Product Ticker",
    description: "Retrieves real-time ticker data for a product on Coinbase",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Product ID (e.g., 'BTC-USD', 'ETH-USDC')",
          pattern: "^[A-Z0-9]+-[A-Z0-9]+$"
        }
      },
      required: ["product_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        product_id: %{type: :string},
        price: %{type: :string, description: "Current price"},
        volume_24h: %{type: :string, description: "24h trading volume"},
        low_52w: %{type: :string, description: "52-week low"},
        high_52w: %{type: :string, description: "52-week high"},
        price_change_24h: %{type: :string, description: "24h price change percentage"}
      },
      required: ["product_id", "price"]
    }

  alias Lux.Integrations.Coinbase
  require Logger

  def handler(%{product_id: product_id} = _params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} fetching Coinbase ticker for #{product_id}")

    case Coinbase.get("/api/v3/brokerage/products/#{product_id}") do
      {:ok, %{"product_id" => pid, "price" => price} = data} ->
        result = %{
          product_id: pid,
          price: price,
          volume_24h: data["volume_24h"],
          low_52w: data["price_percentage_change_24h"],
          high_52w: data["high_52w"],
          price_change_24h: data["price_percentage_change_24h"]
        }
        Logger.info("Coinbase ticker fetched for #{product_id}: #{price}")
        {:ok, result}

      {:error, {status, body}} ->
        msg = get_in(body, ["message"]) || inspect(body)
        Logger.error("Coinbase ticker error for #{product_id}: #{status} - #{msg}")
        {:error, {status, msg}}

      {:error, reason} ->
        Logger.error("Coinbase ticker request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
