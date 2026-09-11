defmodule Lux.LLM.EmpiricalChallengerTest do
  use UnitAPICase, async: false

  alias Lux.LLM.ModelConfig
  alias Lux.LLM.ProviderRegistry
  alias Lux.LLM.Router
  alias Lux.LLM.Fallback
  alias Lux.LLM.OpenAI
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

  # Strict provider that raises KeyError if any unknown option is passed to struct!
  defmodule StrictConfig do
    defstruct [:model, :api_key, :endpoint, :temperature, :custom_param]
  end

  defmodule StrictProvider do
    @behaviour Lux.LLM.Provider

    @impl true
    def id, do: :strict_provider

    @impl true
    def models do
      [
        %ModelConfig{
          id: "strict-model-1",
          name: "Strict Model 1",
          provider_id: :strict_provider,
          cost_per_1k_prompt_tokens: 0.001,
          cost_per_1k_completion_tokens: 0.002,
          capabilities: [:tools]
        }
      ]
    end

    @impl true
    def call(prompt, _tools, opts) do
      # This will raise KeyError if opts contains any key not in StrictConfig
      config = struct!(StrictConfig, opts)

      payload = %{
        content: %{"response" => "strict response for #{inspect(prompt)}", "config" => Map.from_struct(config)},
        model: config.model || "strict-model-1",
        finish_reason: "stop",
        tool_calls: nil,
        tool_calls_results: nil
      }

      {:ok, Signal.new(%{schema_id: ResponseSignal, payload: payload, metadata: %{}})}
    end
  end

  setup do
    reg_name = :"challenger_reg_#{System.unique_integer([:positive])}"
    {:ok, _pid} = ProviderRegistry.start_link(name: reg_name, providers: [])

    %{registry_name: reg_name}
  end

  # ===================================================================
  # 1. R1 / AC1 FIX: Null Credential Propagation & Preserving Defaults
  # ===================================================================
  describe "R1 Fix Verification: Null Credential Propagation" do
    test "preserves explicit api_key in opts when provider config in registry has api_key: nil", %{registry_name: reg} do
      ProviderRegistry.register_provider(StrictProvider, registry_name: reg, api_key: nil, endpoint: nil)

      # Call router with explicit api_key
      opts = [
        registry_name: reg,
        provider_id: :strict_provider,
        api_key: "my-explicit-key"
      ]

      assert {:ok, %Signal{} = signal} = Router.call("test prompt", [], opts)
      assert signal.payload.content["config"][:api_key] == "my-explicit-key"
    end

    test "preserves explicit endpoint in opts when provider config in registry has endpoint: nil", %{registry_name: reg} do
      ProviderRegistry.register_provider(StrictProvider, registry_name: reg, api_key: "some-key", endpoint: nil)

      opts = [
        registry_name: reg,
        provider_id: :strict_provider,
        endpoint: "http://custom-proxy:8080/v1"
      ]

      assert {:ok, %Signal{} = signal} = Router.call("test prompt", [], opts)
      assert signal.payload.content["config"][:endpoint] == "http://custom-proxy:8080/v1"
    end

    test "preserves application-level api_key when provider config in registry has api_key: nil", %{registry_name: reg} do
      Req.Test.verify_on_exit!()

      original_keys = Application.get_env(:lux, :api_keys, [])
      Application.put_env(:lux, :api_keys, [openai: "app-env-key-123"])

      on_exit(fn ->
        Application.put_env(:lux, :api_keys, original_keys)
      end)

      # OpenAI registered with api_key: nil (default)
      ProviderRegistry.register_provider(OpenAI, registry_name: reg)

      Req.Test.expect(OpenAI, fn conn ->
        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert ["Bearer app-env-key-123"] = auth_header

        Req.Test.json(conn, %{
          "model" => "gpt-4o",
          "choices" => [%{"message" => %{"content" => ~s({"result": "app_key_ok"})}, "finish_reason" => "stop"}]
        })
      end)

      assert {:ok, %Signal{} = signal} = Router.call("hello", [], registry_name: reg, provider_id: :openai)
      assert signal.payload.content["result"] == "app_key_ok"
    end

    test "when provider config in registry has valid api_key and endpoint, Router propagates them", %{registry_name: reg} do
      ProviderRegistry.register_provider(StrictProvider, registry_name: reg, api_key: "registry-key", endpoint: "http://registry-endpoint:9000")

      opts = [registry_name: reg, provider_id: :strict_provider]

      assert {:ok, %Signal{} = signal} = Router.call("test prompt", [], opts)
      assert signal.payload.content["config"][:api_key] == "registry-key"
      assert signal.payload.content["config"][:endpoint] == "http://registry-endpoint:9000"
    end
  end

  # ===================================================================
  # 2. R2 / AC2 FIX: Filter Control Options in Router & Fallback
  # ===================================================================
  describe "R2 Fix Verification: Control Option Filtering & Edge Cases" do
    test "Router strips all 9 control options before forwarding call_opts to strict provider", %{registry_name: reg} do
      ProviderRegistry.register_provider(StrictProvider, registry_name: reg)

      control_opts = [
        strategy: :cheapest,
        capabilities: [:tools],
        registry_name: reg,
        estimated_prompt_tokens: 1000,
        estimated_completion_tokens: 500,
        provider_id: :strict_provider,
        primary: {Router, []},
        fallbacks: [:openai],
        fallback_on_all_errors: true,
        # non-control option that StrictConfig accepts:
        custom_param: "allowed"
      ]

      assert {:ok, %Signal{} = signal} = Router.call("hello strict", [], control_opts)
      assert signal.payload.model == "strict-model-1"
      assert signal.payload.content["config"][:custom_param] == "allowed"
    end

    test "Fallback.call with primary router spec containing control options works with strict provider", %{registry_name: reg} do
      ProviderRegistry.register_provider(StrictProvider, registry_name: reg)

      control_opts = [
        primary: {Router, [registry_name: reg, provider_id: :strict_provider, strategy: :cheapest]},
        fallbacks: [],
        fallback_on_all_errors: true,
        capabilities: [:tools],
        estimated_prompt_tokens: 250,
        estimated_completion_tokens: 100
      ]

      assert {:ok, %Signal{} = signal} = Fallback.call("hello fallback", [], control_opts)
      assert signal.payload.model == "strict-model-1"
    end

    test "Router handles unusual control option payloads with valid numeric token estimates", %{registry_name: reg} do
      ProviderRegistry.register_provider(StrictProvider, registry_name: reg)

      unusual_opts = [
        registry_name: reg,
        provider_id: :strict_provider,
        strategy: nil,
        capabilities: [],
        estimated_prompt_tokens: -99_999,
        estimated_completion_tokens: 500,
        fallback_on_all_errors: "maybe",
        primary: nil,
        fallbacks: :invalid_list_type
      ]

      assert {:ok, %Signal{} = signal} = Router.call("unusual payload test", [], unusual_opts)
      assert signal.payload.model == "strict-model-1"
    end

    test "Router raises ArithmeticError when non-numeric token estimates are provided", %{registry_name: reg} do
      ProviderRegistry.register_provider(StrictProvider, registry_name: reg)

      invalid_token_opts = [
        registry_name: reg,
        provider_id: :strict_provider,
        strategy: :cheapest,
        estimated_prompt_tokens: 100,
        estimated_completion_tokens: "not_a_number"
      ]

      assert_raise ArithmeticError, fn ->
        Router.call("invalid token type test", [], invalid_token_opts)
      end
    end

    test "Router handles empty options map and keyword list", %{registry_name: reg} do
      ProviderRegistry.register_provider(StrictProvider, registry_name: reg)

      assert {:ok, %Signal{} = sig1} = Router.call("empty list", [], [registry_name: reg])
      assert sig1.payload.model == "strict-model-1"

      assert {:ok, %Signal{} = sig2} = Router.call("empty map", [], %{registry_name: reg})
      assert sig2.payload.model == "strict-model-1"
    end
  end

  # ===================================================================
  # 3. R3 / AC3 FIX: Custom Proxy Endpoint & OpenAI Edge Cases
  # ===================================================================
  describe "R3 Fix Verification: OpenAI Custom Proxy URLs & Endpoint Resolution" do
    test "OpenAI respects dynamic custom proxy URL with port and custom path" do
      Req.Test.verify_on_exit!()

      custom_proxy = "http://127.0.0.1:8089/proxy/v1/chat/completions"

      config = %{
        api_key: "proxy-key",
        model: "gpt-4o",
        endpoint: custom_proxy
      }

      Req.Test.expect(OpenAI, fn conn ->
        assert conn.scheme == :http
        assert conn.host == "127.0.0.1"
        assert conn.port == 8089
        assert conn.request_path == "/proxy/v1/chat/completions"

        Req.Test.json(conn, %{
          "model" => "gpt-4o",
          "choices" => [%{"message" => %{"content" => ~s({"result": "proxy_ok"})}, "finish_reason" => "stop"}]
        })
      end)

      assert {:ok, %Signal{payload: %{content: %{"result" => "proxy_ok"}}}} = OpenAI.call("test prompt", [], config)
    end

    test "OpenAI handles endpoint resolved from {:system, var_name} tuple" do
      Req.Test.verify_on_exit!()

      System.put_env("TEST_OPENAI_PROXY_URL", "http://localhost:9999/system_proxy/chat/completions")

      on_exit(fn ->
        System.delete_env("TEST_OPENAI_PROXY_URL")
      end)

      config = %{
        api_key: "sys-key",
        model: "gpt-4o",
        endpoint: {:system, "TEST_OPENAI_PROXY_URL"}
      }

      Req.Test.expect(OpenAI, fn conn ->
        assert conn.scheme == :http
        assert conn.host == "localhost"
        assert conn.port == 9999
        assert conn.request_path == "/system_proxy/chat/completions"

        Req.Test.json(conn, %{
          "model" => "gpt-4o",
          "choices" => [%{"message" => %{"content" => ~s({"result": "system_env_ok"})}, "finish_reason" => "stop"}]
        })
      end)

      assert {:ok, %Signal{payload: %{content: %{"result" => "system_env_ok"}}}} = OpenAI.call("test prompt", [], config)
    end

    test "OpenAI falls back to default @endpoint when endpoint is nil in config" do
      Req.Test.verify_on_exit!()

      config = %{
        api_key: "default-key",
        model: "gpt-4o",
        endpoint: nil
      }

      Req.Test.expect(OpenAI, fn conn ->
        assert conn.scheme == :https
        assert conn.host == "api.openai.com"
        assert conn.request_path == "/v1/chat/completions"

        Req.Test.json(conn, %{
          "model" => "gpt-4o",
          "choices" => [%{"message" => %{"content" => ~s({"result": "default_endpoint_ok"})}, "finish_reason" => "stop"}]
        })
      end)

      assert {:ok, %Signal{payload: %{content: %{"result" => "default_endpoint_ok"}}}} = OpenAI.call("test prompt", [], config)
    end

    test "OpenAI handles empty options map and keyword list gracefully" do
      Req.Test.verify_on_exit!()

      # With empty opts [], OpenAI uses Application env or defaults
      Req.Test.expect(OpenAI, fn conn ->
        assert conn.scheme == :https
        assert conn.host == "api.openai.com"

        Req.Test.json(conn, %{
          "model" => "gpt-4o",
          "choices" => [%{"message" => %{"content" => ~s({"result": "empty_opts_ok"})}, "finish_reason" => "stop"}]
        })
      end)

      assert {:ok, %Signal{payload: %{content: %{"result" => "empty_opts_ok"}}}} = OpenAI.call("hello", [], [])
    end
  end

  # ===================================================================
  # 4. Fallback.call/3 Comprehensive Edge Cases
  # ===================================================================
  describe "Fallback.call/3 Edge Cases & Options Robustness" do
    test "Fallback.call/3 with empty options defaults to Router primary and empty fallbacks", %{registry_name: reg} do
      ProviderRegistry.register_provider(StrictProvider, registry_name: reg)

      assert {:ok, %Signal{} = signal} = Fallback.call("hello fallback empty", [], [registry_name: reg])
      assert signal.payload.model == "strict-model-1"
    end

    test "Fallback.call/3 with map options vs keyword list options works identically", %{registry_name: reg} do
      ProviderRegistry.register_provider(StrictProvider, registry_name: reg)

      kw_opts = [primary: {Router, [registry_name: reg, provider_id: :strict_provider]}]
      map_opts = %{primary: {Router, %{registry_name: reg, provider_id: :strict_provider}}}

      assert {:ok, %Signal{} = sig1} = Fallback.call("hello kw", [], kw_opts)
      assert {:ok, %Signal{} = sig2} = Fallback.call("hello map", [], map_opts)

      assert sig1.payload.model == "strict-model-1"
      assert sig2.payload.model == "strict-model-1"
    end
  end
end
