defmodule Lux.Integrations.Telegram.Analytics.ReportGenerator do
  @moduledoc """
  Generates executive analytics reports for Telegram bots and communities.
  Features ASCII / Unicode data visualization helpers (bar charts, sparklines, progress meters).
  """

  @sparkline_bars [" ", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

  @doc """
  Generates a formatted Markdown report from combined analytics metrics.
  """
  @spec generate_markdown_report(map()) :: String.t()
  def generate_markdown_report(analytics) do
    msg_stats = Map.get(analytics, :messages, %{})
    eng_stats = Map.get(analytics, :engagement, %{})
    cmd_stats = Map.get(analytics, :commands, %{})
    perf_stats = Map.get(analytics, :performance, %{})

    top_cmds_data =
      cmd_stats
      |> Map.get(:commands, [])
      |> Enum.take(5)
      |> Enum.map(fn c -> {c.command, c.invocations} end)

    bar_chart = ascii_bar_chart(top_cmds_data)

    """
    📊 *Telegram Bot Analytics & Performance Report*

    📈 *Overview:*
    • Total Messages: `#{msg_stats[:total_messages] || 0}`
    • Unique Active Users: `#{eng_stats[:unique_active_users] || 0}`
    • Total Command Invocations: `#{cmd_stats[:total_command_invocations] || 0}`
    • Messages / Hour: `#{msg_stats[:messages_per_hour] || 0}`

    ⚡ *Performance & Reliability:*
    • Error Rate: `#{perf_stats[:error_rate_percent] || 0}%`
    • Latency (p50): `#{get_in(perf_stats, [:latency, :p50]) || 0}ms`
    • Latency (p95): `#{get_in(perf_stats, [:latency, :p95]) || 0}ms`
    • Rate Limit (429) Hits: `#{perf_stats[:rate_limit_429_count] || 0}`

    🏆 *Top Commands:*
    ```
    #{bar_chart}
    ```
    """
    |> String.trim()
  end

  @doc """
  Generates a formatted HTML report.
  """
  @spec generate_html_report(map()) :: String.t()
  def generate_html_report(analytics) do
    msg_stats = Map.get(analytics, :messages, %{})
    eng_stats = Map.get(analytics, :engagement, %{})
    cmd_stats = Map.get(analytics, :commands, %{})
    perf_stats = Map.get(analytics, :performance, %{})

    """
    📊 <b>Telegram Bot Analytics Report</b>

    <b>📈 Overview:</b>
    • Total Messages: <code>#{msg_stats[:total_messages] || 0}</code>
    • Unique Users: <code>#{eng_stats[:unique_active_users] || 0}</code>
    • Commands Executed: <code>#{cmd_stats[:total_command_invocations] || 0}</code>

    <b>⚡ Performance:</b>
    • Error Rate: <code>#{perf_stats[:error_rate_percent] || 0}%</code>
    • Latency (p95): <code>#{get_in(perf_stats, [:latency, :p95]) || 0}ms</code>
    • Status: #{if Enum.empty?(perf_stats[:alerts] || []), do: "🟢 Healthy", else: "🔴 Alerts Active"}
    """
    |> String.trim()
  end

  @doc """
  Renders an ASCII horizontal bar chart for key-value frequency pairs.
  """
  @spec ascii_bar_chart(list({String.t(), number()}), pos_integer()) :: String.t()
  def ascii_bar_chart([], _width), do: "No data available"

  def ascii_bar_chart(data, max_bar_width \\ 20) when is_list(data) do
    max_val = Enum.max_by(data, fn {_label, val} -> val end, fn -> {"", 1} end) |> elem(1)
    max_val = max(1, max_val)

    data
    |> Enum.map(fn {label, val} ->
      bar_len = round(val / max_val * max_bar_width)
      bar_str = String.duplicate("█", max(1, bar_len))
      label_padded = String.pad_trailing(to_string(label), 12)
      "#{label_padded} | #{bar_str} (#{val})"
    end)
    |> Enum.join("\n")
  end

  @doc """
  Renders a unicode sparkline string from a series of numeric values.
  """
  @spec sparkline(list(number())) :: String.t()
  def sparkline([]), do: ""

  def sparkline(values) when is_list(values) do
    min_val = Enum.min(values)
    max_val = Enum.max(values)
    range = max(1.0, max_val - min_val * 1.0)

    values
    |> Enum.map(fn v ->
      normalized = (v - min_val) / range
      idx = min(7, round(normalized * 7))
      Enum.at(@sparkline_bars, idx)
    end)
    |> Enum.join("")
  end

  @doc """
  Renders a percentage progress bar.
  """
  @spec progress_bar(float(), pos_integer()) :: String.t()
  def progress_bar(percentage, length \\ 15) do
    clamped = max(0.0, min(100.0, percentage))
    filled = round(clamped / 100.0 * length)
    empty = length - filled

    "[" <> String.duplicate("■", filled) <> String.duplicate("□", empty) <> "] #{Float.round(clamped, 1)}%"
  end
end
