defmodule Lux.LLM.StressTest do
  use UnitAPICase, async: false

  alias Lux.LLM.ModelConfig
  alias Lux.LLM.ProviderRegistry
  alias Lux.LLM.Router
  alias Lux.LLM.Fallback
  alias Lux.LLM.Telemetry
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

  defmodule SuccessProvider do
    @behaviour Lux.LLM.Provider
    @impl true
    def id, do: :success_provider
    @impl true
    def models do
      [
        %ModelConfig{
          id: "success-model",
          name: "Success Model",
          provider_id: :success_provider,
          cost_per_1k_prompt_tokens: 0.002,
          cost_per_1k_completion_tokens: 0.004,
          capabilities: [:tools, :vision],
          context_window: 100_000
        }
      ]
    end
    @impl true
    def call(prompt, _tools, opts) do
      payload = %{
        content: %{"answer" => "ok: #{prompt}"},
        model: Map.get(opts, :model, "success-model"),
        finish_reason: "stop",
        tool_calls: nil,
        tool_calls_results: nil
      }
      {:ok, Signal.new(%{schema_id: ResponseSignal, payload: payload, metadata: %{usage: %{prompt_tokens: 100, completion_tokens: 200}}})}
    end
  end

  defmodule ErrorProvider do
    @behaviour Lux.LLM.Provider
    @impl true
    def id, do: :error_provider
    @impl true
    def models do
      [
        %ModelConfig{
          id: "error-model",
          name: "Error Model",
          provider_id: :error_provider,
          cost_per_1k_prompt_tokens: 0.001,
          cost_per_1k_completion_tokens: 0.001,
          capabilities: [:tools],
          context_window: 50_000
        }
      ]
    end
    @impl true
    def call(_prompt, _tools, opts) do
      err = Map.get(opts, :inject_error, {429, "Rate limit"})
      {:error, err}
    end
  end

  defp make_signal(model_name, usage \\ %{prompt_tokens: 10, completion_tokens: 20}) do
    payload = %{
      content: %{"answer" => "response from #{model_name}"},
      model: model_name,
      finish_reason: "stop",
      tool_calls: nil,
      tool_calls_results: nil
    }
    Signal.new(%{schema_id: ResponseSignal, payload: payload, metadata: %{usage: usage}})
  end

  # ==========================================
  # ROUTER EMPIRICAL TESTS
  # ==========================================
  describe "Router Empirical Edge Cases" do
    test "1.1 Empty provider registry" do
      reg = :"empty_reg_#{System.unique_integer([:positive])}"
      {:ok, _pid} = ProviderRegistry.start_link(name: reg, providers: [])

      assert {:error, :no_matching_model} = Router.route("hello", [], registry_name: reg)
      assert {:error, :no_matching_model} = Router.call("hello", [], registry_name: reg)
    end

    test "1.2 Non-existent / unstarted provider registry" do
      reg = :"non_existent_reg_#{System.unique_integer([:positive])}"

      assert {:error, :registry_not_running} = Router.route("hello", [], registry_name: reg)
    end

    test "1.3 No matching model candidates" do
      reg = :"router_reg_#{System.unique_integer([:positive])}"
      {:ok, _pid} = ProviderRegistry.start_link(name: reg, providers: [])
      ProviderRegistry.register_provider(SuccessProvider, registry_name: reg)

      # Unmatched capability
      assert {:error, :no_matching_model} = Router.route("hello", [], registry_name: reg, capabilities: [:non_existent_capability])

      # Unmatched provider ID
      assert {:error, :no_matching_model} = Router.route("hello", [], registry_name: reg, provider_id: :unknown_provider)

      # Unmatched model ID string
      assert {:error, :no_matching_model} = Router.route("hello", [], registry_name: reg, model: "non-existent-model")
    end

    test "1.4 Model in list_models but provider un-registered before get_provider" do
      reg = :"unreg_prov_#{System.unique_integer([:positive])}"
      {:ok, _pid} = ProviderRegistry.start_link(name: reg, providers: [])
      ProviderRegistry.register_provider(SuccessProvider, registry_name: reg)

      # Unregister provider right before routing get_provider
      ProviderRegistry.unregister_provider(:success_provider, registry_name: reg)

      assert {:error, :no_matching_model} = Router.route("hello", [], registry_name: reg)
    end

    test "1.5 Invalid strategies" do
      reg = :"strategy_reg_#{System.unique_integer([:positive])}"
      {:ok, _pid} = ProviderRegistry.start_link(name: reg, providers: [])
      ProviderRegistry.register_provider(SuccessProvider, registry_name: reg)

      # Unknown atom strategy falls back to :cheapest
      assert {:ok, {_prov, model}} = Router.route("hello", [], registry_name: reg, strategy: :invalid_strategy)
      assert model.id == "success-model"

      # Non-atom / non-function strategy falls back to :cheapest
      assert {:ok, {_prov, model}} = Router.route("hello", [], registry_name: reg, strategy: 12_345)
      assert model.id == "success-model"

      # Function with 2 arity (invalid for select_candidate) falls back to :cheapest
      two_arity_fun = fn _a, _b -> 0 end
      assert {:ok, {_prov, model}} = Router.route("hello", [], registry_name: reg, strategy: two_arity_fun)
      assert model.id == "success-model"

      # Function with 1 arity that raises exception
      raising_fun = fn _model -> raise "strategy error" end
      assert_raise RuntimeError, "strategy error", fn ->
        Router.route("hello", [], registry_name: reg, strategy: raising_fun)
      end
    end
  end

  # ==========================================
  # FALLBACK EMPIRICAL TESTS
  # ==========================================
  describe "Fallback Empirical Progression & Error Handling" do
    test "2.1 Exhausting all fallbacks" do
      spec1 = fn _p, _t -> {:error, {429, "Rate limit 1"}} end
      spec2 = fn _p, _t -> {:error, {503, "Unavailable 2"}} end
      spec3 = fn _p, _t -> {:error, :econnrefused} end

      res = Fallback.call("hello", [], primary: spec1, fallbacks: [spec2, spec3])
      assert {:error, {:all_fallbacks_failed, history}} = res
      assert length(history) == 3
      assert Enum.map(history, & &1.error) == [{429, "Rate limit 1"}, {503, "Unavailable 2"}, :econnrefused]
    end

    test "2.2 Non-fallbackable error behavior in primary vs intermediate fallback vs final fallback" do
      # Primary fails with non-fallbackable error -> stops immediately
      spec_non_retry = fn _p, _t -> {:error, :invalid_api_key} end
      spec_ok = fn _p, _t -> {:ok, make_signal("fallback")} end

      assert {:error, :invalid_api_key} = Fallback.call("hello", [], primary: spec_non_retry, fallbacks: [spec_ok])

      # Primary 429, Intermediate Fallback non-retryable -> stops immediately, does not call final fallback
      spec_429 = fn _p, _t -> {:error, {429, "Rate limit"}} end
      spec_final = fn _p, _t -> {:ok, make_signal("final")} end

      assert {:error, :invalid_api_key} = Fallback.call("hello", [], primary: spec_429, fallbacks: [spec_non_retry, spec_final])

      # With fallback_on_all_errors: true, continues past non-retryable error
      assert {:ok, signal} = Fallback.call("hello", [], primary: spec_non_retry, fallbacks: [spec_ok], fallback_on_all_errors: true)
      assert signal.payload.model == "fallback"

      # BEHAVIOR CHECK: When the LAST fallback in the list fails with a non-fallbackable error,
      # Fallback returns {:error, {:all_fallbacks_failed, history}} instead of {:error, :invalid_api_key}.
      res_last = Fallback.call("hello", [], primary: spec_429, fallbacks: [spec_non_retry])
      assert {:error, {:all_fallbacks_failed, history}} = res_last
      assert length(history) == 2
    end

    test "2.3 Malformed & diverse error structures in fallback_error?/2" do
      # Atoms
      assert Fallback.fallback_error?(:econnrefused)
      assert Fallback.fallback_error?(:timeout)
      assert Fallback.fallback_error?(:closed)
      assert Fallback.fallback_error?(:rate_limit)
      assert Fallback.fallback_error?(:too_many_requests)
      assert Fallback.fallback_error?(:service_unavailable)
      assert Fallback.fallback_error?(:connect_timeout)

      # Integers
      assert Fallback.fallback_error?(408)
      assert Fallback.fallback_error?(429)
      assert Fallback.fallback_error?(500)
      assert Fallback.fallback_error?(502)
      assert Fallback.fallback_error?(503)
      assert Fallback.fallback_error?(504)
      assert Fallback.fallback_error?(507)
      assert Fallback.fallback_error?(529)
      refute Fallback.fallback_error?(400)
      refute Fallback.fallback_error?(401)
      refute Fallback.fallback_error?(404)

      # Tuples
      assert Fallback.fallback_error?({429, "Too many requests"})
      assert Fallback.fallback_error?({503, "Service unavailable"})
      assert Fallback.fallback_error?({:error, {429, "Rate limit"}}) # Nested tuple
      refute Fallback.fallback_error?({400, "Bad request"})
      refute Fallback.fallback_error?({})

      # Strings
      assert Fallback.fallback_error?("Error 429: Too Many Requests")
      assert Fallback.fallback_error?("HTTP 503 Service Unavailable")
      assert Fallback.fallback_error?("rate limit exceeded")
      assert Fallback.fallback_error?("server overloaded")
      assert Fallback.fallback_error?("connection refused")
      refute Fallback.fallback_error?("Invalid API Key")
      refute Fallback.fallback_error?("Bad Request 400")

      # Structs
      assert Fallback.fallback_error?(%Req.TransportError{reason: :econnrefused})
      refute Fallback.fallback_error?(%RuntimeError{message: "429 Rate limit"}) # Struct not in white-list
      refute Fallback.fallback_error?(%ArgumentError{message: "connection refused"})
    end
  end

  # ==========================================
  # TELEMETRY EMPIRICAL TESTS
  # ==========================================
  describe "Telemetry Event Generation & Cost Calculations" do
    setup do
      test_pid = self()
      handler_id = "stress-telemetry-handler-#{System.unique_integer([:positive])}"
      events = [
        [:lux, :llm, :call, :start],
        [:lux, :llm, :call, :stop],
        [:lux, :llm, :call, :exception]
      ]
      :telemetry.attach_many(handler_id, events, fn name, meas, meta, _ ->
        send(test_pid, {:telemetry_event, name, meas, meta})
      end, nil)

      on_exit(fn -> :telemetry.detach(handler_id) end)
      :ok
    end

    test "3.1 Telemetry events on success" do
      provider_fn = fn _p, _t, _o -> {:ok, make_signal("m1", %{prompt_tokens: 500, completion_tokens: 1000})} end

      opts = [model: "m1", cost_per_1k_prompt_tokens: 0.002, cost_per_1k_completion_tokens: 0.004]
      {:ok, signal} = Telemetry.call(provider_fn, "prompt1", [], opts)

      assert_receive {:telemetry_event, [:lux, :llm, :call, :start], %{system_time: _}, meta_start}
      assert meta_start.prompt == "prompt1"

      assert_receive {:telemetry_event, [:lux, :llm, :call, :stop], meas_stop, meta_stop}
      assert meas_stop.prompt_tokens == 500
      assert meas_stop.completion_tokens == 1000
      # 500/1000 * 0.002 = 0.001, 1000/1000 * 0.004 = 0.004 -> total 0.005
      assert_in_delta meas_stop.total_cost, 0.005, 0.00001
      assert meta_stop.signal == signal
    end

    test "3.2 Telemetry events on error" do
      provider_fn = fn _p, _t, _o -> {:error, {503, "Overloaded"}} end

      assert {:error, {503, "Overloaded"}} = Telemetry.call(provider_fn, "prompt1", [], model: "m1")

      assert_receive {:telemetry_event, [:lux, :llm, :call, :start], _, _}
      assert_receive {:telemetry_event, [:lux, :llm, :call, :exception], meas_exc, meta_exc}
      assert is_integer(meas_exc.duration_ms)
      assert meta_exc.reason == {503, "Overloaded"}
    end

    test "3.3 Instrument with lambda raising exception vs return error" do
      # Lambda returning error
      err_lambda = fn -> {:error, :bad_input} end
      assert {:error, :bad_input} = Telemetry.instrument(%{provider: :p1}, err_lambda)
      assert_receive {:telemetry_event, [:lux, :llm, :call, :exception], _, meta_exc}
      assert meta_exc.reason == :bad_input

      # Lambda raising exception
      raise_lambda = fn -> raise "crash!" end
      assert_raise RuntimeError, "crash!", fn ->
        Telemetry.instrument(%{provider: :p1}, raise_lambda)
      end
      assert_receive {:telemetry_event, [:lux, :llm, :call, :exception], _, meta_exc_raise}
      assert meta_exc_raise.kind == :error
      assert %RuntimeError{message: "crash!"} = meta_exc_raise.reason
    end

    test "3.4 Usage normalization with string values vs missing keys vs invalid input" do
      # Normal integer map
      assert Telemetry.normalize_usage(%{prompt_tokens: 10, completion_tokens: 20}) == %{prompt_tokens: 10, completion_tokens: 20, total_tokens: 30}

      # Non-map input
      assert Telemetry.normalize_usage(nil) == %{prompt_tokens: 0, completion_tokens: 0, total_tokens: 0}
      assert Telemetry.normalize_usage(123) == %{prompt_tokens: 0, completion_tokens: 0, total_tokens: 0}

      # String values in usage map are parsed safely into integers without raising ArithmeticError
      str_usage = %{"prompt_tokens" => "100", "completion_tokens" => "200"}
      assert Telemetry.normalize_usage(str_usage) == %{prompt_tokens: 100, completion_tokens: 200, total_tokens: 300}
    end

    test "3.5 Lookup model pricing when registry is missing or model not found" do
      # Registry missing
      res_no_reg = Telemetry.calculate_cost(:p1, "m1", 1000, 1000, registry_name: :non_existent_reg)
      assert res_no_reg.total_cost == 0.0

      # Model not found in active registry
      reg = :"telemetry_reg_#{System.unique_integer([:positive])}"
      {:ok, _pid} = ProviderRegistry.start_link(name: reg, providers: [])
      res_unreg = Telemetry.calculate_cost(:p1, "m1", 1000, 1000, registry_name: reg)
      assert res_unreg.total_cost == 0.0
    end
  end
end
