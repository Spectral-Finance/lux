defmodule Lux.Lenses.Binance.Spot.GetTicker do
  @moduledoc """
  Fetches the current ticker price for a Binance trading pair.

  ## Examples

      iex> GetTicker.focus(%{symbol: "BTCUSDT"})
      {:ok, %{symbol: "BTCUSDT", price: "50000.00"}}
  """

  alias Lux.Integrations.Binance
  require Logger

  use Lux.Lens,
    name: "Binance Get Ticker",
    description: "Fetches ticker price from Binance",
    url: "#{Binance.base_url()}/api/v3/ticker/price",
    method: :get,
    headers: Binance.headers(),
    auth: Binance.auth(),
    schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Trading pair symbol (e.g. BTCUSDT)"}
      },
      required: ["symbol"]
    }

  def before_focus(%{symbol: symbol}) do
    %{url: "#{Lux.Integrations.Binance.base_url()}/api/v3/ticker/price?symbol=#{symbol}"}
  end

  def after_focus(body) when is_map(body) do
    {:ok, body}
  end

  def after_focus(body) do
    {:error, %{error: "Unexpected response", raw: body}}
  end
end
