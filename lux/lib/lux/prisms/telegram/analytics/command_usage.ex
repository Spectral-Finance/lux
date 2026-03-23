defmodule Lux.Prisms.Telegram.Analytics.CommandUsage do
  @moduledoc """
  A prism for analyzing command usage statistics from Telegram bot analytics.

  Tracks which bot commands are used most frequently, identifies underutilized
  commands, and calculates usage rates over time.

  ## Examples

      iex> CommandUsage.handler(%{}, %{name: "Agent"})
      {:ok, %{total_commands: 500, commands_by_name: %{"/start" => 200, "/help" => 150}, ...}}
  """

  use Lux.Prism,
    name: "Telegram Command Usage",
    description: "Analyzes command usage statistics from Telegram bot analytics data",
    input_schema: %{
      type: :object,
      properties: %{
        time_range: %{
          type: :object,
          description: "Optional time range filter",
          properties: %{
            start: %{type: :string, description: "ISO 8601 start timestamp"},
            end: %{type: :string, description: "ISO 8601 end timestamp"}
          }
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        total_commands: %{type: :integer, description: "Total number of commands executed"},
        commands_by_name: %{type: :object, description: "Command counts grouped by name"},
        most_used: %{type: :string, description: "Most frequently used command"},
        least_used: %{type: :string, description: "Least frequently used command"},
        commands_per_hour: %{type: :number, description: "Average commands per hour"}
      },
      required: ["total_commands", "commands_by_name", "most_used", "least_used", "commands_per_hour"]
    }

  alias Lux.Integrations.Telegram.Analytics.{Aggregator, Collector}
  require Logger

  @doc """
  Computes command usage statistics from collected analytics data.
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} requesting command usage analytics")

    try do
      stats = Collector.get_stats()
      commands = filter_commands(stats.commands, params)
      by_name = Aggregator.group_by_key(commands, :name)

      {most_used, least_used} = find_extremes(by_name)

      result = %{
        total_commands: length(commands),
        commands_by_name: by_name,
        most_used: most_used,
        least_used: least_used,
        commands_per_hour: Aggregator.calculate_rate(commands, :per_hour)
      }

      {:ok, result}
    rescue
      e ->
        Logger.error("Command usage analytics failed: #{inspect(e)}")
        {:error, "Failed to compute command usage analytics: #{Exception.message(e)}"}
    end
  end

  defp filter_commands(commands, params) do
    maybe_filter_time_range(commands, params[:time_range])
  end

  defp maybe_filter_time_range(commands, nil), do: commands

  defp maybe_filter_time_range(commands, %{start: start_str, end: end_str}) do
    {:ok, start_dt, _} = DateTime.from_iso8601(start_str)
    {:ok, end_dt, _} = DateTime.from_iso8601(end_str)

    Enum.filter(commands, fn cmd ->
      DateTime.compare(cmd.timestamp, start_dt) in [:gt, :eq] and
        DateTime.compare(cmd.timestamp, end_dt) in [:lt, :eq]
    end)
  end

  defp maybe_filter_time_range(commands, _), do: commands

  defp find_extremes(by_name) when map_size(by_name) == 0, do: {nil, nil}

  defp find_extremes(by_name) do
    sorted = Enum.sort_by(by_name, fn {_name, count} -> count end)
    {least_name, _} = List.first(sorted)
    {most_name, _} = List.last(sorted)
    {most_name, least_name}
  end
end
