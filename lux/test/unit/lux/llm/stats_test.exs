defmodule Lux.LLM.StatsTest do
  use UnitAPICase, async: false

  alias Lux.LLM.Stats

  setup do
    start_supervised!(Stats)
    :ok
  end

  describe "measure/3" do
    test "returns the function result unchanged and counts the call" do
      assert {:ok, %Lux.LLM.Response{content: "ok"}} =
               Stats.measure(:stats_fixture, "m1", fn ->
                 {:ok, %Lux.LLM.Response{content: "ok"}}
               end)

      snapshot = Stats.snapshot()
      assert snapshot.calls == 1
      assert snapshot.errors == 0
      assert snapshot.latency_ms.max >= 0
      assert snapshot.providers[:stats_fixture].calls == 1
    end

    test "counts errors without raising" do
      assert {:error, :boom} =
               Stats.measure(:stats_fixture, "m1", fn -> {:error, :boom} end)

      snapshot = Stats.snapshot()
      assert snapshot.calls == 1
      assert snapshot.errors == 1
      assert snapshot.providers[:stats_fixture].errors == 1
    end

    test "emits a :telemetry stop event" do
      :ok =
        :telemetry.attach(
          "stats-test-handler",
          [:lux, :llm, :call, :stop],
          fn _event, measurements, metadata, _config ->
            send(self(), {:telemetry, measurements, metadata})
          end,
          nil
        )

      Stats.measure(:stats_fixture, "m1", fn -> {:ok, %Lux.LLM.Response{content: "x"}} end)

      assert_received {:telemetry, %{duration: duration}, %{provider: :stats_fixture, model: "m1", status: :ok}}
      assert is_integer(duration)
    after
      :telemetry.detach("stats-test-handler")
    end
  end

  describe "snapshot/0" do
    test "aggregates latency percentiles" do
      for _ <- 1..10 do
        Stats.measure(:stats_fixture, "m1", fn -> {:ok, %Lux.LLM.Response{content: "x"}} end)
      end

      snapshot = Stats.snapshot()
      assert snapshot.calls == 10
      assert %{p50: p50, p95: p95, max: max} = snapshot.latency_ms
      assert is_integer(p50) and is_integer(p95) and is_integer(max)
      assert p50 <= p95 and p95 <= max
    end

    test "reset/0 clears aggregates" do
      Stats.measure(:stats_fixture, "m1", fn -> {:ok, %Lux.LLM.Response{content: "x"}} end)
      :ok = Stats.reset()

      snapshot = Stats.snapshot()
      assert snapshot.calls == 0
      assert snapshot.errors == 0
      assert snapshot.latency_ms == %{p50: nil, p95: nil, max: nil}
    end
  end
end
