defmodule Lux.LLM.ProviderTest do
  @moduledoc """
  Tests for the Lux.LLM.Provider behaviour compliance and contract validation.
  """

  use ExUnit.Case, async: true

  alias Lux.LLM.Provider

  # Mock provider for testing behaviour compliance
  defmodule MockProvider do
    @behaviour Lux.LLM.Provider

    @impl true
    def name, do: :mock_provider

    @impl true
    def default_config do
      %{
        name: :mock_provider,
        api_key: nil,
        base_url: "https://api.mock.com",
        timeout: 30_000,
        max_retries: 3,
        models: [
          %{
            id: "mock-model-1",
            name: "Mock Model 1",
            capabilities: [:chat, :completion],
            context_window: 4096,
            max_output_tokens: 2048,
            cost_per_input_token: 0.001,
            cost_per_output_token: 0.002,
            supports_streaming: true,
            supports_functions: false,
            supports_vision: false
          }
        ],
        metadata: %{}
      }
    end

    @impl true
    def validate_config(config) do
      if is_map(config) do
        {:ok, config}
      else
        {:error, :invalid_config}
      end
    end

    @impl true
    def complete(request, _config) do
      {:ok,
       %{
         id: "mock-response-1",
         provider: :mock_provider,
         model: request.model || "mock-model-1",
         choices: [
           %{
             index: 0,
             message: %{role: :assistant, content: "Mock response", name: nil, function_call: nil},
             finish_reason: :stop
           }
         ],
         usage: %{
           prompt_tokens: 10,
           completion_tokens: 5,
           total_tokens: 15
         },
         created_at: DateTime.utc_now(),
         metadata: %{}
       }}
    end

    @impl true
    def stream(request, config) do
      complete(request, config)
    end

    @impl true
    def list_models(_config) do
      {:ok,
       [
         %{
           id: "mock-model-1",
           name: "Mock Model 1",
           capabilities: [:chat, :completion],
           context_window: 4096,
           max_output_tokens: 2048,
           cost_per_input_token: 0.001,
           cost_per_output_token: 0.002,
           supports_streaming: true,
           supports_functions: false,
           supports_vision: false
         }
       ]}
    end

    @impl true
    def model_info(model_id, _config) do
      if model_id == "mock-model-1" do
        {:ok,
         %{
           id: "mock-model-1",
           name: "Mock Model 1",
           capabilities: [:chat, :completion],
           context_window: 4096,
           max_output_tokens: 2048,
           cost_per_input_token: 0.001,
           cost_per_output_token: 0.002,
           supports_streaming: true,
           supports_functions: false,
           supports_vision: false
         }}
      else
        {:error, :model_not_found}
      end
    end

    @impl true
    def health_check(_config) do
      {:ok, %{status: :healthy, latency_ms: 10}}
    end
  end

  describe "behaviour compliance" do
    test "MockProvider implements all required callbacks" do
      assert function_exported?(MockProvider, :name, 0)
      assert function_exported?(MockProvider, :default_config, 0)
      assert function_exported?(MockProvider, :validate_config, 1)
      assert function_exported?(MockProvider, :complete, 2)
      assert function_exported?(MockProvider, :stream, 2)
      assert function_exported?(MockProvider, :list_models, 1)
      assert function_exported?(MockProvider, :model_info, 2)
      assert function_exported?(MockProvider, :health_check, 1)
    end
  end

  describe "name/0" do
    test "returns the provider name as an atom" do
      assert MockProvider.name() == :mock_provider
    end
  end

  describe "default_config/0" do
    test "returns a valid provider config map" do
      config = MockProvider.default_config()

      assert is_map(config)
      assert Map.has_key?(config, :name)
      assert Map.has_key?(config, :base_url)
      assert Map.has_key?(config, :timeout)
      assert Map.has_key?(config, :max_retries)
      assert Map.has_key?(config, :models)
      assert Map.has_key?(config, :metadata)
    end

    test "config contains valid model configurations" do
      config = MockProvider.default_config()

      assert is_list(config.models)
      assert length(config.models) > 0

      [model | _] = config.models
      assert Map.has_key?(model, :id)
      assert Map.has_key?(model, :name)
      assert Map.has_key?(model, :capabilities)
      assert Map.has_key?(model, :context_window)
      assert Map.has_key?(model, :max_output_tokens)
    end
  end

  describe "validate_config/1" do
    test "returns :ok for valid config" do
      config = MockProvider.default_config()
      assert {:ok, ^}config} = MockProvider.validate_config(config)
    end

    test "returns :error for invalid config" do
      assert {:error, :invalid_config} = MockProvider.validate_config("invalid")
    end
  end

  describe "complete/2" do
    test "returns a valid completion response" do
      request = %{
        messages: [%{role: :user, content: "Hello", name: nil, function_call: nil}],
        model: "mock-model-1",
        temperature: 0.7,
        max_tokens: 100,
        stream: false,
        functions: nil,
        function_call: nil,
        stop: nil,
        metadata: %{}
      }

      config = MockProvider.default_config()

      assert {:ok, response} = MockProvider.complete(request, config)
      assert Map.has_key?(response, :id)
      assert Map.has_key?(response, :provider)
      assert Map.has_key?(response, :model)
      assert Map.has_key?(response, :choices)
      assert Map.has_key?(response, :usage)
      assert Map.has_key?(response, :created_at)
    end

    test "response contains valid choices" do
      request = %{
        messages: [%{role: :user, content: "Hello", name: nil, function_call: nil}],
        model: "mock-model-1",
        temperature: 0.7,
        max_tokens: 100,
        stream: false,
        functions: nil,
        function_call: nil,
        stop: nil,
        metadata: %{}
      }

      config = MockProvider.default_config()

      {:ok, response} = MockProvider.complete(request, config)

      assert is_list(response.choices)
      assert length(response.choices) > 0

      [choice | _] = response.choices
      assert Map.has_key?(choice, :index)
      assert Map.has_key?(choice, :message)
      assert Map.has_key?(choice, :finish_reason)
    end

    test "response contains valid usage info" do
      request = %{
        messages: [%{role: :user, content: "Hello", name: nil, function_call: nil}],
        model: "mock-model-1",
        temperature: 0.7,
        max_tokens: 100,
        stream: false,
        functions: nil,
        function_call: nil,
        stop: nil,
        metadata: %{}
      }

      config = MockProvider.default_config()

      {:ok, response} = MockProvider.complete(request, config)

      assert is_map(response.usage)
      assert Map.has_key?(response.usage, :prompt_tokens)
      assert Map.has_key?(response.usage, :completion_tokens)
      assert Map.has_key?(response.usage, :total_tokens)
    end
  end

  describe "list_models/1" do
    test "returns a list of model configurations" do
      config = MockProvider.default_config()

      assert {:ok, models} = MockProvider.list_models(config)
      assert is_list(models)
      assert length(models) > 0
    end
  end

  describe "model_info/2" do
    test "returns model info for a valid model id" do
      config = MockProvider.default_config()

      assert {:ok, model} = MockProvider.model_info("mock-model-1", config)
      assert model.id == "mock-model-1"
    end

    test "returns error for unknown model id" do
      config = MockProvider.default_config()

      assert {:error, :model_not_found} = MockProvider.model_info("unknown-model", config)
    end
  end

  describe "health_check/1" do
    test "returns health status" do
      config = MockProvider.default_config()

      assert {:ok, health} = MockProvider.health_check(config)
      assert Map.has_key?(health, :status)
      assert health.status == :healthy
    end
  end

  describe "Provider helper functions" do
    test "Provider.ensure_implemented/1 validates behaviour implementation" do
      # This should not raise for a valid provider
      assert :ok = Provider.ensure_implemented(MockProvider)
    end

    test "Provider.ensure_implemented/1 returns error for non-provider module" do
      assert {:error, _} = Provider.ensure_implemented(Enum)
    end
  end
end