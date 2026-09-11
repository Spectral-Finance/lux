defmodule Lux.LLM.RouterTest do
  use UnitAPICase, async: false

  alias Lux.LLM.ModelConfig
  alias Lux.LLM.ProviderRegistry
  alias Lux.LLM.Router
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

  defmodule MockProvider do
    @behaviour Lux.LLM.Provider

    @impl true
    def id, do: :mock_provider

    @impl true
    def models do
      [
        %ModelConfig{
          id: "cheap-model",
          name: "Cheap Model",
          provider_id: :mock_provider,
          cost_per_1k_prompt_tokens: 0.0001,
          cost_per_1k_completion_tokens: 0.0002,
          capabilities: [:tools, :json_schema],
          context_window: 32_000
        },
        %ModelConfig{
          id: "smart-model",
          name: "Smart Model",
          provider_id: :mock_provider,
          cost_per_1k_prompt_tokens: 0.01,
          cost_per_1k_completion_tokens: 0.03,
          capabilities: [:tools, :json_schema, :vision, :reasoning],
          context_window: 200_000
        }
      ]
    end

    @impl true
    def call(prompt, _tools, opts) do
      model = Map.get(opts, :model, "cheap-model")

      payload = %{
        content: %{"response" => "mocked answer for #{prompt}"},
        model: model,
        finish_reason: "stop",
        tool_calls: nil,
        tool_calls_results: nil
      }

      signal =
        %{schema_id: ResponseSignal, payload: payload, metadata: %{usage: %{prompt_tokens: 10, completion_tokens: 20}}}
        |> Lux.Signal.new()

      {:ok, signal}
    end
  end

  defmodule VisionOnlyProvider do
    @behaviour Lux.LLM.Provider

    @impl true
    def id, do: :vision_provider

    @impl true
    def models do
      [
        %ModelConfig{
          id: "vision-model",
          name: "Vision Model",
          provider_id: :vision_provider,
          cost_per_1k_prompt_tokens: 0.005,
          cost_per_1k_completion_tokens: 0.015,
          capabilities: [:vision],
          context_window: 128_000
        }
      ]
    end

    @impl true
    def call(_prompt, _tools, opts) do
      payload = %{
        content: %{"response" => "vision answer"},
        model: Map.get(opts, :model, "vision-model"),
        finish_reason: "stop",
        tool_calls: nil,
        tool_calls_results: nil
      }

      {:ok, Lux.Signal.new(%{schema_id: ResponseSignal, payload: payload, metadata: %{}})}
    end
  end

  defmodule StrictConfig do
    defstruct [:model, :api_key, :endpoint]
  end

  defmodule StrictProvider do
    @behaviour Lux.LLM.Provider

    @impl true
    def id, do: :strict_provider

    @impl true
    def models do
      [
        %ModelConfig{
          id: "strict-model",
          name: "Strict Model",
          provider_id: :strict_provider,
          cost_per_1k_prompt_tokens: 0.001,
          cost_per_1k_completion_tokens: 0.002
        }
      ]
    end

    @impl true
    def call(prompt, _tools, opts) do
      _config = struct!(StrictConfig, opts)

      payload = %{
        content: %{"response" => "strict response for #{prompt}"},
        model: "strict-model",
        finish_reason: "stop",
        tool_calls: nil,
        tool_calls_results: nil
      }

      {:ok, Lux.Signal.new(%{schema_id: ResponseSignal, payload: payload, metadata: %{}})}
    end
  end

  setup do
    registry_name = :"router_test_registry_#{System.unique_integer([:positive])}"
    {:ok, _pid} = ProviderRegistry.start_link(name: registry_name, providers: [])

    ProviderRegistry.register_provider(MockProvider, registry_name: registry_name)
    ProviderRegistry.register_provider(VisionOnlyProvider, registry_name: registry_name)
    ProviderRegistry.register_provider(StrictProvider, registry_name: registry_name)

    %{registry_name: registry_name}
  end

  describe "route/3 strategies" do
    test "selects cheapest model by default or with :cheapest strategy", %{registry_name: reg} do
      assert {:ok, {_prov, model}} = Router.route("hello", [], registry_name: reg, strategy: :cheapest)
      assert model.id == "cheap-model"
    end

    test "selects smartest model with :smartest strategy", %{registry_name: reg} do
      assert {:ok, {_prov, model}} = Router.route("hello", [], registry_name: reg, strategy: :smartest)
      assert model.id == "smart-model"
    end

    test "supports custom function strategy", %{registry_name: reg} do
      custom_strategy = fn model -> -model.context_window end
      assert {:ok, {_prov, model}} = Router.route("hello", [], registry_name: reg, strategy: custom_strategy)
      assert model.id == "smart-model"
    end
  end

  describe "route/3 capability filtering" do
    test "filters models by required capabilities", %{registry_name: reg} do
      assert {:ok, {_prov, model}} = Router.route("hello", [], registry_name: reg, capabilities: [:reasoning])
      assert model.id == "smart-model"
    end

    test "auto-infers :tools capability when tools are provided", %{registry_name: reg} do
      # VisionOnlyProvider does not have :tools capability
      assert {:ok, {prov, _model}} = Router.route("hello", [:some_tool], registry_name: reg)
      assert prov.id == :mock_provider
    end

    test "returns error when no model satisfies capability requirements", %{registry_name: reg} do
      assert {:error, :no_matching_model} = Router.route("hello", [], registry_name: reg, capabilities: [:non_existent_cap])
    end
  end

  describe "route/3 provider & model filtering" do
    test "filters by provider_id", %{registry_name: reg} do
      assert {:ok, {prov, model}} = Router.route("hello", [], registry_name: reg, provider_id: :vision_provider)
      assert prov.id == :vision_provider
      assert model.id == "vision-model"
    end

    test "filters by model ID string", %{registry_name: reg} do
      assert {:ok, {_prov, model}} = Router.route("hello", [], registry_name: reg, model: "smart-model")
      assert model.id == "smart-model"
    end
  end

  describe "calculate_cost/3" do
    test "calculates prompt and completion costs correctly" do
      model = %ModelConfig{
        id: "test",
        name: "Test",
        provider_id: :test,
        cost_per_1k_prompt_tokens: 0.002,
        cost_per_1k_completion_tokens: 0.006
      }

      # 2000 prompt tokens = 2 * 0.002 = 0.004
      # 1000 completion tokens = 1 * 0.006 = 0.006
      # total = 0.010
      cost = Router.calculate_cost(model, 2000, 1000)
      assert_in_delta cost, 0.010, 0.00001
    end
  end

  describe "call/3" do
    test "routes and invokes provider successfully", %{registry_name: reg} do
      assert {:ok, %Signal{} = signal} = Router.call("test prompt", [], registry_name: reg, strategy: :smartest)
      assert signal.payload.model == "smart-model"
      assert signal.payload.content["response"] == "mocked answer for test prompt"
    end
  end

  describe "route/3 with unstarted registry" do
    test "returns {:error, :registry_not_running} when registry GenServer is not running" do
      unstarted_reg = :"unstarted_registry_#{System.unique_integer([:positive])}"
      assert {:error, :registry_not_running} = Router.route("hello", [], registry_name: unstarted_reg)
      assert {:error, :registry_not_running} = Router.call("hello", [], registry_name: unstarted_reg)
    end
  end

  describe "AC1: null credential propagation" do
    test "preserves application-level api_key when using default provider registry with nil credentials" do
      Req.Test.verify_on_exit!()

      original_keys = Application.get_env(:lux, :api_keys, [])
      Application.put_env(:lux, :api_keys, [openai: "test-app-level-key"])

      on_exit(fn ->
        Application.put_env(:lux, :api_keys, original_keys)
      end)

      reg_name = :"ac1_registry_#{System.unique_integer([:positive])}"
      {:ok, _pid} = ProviderRegistry.start_link(name: reg_name, providers: [Lux.LLM.OpenAI])

      Req.Test.expect(Lux.LLM.OpenAI, fn conn ->
        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert ["Bearer test-app-level-key"] = auth_header

        Req.Test.json(conn, %{
          "model" => "gpt-4o",
          "choices" => [
            %{
              "message" => %{"content" => ~s({"result": "ok"})},
              "finish_reason" => "stop"
            }
          ]
        })
      end)

      assert {:ok, %Signal{}} = Router.call("hello", [], registry_name: reg_name, provider_id: :openai)
    end
  end

  describe "AC2: filter control options in Router" do
    test "passes control options to Router.call with strict provider without raising KeyError", %{registry_name: reg} do
      control_opts = [
        strategy: :cheapest,
        capabilities: [],
        registry_name: reg,
        estimated_prompt_tokens: 1000,
        estimated_completion_tokens: 500,
        provider_id: :strict_provider,
        primary: nil,
        fallbacks: [],
        fallback_on_all_errors: false
      ]

      assert {:ok, %Signal{} = signal} = Router.call("hello", [], control_opts)
      assert signal.payload.model == "strict-model"
      assert signal.payload.content["response"] == "strict response for hello"
    end

    test "passes control options to Router.call with OpenAI provider without raising KeyError" do
      Req.Test.verify_on_exit!()

      reg_name = :"ac2_openai_router_test_#{System.unique_integer([:positive])}"
      {:ok, _pid} = ProviderRegistry.start_link(name: reg_name, providers: [Lux.LLM.OpenAI])

      Req.Test.expect(Lux.LLM.OpenAI, fn conn ->
        Req.Test.json(conn, %{
          "model" => "gpt-4o",
          "choices" => [
            %{
              "message" => %{"content" => ~s({"result": "ok"})},
              "finish_reason" => "stop"
            }
          ]
        })
      end)

      control_opts = [
        strategy: :smartest,
        capabilities: [:tools],
        registry_name: reg_name,
        estimated_prompt_tokens: 2000,
        estimated_completion_tokens: 1000,
        provider_id: :openai,
        fallback_on_all_errors: true
      ]

      assert {:ok, %Signal{}} = Router.call("hello", [], control_opts)
    end
  end

  describe "select_model/2" do
    test "selects cheapest model by default", %{registry_name: reg} do
      assert {:ok, {_prov, model}} = Router.select_model(:cheapest, registry_name: reg)
      assert model.id == "cheap-model"
    end

    test "selects smartest model with :smartest criteria", %{registry_name: reg} do
      assert {:ok, {_prov, model}} = Router.select_model(:smartest, registry_name: reg)
      assert model.id == "smart-model"
    end

    test "selects model with map criteria matching capabilities", %{registry_name: reg} do
      assert {:ok, {_prov, model}} = Router.select_model(%{capabilities: [:reasoning]}, registry_name: reg)
      assert model.id == "smart-model"
    end
  end
end
