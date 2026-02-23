defmodule Lux.Prisms.DeFiAnalytics.DeFiAnalyticsAlertPrism do
  @moduledoc """
  A prism for evaluating DeFi analytics data and generating alerts.

  Fetches current protocol metrics from DeFiLlama and checks them against
  user-defined thresholds. Returns structured alerts when conditions are met.

  Use cases:
  - Monitor TVL drops that may indicate protocol risk
  - Alert when yield drops below target APY
  - Detect unusual volume spikes or crashes
  - Track protocol health across multiple metrics simultaneously

  ## Example

      iex> Lux.Prisms.DeFiAnalytics.DeFiAnalyticsAlertPrism.run(%{
      ...>   protocol: "aave-v3",
      ...>   rules: [
      ...>     %{metric: "tvl", condition: "below", threshold: 5000000000.0, severity: "high"},
      ...>     %{metric: "tvl_change_1d", condition: "below", threshold: -10.0, severity: "critical"}
      ...>   ]
      ...> })
      {:ok, %{
        protocol: "aave-v3",
        alerts: [
          %{
            metric: "tvl_change_1d",
            condition: "below",
            threshold: -10.0,
            current_value: -12.5,
            severity: "critical",
            message: "aave-v3 TVL 1-day change (-12.50%) is below threshold (-10.00%)"
          }
        ],
        current_metrics: %{tvl: 5400000000.0, tvl_change_1d: -12.5},
        alert_count: 1,
        checked_at: 1708300800,
        status: "success"
      }}
  """

  use Lux.Prism,
    name: "DeFi Analytics Alert",
    description: "Evaluates DeFi protocol metrics against thresholds and generates structured alerts",
    input_schema: %{
      type: :object,
      properties: %{
        protocol: %{
          type: :string,
          description: "Protocol slug to monitor (e.g. 'aave-v3', 'uniswap', 'curve-dex')"
        },
        check_yield_pool: %{
          type: :string,
          description: "Yield pool ID to monitor (from DeFiLlama yields API)"
        },
        rules: %{
          type: :array,
          description: "Alert rules to evaluate",
          items: %{
            type: :object,
            properties: %{
              metric: %{
                type: :string,
                description: "Metric to check: tvl, tvl_change_1d, tvl_change_7d, apy, apy_base, volume_24h, fees_24h"
              },
              condition: %{
                type: :string,
                description: "Comparison: 'above', 'below', 'change_above', 'change_below'",
                enum: ["above", "below", "change_above", "change_below"]
              },
              threshold: %{
                type: :number,
                description: "Threshold value to compare against"
              },
              severity: %{
                type: :string,
                description: "Alert severity: 'info', 'warning', 'high', 'critical'",
                default: "warning",
                enum: ["info", "warning", "high", "critical"]
              }
            },
            required: ["metric", "condition", "threshold"]
          }
        }
      },
      required: ["rules"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        protocol: %{type: :string, description: "Protocol that was evaluated"},
        alerts: %{type: :array, description: "List of triggered alerts"},
        current_metrics: %{type: :object, description: "Current metric values fetched"},
        alert_count: %{type: :integer, description: "Number of alerts triggered"},
        checked_at: %{type: :integer, description: "Unix timestamp of evaluation"},
        status: %{type: :string, description: "Operation result"}
      },
      required: ["alerts", "alert_count", "current_metrics", "status"]
    }

  import Lux.Python
  require Lux.Python
  require Logger

  @defillama_base "https://api.llama.fi"
  @defillama_yields "https://yields.llama.fi"

  def handler(%{rules: rules} = input, _ctx) do
    protocol = Map.get(input, :protocol, nil)
    yield_pool_id = Map.get(input, :check_yield_pool, nil)

    Logger.info("DeFi analytics alert check: protocol=#{protocol || "none"} rules=#{length(rules)}")

    with {:ok, metrics} <- fetch_metrics(protocol, yield_pool_id),
         {:ok, alerts} <- evaluate_rules(rules, metrics, protocol || yield_pool_id || "unknown") do
      {:ok, %{
        protocol: protocol || yield_pool_id || "N/A",
        alerts: alerts,
        current_metrics: metrics,
        alert_count: length(alerts),
        checked_at: System.system_time(:second),
        status: "success"
      }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_metrics(nil, nil), do: {:error, "Provide protocol or check_yield_pool"}

  defp fetch_metrics(protocol, yield_pool_id) do
    result =
      python variables: %{
               base_url: @defillama_base,
               yields_url: @defillama_yields,
               protocol: protocol,
               yield_pool_id: yield_pool_id
             } do
        ~PY"""
        import urllib.request
        import json

        def fetch(url, timeout=15):
            req = urllib.request.Request(url, headers={"User-Agent": "LuxDeFiAnalytics/1.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())

        try:
            metrics = {}

            if protocol:
                protos = fetch(f"{base_url}/protocols")
                proto_data = next((p for p in protos if p.get("slug", "").lower() == protocol.lower()
                                   or p.get("name", "").lower() == protocol.lower()), None)
                if proto_data:
                    metrics["tvl"] = proto_data.get("tvl") or 0
                    metrics["tvl_change_1d"] = proto_data.get("change_1d") or 0
                    metrics["tvl_change_7d"] = proto_data.get("change_7d") or 0
                    metrics["mcap_tvl"] = proto_data.get("mcap") or 0
                    # Try to get volume
                    try:
                        vol_data = fetch(f"{base_url}/summary/dexs/{protocol}?excludeTotalDataChart=true")
                        metrics["volume_24h"] = vol_data.get("total24h") or 0
                        metrics["fees_24h"] = vol_data.get("totalFees24h") or 0
                    except:
                        metrics["volume_24h"] = 0
                        metrics["fees_24h"] = 0

            if yield_pool_id:
                pools = fetch(f"{yields_url}/pools")
                pool = next((p for p in pools.get("data", [])
                             if p.get("pool") == yield_pool_id), None)
                if pool:
                    metrics["apy"] = pool.get("apy") or 0
                    metrics["apy_base"] = pool.get("apyBase") or 0
                    metrics["apy_reward"] = pool.get("apyReward") or 0
                    metrics["tvl"] = metrics.get("tvl") or pool.get("tvlUsd") or 0
                    metrics["apy_change_1d"] = pool.get("apyPct1D") or 0
                    metrics["apy_change_7d"] = pool.get("apyPct7D") or 0

            metrics
        except Exception as e:
            {"error": str(e)}
        """
      end

    if is_map(result) and Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      metrics = Map.new(result, fn {k, v} -> {String.to_atom(k), v} end)
      {:ok, metrics}
    end
  end

  defp evaluate_rules(rules, metrics, label) do
    alerts =
      Enum.reduce(rules, [], fn rule, acc ->
        metric = Map.get(rule, :metric, Map.get(rule, "metric", ""))
        condition = Map.get(rule, :condition, Map.get(rule, "condition", ""))
        threshold = Map.get(rule, :threshold, Map.get(rule, "threshold", 0))
        severity = Map.get(rule, :severity, Map.get(rule, "severity", "warning"))

        metric_atom = String.to_atom(metric)
        current = Map.get(metrics, metric_atom, 0)

        triggered =
          case condition do
            "above" -> current > threshold
            "below" -> current < threshold
            "change_above" -> current > threshold
            "change_below" -> current < threshold
            _ -> false
          end

        if triggered do
          [%{
            metric: metric,
            condition: condition,
            threshold: threshold,
            current_value: current,
            severity: severity,
            message: "#{label} #{format_metric_name(metric)} (#{format_value(metric, current)}) is #{condition} threshold (#{format_value(metric, threshold)})"
          } | acc]
        else
          acc
        end
      end)

    {:ok, Enum.reverse(alerts)}
  end

  defp format_metric_name(metric) do
    case metric do
      "tvl" -> "TVL"
      "tvl_change_1d" -> "TVL 1-day change"
      "tvl_change_7d" -> "TVL 7-day change"
      "apy" -> "APY"
      "apy_base" -> "base APY"
      "apy_change_1d" -> "APY 1-day change"
      "volume_24h" -> "24h volume"
      "fees_24h" -> "24h fees"
      other -> other
    end
  end

  defp format_value(metric, value) when metric in ~w(tvl volume_24h fees_24h) do
    cond do
      value >= 1.0e9 -> "$#{Float.round(value / 1.0e9, 2)}B"
      value >= 1.0e6 -> "$#{Float.round(value / 1.0e6, 2)}M"
      true -> "$#{value}"
    end
  end

  defp format_value(_metric, value) when is_float(value), do: "#{Float.round(value, 2)}%"
  defp format_value(_metric, value), do: "#{value}"
end
