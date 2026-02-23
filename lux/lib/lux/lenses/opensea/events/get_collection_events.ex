defmodule Lux.Lenses.OpenSea.Events.GetCollectionEvents do
  @moduledoc """
  A lens for retrieving NFT events (sales, transfers, listings) for a collection
  from the OpenSea API v2.

  This lens provides:
  - Sale events with price and payment token info
  - Transfer history for provenance tracking
  - Listing and offer events
  - Pagination support
  - Filtering by event type

  ## Authentication

  Uses optional API key via `x-api-key` header. Configure in application config:

      config :lux, :api_keys, opensea: "your_api_key"

  ## Examples

      iex> GetCollectionEvents.focus(%{
      ...>   collection_slug: "boredapeyachtclub",
      ...>   event_type: "sale",
      ...>   limit: 10
      ...> })
      {:ok, %{
        events: [
          %{
            event_type: "sale",
            price: 15.5,
            price_currency: "ETH",
            seller: "0x...",
            buyer: "0x...",
            nft: %{identifier: "1234", name: "Bored Ape #1234"},
            transaction: "0x...",
            timestamp: "2024-01-01T00:00:00.000Z"
          }
        ],
        next_cursor: "xyz789"
      }}
  """

  alias Lux.Integrations.OpenSea

  use Lux.Lens,
    name: "Get NFT Collection Events",
    description: "Retrieves sale, transfer, and listing events for an NFT collection",
    url: "https://api.opensea.io/api/v2/events/collection/:collection_slug",
    method: :get,
    headers: OpenSea.headers(),
    auth: OpenSea.auth(),
    schema: %{
      type: :object,
      properties: %{
        collection_slug: %{
          type: :string,
          description: "The unique identifier (slug) for the collection",
          pattern: "^[a-z0-9-]+$"
        },
        event_type: %{
          type: :string,
          description: "Type of events to retrieve",
          enum: ["all", "cancel", "listing", "offer", "order", "redemption", "sale", "transfer"]
        },
        limit: %{
          type: :integer,
          description: "Number of events to return (1-50, default 20)",
          minimum: 1,
          maximum: 50,
          default: 20
        },
        next: %{
          type: :string,
          description: "Cursor for pagination"
        },
        occurred_after: %{
          type: :integer,
          description: "Unix timestamp to filter events after this time"
        },
        occurred_before: %{
          type: :integer,
          description: "Unix timestamp to filter events before this time"
        }
      },
      required: ["collection_slug"]
    }

  @doc """
  Transforms the OpenSea API response into a simplified format.
  """
  @impl true
  def after_focus(%{"asset_events" => events} = data) do
    transformed = Enum.map(events, &transform_event/1)
    {:ok, %{events: transformed, next_cursor: data["next"]}}
  end

  def after_focus(%{"detail" => detail}) do
    {:error, %{detail: detail}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end

  defp transform_event(event) do
    base = %{
      event_type: event["event_type"],
      chain: event["chain"],
      transaction: event["transaction"],
      timestamp: event["event_timestamp"],
      nft: transform_nft_summary(event["nft"])
    }

    case event["event_type"] do
      "sale" ->
        sale_price = get_in(event, ["sale_price"])
        payment = event["payment"] || %{}

        Map.merge(base, %{
          price: format_price(sale_price, payment["decimals"]),
          price_currency: payment["symbol"],
          price_usd: event["payment_usd"],
          seller: event["seller"],
          buyer: event["buyer"],
          quantity: event["quantity"]
        })

      "transfer" ->
        Map.merge(base, %{
          from_address: event["from_address"],
          to_address: event["to_address"],
          quantity: event["quantity"]
        })

      "listing" ->
        payment = event["payment"] || %{}

        Map.merge(base, %{
          price: format_price(event["starting_price"], payment["decimals"]),
          price_currency: payment["symbol"],
          maker: event["maker"],
          expiration_date: event["expiration_date"]
        })

      _ ->
        base
    end
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp transform_nft_summary(nil), do: nil
  defp transform_nft_summary(nft) do
    %{
      identifier: nft["identifier"],
      collection: nft["collection"],
      contract: nft["contract"],
      name: nft["name"],
      image_url: nft["image_url"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp format_price(nil, _decimals), do: nil
  defp format_price(price_str, nil) when is_binary(price_str) do
    case Integer.parse(price_str) do
      {price_wei, ""} -> price_wei / :math.pow(10, 18)
      _ -> nil
    end
  end
  defp format_price(price_str, decimals) when is_binary(price_str) do
    case Integer.parse(price_str) do
      {price_raw, ""} -> price_raw / :math.pow(10, decimals)
      _ -> nil
    end
  end
  defp format_price(price, _) when is_number(price), do: price
end
