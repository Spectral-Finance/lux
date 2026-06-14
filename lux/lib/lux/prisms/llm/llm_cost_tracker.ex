defmodule Lux.Prisms.LLM.LLMCostTrackerPrism do
  @moduledoc """
  A prism that tracks LLM usage costs and performance metrics.

  ## Example

      iex> Lux.Prisms.LLM.LLMCostTrackerPrism.handler(%{
      ...>   action: "estimate_cost",
      ...>   provider: "openrouter",
      ...>   model: "openai/gpt-4o-mini",
      ...>   input_tokens: 1000,
      ...>   output_tokens: 500
      ...> }, %{})
      {:ok, %{status: "success", estimated_cost_usd: 0.0003, provider: "openrouter"}}
  """

  use Lux.Prism,
    name: "LLM Cost Tracker",
    description: "Tracks and estimates LLM usage costs across providers",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["estimate_cost", "compare_providers", "get_cheapest"],
          description: "Action to perform"
        },
        provider: %{type: :string, description: "Provider name"},
        model: %{type: :string, description: "Model ID"},
        input_tokens: %{type: :integer, description: "Input token count", default: 1000},
        output_tokens: %{type: :integer, description: "Output token count", default: 500},
        task: %{type: :string, description: "Task type for comparison", default: "chat"}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        estimated_cost_usd: %{type: :number},
        provider: %{type: :string},
        comparison: %{type: :array},
        cheapest_provider: %{type: :string},
        cheapest_model: %{type: :string}
      },
      required: ["status"]
    }

  @pricing %{
    "openrouter" => %{
      "openai/gpt-4o-mini" => %{input: 0.00015, output: 0.0006},
      "openai/gpt-3.5-turbo" => %{input: 0.0005, output: 0.0015},
      "anthropic/claude-3-haiku" => %{input: 0.00025, output: 0.00125},
      "anthropic/claude-3-opus" => %{input: 0.015, output: 0.075},
      "deepseek/deepseek-coder" => %{input: 0.00014, output: 0.00028},
      "default" => %{input: 0.001, output: 0.002}
    },
    "together_ai" => %{
      "meta-llama/Llama-3-70b-chat-hf" => %{input: 0.0009, output: 0.0009},
      "meta-llama/Llama-3-8b-chat-hf" => %{input: 0.0002, output: 0.0002},
      "mistralai/Mixtral-8x7B-Instruct-v0.1" => %{input: 0.0006, output: 0.0006},
      "default" => %{input: 0.0008, output: 0.0008}
    },
    "perplexity" => %{
      "sonar-medium-chat" => %{input: 0.0006, output: 0.0018},
      "sonar-small-chat" => %{input: 0.0002, output: 0.0006},
      "sonar-medium-online" => %{input: 0.0006, output: 0.0018},
      "default" => %{input: 0.001, output: 0.001}
    },
    "ollama" => %{
      "default" => %{input: 0.0, output: 0.0}
    }
  }

  @task_models %{
    "openrouter" => %{"chat" => "openai/gpt-4o-mini", "coding" => "deepseek/deepseek-coder",
                      "analysis" => "anthropic/claude-3-haiku", "creative" => "anthropic/claude-3-opus",
                      "fast" => "openai/gpt-3.5-turbo"},
    "together_ai" => %{"chat" => "meta-llama/Llama-3-70b-chat-hf",
                       "coding" => "codellama/CodeLlama-70b-Instruct-hf",
                       "fast" => "meta-llama/Llama-3-8b-chat-hf",
                       "analysis" => "mistralai/Mixtral-8x7B-Instruct-v0.1"},
    "perplexity" => %{"chat" => "sonar-medium-chat", "fast" => "sonar-small-chat",
                      "analysis" => "sonar-medium-online"},
    "ollama" => %{"chat" => "llama3", "coding" => "codellama", "fast" => "phi3"}
  }

  def handler(input, _ctx) do
    action = input[:action] || input["action"]
    provider = input[:provider] || input["provider"]
    model = input[:model] || input["model"]
    input_tokens = input[:input_tokens] || input["input_tokens"] || 1000
    output_tokens = input[:output_tokens] || input["output_tokens"] || 500
    task = input[:task] || input["task"] || "chat"

    case action do
      "estimate_cost" ->
        cost = calculate_cost(provider, model, input_tokens, output_tokens)
        {:ok, %{
          status: "success",
          provider: provider,
          model: model,
          input_tokens: input_tokens,
          output_tokens: output_tokens,
          estimated_cost_usd: cost
        }}

      "compare_providers" ->
        comparison = @pricing
          |> Map.keys()
          |> Enum.map(fn p ->
            m = get_in(@task_models, [p, task]) || "default"
            cost = calculate_cost(p, m, input_tokens, output_tokens)
            %{provider: p, model: m, cost_usd: cost}
          end)
          |> Enum.sort_by(& &1.cost_usd)

        {:ok, %{status: "success", comparison: comparison, task: task}}

      "get_cheapest" ->
        cheapest = @pricing
          |> Map.keys()
          |> Enum.map(fn p ->
            m = get_in(@task_models, [p, task]) || "default"
            cost = calculate_cost(p, m, input_tokens, output_tokens)
            {p, m, cost}
          end)
          |> Enum.min_by(fn {_, _, cost} -> cost end)

        case cheapest do
          {p, m, cost} ->
            {:ok, %{
              status: "success",
              cheapest_provider: p,
              cheapest_model: m,
              estimated_cost_usd: cost,
              task: task
            }}
        end

      _ ->
        {:error, "Unknown action: #{action}"}
    end
  end

  defp calculate_cost(provider, model, input_tokens, output_tokens) do
    pricing = get_in(@pricing, [provider, model]) ||
              get_in(@pricing, [provider, "default"]) ||
              %{input: 0.001, output: 0.002}

    (input_tokens / 1000 * pricing.input) + (output_tokens / 1000 * pricing.output)
  end
end
