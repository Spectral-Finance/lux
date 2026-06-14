defmodule Lux.Prisms.LLM.LLMProviderSelectorPrism do
  @moduledoc """
  A prism that automatically selects the best LLM provider and handles
  fallback when primary provider fails.

  ## Example

      iex> Lux.Prisms.LLM.LLMProviderSelectorPrism.handler(%{
      ...>   messages: [%{role: "user", content: "Hello!"}],
      ...>   task: "chat",
      ...>   fallback: true
      ...> }, %{})
      {:ok, %{status: "success", content: "Hello!", provider_used: "openrouter", model_used: "openai/gpt-4o-mini"}}
  """

  use Lux.Prism,
    name: "LLM Provider Selector",
    description: "Auto-selects best LLM provider with intelligent fallback handling",
    input_schema: %{
      type: :object,
      properties: %{
        messages: %{
          type: :array,
          description: "Chat messages",
          items: %{type: :object}
        },
        task: %{
          type: :string,
          description: "Task type: coding | chat | analysis | creative | fast",
          enum: ["coding", "chat", "analysis", "creative", "fast"],
          default: "chat"
        },
        preferred_provider: %{
          type: :string,
          description: "Preferred provider (optional)"
        },
        fallback: %{
          type: :boolean,
          description: "Enable fallback to next provider on failure",
          default: true
        },
        max_cost_per_1k: %{
          type: :number,
          description: "Max cost per 1k tokens",
          default: 0.1
        },
        temperature: %{type: :number, default: 0.7},
        max_tokens: %{type: :integer, default: 1000}
      },
      required: ["messages"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        content: %{type: :string},
        provider_used: %{type: :string},
        model_used: %{type: :string},
        tokens_used: %{type: :integer},
        cost_usd: %{type: :number},
        fallback_used: %{type: :boolean}
      },
      required: ["status"]
    }

  require Logger
  alias Lux.Config

  @provider_order ["openrouter", "together_ai", "perplexity", "ollama"]

  @models %{
    "openrouter" => %{
      "coding" => "deepseek/deepseek-coder",
      "chat" => "openai/gpt-4o-mini",
      "analysis" => "anthropic/claude-3-haiku",
      "creative" => "anthropic/claude-3-opus",
      "fast" => "openai/gpt-3.5-turbo"
    },
    "together_ai" => %{
      "coding" => "codellama/CodeLlama-70b-Instruct-hf",
      "chat" => "meta-llama/Llama-3-70b-chat-hf",
      "analysis" => "mistralai/Mixtral-8x7B-Instruct-v0.1",
      "creative" => "NousResearch/Nous-Hermes-2-Mixtral-8x7B-DPO",
      "fast" => "meta-llama/Llama-3-8b-chat-hf"
    },
    "perplexity" => %{
      "coding" => "codellama-70b-instruct",
      "chat" => "sonar-medium-chat",
      "analysis" => "sonar-medium-online",
      "creative" => "sonar-medium-chat",
      "fast" => "sonar-small-chat"
    },
    "ollama" => %{
      "coding" => "codellama",
      "chat" => "llama3",
      "analysis" => "llama3",
      "creative" => "mistral",
      "fast" => "phi3"
    }
  }

  @costs %{
    "openrouter" => 0.002,
    "together_ai" => 0.0008,
    "perplexity" => 0.001,
    "ollama" => 0.0
  }

  def handler(input, _ctx) do
    messages = input[:messages] || input["messages"]
    task = input[:task] || input["task"] || "chat"
    preferred = input[:preferred_provider] || input["preferred_provider"]
    fallback = Map.get(input, :fallback, Map.get(input, "fallback", true))
    temperature = input[:temperature] || input["temperature"] || 0.7
    max_tokens = input[:max_tokens] || input["max_tokens"] || 1000

    providers = build_provider_order(preferred)

    try_providers(providers, messages, task, temperature, max_tokens, fallback, false)
  end

  defp build_provider_order(nil), do: @provider_order
  defp build_provider_order(preferred) do
    [preferred | Enum.reject(@provider_order, &(&1 == preferred))]
  end

  defp try_providers([], _messages, _task, _temp, _max_tokens, _fallback, _used_fallback) do
    {:error, "All LLM providers failed"}
  end

  defp try_providers([provider | rest], messages, task, temperature, max_tokens, fallback, used_fallback) do
    model = get_in(@models, [provider, task]) || get_in(@models, [provider, "chat"])
    api_key = get_api_key(provider)

    case call_provider(provider, api_key, model, messages, temperature, max_tokens) do
      {:ok, content, tokens} ->
        cost = (@costs[provider] || 0.0) * tokens / 1000
        {:ok, %{
          status: "success",
          content: content,
          provider_used: provider,
          model_used: model,
          tokens_used: tokens,
          cost_usd: cost,
          fallback_used: used_fallback
        }}

      {:error, reason} ->
        Logger.warning("Provider #{provider} failed: #{reason}")
        if fallback and rest != [] do
          try_providers(rest, messages, task, temperature, max_tokens, fallback, true)
        else
          {:error, "Provider #{provider} failed: #{reason}"}
        end
    end
  end

  defp get_api_key("openrouter") do
    Config.get(:openrouter_api_key) || System.get_env("OPENROUTER_API_KEY")
  end
  defp get_api_key("together_ai") do
    Config.get(:together_ai_api_key) || System.get_env("TOGETHER_AI_API_KEY")
  end
  defp get_api_key("perplexity") do
    Config.get(:perplexity_api_key) || System.get_env("PERPLEXITY_API_KEY")
  end
  defp get_api_key("ollama"), do: "ollama"
  defp get_api_key(_), do: nil

  defp call_provider("ollama", _api_key, model, messages, temperature, max_tokens) do
    call_openai_compatible("http://localhost:11434/api/chat", "ollama", model, messages, temperature, max_tokens)
  end

  defp call_provider("openrouter", api_key, model, messages, temperature, max_tokens) do
    call_openai_compatible("https://openrouter.ai/api/v1/chat/completions", api_key, model, messages, temperature, max_tokens)
  end

  defp call_provider("together_ai", api_key, model, messages, temperature, max_tokens) do
    call_openai_compatible("https://api.together.xyz/v1/chat/completions", api_key, model, messages, temperature, max_tokens)
  end

  defp call_provider("perplexity", api_key, model, messages, temperature, max_tokens) do
    call_openai_compatible("https://api.perplexity.ai/chat/completions", api_key, model, messages, temperature, max_tokens)
  end

  defp call_provider(provider, _api_key, _model, _messages, _temp, _max_tokens) do
    {:error, "Unknown provider: #{provider}"}
  end

  defp call_openai_compatible(url, api_key, model, messages, temperature, max_tokens) do
    import Lux.Python
    require Lux.Python

    messages_json = Jason.encode!(messages)

    python_result =
      python variables: %{
        url: url,
        api_key: api_key,
        model: model,
        messages_json: messages_json,
        temperature: temperature,
        max_tokens: max_tokens
      } do
        ~PY"""
        result = None
        try:
            import urllib.request
            import json

            messages = json.loads(messages_json)
            payload = json.dumps({
                "model": model,
                "messages": messages,
                "temperature": temperature,
                "max_tokens": max_tokens
            }).encode("utf-8")

            req = urllib.request.Request(
                url,
                data=payload,
                method="POST"
            )
            req.add_header("Content-Type", "application/json")
            req.add_header("Authorization", f"Bearer {api_key}")
            req.add_header("HTTP-Referer", "https://github.com/Spectral-Finance/lux")
            req.add_header("X-Title", "Lux Framework")

            with urllib.request.urlopen(req, timeout=30) as response:
                data = json.loads(response.read().decode("utf-8"))
                content = data["choices"][0]["message"]["content"]
                tokens = data.get("usage", {}).get("total_tokens", 0)
                result = {"content": content, "tokens": tokens}
        except Exception as e:
            result = {"error": str(e)}
        result
        """
      end

    case python_result do
      %{"content" => content, "tokens" => tokens} -> {:ok, content, tokens}
      %{"error" => error} -> {:error, error}
      _ -> {:error, "Unknown error"}
    end
  end
end
