defmodule Lux.Lenses.TradingView.Screener do
  @moduledoc """
  Stock/crypto screener lens for TradingView.
  """
  use Lux.Lens,
    name: "TradingView Screener",
    description: "Runs a market screen using TradingView scanner API",
    url: "https://scanner.tradingview.com/crypto/scan",
    method: :post,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        market: %{type: :string, default: "crypto"},
        conditions: %{type: :array, items: %{type: :string}}
      },
      required: ["market"]
    }

  def before_focus(params) do
    payload = %{
      "filter" => [],
      "options" => %{"lang" => "en"},
      "columns" => ["name", "close", "volume"]
    }
    {:ok, payload}
  end

  def after_focus({:ok, response}), do: {:ok, response}
  def after_focus(error), do: error
end
