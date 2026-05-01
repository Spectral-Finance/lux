defmodule Lux.Prisms.Nft.NftCollectionStatsPrism do
  @moduledoc """
  A prism that fetches NFT collection statistics from OpenSea.

  ## Example

      iex> Lux.Prisms.Nft.NftCollectionStatsPrism.run(%{
      ...>   collection_slug: "bored-ape-yacht-club",
      ...>   marketplace: "opensea"
      ...> })
      {:ok, %{
        "status" => "success",
        "collection_stats" => %{
          "floor_price" => 12.5,
          "total_supply" => 10000,
          "owners" => 6500,
          "total_volume" => 150000.0,
          "one_day_volume" => 250.0,
          "seven_day_volume" => 1800.0,
          "thirty_day_volume" => 7500.0
        }
      }}

  The prism reads API configuration from application config:
  - :opensea_api_key - OpenSea API key for authenticated requests
  """

  use Lux.Prism,
    name: "NFT Collection Statistics",
    description: "Fetches NFT collection statistics including floor price, volume, and ownership data",
    input_schema: %{
      type: :object,
      properties: %{
        collection_slug: %{
          type: :string,
          description: "OpenSea collection slug (e.g., 'bored-ape-yacht-club')"
        },
        collection_address: %{
          type: :string,
          description: "Contract address for the NFT collection",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        marketplace: %{
          type: :string,
          description: "Marketplace to query (opensea, blur)",
          enum: ["opensea", "blur"],
          default: "opensea"
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        collection_stats: %{
          type: :object,
          properties: %{
            floor_price: %{type: :number},
            floor_price_currency: %{type: :string},
            total_supply: %{type: :integer},
            owners: %{type: :integer},
            total_volume: %{type: :number},
            one_day_volume: %{type: :number},
            seven_day_volume: %{type: :number},
            thirty_day_volume: %{type: :number},
            one_day_sales: %{type: :integer},
            seven_day_sales: %{type: :integer},
            thirty_day_sales: %{type: :integer},
            one_day_change: %{type: :number},
            seven_day_change: %{type: :number},
            thirty_day_change: %{type: :number}
          }
        }
      },
      required: ["status", "collection_stats"]
    }

  import Lux.Python

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, result} <- fetch_collection_stats(api_key, input) do
      {:ok, %{status: "success", collection_stats: result}}
    else
      {:error, :missing_api_key} ->
        {:ok, fetch_public_stats(input)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_api_key do
    case Application.get_env(:lux, :opensea_api_key) do
      nil -> {:error, :missing_api_key}
      key -> {:ok, key}
    end
  rescue
    _ -> {:error, :missing_api_key}
  end

  defp fetch_public_stats(input) do
    python_result =
      python variables: %{input: input} do
        ~PY"""
        import urllib.request
        import json

        slug = input.get("collection_slug", "")
        address = input.get("collection_address", "")
        marketplace = input.get("marketplace", "opensea")

        result = {}

        if marketplace == "opensea" and slug:
          url = f"https://api.opensea.io/api/v2/collections/{slug}/stats"
          req = urllib.request.Request(url, headers={"User-Agent": "Lux/1.0"})
          try:
            resp = urllib.request.urlopen(req, timeout=15)
            data = json.loads(resp.read().decode())
            result = {
              "floor_price": data.get("total", {}).get("floor_price", 0),
              "floor_price_currency": data.get("total", {}).get("floor_price_unit", "ETH"),
              "total_supply": data.get("total", {}).get("supply", 0),
              "owners": data.get("total", {}).get("num_owners", 0),
              "total_volume": data.get("total", {}).get("volume", 0),
              "one_day_volume": data.get("1day", {}).get("volume", 0),
              "seven_day_volume": data.get("7day", {}).get("volume", 0),
              "thirty_day_volume": data.get("30day", {}).get("volume", 0),
              "one_day_sales": data.get("1day", {}).get("sales", 0),
              "seven_day_sales": data.get("7day", {}).get("sales", 0),
              "thirty_day_sales": data.get("30day", {}).get("sales", 0),
              "one_day_change": data.get("1day", {}).get("change", 0),
              "seven_day_change": data.get("7day", {}).get("change", 0),
              "thirty_day_change": data.get("30day", {}).get("change", 0)
            }
          except Exception as e:
            result = {"error": str(e)}
        elif marketplace == "blur" and address:
          result = {"note": "Blur API requires authentication", "contract": address}
        else:
          result = {"error": "Provide collection_slug for OpenSea or collection_address for Blur"}

        result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end

  defp fetch_collection_stats(api_key, input) do
    python_result =
      python variables: %{api_key: api_key, input: input} do
        ~PY"""
        import urllib.request
        import json

        slug = input.get("collection_slug", "")
        address = input.get("collection_address", "")
        marketplace = input.get("marketplace", "opensea")

        result = {}

        if marketplace == "opensea" and slug:
          url = f"https://api.opensea.io/api/v2/collections/{slug}/stats"
          req = urllib.request.Request(url, headers={
            "User-Agent": "Lux/1.0",
            "X-API-KEY": api_key
          })
          try:
            resp = urllib.request.urlopen(req, timeout=15)
            data = json.loads(resp.read().decode())
            result = {
              "floor_price": data.get("total", {}).get("floor_price", 0),
              "floor_price_currency": data.get("total", {}).get("floor_price_unit", "ETH"),
              "total_supply": data.get("total", {}).get("supply", 0),
              "owners": data.get("total", {}).get("num_owners", 0),
              "total_volume": data.get("total", {}).get("volume", 0),
              "one_day_volume": data.get("1day", {}).get("volume", 0),
              "seven_day_volume": data.get("7day", {}).get("volume", 0),
              "thirty_day_volume": data.get("30day", {}).get("volume", 0),
              "one_day_sales": data.get("1day", {}).get("sales", 0),
              "seven_day_sales": data.get("7day", {}).get("sales", 0),
              "thirty_day_sales": data.get("30day", {}).get("sales", 0),
              "one_day_change": data.get("1day", {}).get("change", 0),
              "seven_day_change": data.get("7day", {}).get("change", 0),
              "thirty_day_change": data.get("30day", {}).get("change", 0)
            }
          except Exception as e:
            result = {"error": str(e)}
        elif marketplace == "blur" and address:
          url = f"https://api.blur.io/api/v1/collections/{address}/stats"
          req = urllib.request.Request(url, headers={
            "User-Agent": "Lux/1.0",
            "Cookie": f"auth_key={api_key}"
          })
          try:
            resp = urllib.request.urlopen(req, timeout=15)
            data = json.loads(resp.read().decode())
            result = {
              "floor_price": data.get("floorPrice", 0),
              "total_supply": data.get("totalSupply", 0),
              "owners": data.get("uniqueOwners", 0),
              "total_volume": data.get("totalVolume", 0)
            }
          except Exception as e:
            result = {"error": str(e)}
        else:
          result = {"error": "Provide collection_slug for OpenSea or collection_address for Blur"}

        result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end
