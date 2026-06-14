defmodule Lux.Prisms.LLM.LLMProviderRegistryPrism do
  @moduledoc """
  A prism that manages LLM provider registry with automatic model selection,
  fallback handling, and cost optimization.

  ## Example

      iex> Lux.Prisms.LLM.LLMProviderRegistryPrism.handler(%{
      ...>   action: "list_providers"
      ...> }, %{})
      {:ok, %{status: "success", providers: ["openrouter", "ollama", "perplexity", "together_ai"]}}

      iex> Lux.Prisms.LLM.LLMProviderRegistryPrism.handler(%{
      ...>   action: "get_best_provider",
      ...>   task: "coding",
      ...>   max_cost_per_1k: 0.01
      ...> }, %{})
      {:ok, %{status: "success", provider: "openrouter", model: "deepseek/deepseek-coder"}}

  Reads config:
  - :openrouter_api_key
  - :ollama_base_url
  - :perplexity_api_key
  - :together_ai_api_key
  """

  use Lux.Prism,
    name: "LLM Provider Registry",
    description: "Manages multiple LLM providers with automatic selection, fallback, and cost optimization",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action: list_providers | get_best_provider | get_provider_models | check_availability",
          enum: ["list_providers", "get_best_provider", "get_provider_models", "check_availability"]
        },
        provider: %{type: :string, description: "Provider name: openrouter | ollama | perplexity | together_ai"},
        task: %{
          type: :string,
          description: "Task type for best provider selection: coding | chat | analysis | creative | fast",
          enum: ["coding", "chat", "analysis", "creative", "fast"]
        },
        max_cost_per_1k: %{type: :number, description: "Max cost per 1k tokens in USD", default: 0.1}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        providers: %{type: :array},
        provider: %{type: :string},
        model: %{type: :string},
        models: %{type: :array},
        available: %{type: :boolean}
      },
      required: ["status"]
    }

  import Lux.Python
  require Lux.Python
  require Logger

  # Provider registry with capabilities and costs
  @providers %{
    "openrouter" => %{
      base_url: "https://openrouter.ai/api/v1",
      models: %{
        "coding" => "deepseek/deepseek-coder",
        "chat" => "openai/gpt-4o-mini",
        "analysis" => "anthropic/claude-3-haiku",
        "creative" => "anthropic/claude-3-opus",
        "fast" => "openai/gpt-3.5-turbo"
      },
      cost_per_1k: 0.002
    },
    "ollama" => %{
      base_url: "http://localhost:11434",
      models: %{
        "coding" => "codellama",
        "chat" => "llama3",
        "analysis" => "llama3",
        "creative" => "mistral",
        "fast" => "phi3"
      },
      cost_per_1k: 0.0
    },
    "perplexity" => %{
      base_url: "https://api.perplexity.ai",
      models: %{
        "coding" => "codellama-70b-instruct",
        "chat" => "sonar-medium-chat",
        "analysis" => "sonar-medium-online",
        "creative" => "sonar-medium-chat",
        "fast" => "sonar-small-chat"
      },
      cost_per_1k: 0.001
    },
    "together_ai" => %{
      base_url: "https://api.together.xyz/v1",
      models: %{
        "coding" => "codellama/CodeLlama-70b-Instruct-hf",
        "chat" => "meta-llama/Llama-3-70b-chat-hf",
        "analysis" => "mistralai/Mixtral-8x7B-Instruct-v0.1",
        "creative" => "NousResearch/Nous-Hermes-2-Mixtral-8x7B-DPO",
        "fast" => "meta-llama/Llama-3-8b-chat-hf"
      },
      cost_per_1k: 0.0008
    }
  }

  def handler(input, _ctx) do
    action = input[:action] || input["action"]
    provider = input[:provider] || input["provider"]
    task = input[:task] || input["task"] || "chat"
    max_cost = input[:max_cost_per_1k] || input["max_cost_per_1k"] || 0.1

    case action do
      "list_providers" ->
        {:ok, %{
          status: "success",
          providers: Map.keys(@providers),
          details: @providers
        }}

      "get_best_provider" ->
        result = @providers
          |> Enum.filter(fn {_, info} -> info.cost_per_1k <= max_cost end)
          |> Enum.min_by(fn {_, info} -> info.cost_per_1k end)

        case result do
          {name, info} ->
            {:ok, %{
              status: "success",
              provider: name,
              model: get_in(info, [:models, task]),
              cost_per_1k: info.cost_per_1k
            }}
          _ ->
            {:error, "No provider found within cost limit"}
        end

      "get_provider_models" ->
        case Map.get(@providers, provider) do
          nil -> {:error, "Unknown provider: #{provider}"}
          info ->
            {:ok, %{
              status: "success",
              provider: provider,
              models: info.models,
              base_url: info.base_url
            }}
        end

      "check_availability" ->
        check_provider_availability(provider)

      _ ->
        {:error, "Unknown action: #{action}"}
    end
  end

  defp check_provider_availability(provider) do
    case Map.get(@providers, provider) do
      nil ->
        {:error, "Unknown provider: #{provider}"}
      info ->
        python_result =
          python variables: %{base_url: info.base_url} do
            ~PY"""
            result = None
            try:
                import urllib.request
                req = urllib.request.Request(base_url, method='GET')
                req.add_header('User-Agent', 'LuxFramework/1.0')
                with urllib.request.urlopen(req, timeout=5) as response:
                    result = {"available": True, "status": response.status}
            except Exception as e:
                result = {"available": False, "error": str(e)}
            result
            """
          end

        case python_result do
          %{"available" => available} ->
            {:ok, %{status: "success", provider: provider, available: available}}
          _ ->
            {:ok, %{status: "success", provider: provider, available: false}}
        end
    end
  end
end
