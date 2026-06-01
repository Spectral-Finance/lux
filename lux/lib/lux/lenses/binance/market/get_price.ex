defmodule Lux.Lenses.Binance.Market.GetPrice do
  @moduledoc """
  A lens for fetching the latest price of a symbol or all symbols from Binance.

  ## Examples

      iex> GetPrice.focus(%{symbol: "BTCUSDT"})
      {:ok, %{symbol: "BTCUSDT", price: "50000.00000000"}}

      iex> GetPrice.focus(%{})
      {:ok, [%{symbol: "BTCUSDT", price: "50000.00"}, ...]}
  """

  use Lux.Lens,
    name: "Binance Get Price",
    description: "Fetches the latest price for a symbol (or all symbols) from Binance",
    url: "https://api.binance.com/api/v3/ticker/price",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol, e.g. BTCUSDT. Omit to get all prices."
        }
      },
      required: []
    }

  @impl true
  def after_focus(%{"symbol" => symbol, "price" => price}) do
    {:ok, %{symbol: symbol, price: price}}
  end

  def after_focus(prices) when is_list(prices) do
    {:ok, Enum.map(prices, fn %{"symbol" => s, "price" => p} -> %{symbol: s, price: p} end)}
  end

  def after_focus(%{"code" => code, "msg" => msg}) do
    {:error, %{code: code, message: msg}}
  end
end
