defmodule Lux.Lenses.TradingView.QuoteLens do
  @moduledoc """
  Lens for fetching real-time quotes and market data from TradingView.

  ## Example

      alias Lux.Lenses.TradingView.QuoteLens

      QuoteLens.focus(%{
        symbols: ["BINANCE:BTCUSDT", "BINANCE:ETHUSDT"]
      })
  """

  use Lux.Lens,
    name: "TradingView Quotes",
    description: "Fetches real-time market quotes from TradingView",
    url: "https://api.tradingview.io/v2/screener/quotes",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        symbols: %{
          type: :array,
          description: "List of TradingView symbols to fetch quotes for",
          items: %{type: :string}
        },
        screen: %{
          type: :string,
          description: "Screener area",
          default: "crypto",
          enum: ["crypto", "forex", "stock", "cfd", "future"]
        }
      },
      required: ["symbols"]
    }

  def before_focus(params) do
    Map.update!(params, :symbols, &if(is_list(&1), do: Enum.join(&1, ","), else: &1))
  end

  @impl true
  def after_focus(%{"data" => quotes}) when is_list(quotes) do
    result =
      Enum.map(quotes, fn q ->
        %{
          symbol: Map.get(q, "s", Map.get(q, "symbol")),
          price: Map.get(q, "v", %{})["price"],
          change: Map.get(q, "v", %{})["chng"],
          change_pct: Map.get(q, "v", %{})["changespercentage"],
          volume: Map.get(q, "v", %{})["volume"],
          high: Map.get(q, "v", %{})["high"],
          low: Map.get(q, "v", %{})["low"],
          open: Map.get(q, "v", %{})["open"],
          previous_close: Map.get(q, "v", %{})["previous_close"]
        }
        |> Map.reject(fn {_, v} -> is_nil(v) end)
      end)

    {:ok, %{quotes: result}}
  end

  @impl true
  def after_focus(%{"data" => %{} = quote}) do
    result =
      quote
      |> Map.take(["s", "symbol", "v"])
      |> Map.get("v", %{})
      |> Map.merge(Map.take(quote, ["s", "symbol"]))

    {:ok, %{quote: result}}
  end

  @impl true
  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  @impl true
  def after_focus(response) do
    {:ok, response}
  end
end
