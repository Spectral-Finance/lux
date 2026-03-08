defmodule Lux.Prisms.TradingView.AlertManager do
  @moduledoc """
  Prism for managing TradingView-style price and indicator alerts.

  Creates, checks, and manages alerts based on price levels,
  indicator values, or signal changes.

  ## Alert Types
  - `:price_above` / `:price_below` — Price level alerts
  - `:indicator_cross` — Indicator crossover alerts (e.g., MACD cross)
  - `:signal_change` — Trading signal change alerts
  - `:custom` — Custom condition alerts

  ## Examples

      iex> AlertManager.handler(%{
      ...>   "action" => "create",
      ...>   "symbol" => "BINANCE:BTCUSDT",
      ...>   "type" => "price_above",
      ...>   "value" => 70000.0,
      ...>   "message" => "BTC broke 70K!"
      ...> }, nil)
      {:ok, %{alert_id: "alert_abc123", status: :active}}

      iex> AlertManager.handler(%{
      ...>   "action" => "check",
      ...>   "symbol" => "BINANCE:BTCUSDT"
      ...> }, nil)
      {:ok, %{triggered: [%{alert_id: "alert_abc123", ...}], active: 3}}
  """

  use Lux.Prism,
    name: "TradingView Alert Manager",
    description: "Manages price and indicator alerts based on TradingView data",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action: create, check, list, delete",
          enum: ["create", "check", "list", "delete"]
        },
        symbol: %{type: :string, description: "Symbol in EXCHANGE:PAIR format"},
        type: %{
          type: :string,
          description: "Alert type: price_above, price_below, indicator_cross, signal_change",
          enum: ["price_above", "price_below", "indicator_cross", "signal_change"]
        },
        value: %{type: :number, description: "Trigger value (price level or indicator threshold)"},
        indicator: %{type: :string, description: "Indicator name for indicator_cross alerts"},
        message: %{type: :string, description: "Alert message"},
        alert_id: %{type: :string, description: "Alert ID for delete action"}
      },
      required: ["action"]
    }

  alias Lux.Lenses.TradingView.{ChartData, TechnicalRating}

  require Logger

  # In-memory alert store (in production, use persistent storage)
  # This is a stateless implementation - alerts are passed in/out as data
  def handler(%{"action" => "create"} = params, _context) do
    alert = %{
      alert_id: "alert_#{:crypto.strong_rand_bytes(8) |> Base.hex_encode32(case: :lower) |> String.slice(0, 12)}",
      symbol: params["symbol"],
      type: String.to_atom(params["type"] || "price_above"),
      value: params["value"],
      indicator: params["indicator"],
      message: params["message"] || "Alert triggered",
      status: :active,
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    {:ok, alert}
  end

  def handler(%{"action" => "check", "symbol" => symbol} = params, _context) do
    alerts = params["alerts"] || []

    case ChartData.focus(%{symbol: symbol, interval: "D"}) do
      {:ok, %{data: [%{close: price} | _]}} when is_number(price) ->
        {triggered, still_active} =
          Enum.split_with(alerts, fn alert ->
            check_alert(alert, price)
          end)

        {:ok, %{
          symbol: symbol,
          current_price: price,
          triggered: Enum.map(triggered, &Map.put(&1, :triggered_at, DateTime.utc_now() |> DateTime.to_iso8601())),
          active: length(still_active),
          total: length(alerts)
        }}

      {:error, reason} ->
        {:error, "Failed to check alerts: #{inspect(reason)}"}

      _ ->
        {:error, "No price data available for #{symbol}"}
    end
  end

  def handler(%{"action" => "list"} = params, _context) do
    alerts = params["alerts"] || []
    symbol = params["symbol"]

    filtered =
      if symbol do
        Enum.filter(alerts, &(&1[:symbol] == symbol || &1["symbol"] == symbol))
      else
        alerts
      end

    {:ok, %{alerts: filtered, count: length(filtered)}}
  end

  def handler(%{"action" => "delete", "alert_id" => alert_id} = params, _context) do
    alerts = params["alerts"] || []
    remaining = Enum.reject(alerts, &(&1[:alert_id] == alert_id || &1["alert_id"] == alert_id))

    {:ok, %{deleted: alert_id, remaining: length(remaining), alerts: remaining}}
  end

  def handler(params, _context) do
    {:error, "Unknown action: #{inspect(params["action"])}. Use: create, check, list, delete"}
  end

  defp check_alert(%{type: :price_above, value: target}, price) when is_number(target) do
    price >= target
  end

  defp check_alert(%{type: :price_below, value: target}, price) when is_number(target) do
    price <= target
  end

  defp check_alert(%{"type" => "price_above", "value" => target}, price) when is_number(target) do
    price >= target
  end

  defp check_alert(%{"type" => "price_below", "value" => target}, price) when is_number(target) do
    price <= target
  end

  defp check_alert(_, _), do: false
end
