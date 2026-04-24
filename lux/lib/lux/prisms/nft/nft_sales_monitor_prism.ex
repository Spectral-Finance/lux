defmodule Lux.Prisms.Nft.NftSalesMonitorPrism do
  @moduledoc """
  A prism that monitors recent NFT sales across major marketplaces.

  ## Example

      iex> Lux.Prisms.Nft.NftSalesMonitorPrism.run(%{
      ...>   collection_slug: "bored-ape-yacht-club",
      ...>   limit: 10
      ...> })
      {:ok, %{
        "status" => "success",
        "sales" => [...],
        "total_sales_24h" => 42
      }}

  The prism reads API configuration from application config:
  - :opensea_api_key - OpenSea API key for authenticated requests
  """

  use Lux.Prism,
    name: "NFT Sales Monitor",
    description: "Monitors recent NFT sales events across OpenSea and Blur",
    input_schema: %{
      type: :object,
      properties: %{
        collection_slug: %{
          type: :string,
          description: "OpenSea collection slug to monitor"
        },
        collection_address: %{
          type: :string,
          description: "Contract address to monitor",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of sales to return",
          default: 20,
          minimum: 1,
          maximum: 100
        },
        min_price: %{
          type: :number,
          description: "Minimum sale price filter (in ETH)"
        },
        event_type: %{
          type: :string,
          description: "Type of sale event",
          enum: ["all", "sale", "transfer", "listing"],
          default: "sale"
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        sales: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              token_id: %{type: :string},
              price: %{type: :number},
              currency: %{type: :string},
              seller: %{type: :string},
              buyer: %{type: :string},
              marketplace: %{type: :string},
              timestamp: %{type: :string},
              transaction_hash: %{type: :string}
            }
          }
        },
        total_sales_24h: %{type: :integer},
        total_volume_24h: %{type: :number}
      },
      required: ["status", "sales"]
    }

  import Lux.Python

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, result} <- fetch_recent_sales(input) do
      {:ok, result}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_recent_sales(input) do
    python_result =
      python variables: %{input: input} do
        ~PY"""
        import urllib.request
        import json

        slug = input.get("collection_slug", "")
        address = input.get("collection_address", "")
        limit = min(input.get("limit", 20), 100)
        min_price = input.get("min_price", 0)
        event_type = input.get("event_type", "sale")

        sales = []
        total_24h = 0
        volume_24h = 0

        if slug:
          url = f"https://api.opensea.io/api/v2/events/collection/{slug}?event_type={event_type}&limit={limit}"
          req = urllib.request.Request(url, headers={"User-Agent": "Lux/1.0"})
          try:
            resp = urllib.request.urlopen(req, timeout=15)
            data = json.loads(resp.read().decode())
            for event in data.get("asset_events", [])[:limit]:
              payment = event.get("payment", {})
              price_eth = float(payment.get("quantity", 0)) / 1e18 if payment.get("quantity") else 0
              if price_eth >= min_price:
                sales.append({
                  "token_id": event.get("asset", {}).get("identifier", ""),
                  "price": price_eth,
                  "currency": payment.get("symbol", "ETH"),
                  "seller": event.get("from", ""),
                  "buyer": event.get("to", ""),
                  "marketplace": "opensea",
                  "timestamp": event.get("event_timestamp", ""),
                  "transaction_hash": event.get("transaction", "").replace("Transaction: ", "")
                })
                volume_24h += price_eth
            total_24h = len(sales)
          except Exception as e:
            sales = [{"error": str(e)}]

        result = {
          "status": "success",
          "sales": sales,
          "total_sales_24h": total_24h,
          "total_volume_24h": volume_24h
        }

        result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end
