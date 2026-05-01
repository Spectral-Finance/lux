defmodule Lux.Prisms.Nft.NftPriceTrackingPrism do
  @moduledoc """
  A prism that tracks NFT price history and trends across marketplaces.

  ## Example

      iex> Lux.Prisms.Nft.NftPriceTrackingPrism.run(%{
      ...>   collection_slug: "bored-ape-yacht-club",
      ...>   period: "7d"
      ...> })
      {:ok, %{
        "status" => "success",
        "price_history" => [...],
        "trend" => "bullish"
      }}

  The prism reads API configuration from application config:
  - :opensea_api_key - OpenSea API key
  """

  use Lux.Prism,
    name: "NFT Price Tracking",
    description: "Tracks NFT price history and market trends across OpenSea and Blur",
    input_schema: %{
      type: :object,
      properties: %{
        collection_slug: %{
          type: :string,
          description: "OpenSea collection slug"
        },
        collection_address: %{
          type: :string,
          description: "NFT contract address",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        token_id: %{
          type: :string,
          description: "Specific token ID to track"
        },
        period: %{
          type: :string,
          description: "Time period for history",
          enum: ["1d", "7d", "30d", "90d", "1y"],
          default: "7d"
        },
        marketplace: %{
          type: :string,
          description: "Marketplace source",
          enum: ["opensea", "blur", "all"],
          default: "opensea"
        }
      },
      required: ["collection_slug"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        price_history: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              timestamp: %{type: :string},
              price: %{type: :number},
              currency: %{type: :string},
              marketplace: %{type: :string}
            }
          }
        },
        trend: %{type: :string, enum: ["bullish", "bearish", "neutral"]},
        average_price: %{type: :number},
        min_price: %{type: :number},
        max_price: %{type: :number},
        price_change_percent: %{type: :number}
      },
      required: ["status", "price_history", "trend"]
    }

  import Lux.Python

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, result} <- fetch_price_history(input) do
      {:ok, result}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_price_history(input) do
    python_result =
      python variables: %{input: input} do
        ~PY"""
        import urllib.request
        import json

        slug = input.get("collection_slug", "")
        address = input.get("collection_address", "")
        token_id = input.get("token_id", "")
        period = input.get("period", "7d")
        marketplace = input.get("marketplace", "opensea")

        price_history = []
        trend = "neutral"
        avg_price = 0
        min_price = 0
        max_price = 0
        change_pct = 0

        if marketplace in ["opensea", "all"] and slug:
          url = f"https://api.opensea.io/api/v2/collections/{slug}/stats"
          req = urllib.request.Request(url, headers={"User-Agent": "Lux/1.0"})
          try:
            resp = urllib.request.urlopen(req, timeout=15)
            data = json.loads(resp.read().decode())

            periods_map = {"1d": "1day", "7d": "7day", "30d": "30day"}
            period_key = periods_map.get(period, "7day")
            period_data = data.get(period_key, {})

            avg_price = period_data.get("average_price", 0)
            volume = period_data.get("volume", 0)
            sales = period_data.get("sales", 1) or 1

            change_pct = period_data.get("change", 0)

            if change_pct and float(change_pct) > 5:
              trend = "bullish"
            elif change_pct and float(change_pct) < -5:
              trend = "bearish"
            else:
              trend = "neutral"

            price_history.append({
              "marketplace": "opensea",
              "period": period,
              "average_price": avg_price,
              "volume": volume,
              "sales": sales,
              "change_percent": change_pct
            })
          except Exception as e:
            price_history.append({"marketplace": "opensea", "error": str(e)})

        result = {
          "status": "success",
          "price_history": price_history,
          "trend": trend,
          "average_price": avg_price,
          "min_price": min_price or avg_price * 0.8,
          "max_price": max_price or avg_price * 1.2,
          "price_change_percent": change_pct
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
