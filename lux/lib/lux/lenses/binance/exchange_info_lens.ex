defmodule Lux.Lenses.Binance.ExchangeInfoLens do
  @moduledoc """
  A Lens for fetching exchange rules, active symbols, precisions, and rate limits from Binance Spot or Futures APIs.

  ## Examples

      # Query Spot exchange info
      iex> Lux.Lenses.Binance.ExchangeInfoLens.focus(%{market_type: "spot", symbol: "BTCUSDT"})
      {:ok, %{"symbols" => [%{"symbol" => "BTCUSDT", "status" => "TRADING"}]}}

      # Query Futures exchange info
      iex> Lux.Lenses.Binance.ExchangeInfoLens.focus(%{market_type: "futures"})
      {:ok, %{"symbols" => [...]}}
  """

  use Lux.Lens,
    name: "Binance Exchange Info Lens",
    description: "Fetches exchange rules, symbol precisions, and rate limits from Binance Spot or Futures.",
    url: "https://api.binance.com/api/v3/exchangeInfo",
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
          description: "Optional specific symbol to query (e.g. 'BTCUSDT')"
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
  Focuses the lens to fetch exchange rules and symbol details from Binance.
  """
  def focus(input, opts) do
    market_type = parse_market_type(input)
    testnet? = Map.get(input, :testnet) || Map.get(input, "testnet", false) || Keyword.get(opts, :testnet, false)
    symbol = Map.get(input, :symbol) || Map.get(input, "symbol")

    path = if market_type == :futures, do: "/fapi/v1/exchangeInfo", else: "/api/v3/exchangeInfo"
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
