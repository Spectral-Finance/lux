defmodule Lux.LLM.Providers.OpenAITest do
  @moduledoc """
  Tests for the Lux.LLM.Providers.OpenAI provider.

  Verifies:
  - Behaviour compliance
  - API request formatting
  - Response parsing
  - Streaming support
  - Error handling
  - Model listing and capabilities
  """

  use ExUnit.Case, async: true

  alias Lux.LLM.Providers.OpenAI

  describe "name/0" do
    test "returns :openai" do
      assert OpenAI.name() == :openai
    end
  end

  describe "default_config/0" do
    test "returns valid configuration structure" do
      config = OpenAI.default_config()

      assert is_map(config)
      assert config.name == :openai
      assert config.base_url == "https://api.openai.com/v1"
      assert is_integer(config.timeout)
      assert config.timeout > 0
      assert is_integer(config.max_retries)
      assert is_list(config.models)
      assert length(config.models) > 0
    end

    test "includes expected models" do
      config = OpenAI.default_config()
      model_ids = Enum.map(config.models, & &1.id)

      assert "gpt-4-turbo" in model_ids
      assert "gpt-4" in model_ids
      assert "gpt-3.5-turbo" in model_ids
    end

    test "all models have required fields" do
      config = OpenAI.default_config()

      for model <- config.models do
        assert is_binary(model.id)
        assert is_binary(model.name)
        assert is_list(model.capabilities)
        assert is_integer(model.context_window)
        assert is_integer(model.max_output_tokens)
        assert is_float(model.cost_per_input_token) or is_integer(model.cost_per_input_token)
        assert is_float(model.cost_per_output_token) or is_integer(model.cost_per_output_token)
        assert is_boolean(model.supports_streaming)
        assert is_boolean(model.supports_functions)
        assert is_boolean(model.supports_vision)
      end
    end
  end

  describe "validate_config/1" do
    test "succeeds with valid config" do
      config = %{OpenAI.default_config() | api_key: "sk-test-key-123"}
      assert {:ok, ^~config} = OpenAI.validate_config(config)
    end

    test "fails without api_key" do
      config = %{OpenAI.default_config() | api_key: nil}
      assert {:error, reason} = OpenAI.validate_config(config)
      assert reason =~ "api_key" or is_atom(reason)
    end

    test "fails with empty api_key" do
      config = %{OpenAI.default_config() | api_key: ""}
      assert {:error, _reason} = OpenAI.validate_config(config)
    end

    test "fails with invalid timeout" do
      config = %{OpenAI.default_config() | api_key: "sk-test", timeout: -1}
      assert {:error, _reason} = OpenAI.validate_config(config)
    end
  end

  describe "list_models/1" do
    test "returns all models from config" do
      config = %{OpenAI.default_config() | api_key: "sk-test"}
      assert {:ok, models} = OpenAI.list_models(config)
      assert is_list(models)
      assert length(models) > 0
    end
  end

  describe "get_model/2" do
    test "returns model when found" do
      config = %{OpenAI.default_config() | api_key: "sk-test"}
      assert {:ok, model} = OpenAI.get_model("gpt-4-turbo", config)
      assert model.id == "gpt-4-turbo"
    end

    test "returns error for unknown model" do
      config = %{OpenAI.default_config() | api_key: "sk-test"}
      assert {:error, :model_not_found} = OpenAI.get_model("unknown-model", config)
    end
  end

  describe "supports_capability?/3" do
    test "returns true for supported capability" do
      config = %{OpenAI.default_config() | api_key: "sk-test"}
      assert OpenAI.supports_capability?("gpt-4-turbo", :chat, config)
      assert OpenAI.supports_capability?("gpt-4-turbo", :function_calling, config)
    end

    test "returns false for unsupported capability" do
      config = %{OpenAI.default_config() | api_key: "sk-test"}
      # gpt-3.5-turbo typically doesn't support vision
      refute OpenAI.supports_capability?("gpt-3.5-turbo", :vision, config)
    end

    test "returns false for unknown model" do
      config = %{OpenAI.default_config() | api_key: "sk-test"}
      refute OpenAI.supports_capability?("unknown-model", :chat, config)
    end
  end

  describe "build_request/2" do
    setup do
      config = %{OpenAI.default_config() | api_key: "sk-test-key-123"}

      request = %{
        messages: [
          %{role: :system, content: "You are a helpful assistant.", name: nil, function_call: nil},
          %{role: :user, content: "Hello!", name: nil, function_call: nil}
        ],
        model: "gpt-4-turbo",
        temperature: 0.7,
        max_tokens: 1000,
        stream: false,
        functions: nil,
        function_call: nil,
        stop: nil,
        metadata: %{}
      }

      {:ok, %{config: config, request: request}}
    end

    test "builds valid HTTP request", %{config: config, request: request} do
      assert {:ok, http_request} = OpenAI.build_request(request, config)

      assert is_binary(http_request.url)
      assert http_request.url =~ "chat/completions"
      assert http_request.method == :post
      assert is_map(http_request.headers)
      assert is_map(http_request.body)
    end

    test "includes authorization header", %{config: config, request: request} do
      assert {:ok, http_request} = OpenAI.build_request(request, config)

      assert http_request.headers["Authorization"] == "Bearer sk-test-key-123"
      assert http_request.headers["Content-Type"] == "application/json"
    end

    test "includes model and messages in body", %{config: config, request: request} do
      assert {:ok, http_request} = OpenAI.build_request(request, config)

      assert http_request.body["model"] == "gpt-4-turbo"
      assert is_list(http_request.body["messages"])
      assert length(http_request.body["messages"]) == 2
    end

    test "includes optional parameters when provided", %{config: config, request: request} do
      assert {:ok, http_request} = OpenAI.build_request(request, config)

      assert http_request.body["temperature"] == 0.7
      assert http_request.body["max_tokens"] == 1000
    end

    test "sets stream flag correctly", %{config: config, request: request} do
      stream_request = %{request | stream: true}
      assert {:ok, http_request} = OpenAI.build_request(stream_request, config)
      assert http_request.body["stream"] == true
    end

    test "includes functions when provided", %{config: config, request: request} do
      functions = [
        %{
          name: "get_weather",
          description: "Get the current weather",
          parameters: %{
            "type" => "object",
            "properties" => %{
              "location" => %{"type" => "string"}
            }
          }
        }
      ]

      func_request = %{request | functions: functions, function_call: :auto}
      assert {:ok, http_request} = OpenAI.build_request(func_request, config)

      assert is_list(http_request.body["functions"]) or is_list(http_request.body["tools"])
    end
  end

  describe "parse_response/2" do
    setup do
      config = %{OpenAI.default_config() | api_key: "sk-test"}
      {:ok, %{config: config}}
    end

    test "parses successful completion response", %{config: config} do
      raw_response = %{
        "id" => "chatcmpl-abc123",
        "object" => "chat.completion",
        "created" => 1700000000,
        "model" => "gpt-4-turbo",
        "choices" => [
          %{
            "index" => 0,
            "message" => %{
              "role" => "assistant",
              "content" => "Hello! How can I help you?"
            },
            "finish_reason" => "stop"
          }
        ],
        "usage" => %{
          "prompt_tokens" => 10,
          "completion_tokens" => 20,
          "total_tokens" => 30
        }
      }

      assert {:ok, response} = OpenAI.parse_response(raw_response, config)

      assert response.id == "chatcmpl-abc123"
      assert response.provider == :openai
      assert response.model == "gpt-4-turbo"
      assert length(response.choices) == 1
      assert hd(response.choices).message.content == "Hello! How can I help you?"
      assert response.usage.prompt_tokens == 10
      assert response.usage.completion_tokens == 20
    end

    test "parses function call response", %{config: config} do
      raw_response = %{
        "id" => "chatcmpl-func123",
        "object" => "chat.completion",
        "created" => 1700000000,
        "model" => "gpt-4-turbo",
        "choices" => [
          %{
            "index" => 0,
            "message" => %{
              "role" => "assistant",
              "content" => nil,
              "function_call" => %{
                "name" => "get_weather",
                "arguments" => "{\"location\":\"New York\"}"
              }
            },
            "finish_reason" => "function_call"
          }
        ],
        "usage" => %{
          "prompt_tokens" => 15,
          "completion_tokens" => 25,
          "total_tokens" => 40
        }
      }

      assert {:ok, response} = OpenAI.parse_response(raw_response, config)

      choice = hd(response.choices)
      assert choice.finish_reason == :function_call
      assert choice.message.function_call != nil
    end

    test "handles error response", %{config: config} do
      error_response = %{
        "error" => %{
          "message" => "Invalid API key",
          "type" => "invalid_request_error",
          "code" => "invalid_api_key"
        }
      }

      assert {:error, error} = OpenAI.parse_response(error_response, config)
      assert is_binary(error) or is_map(error) or is_atom(error)
    end
  end

  describe "parse_stream_chunk/2" do
    setup do
      config = %{OpenAI.default_config() | api_key: "sk-test"}
      {:ok, %{config: config}}
    end

    test "parses content delta chunk", %{config: config} do
      chunk = "data: #{Jason.encode!(%{
        "id" => "chatcmpl-stream123",
        "object" => "chat.completion.chunk",
        "created" => 1700000000,
        "model" => "gpt-4-turbo",
        "choices" => [
          %{
            "index" => 0,
            "delta" => %{
              "content" => "Hello"
            },
            "finish_reason" => nil
          }
        ]
      })}"

      assert {:ok, parsed} = OpenAI.parse_stream_chunk(chunk, config)
      assert is_map(parsed) or parsed == :done
    end

    test "handles [DONE] message", %{config: config} do
      assert {:ok, :done} = OpenAI.parse_stream_chunk("data: [DONE]", config)
    end

    test "handles empty lines", %{config: config} do
      assert {:ok, :keep_alive} = OpenAI.parse_stream_chunk("", config)
    end
  end

  describe "handle_error/2" do
    setup do
      config = %{OpenAI.default_config() | api_key: "sk-test"}
      {:ok, %{config: config}}
    end

    test "handles rate limit error", %{config: config} do
      error = %{
        status: 429,
        body: %{
          "error" => %{
            "message" => "Rate limit exceeded",
            "type" => "rate_limit_error"
          }
        }
      }

      assert {:error, result} = OpenAI.handle_error(error, config)
      assert is_map(result) or is_atom(result) or is_binary(result)
    end

    test "handles authentication error", %{config: config} do
      error = %{
        status: 401,
        body: %{
          "error" => %{
            "message" => "Invalid API key",
            "type" => "authentication_error"
          }
        }
      }

      assert {:error, result} = OpenAI.handle_error(error, config)
      assert is_map(result) or is_atom(result) or is_binary(result)
    end

    test "handles network error", %{config: config} do
      error = %{
        status: nil,
        reason: :timeout
      }

      assert {:error, result} = OpenAI.handle_error(error, config)
      assert is_map(result) or is_atom(result) or is_binary(result)
    end
  end

  describe "behaviour compliance" do
    test "implements all required callbacks" do
      behaviours = OpenAI.__info__(:attributes)[:behaviour] || []
      assert Lux.LLM.Provider in behaviours
    end

    test "all callbacks are exported" do
      exports = OpenAI.__info__(:functions)

      assert {:name, 0} in exports
      assert {:default_config, 0} in exports
      assert {:validate_config, 1} in exports
      assert {:list_models, 1} in exports
      assert {:get_model, 2} in exports
      assert {:supports_capability?, 3} in exports
      assert {:build_request, 2} in exports
      assert {:parse_response, 2} in exports
      assert {:parse_stream_chunk, 2} in exports
      assert {:handle_error, 2} in exports
    end
  end
end