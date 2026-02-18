defmodule Lux.Prisms.Telegram.Analytics.CommandUsageTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Prisms.Telegram.Analytics.CommandUsage
  alias Lux.Integrations.Telegram.Analytics

  @agent_ctx %{name: "TestAgent"}

  setup do
    start_supervised!({Analytics, [name: :"test_#{:erlang.unique_integer([:positive])}", cleanup_interval_ms: 0]})
    Analytics.reset()
    :ok
  end

  describe "handler/2 - record action" do
    test "records a command execution" do
      assert {:ok, %{recorded: true, command: "start"}} =
               CommandUsage.handler(
                 %{action: "record", command: "start", user_id: 42},
                 @agent_ctx
               )
    end

    test "records with response time" do
      assert {:ok, %{recorded: true, command: "help"}} =
               CommandUsage.handler(
                 %{action: "record", command: "help", response_time_ms: 150},
                 @agent_ctx
               )
    end

    test "records with success status" do
      assert {:ok, %{recorded: true}} =
               CommandUsage.handler(
                 %{action: "record", command: "search", success: false},
                 @agent_ctx
               )
    end

    test "returns error when command missing" do
      assert {:error, "Missing or invalid command parameter"} =
               CommandUsage.handler(%{action: "record"}, @agent_ctx)
    end

    test "returns error when command is empty string" do
      assert {:error, "Missing or invalid command parameter"} =
               CommandUsage.handler(%{action: "record", command: ""}, @agent_ctx)
    end

    test "records with chat_id" do
      assert {:ok, %{recorded: true}} =
               CommandUsage.handler(
                 %{action: "record", command: "settings", chat_id: 123},
                 @agent_ctx
               )
    end
  end

  describe "handler/2 - stats action" do
    test "returns command statistics" do
      CommandUsage.handler(%{action: "record", command: "start"}, @agent_ctx)
      CommandUsage.handler(%{action: "record", command: "start"}, @agent_ctx)
      CommandUsage.handler(%{action: "record", command: "help"}, @agent_ctx)

      assert {:ok, stats} = CommandUsage.handler(%{action: "stats"}, @agent_ctx)
      assert stats.total_commands == 3
      assert stats.most_used == "start"
      assert Map.has_key?(stats.commands, "start")
      assert Map.has_key?(stats.commands, "help")
    end

    test "returns empty stats when no commands recorded" do
      assert {:ok, stats} = CommandUsage.handler(%{action: "stats"}, @agent_ctx)
      assert stats.commands == %{}
      assert stats.total_commands == 0
    end

    test "tracks success rates" do
      CommandUsage.handler(%{action: "record", command: "search", success: true}, @agent_ctx)
      CommandUsage.handler(%{action: "record", command: "search", success: false}, @agent_ctx)

      assert {:ok, stats} = CommandUsage.handler(%{action: "stats"}, @agent_ctx)
      assert stats.commands["search"].count == 2
      assert stats.commands["search"].error_count == 1
      assert stats.commands["search"].success_rate == 50.0
    end
  end

  describe "handler/2 - error cases" do
    test "returns error for unknown action" do
      assert {:error, "Unknown action: invalid. Use 'record' or 'stats'."} =
               CommandUsage.handler(%{action: "invalid"}, @agent_ctx)
    end

    test "returns error for missing action" do
      assert {:error, "Missing required parameter: action"} =
               CommandUsage.handler(%{}, @agent_ctx)
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = CommandUsage.view()
      assert prism.input_schema.required == ["action"]
      assert Map.has_key?(prism.input_schema.properties, :action)
      assert Map.has_key?(prism.input_schema.properties, :command)
      assert Map.has_key?(prism.input_schema.properties, :response_time_ms)
      assert Map.has_key?(prism.input_schema.properties, :success)
    end

    test "validates output schema" do
      prism = CommandUsage.view()
      assert Map.has_key?(prism.output_schema.properties, :recorded)
      assert Map.has_key?(prism.output_schema.properties, :commands)
      assert Map.has_key?(prism.output_schema.properties, :total_commands)
      assert Map.has_key?(prism.output_schema.properties, :most_used)
    end
  end
end
