defmodule Lux.Prisms.Analytics.Defi.DeFiAlertsPrism do
  @moduledoc """
  Evaluates protocol metrics for critical anomalies, TVL drawdowns, and stablecoin depeg risks.
  """

  use Lux.Prism,
    name: "DeFi Anomaly Alerts",
    description: "Evaluates TVL drawdowns, APY anomalies, and stablecoin peg variances",
    input_schema: %{
      type: :object,
      properties: %{
        protocol: %{type: :string, description: "Protocol name or symbol"},
        change_1d_pct: %{type: :number, description: "24h TVL change percentage"},
        current_price: %{type: :number, description: "Current asset or stablecoin price"},
        apy_pct: %{type: :number, description: "Current pool APY percentage"}
      },
      required: ["protocol"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        has_alerts?: %{type: :boolean},
        alert_count: %{type: :integer},
        alerts: %{type: :array}
      },
      required: ["has_alerts?", "alert_count", "alerts"]
    }

  alias Lux.Analytics.Defi.AlertEngine

  def handler(input, _ctx) do
    protocol = Map.get(input, :protocol) || Map.get(input, "protocol", "Unknown")
    change_1d = Map.get(input, :change_1d_pct) || Map.get(input, "change_1d_pct")
    price = Map.get(input, :current_price) || Map.get(input, "current_price")
    apy = Map.get(input, :apy_pct) || Map.get(input, "apy_pct")

    alerts = []

    alerts =
      if change_1d do
        case AlertEngine.check_tvl_drawdown(protocol, change_1d * 1.0) do
          {:ok, alt} -> [alt | alerts]
          :no_alert -> alerts
        end
      else
        alerts
      end

    alerts =
      if price do
        case AlertEngine.check_depeg(protocol, price * 1.0) do
          {:ok, alt} -> [alt | alerts]
          :no_alert -> alerts
        end
      else
        alerts
      end

    alerts =
      if apy do
        case AlertEngine.check_yield_anomaly(protocol, apy * 1.0) do
          {:ok, alt} -> [alt | alerts]
          :no_alert -> alerts
        end
      else
        alerts
      end

    {:ok,
     %{
       has_alerts?: length(alerts) > 0,
       alert_count: length(alerts),
       alerts: alerts
     }}
  end
end
