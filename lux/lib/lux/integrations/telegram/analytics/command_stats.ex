defmodule Lux.Integrations.Telegram.Analytics.CommandStats do
  @moduledoc """
  Analyzes bot command usage statistics, invocation frequencies,
  command latency profiles, and failure/success ratios.
  """

  @doc """
  Computes command usage analytics over events.
  """
  @spec analyze(list(map())) :: map()
  def analyze(events) when is_list(events) do
    cmd_events = Enum.filter(events, &(&1.type == :command or not is_nil(&1.command)))
    total_commands = length(cmd_events)

    grouped_by_command =
      Enum.group_by(cmd_events, fn e ->
        String.downcase(to_string(e.command || "unknown"))
      end)

    command_breakdown =
      grouped_by_command
      |> Enum.map(fn {cmd_name, cmd_list} ->
        count = length(cmd_list)
        successes = Enum.count(cmd_list, &(&1.status == :success))
        failures = count - successes
        success_rate = if count > 0, do: Float.round(successes / count * 100, 1), else: 0.0

        latencies = Enum.map(cmd_list, & &1.latency_ms) |> Enum.reject(&is_nil/1)

        avg_latency =
          if latencies != [] do
            Float.round(Enum.sum(latencies) / length(latencies), 1)
          else
            0.0
          end

        %{
          command: cmd_name,
          invocations: count,
          success_count: successes,
          failure_count: failures,
          success_rate: success_rate,
          avg_latency_ms: avg_latency
        }
      end)
      |> Enum.sort_by(& &1.invocations, :desc)

    %{
      total_command_invocations: total_commands,
      distinct_commands_used: length(Map.keys(grouped_by_command)),
      commands: command_breakdown
    }
  end
end
