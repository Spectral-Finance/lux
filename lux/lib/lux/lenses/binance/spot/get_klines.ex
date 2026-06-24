defmodule Lux.Lenses.Binance.Spot.GetKlines do
  @moduledoc """
  Fetches kline/candlestick data from Binance.

  ## Examples

      iex> GetKlines.focus(%{symbol: "BTCUSDT", interval: "1h", limit: 100})
      {:ok, [...]}
  """

  alias Lux.Integrations.Binance
  require Logger

  use Lux.Lens,
    name: "Binance Get Klines",
    description: "Fetches kline/candlestick data from Binance",
    url: "#{Binance.base_url()}/api/v3/klines",
    method: :get,
    headers: Binance.headers(),
    auth: Binance.auth(),
    schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Trading pair"},
        interval: %{
          type: :string,
          description: "Kline interval",
          enum: ["1m", "3m", "5m", "15m", "30m", "1h", "2h", "4h", "6h", "8h", "12h", "1d", "3d", "1w", "1M"]
        },
        limit: %{type: :integer, description: "Number of klines (default 500, max 1000)", default: 500}
      },
      required: ["symbol", "interval"]
    }

  def before_focus(params) do
    %{url: "#{Lux.Integrations.Binance.base_url()}/api/v3/klines?symbol=#{params.symbol}&interval=#{params.interval}&limit=#{params.limit || 500}"}
  end

  def after_focus(data) when is_list(data) do
    {:ok, data}
  end

  def after_focus(body) do
    {:error, %{error: "Unexpected response", raw: body}}
  end
end
