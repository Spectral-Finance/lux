defmodule Lux.Integrations.Telegram.Analytics.CollectorTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.Analytics.Collector

  describe "Collector" do
    test "records events and enforces max_events buffer" do
      state = Collector.init(max_events: 3)

      {:ok, state, e1} = Collector.record_event(state, :message, %{chat_id: 10, user_id: 20})
      {:ok, state, e2} = Collector.record_event(state, :command, %{command: "start"})
      {:ok, state, e3} = Collector.record_event(state, :callback, %{latency_ms: 120})
      {:ok, state, e4} = Collector.record_event(state, :error, %{status: :error, error_code: 400})

      assert length(state.events) == 3
      assert hd(state.events).id == e4.id
      refute Enum.any?(state.events, &(&1.id == e1.id))
      assert e2.type == :command
      assert e3.latency_ms == 120
      assert e4.status == :error
    end

    test "queries events with filters" do
      state = Collector.init()
      {:ok, state, _} = Collector.record_event(state, :message, %{chat_id: 100, user_id: 1})
      {:ok, state, _} = Collector.record_event(state, :command, %{chat_id: 100, user_id: 2, command: "help"})
      {:ok, state, _} = Collector.record_event(state, :error, %{chat_id: 200, status: :error})

      commands = Collector.query_events(state, %{type: :command})
      assert length(commands) == 1
      assert hd(commands).command == "help"

      chat_100 = Collector.query_events(state, %{chat_id: 100})
      assert length(chat_100) == 2

      errors = Collector.query_events(state, %{status: :error})
      assert length(errors) == 1
    end
  end
end
