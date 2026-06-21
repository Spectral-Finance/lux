defmodule Lux.Lenses.Hyperliquid.GetOrderBook do
  @moduledoc """
  A lens for fetching order book data from Hyperliquid.

  Returns the current order book for a specific trading pair with configurable depth.

  ## Examples

      iex> Lux.Lenses.Hyperliquid.GetOrderBook.focus(%{coin: "ETH", depth: 10})
      {:ok, %{
        coin: "ETH",
        levels: [
          %{
            bids: [%{px: "2799.0", sz: "10.5", n: 3}],
            asks: [%{px: "2801.0", sz: "8.2", n: 2}]
          }
        ]
      }}
  """

  alias Lux.Integrations.Hyperliquid

  use Lux.Lens,
    name: "Hyperliquid Get Order Book",
    description: "Fetches order book data for a specific market on Hyperliquid",
    url: "#{Hyperliquid.info_url()}",
    method: :post,
    headers: Hyperliquid.headers(),
    schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'ETH', 'BTC')"
        },
        depth: %{
          type: :integer,
          description: "Number of price levels to fetch (default: 20)",
          default: 20
        }
      },
      required: ["coin"]
    }

  require Logger

  @impl true
  def before_focus(params) do
    coin = Map.get(params, :coin, Map.get(params, "coin"))
    depth = Map.get(params, :depth, Map.get(params, "depth", 20))

    %{
      url: Hyperliquid.info_url(),
      type: "l2Book",
      coin: coin,
      nSigFigs: 5,
      depth: depth
    }
  end

  @impl true
  def after_focus(%{"levels" => levels} = _response) do
    parsed_levels =
      levels
      |> Enum.map(fn level ->
        %{
          bids: parse_orders(level, 0),
          asks: parse_orders(level, 1)
        }
      end)

    {:ok, %{levels: parsed_levels}}
  end

  def after_focus(%{"error" => error}) do
    Logger.error("Failed to fetch order book from Hyperliquid: #{inspect(error)}")
    {:error, error}
  end

  def after_focus(response) do
    Logger.error("Unexpected Hyperliquid order book response: #{inspect(response)}")
    {:error, "Unexpected response format"}
  end

  defp parse_orders(level, index) when is_list(level) do
    case Enum.at(level, index) do
      orders when is_list(orders) ->
        Enum.map(orders, fn
          %{"px" => px, "sz" => sz, "n" => n} ->
            %{px: px, sz: sz, n: n}

          [px, sz] ->
            %{px: px, sz: sz, n: 1}

          order ->
            order
        end)

      _ ->
        []
    end
  end

  defp parse_orders(_level, _index), do: []
end
