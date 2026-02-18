defmodule Lux.Prisms.Telegram.Analytics.MessageAnalyticsTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Prisms.Telegram.Analytics.MessageAnalytics
  alias Lux.Integrations.Telegram.Analytics

  @agent_ctx %{name: "TestAgent"}

  setup do
    start_supervised!({Analytics, [name: :"test_#{:erlang.unique_integer([:positive])}", cleanup_interval_ms: 0]})
    Analytics.reset()
    :ok
  end

  describe "handler/2 - record action" do
    test "records a sent message event" do
      assert {:ok, %{recorded: true, event_type: :message_sent}} =
               MessageAnalytics.handler(
                 %{action: "record", direction: "sent", chat_id: 123, user_id: 42},
                 @agent_ctx
               )
    end

    test "records a received message event" do
      assert {:ok, %{recorded: true, event_type: :message_received}} =
               MessageAnalytics.handler(
                 %{action: "record", direction: "received", chat_id: 123, user_id: 42},
                 @agent_ctx
               )
    end

    test "records a forwarded message event" do
      assert {:ok, %{recorded: true, event_type: :message_forwarded}} =
               MessageAnalytics.handler(
                 %{action: "record", direction: "forwarded", chat_id: 123},
                 @agent_ctx
               )
    end

    test "records an edited message event" do
      assert {:ok, %{recorded: true, event_type: :message_edited}} =
               MessageAnalytics.handler(
                 %{action: "record", direction: "edited", chat_id: 123},
                 @agent_ctx
               )
    end

    test "records a deleted message event" do
      assert {:ok, %{recorded: true, event_type: :message_deleted}} =
               MessageAnalytics.handler(
                 %{action: "record", direction: "deleted", chat_id: 123},
                 @agent_ctx
               )
    end

    test "defaults to received when direction missing" do
      assert {:ok, %{recorded: true, event_type: :message_received}} =
               MessageAnalytics.handler(
                 %{action: "record", chat_id: 123},
                 @agent_ctx
               )
    end

    test "includes message type metadata" do
      assert {:ok, %{recorded: true}} =
               MessageAnalytics.handler(
                 %{action: "record", direction: "sent", chat_id: 123, message_type: "photo"},
                 @agent_ctx
               )
    end
  end

  describe "handler/2 - stats action" do
    test "returns message statistics" do
      MessageAnalytics.handler(%{action: "record", direction: "sent", chat_id: 1}, @agent_ctx)
      MessageAnalytics.handler(%{action: "record", direction: "sent", chat_id: 2}, @agent_ctx)
      MessageAnalytics.handler(%{action: "record", direction: "received", chat_id: 1}, @agent_ctx)

      assert {:ok, stats} = MessageAnalytics.handler(%{action: "stats"}, @agent_ctx)
      assert stats.total_sent == 2
      assert stats.total_received == 1
      assert stats.total >= 3
    end

    test "returns stats for time range" do
      MessageAnalytics.handler(%{action: "record", direction: "sent", chat_id: 1}, @agent_ctx)

      now = System.system_time(:millisecond)

      assert {:ok, stats} =
               MessageAnalytics.handler(
                 %{action: "stats", from: now - 5000, to: now + 1000},
                 @agent_ctx
               )

      assert Map.has_key?(stats, :period)
    end

    test "returns zeroes when no data" do
      assert {:ok, stats} = MessageAnalytics.handler(%{action: "stats"}, @agent_ctx)
      assert stats.total == 0
    end
  end

  describe "handler/2 - error cases" do
    test "returns error for unknown action" do
      assert {:error, "Unknown action: unknown. Use 'record' or 'stats'."} =
               MessageAnalytics.handler(%{action: "unknown"}, @agent_ctx)
    end

    test "returns error for missing action" do
      assert {:error, "Missing required parameter: action"} =
               MessageAnalytics.handler(%{}, @agent_ctx)
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = MessageAnalytics.view()
      assert prism.input_schema.required == ["action"]
      assert Map.has_key?(prism.input_schema.properties, :action)
      assert Map.has_key?(prism.input_schema.properties, :direction)
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :user_id)
    end

    test "validates output schema" do
      prism = MessageAnalytics.view()
      assert Map.has_key?(prism.output_schema.properties, :recorded)
      assert Map.has_key?(prism.output_schema.properties, :total_sent)
      assert Map.has_key?(prism.output_schema.properties, :total_received)
    end
  end
end
