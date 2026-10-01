defmodule Lux.Lenses.TradingView.Alerts do
  @moduledoc """
  Alert management lens for TradingView.
  """
  use Lux.Lens,
    name: "TradingView Alerts",
    description: "Manage TradingView alerts and webhooks",
    url: "https://api.tradingview.com/v1/alerts",
    method: :get,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["list", "create"]},
        alert_data: %{type: :object}
      },
      required: ["action"]
    }

  def before_focus(params), do: {:ok, params}
  def after_focus(res), do: {:ok, res}
end
