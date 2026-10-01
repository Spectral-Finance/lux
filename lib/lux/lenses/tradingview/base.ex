defmodule Lux.Lenses.TradingView.Base do
  @moduledoc """
  Base module for TradingView API configurations.
  """

  def add_api_key(headers) do
    case System.get_env("TRADINGVIEW_API_KEY") do
      nil -> headers
      key -> [{"authorization", "Bearer #{key}"} | headers]
    end
  end
end
