defmodule Lux.Prisms.DefiAnalytics.AlertSystem do
  @moduledoc """
  A prism that monitors DeFi protocol metrics and generates alerts
  for significant changes in TVL, yield, or volume.

  ## Example

      iex> Lux.Prisms.DefiAnalytics.AlertSystem.run(%{
      ...>   protocols: ["uniswap", "aave"],
      ...>   tvl_change_threshold: 15.0,
      ...>   min_tvl: 1000000
      ...> })
      {:ok, %{alerts: [...]}}
  """

  use Lux.Prism,
    name: "DeFi Alert System",
    description: "Monitors DeFi protocols and generates alerts for metric anomalies",
    input_schema: %{
      type: :object,
      properties: %{
        protocols: %{
          type: :array,
          items: %{type: :string},
          description: "Protocols to monitor"
        },
        tvl_change_threshold: %{
          type: :number,
          description: "TVL change percentage to trigger alert",
          default: 15.0
        },
        min_tvl: %{
          type: :number,
          description: "Minimum TVL to consider (skip small protocols)",
          default: 1000000
        },
        check_yield: %{
          type: :boolean,
          description: "Also check yield data for anomalies",
          default: false
        }
      },
      required: ["protocols"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        alerts: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              protocol: %{type: :string},
              metric: %{type: :string},
              severity: %{type: :string},
              message: %{type: :string},
              value: %{type: :number}
            }
          }
        },
        summary: %{
          type: :object,
          properties: %{
            total_alerts: %{type: :integer},
            critical_count: %{type: :integer},
            warning_count: %{type: :integer}
          }
        }
      },
      required: ["alerts", "summary"]
    }

  alias Lux.Integrations.DeFiLlama

  require Logger

  @doc """
  Handler for the alert system prism.
  """
  def handler(input, _ctx) do
    protocols = Map.get(input, "protocols", [])
    tvl_threshold = Map.get(input, "tvl_change_threshold", 15.0)
    min_tvl = Map.get(input, "min_tvl", 1_000_000)
    check_yield = Map.get(input, "check_yield", false)

    protocol_tasks = Enum.map(protocols, fn protocol ->
      Task.async(fn ->
        case DeFiLlama.protocol_tvl(protocol) do
          {:ok, data} when is_map(data) ->
            current_tvl = get_tvl(data)
            if current_tvl >= min_tvl do
              [{:alert, protocol, "tv_l", current_tvl}]
            else
              []
            end

          _ ->
            [{:error, protocol, "Failed to fetch TVL data"}]
        end
      end)
    end)

    protocol_alerts =
      Enum.map(protocol_tasks, fn task ->
        Task.await(task, 30_000)
      end)
      |> List.flatten()

    alerts = protocol_alerts

    # Optionally check yield anomalies
    if check_yield do
      case DeFiLlama.yield_data() do
        {:ok, yields} when is_list(yields) ->
          yield_alerts = check_yield_anomalies(yields, min_tvl)
          alerts = yield_alerts ++ alerts

        _ ->
          :ok
      end
    end

    critical_count = Enum.count(alerts, fn
      {:alert, _, "critical", _} -> true
      _ -> false
    end)

    warning_count = Enum.count(alerts, fn
      {:alert, _, "warning", _} -> true
      _ -> false
    end)

    {:ok, %{
      alerts: alerts,
      total_alerts: length(alerts),
      critical_count: critical_count,
      warning_count: warning_count,
      checked_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }}
  rescue
    e ->
      Logger.error("Alert system error: #{inspect(e)}")
      {:error, "Alert monitoring failed: #{inspect(e)}"}
  end

  defp check_yield_anomalies(yields, min_tvl) do
    yields
    |> Enum.filter(fn y ->
      apy = Map.get(y, "apy", 0)
      fdv_tvl = Map.get(y, "fdvTvl", 0)
      apy > 100 or fdv_tvl > min_tvl
    end)
    |> Enum.map(fn y ->
      apy = Map.get(y, "apy", 0)
      pool = Map.get(y, "pool", "unknown")
      {:alert, pool, "high_apy", apy}
    end)
  end

  defp get_tvl(data) do
    case data["tvl"] do
      [] -> 0
      [last | _] when is_map(last) ->
        Map.get(last, "totalLiquidityUSD", Map.get(last, "tvl", 0))
      _ -> 0
    end
  end
end
