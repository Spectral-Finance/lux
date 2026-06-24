defmodule Lux.Prisms.Coinbase.GetBestBidAskPrism do
  @moduledoc """
  A prism for retrieving the best bid/ask prices for one or more products on Coinbase.

  ## Examples

      iex> Lux.Prisms.Coinbase.GetBestBidAskPrism.handler(%{product_ids: ["BTC-USD", "ETH-USD"]}, %{name: "Agent"})
      {:ok, %{
        pricebooks: [%{
          product_id: "BTC-USD",
          bids: [%{price: "65000.00", size: "0.5"}],
          asks: [%{price: "65001.00", size: "0.3"}],
          time: "2024-01-01T00:00:00Z"
        }]
      }}
  """

  use Lux.Prism,
    name: "Coinbase Get Best Bid/Ask",
    description: "Gets the best bid and ask prices for multiple products on Coinbase",
    input_schema: %{
      type: :object,
      properties: %{
        product_ids: %{
          type: :array,
          description: "List of product IDs to query",
          items: %{type: :string},
          minItems: 1
        }
      },
      required: ["product_ids"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        pricebooks: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              product_id: %{type: :string},
              bids: %{type: :array},
              asks: %{type: :array},
              time: %{type: :string}
            }
          }
        }
      },
      required: ["pricebooks"]
    }

  alias Lux.Integrations.Coinbase
  require Logger

  def handler(%{product_ids: product_ids}, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} fetching best bid/ask for #{length(product_ids)} products")

    query = Enum.reduce(product_ids, "", fn id, acc ->
      acc <> (if acc == "", do: "", else: "&") <> "product_ids=#{id}"
    end)

    case Coinbase.get("/api/v3/brokerage/best_bid_ask?" <> query) do
      {:ok, %{"pricebooks" => pricebooks}} ->
        result = %{
          pricebooks: Enum.map(pricebooks, fn pb ->
            %{
              product_id: pb["product_id"],
              bids: pb["bids"] || [],
              asks: pb["asks"] || [],
              time: pb["time"]
            }
          end)
        }
        Logger.info("Fetched bid/ask for #{length(pricebooks)} products")
        {:ok, result}

      {:error, {status, body}} ->
        msg = get_in(body, ["message"]) || inspect(body)
        Logger.error("Coinbase best bid/ask error: #{status} - #{msg}")
        {:error, {status, msg}}

      {:error, reason} ->
        Logger.error("Best bid/ask request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
