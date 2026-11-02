defmodule Lux.Integrations.Telegram.Analytics.CommandStatsTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.Analytics.CommandStats

  describe "CommandStats" do
    test "breaks down command frequencies, success rates, and average latencies" do
      events = [
        %{type: :command, command: "swap", status: :success, latency_ms: 100},
        %{type: :command, command: "swap", status: :success, latency_ms: 200},
        %{type: :command, command: "swap", status: :error, latency_ms: 150},
        %{type: :command, command: "balance", status: :success, latency_ms: 50}
      ]

      result = CommandStats.analyze(events)
      assert result.total_command_invocations == 4
      assert result.distinct_commands_used == 2

      swap_stat = Enum.find(result.commands, &(&1.command == "swap"))
      assert swap_stat.invocations == 3
      assert swap_stat.success_count == 2
      assert swap_stat.failure_count == 1
      assert swap_stat.success_rate == 66.7
      assert swap_stat.avg_latency_ms == 150.0

      balance_stat = Enum.find(result.commands, &(&1.command == "balance"))
      assert balance_stat.invocations == 1
      assert balance_stat.success_rate == 100.0
    end
  end
end
