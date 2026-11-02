defmodule Lux.YouTube.GrowthEngine.ReportingSystem do
  @moduledoc """
  Generates automated executive growth digests, P&L reporting, and milestone progress summaries.
  """

  @doc """
  Builds a Markdown-formatted executive growth report summarizing telemetry, audit, and ROI.
  """
  @spec generate_executive_markdown(map()) :: String.t()
  def generate_executive_markdown(data) when is_map(data) do
    channel = Map.get(data, :channel_name, "Lux Channel")
    telemetry = Map.get(data, :telemetry, %{})
    forecast = Map.get(data, :forecast, %{})
    audit = Map.get(data, :audit, %{})
    roi = Map.get(data, :roi, %{})

    views = Map.get(telemetry, :views, 0)
    revenue = Map.get(telemetry, :estimated_revenue_usd, 0.0)
    rpm = Map.get(telemetry, :rpm, 0.0)
    subs = Map.get(telemetry, :net_subscribers, 0)

    grade = Map.get(audit, :health_grade, :a)
    score = Map.get(audit, :overall_score, 85.0)

    p30_subs = get_in(forecast, [:projected_30d, :projected_subscribers]) || "N/A"
    p30_rev = get_in(forecast, [:projected_30d, :projected_revenue_usd]) || "N/A"

    roi_mult = Map.get(roi, :roi_multiplier, 1.0)
    net_profit = Map.get(roi, :net_profit_usd, 0.0)

    """
    # 📈 YouTube Executive Growth & Analytics Report: #{channel}

    ## 1. Key Performance Indicators (Last Window)
    - **Total Views:** #{format_num(views)}
    - **Net Subscribers Gained:** +#{format_num(subs)}
    - **Total Estimated Revenue:** $#{revenue}
    - **Blended RPM:** $#{rpm}

    ## 2. Channel Health & Algorithmic Audit
    - **Health Grade:** `:#{grade}` (#{score}/100)
    - **CTR Performance:** #{get_in(audit, [:category_scores, :ctr_performance]) || "N/A"}/100
    - **Upload Cadence:** #{get_in(audit, [:category_scores, :cadence_consistency]) || "N/A"}/100

    ## 3. 30-Day Growth Forecast
    - **Projected Subscribers:** #{p30_subs}
    - **Projected Revenue:** $#{p30_rev}

    ## 4. Financial ROI & Profitability
    - **Production ROI Multiplier:** #{roi_mult}x
    - **Net Profit:** $#{net_profit}
    """
    |> String.trim()
  end

  defp format_num(val) when is_integer(val) or is_float(val) do
    val
    |> round()
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp format_num(other), do: to_string(other)
end
