defmodule Lux.Lenses.Binance.TickerPriceLens do
  @moduledoc """
  A Lens for fetching current price ticker data from Binance Spot or Futures APIs.

  ## Examples

      # Query single Spot symbol price
      iex> Lux.Lenses.Binance.TickerPriceLens.focus(%{market_type: "spot", symbol: "BTCUSDT"})
      {:ok, %{"symbol" => "BTCUSDT", "price" => "95120.50"}}

      # Query single Futures symbol price
      iex> Lux.Lenses.Binance.TickerPriceLens.focus(%{market_type: "futures", symbol: "BTCUSDT"})
      {:ok, %{"symbol" => "BTCUSDT", "price" => "95150.00"}}
  """

  use Lux.Lens,
    name: "Binance Ticker Price Lens",
    description: "Fetches current ticker price for a symbol or all symbols on Binance Spot or Futures.",
    url: "https://api.binance.com/api/v3/ticker/price",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        market_type: %{
          type: :string,
          enum: ["spot", "futures"],
          default: "spot",
          description: "Market type: 'spot' or 'futures'"
        },
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g. 'BTCUSDT'). Omit for all symbols."
        },
        testnet: %{
          type: :boolean,
          default: false,
          description: "Whether to target testnet API"
        }
      }
    }

  alias Lux.Binance.Client

  @doc """
  Focuses the lens to fetch ticker price from Binance.
  """
  def focus(input, opts) do
    market_type = parse_market_type(input)
    testnet? = Map.get(input, :testnet) || Map.get(input, "testnet", false) || Keyword.get(opts, :testnet, false)
    symbol = Map.get(input, :symbol) || Map.get(input, "symbol")

    path = if market_type == :futures, do: "/fapi/v1/ticker/price", else: "/api/v3/ticker/price"
    params = if symbol, do: %{symbol: symbol}, else: %{}

    client_opts = Keyword.merge([testnet: testnet?], opts)

    case Client.request(:get, market_type, path, params, client_opts) do
      {:ok, body} -> after_focus(body)
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def after_focus(body) do
    {:ok, body}
  end

  defp parse_market_type(input) do
    case Map.get(input, :market_type) || Map.get(input, "market_type", "spot") do
      "futures" -> :futures
      :futures -> :futures
      _ -> :spot
    end
  end
end
