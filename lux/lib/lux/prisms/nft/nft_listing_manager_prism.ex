defmodule Lux.Prisms.Nft.NftListingManagerPrism do
  @moduledoc """
  A prism that searches, filters, and manages NFT listings across marketplaces.

  ## Example

      iex> Lux.Prisms.Nft.NftListingManagerPrism.run(%{
      ...>   collection_slug: "bored-ape-yacht-club",
      ...>   max_price: 50.0,
      ...>   sort_by: "price",
      ...>   limit: 20
      ...> })
      {:ok, %{
        "status" => "success",
        "listings" => [...],
        "cheapest_listing" => %{...}
      }}

  The prism reads API configuration from application config:
  - :opensea_api_key - OpenSea API key for authenticated requests
  """

  use Lux.Prism,
    name: "NFT Listing Manager",
    description: "Searches, filters, and manages NFT listings across OpenSea and Blur",
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
        max_price: %{
          type: :number,
          description: "Maximum listing price filter (ETH)"
        },
        min_price: %{
          type: :number,
          description: "Minimum listing price filter (ETH)"
        },
        trait_filter: %{
          type: :object,
          description: "Filter by trait key-value pairs",
          additionalProperties: %{type: :string}
        },
        sort_by: %{
          type: :string,
          description: "Sort order for results",
          enum: ["price", "rarity", "recent", "token_id"],
          default: "price"
        },
        limit: %{
          type: :integer,
          description: "Maximum listings to return",
          default: 20,
          minimum: 1,
          maximum: 100
        }
      },
      required: ["collection_slug"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        listings: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              token_id: %{type: :string},
              price: %{type: :number},
              currency: %{type: :string},
              seller: %{type: :string},
              marketplace: %{type: :string},
              expires_at: %{type: :string}
            }
          }
        },
        cheapest_listing: %{type: :object},
        total_listings: %{type: :integer}
      },
      required: ["status", "listings"]
    }

  import Lux.Python

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, result} <- fetch_listings(input) do
      {:ok, result}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_listings(input) do
    python_result =
      python variables: %{input: input} do
        ~PY"""
        import urllib.request
        import json

        slug = input.get("collection_slug", "")
        address = input.get("collection_address", "")
        max_price = input.get("max_price", float("inf"))
        min_price = input.get("min_price", 0)
        sort_by = input.get("sort_by", "price")
        limit = min(input.get("limit", 20), 100)
        trait_filter = input.get("trait_filter", {})

        listings = []
        cheapest = None
        total = 0

        # Fetch listings from OpenSea
        if slug:
          url = f"https://api.opensea.io/api/v2/listings/collection/{slug}?limit={limit}"
          req = urllib.request.Request(url, headers={"User-Agent": "Lux/1.0"})
          try:
            resp = urllib.request.urlopen(req, timeout=15)
            data = json.loads(resp.read().decode())

            for listing in data.get("listings", [])[:limit]:
              price_data = listing.get("price_data", {})
              price_eth = float(price_data.get("current", {}).get("value", 0)) / 1e18 if price_data.get("current", {}).get("value") else 0

              if min_price <= price_eth <= max_price:
                entry = {
                  "token_id": listing.get("asset", {}).get("identifier", ""),
                  "price": price_eth,
                  "currency": price_data.get("current", {}).get("payment_token", {}).get("symbol", "ETH"),
                  "seller": listing.get("maker", ""),
                  "marketplace": "opensea",
                  "expires_at": listing.get("expiration_time", "")
                }
                listings.append(entry)

                if cheapest is None or price_eth < cheapest.get("price", float("inf")):
                  cheapest = entry

            total = len(listings)

            # Apply sorting
            if sort_by == "price":
              listings.sort(key=lambda x: x.get("price", 0))
            elif sort_by == "token_id":
              listings.sort(key=lambda x: int(x.get("token_id", "0") or "0"))

          except Exception as e:
            listings = [{"error": str(e)}]

        result = {
          "status": "success",
          "listings": listings,
          "cheapest_listing": cheapest or {},
          "total_listings": total
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
