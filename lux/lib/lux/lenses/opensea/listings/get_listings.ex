defmodule Lux.Lenses.OpenSea.Listings.GetListings do
  @moduledoc """
  A lens for retrieving active listings for an NFT collection from the OpenSea API v2.

  This lens provides:
  - Active listing prices and payment tokens
  - Seller information
  - NFT identifiers and metadata
  - Pagination support via cursor
  - Filtering by price range

  ## Authentication

  Uses optional API key via `x-api-key` header. Configure in application config:

      config :lux, :api_keys, opensea: "your_api_key"

  ## Examples

      iex> GetListings.focus(%{
      ...>   collection_slug: "boredapeyachtclub",
      ...>   limit: 10
      ...> })
      {:ok, %{
        listings: [
          %{
            order_hash: "0x...",
            price: 10.5,
            price_currency: "ETH",
            seller: "0x...",
            nft: %{identifier: "1234", name: "Bored Ape #1234"},
            expiration: "2024-12-31T00:00:00.000Z"
          }
        ],
        next_cursor: "abc123"
      }}
  """

  alias Lux.Integrations.OpenSea

  use Lux.Lens,
    name: "Get NFT Collection Listings",
    description: "Retrieves active listings for an NFT collection from OpenSea",
    url: "https://api.opensea.io/api/v2/listings/collection/:collection_slug/all",
    method: :get,
    headers: OpenSea.headers(),
    auth: OpenSea.auth(),
    schema: %{
      type: :object,
      properties: %{
        collection_slug: %{
          type: :string,
          description: "The unique identifier (slug) for the collection on OpenSea",
          pattern: "^[a-z0-9-]+$"
        },
        limit: %{
          type: :integer,
          description: "Number of listings to return (1-100, default 20)",
          minimum: 1,
          maximum: 100,
          default: 20
        },
        next: %{
          type: :string,
          description: "Pagination cursor from a previous response"
        }
      },
      required: ["collection_slug"]
    }

  @doc """
  Transforms the OpenSea API response into a simplified listing format.
  """
  @impl true
  def after_focus(%{"listings" => listings} = data) do
    result = %{
      listings: Enum.map(listings, &format_listing/1),
      next_cursor: data["next"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    {:ok, result}
  end

  def after_focus(%{"errors" => errors}) when is_list(errors) do
    {:error, %{errors: errors}}
  end

  def after_focus(%{"detail" => detail}) do
    {:error, %{detail: detail}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end

  defp format_listing(listing) do
    protocol_data = listing["protocol_data"] || %{}
    parameters = protocol_data["parameters"] || %{}
    consideration = List.first(parameters["consideration"] || []) || %{}
    offer = List.first(parameters["offer"] || []) || %{}

    price_info = listing["price"] || %{}
    current_price = price_info["current"] || %{}

    %{
      order_hash: listing["order_hash"],
      order_type: listing["order_type"],
      price: parse_price(current_price["value"], current_price["decimals"]),
      price_currency: get_currency(current_price["currency"]),
      seller: parameters["offerer"],
      nft: %{
        identifier: offer["identifierOrCriteria"],
        contract: offer["token"]
      },
      expiration: parameters["endTime"] && format_timestamp(parameters["endTime"]),
      created_at: listing["created_date"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp parse_price(nil, _), do: nil
  defp parse_price(value, nil) when is_binary(value) do
    case Integer.parse(value) do
      {i, ""} -> i / 1_000_000_000_000_000_000
      _ -> nil
    end
  end
  defp parse_price(value, decimals) when is_binary(value) do
    case Integer.parse(value) do
      {i, ""} -> i / :math.pow(10, decimals || 18)
      _ -> nil
    end
  end
  defp parse_price(value, _) when is_number(value), do: value

  defp get_currency("ETH"), do: "ETH"
  defp get_currency("WETH"), do: "WETH"
  defp get_currency(other) when is_binary(other), do: other
  defp get_currency(_), do: "ETH"

  defp format_timestamp(unix_str) when is_binary(unix_str) do
    case Integer.parse(unix_str) do
      {unix, ""} ->
        DateTime.from_unix!(unix) |> DateTime.to_iso8601()
      _ -> unix_str
    end
  end
  defp format_timestamp(unix) when is_integer(unix) do
    DateTime.from_unix!(unix) |> DateTime.to_iso8601()
  end
  defp format_timestamp(_), do: nil
end
