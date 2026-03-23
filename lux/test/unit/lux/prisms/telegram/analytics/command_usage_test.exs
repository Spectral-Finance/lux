defmodule Lux.Prisms.Telegram.Analytics.CommandUsageTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Integrations.Telegram.Analytics.Collector
  alias Lux.Prisms.Telegram.Analytics.CommandUsage

  @agent_ctx %{name: "TestAgent"}

  setup do
    {:ok, pid} = Collector.start_link(name: Collector)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    :ok
  end

  describe "handler/2" do
    test "returns command usage with no data" do
      assert {:ok, result} = CommandUsage.handler(%{}, @agent_ctx)

      assert result.total_commands == 0
      assert result.commands_by_name == %{}
      assert result.most_used == nil
      assert result.least_used == nil
    end

    test "returns correct command counts" do
      now = DateTime.utc_now()

      Collector.track_command(%{name: "/start", user_id: 1, timestamp: now})
      Collector.track_command(%{name: "/start", user_id: 2, timestamp: now})
      Collector.track_command(%{name: "/help", user_id: 3, timestamp: now})
      Collector.track_command(%{name: "/settings", user_id: 4, timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = CommandUsage.handler(%{}, @agent_ctx)

      assert result.total_commands == 4
      assert result.commands_by_name["/start"] == 2
      assert result.commands_by_name["/help"] == 1
      assert result.commands_by_name["/settings"] == 1
    end

    test "identifies most and least used commands" do
      now = DateTime.utc_now()

      for _ <- 1..10, do: Collector.track_command(%{name: "/start", user_id: 1, timestamp: now})
      for _ <- 1..5, do: Collector.track_command(%{name: "/help", user_id: 2, timestamp: now})
      Collector.track_command(%{name: "/settings", user_id: 3, timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = CommandUsage.handler(%{}, @agent_ctx)

      assert result.most_used == "/start"
      assert result.least_used == "/settings"
    end

    test "filters by time range" do
      t1 = ~U[2024-06-15 10:00:00Z]
      t2 = ~U[2024-06-15 20:00:00Z]

      Collector.track_command(%{name: "/start", user_id: 1, timestamp: t1})
      Collector.track_command(%{name: "/help", user_id: 2, timestamp: t2})

      :timer.sleep(20)

      params = %{
        time_range: %{
          start: "2024-06-15T09:00:00Z",
          end: "2024-06-15T12:00:00Z"
        }
      }

      assert {:ok, result} = CommandUsage.handler(params, @agent_ctx)
      assert result.total_commands == 1
      assert result.commands_by_name["/start"] == 1
    end

    test "calculates commands per hour" do
      now = DateTime.utc_now()

      for _ <- 1..6 do
        Collector.track_command(%{name: "/start", user_id: 1, timestamp: now})
      end

      :timer.sleep(20)

      assert {:ok, result} = CommandUsage.handler(%{}, @agent_ctx)
      assert is_number(result.commands_per_hour)
    end
  end
end
