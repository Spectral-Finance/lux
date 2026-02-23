defmodule Lux.Lenses.Blur.Collections.GetCollectionBids do
  @moduledoc """
  A lens for retrieving active collection-wide bids from the Blur NFT marketplace.

  This lens provides:
  - Active floor bids with price levels
  - Bid counts at each price level
  - Total bid liquidity depth
  - Criteria-based bids (trait bids)

  ## Examples

      iex> GetCollectionBids.focus(%{
      ...>   contract_address: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"
      ...> })
      {:ok, %{
        contract_address: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
        bids: [
          %{price: 9.8, price_currency: "ETH", bid_count: 12, executions_remaining: 12},
          %{price: 9.7, price_currency: "ETH", bid_count: 25, executions_remaining: 25}
        ],
        best_bid: 9.8,
        best_bid_currency: "ETH",
        total_bid_value: 450.3
      }}
  """

  alias Lux.Integrations.Blur

  use Lux.Lens,
    name: "Get Blur Collection Bids",
    description: "Retrieves active collection-wide bids and bid depth from Blur marketplace",
    url: "https://core-api.prod.blur.io/v1/collections/:contract_address/executable-bids",
    method: :get,
    headers: Blur.headers(),
    auth: Blur.auth(),
    schema: %{
      type: :object,
      properties: %{
        contract_address: %{
          type: :string,
          description: "The contract address of the NFT collection",
          pattern: "^0x[0-9a-fA-F]{40}$"
        }
      },
      required: ["contract_address"]
    }

  @doc """
  Transforms the Blur bids API response.
  """
  @impl true
  def after_focus(%{"priceLevels" => price_levels} = data) do
    bids = Enum.map(price_levels, fn level ->
      %{
        price: parse_number(level["price"]),
        price_currency: "ETH",
        bid_count: level["bidCount"],
        executions_remaining: level["numberBids"]
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()
    end)

    best_bid = List.first(bids)

    total_bid_value = bids
    |> Enum.map(fn bid -> (bid[:price] || 0) * (bid[:bid_count] || 0) end)
    |> Enum.sum()
    |> Float.round(4)

    result = %{
      contract_address: data["contractAddress"],
      bids: bids,
      best_bid: best_bid && best_bid[:price],
      best_bid_currency: "ETH",
      total_bid_value: total_bid_value
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    {:ok, result}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{message: message}}
  end

  def after_focus(%{"error" => error}) do
    {:error, %{error: error}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end

  defp parse_number(nil), do: nil
  defp parse_number(n) when is_number(n), do: n
  defp parse_number(s) when is_binary(s) do
    case Float.parse(s) do
      {f, ""} -> f
      _ ->
        case Integer.parse(s) do
          {i, ""} -> i * 1.0
          _ -> nil
        end
    end
  end
end
