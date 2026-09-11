defmodule Lux.LLM.TelemetryTest do
  use UnitAPICase, async: false

  alias Lux.LLM.ResponseSignal
  alias Lux.LLM.Telemetry
  alias Lux.Signal

  defp make_test_signal(usage_map) do
    payload = %{
      content: %{"result" => "telemetry response"},
      model: "test-model",
      finish_reason: "stop",
      tool_calls: nil,
      tool_calls_results: nil
    }

    Signal.new(%{schema_id: ResponseSignal, payload: payload, metadata: %{usage: usage_map}})
  end

  setup do
    test_pid = self()
    handler_id = "test-telemetry-handler-#{System.unique_integer([:positive])}"

    events = [
      [:lux, :llm, :call, :start],
      [:lux, :llm, :call, :stop],
      [:lux, :llm, :call, :exception]
    ]

    :telemetry.attach_many(
      handler_id,
      events,
      fn event_name, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event_name, measurements, metadata})
      end,
      nil
    )

    on_exit(fn ->
      :telemetry.detach(handler_id)
    end)

    :ok
  end

  describe "normalize_usage/1" do
    test "normalizes OpenAI style usage string keys" do
      raw = %{"prompt_tokens" => 10, "completion_tokens" => 20, "total_tokens" => 30}
      assert Telemetry.normalize_usage(raw) == %{prompt_tokens: 10, completion_tokens: 20, total_tokens: 30}
    end

    test "normalizes Gemini style usage" do
      raw = %{"promptTokenCount" => 15, "candidatesTokenCount" => 25}
      assert Telemetry.normalize_usage(raw) == %{prompt_tokens: 15, completion_tokens: 25, total_tokens: 40}
    end

    test "normalizes Anthropic style usage" do
      raw = %{"input_tokens" => 100, "output_tokens" => 200}
      assert Telemetry.normalize_usage(raw) == %{prompt_tokens: 100, completion_tokens: 200, total_tokens: 300}
    end

    test "handles nil or invalid inputs gracefully" do
      assert Telemetry.normalize_usage(nil) == %{prompt_tokens: 0, completion_tokens: 0, total_tokens: 0}
      assert Telemetry.normalize_usage("invalid") == %{prompt_tokens: 0, completion_tokens: 0, total_tokens: 0}
    end

    test "normalizes string token counts safely" do
      raw = %{"prompt_tokens" => "100", "completion_tokens" => "200"}
      assert Telemetry.normalize_usage(raw) == %{prompt_tokens: 100, completion_tokens: 200, total_tokens: 300}
    end

    test "handles invalid string token counts gracefully" do
      raw = %{"prompt_tokens" => "invalid", "completion_tokens" => "abc"}
      assert Telemetry.normalize_usage(raw) == %{prompt_tokens: 0, completion_tokens: 0, total_tokens: 0}
    end
  end

  describe "calculate_cost/5" do
    test "calculates cost accurately from explicit rates" do
      opts = [cost_per_1k_prompt_tokens: 0.002, cost_per_1k_completion_tokens: 0.004]
      res = Telemetry.calculate_cost(:custom, "model-1", 1000, 2000, opts)

      # 1000 prompt tokens * 0.002 / 1000 = 0.002
      # 2000 completion tokens * 0.004 / 1000 = 0.008
      # total = 0.010
      assert_in_delta res.prompt_cost, 0.002, 0.00001
      assert_in_delta res.completion_cost, 0.008, 0.00001
      assert_in_delta res.total_cost, 0.010, 0.00001
    end
  end

  describe "call/4 telemetry event emission & metadata enrichment" do
    test "emits start and stop events and attaches telemetry to signal metadata" do
      mock_provider_fn = fn _prompt, _tools, _opts ->
        {:ok, make_test_signal(%{"prompt_tokens" => 50, "completion_tokens" => 100})}
      end

      opts = [
        model: "test-model",
        cost_per_1k_prompt_tokens: 0.001,
        cost_per_1k_completion_tokens: 0.002
      ]

      assert {:ok, %Signal{} = signal} = Telemetry.call(mock_provider_fn, "test prompt", [], opts)

      # Verify metadata additions
      assert is_integer(signal.metadata.latency_ms)
      assert signal.metadata.usage == %{prompt_tokens: 50, completion_tokens: 100, total_tokens: 150}
      assert_in_delta signal.metadata.cost.total_cost, 0.00025, 0.00001

      # Verify telemetry events received
      assert_receive {:telemetry_event, [:lux, :llm, :call, :start], %{system_time: _}, meta_start}
      assert meta_start.prompt == "test prompt"

      assert_receive {:telemetry_event, [:lux, :llm, :call, :stop], measurements_stop, meta_stop}
      assert measurements_stop.prompt_tokens == 50
      assert measurements_stop.completion_tokens == 100
      assert meta_stop.signal == signal
    end

    test "emits exception event on error" do
      mock_error_fn = fn _prompt, _tools, _opts ->
        {:error, {429, "Rate limit"}}
      end

      assert {:error, {429, "Rate limit"}} = Telemetry.call(mock_error_fn, "test prompt", [], model: "test-model")

      assert_receive {:telemetry_event, [:lux, :llm, :call, :start], _, _}
      assert_receive {:telemetry_event, [:lux, :llm, :call, :exception], %{duration: _}, meta_exc}
      assert meta_exc.reason == {429, "Rate limit"}
    end
  end

  describe "instrument/2" do
    test "instruments custom lambda block" do
      fun = fn ->
        {:ok, make_test_signal(%{"prompt_tokens" => 10, "completion_tokens" => 20})}
      end

      assert {:ok, %Signal{} = signal} = Telemetry.instrument(%{provider: :custom, model: "m1"}, fun)
      assert signal.metadata.usage.total_tokens == 30
      assert_receive {:telemetry_event, [:lux, :llm, :call, :stop], _, _}
    end
  end
end
