defmodule Lux.Integration.LLM.OpenRouterTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.LLM.OpenRouter
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal
  alias Lux.SignalSchema

  describe "simple text request and response, no tools or structure output" do
    setup do
      config = %{
        api_key: Application.get_env(:lux, :api_keys)[:integration_openrouter],
        model: Application.get_env(:lux, :open_router_models)[:cheapest],
        temperature: 0.7
      }

      %{config: config}
    end

    test "it still returns a structured response with usage and cost metadata", %{config: config} do
      assert {:ok,
              %Signal{
                id: _,
                metadata: %{
                  id: _,
                  usage: %{
                    "completion_tokens" => _,
                    "prompt_tokens" => _,
                    "total_tokens" => _
                  },
                  created: _,
                  system_fingerprint: _
                },
                payload: %{
                  model: _,
                  content: %{"text" => _},
                  tool_calls: nil,
                  tool_calls_results: nil,
                  finish_reason: "stop"
                }
              } = signal} = OpenRouter.call("Reply with exactly the word Paris and nothing else.", [], config)

      summary = OpenRouter.cost_summary(signal)
      assert summary.total_tokens > 0
    end
  end

  describe "fallback model routing" do
    setup do
      config = %{
        api_key: Application.get_env(:lux, :api_keys)[:integration_openrouter],
        models: [
          Application.get_env(:lux, :open_router_models)[:cheapest],
          Application.get_env(:lux, :open_router_models)[:smartest]
        ],
        temperature: 0.7
      }

      %{config: config}
    end

    test "supports models fallback array in config", %{config: config} do
      assert {:ok, %Signal{payload: %{model: _}}} =
               OpenRouter.call("Reply with exactly OK.", [], config)
    end
  end
end
