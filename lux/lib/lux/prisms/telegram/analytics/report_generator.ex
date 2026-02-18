defmodule Lux.Prisms.Telegram.Analytics.ReportGenerator do
  @moduledoc """
  A prism for generating formatted analytics reports.

  Produces human-readable reports using the visualization helpers,
  suitable for display in Telegram messages or other text-based outputs.

  ## Examples

      # Generate a full report
      iex> ReportGenerator.handler(%{action: "full_report"}, %{name: "Agent"})
      {:ok, %{report: "📊 TELEGRAM BOT ANALYTICS REPORT\\n..."}}

      # Generate a specific section report
      iex> ReportGenerator.handler(%{action: "section_report", section: "messages"}, %{name: "Agent"})
      {:ok, %{report: "📨 MESSAGE STATISTICS\\n..."}}
  """

  use Lux.Prism,
    name: "Telegram Report Generator",
    description: "Generates formatted analytics reports for Telegram bot data",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action: 'full_report' or 'section_report'",
          enum: ["full_report", "section_report"]
        },
        section: %{
          type: :string,
          description: "Report section (for 'section_report')",
          enum: ["messages", "commands", "engagement", "errors", "performance", "usage_patterns"]
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        report: %{type: :string, description: "Formatted report text"}
      }
    }

  alias Lux.Integrations.Telegram.Analytics
  alias Lux.Integrations.Telegram.Analytics.Visualization
  require Logger

  @doc """
  Handles report generation actions.
  """
  def handler(%{action: "full_report"}, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} generating full analytics report")

    dashboard = Analytics.get_dashboard()
    report = Visualization.full_report(dashboard)
    {:ok, %{report: report}}
  end

  def handler(%{action: "section_report"} = params, agent) do
    case Map.fetch(params, :section) do
      {:ok, section} when is_binary(section) ->
        agent_name = agent[:name] || "Unknown Agent"
        Logger.info("Agent #{agent_name} generating #{section} report")

        report = generate_section_report(section)
        {:ok, %{report: report}}

      _ ->
        {:error, "Missing or invalid section parameter"}
    end
  end

  def handler(%{action: action}, _agent) do
    {:error, "Unknown action: #{action}. Use 'full_report' or 'section_report'."}
  end

  def handler(_params, _agent) do
    {:error, "Missing required parameter: action"}
  end

  defp generate_section_report("messages") do
    stats = Analytics.get_message_stats()
    Visualization.summary_table(stats, title: "📨 Message Statistics")
  end

  defp generate_section_report("commands") do
    stats = Analytics.get_command_stats()

    header = Visualization.summary_table(
      %{total_commands: stats.total_commands, most_used: stats.most_used || "N/A"},
      title: "🤖 Command Statistics"
    )

    details =
      stats.commands
      |> Enum.map(fn {cmd, info} ->
        "/#{cmd}: #{info.count} calls (#{info.success_rate}% success)"
      end)
      |> Enum.join("\n")

    header <> "\n" <> details <> "\n"
  end

  defp generate_section_report("engagement") do
    stats = Analytics.get_user_engagement()

    Visualization.summary_table(
      %{
        total_unique_users: stats.total_unique_users,
        active_users_last_hour: stats.active_users_last_hour,
        active_users_last_day: stats.active_users_last_day
      },
      title: "👥 User Engagement"
    )
  end

  defp generate_section_report("errors") do
    stats = Analytics.get_error_stats()

    Visualization.summary_table(
      %{
        total_errors: stats.total_errors,
        error_rate: stats.error_rate
      },
      title: "❌ Error Statistics"
    )
  end

  defp generate_section_report("performance") do
    stats = Analytics.get_performance_metrics()
    Visualization.summary_table(stats, title: "⚡ Performance Metrics")
  end

  defp generate_section_report("usage_patterns") do
    stats = Analytics.get_usage_patterns()

    hourly_chart =
      if map_size(stats.hourly_distribution) > 0 do
        Visualization.bar_chart(stats.hourly_distribution, title: "📈 Hourly Distribution", width: 20)
      else
        "📈 Hourly Distribution\nNo data available\n"
      end

    summary =
      Visualization.summary_table(
        %{peak_hour: stats.peak_hour, peak_day: stats.peak_day},
        title: "📈 Usage Patterns"
      )

    summary <> "\n" <> hourly_chart
  end

  defp generate_section_report(section) do
    "Unknown section: #{section}"
  end
end
