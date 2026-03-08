defmodule Lux.Prisms.Telegram.AnalyticsReport do
  @moduledoc """
  Prism for generating and querying Telegram bot analytics reports.
  """

  use Lux.Prism,
    name: "Telegram Analytics Report",
    description: "Generate analytics reports for Telegram bots: overview, performance, engagement, errors",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["full_report", "performance", "engagement", "errors", "patterns"]},
        collector_pid: %{type: :string, description: "Optional collector process name/pid"}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{report: %{type: :object}}
    }

  alias Lux.Integrations.Telegram.Analytics.{Collector, Aggregator}

  @impl true
  def handler(params, _agent) do
    action = params["action"] || params[:action]
    pid = params[:collector_pid] || params["collector_pid"] || Collector

    case action do
      "full_report" ->
        Aggregator.report(pid)

      "performance" ->
        with {:ok, counters} <- Collector.get_counters(pid) do
          {:ok, %{report: Aggregator.performance_metrics(counters[:response_times] || [])}}
        end

      "engagement" ->
        with {:ok, counters} <- Collector.get_counters(pid) do
          {:ok, %{report: %{
            messages_per_user: Aggregator.messages_per_user(counters.messages_total, counters.unique_users),
            unique_users: counters.unique_users,
            unique_chats: counters.unique_chats,
            command_usage_rate: if(counters.messages_total > 0, do: Float.round(counters.commands_total / counters.messages_total * 100, 2), else: 0.0)
          }}}
        end

      "errors" ->
        with {:ok, counters} <- Collector.get_counters(pid) do
          {:ok, %{report: %{
            total: counters.errors_total,
            by_type: counters.errors_by_type,
            rate: Aggregator.error_rate(counters.errors_total, counters.messages_total)
          }}}
        end

      "patterns" ->
        with {:ok, counters} <- Collector.get_counters(pid) do
          {:ok, %{report: %{
            top_commands: counters.top_commands,
            peak_hours: Aggregator.peak_hours(counters.hourly_distribution)
          }}}
        end

      _ -> {:error, "Unknown action: #{action}"}
    end
  end
end
