defmodule Lux.Prisms.Llm.LlmProviderAbstractionPrism do
  @moduledoc """
  A prism that provides a universal LLM provider interface with automatic
  model selection, fallback handling, and cost/performance monitoring.

  This is the native Elixir implementation that replaces the previous
  Python-based approach. It integrates directly with:

  - `Lux.LLM.ProviderRegistry` — Dynamic provider management
  - `Lux.LLM.ModelSelector` — Intelligent model selection
  - `Lux.LLM.FallbackHandler` — Automatic fallback with backoff
  - `Lux.LLM.CostTracker` — Token usage and cost tracking
  - `Lux.LLM.PerformanceMonitor` — Latency and success rate tracking

  ## Example

      iex> Lux.Prisms.Llm.LlmProviderAbstractionPrism.run(%{
      ...>   "prompt" => "Explain quantum computing",
      ...>   "provider" => "auto",
      ...>   "model_preference" => ["gpt-4", "claude-3-opus", "gemini-pro"],
      ...>   "max_tokens" => 500
      ...> })
      {:ok, %{
        "status" => "success",
        "response" => "Quantum computing is...",
        "provider_used" => "openai",
        "model_used" => "gpt-4",
        "tokens_used" => 450,
        "cost_usd" => 0.0135,
        "latency_ms" => 1200
      }}

  ## Provider Configuration

  The prism reads provider configuration from application config:

      config :lux, :api_keys,
        openai: "sk-...",
        anthropic: "sk-ant-...",
        google: "AI..."

  ## Input Fields

    * `prompt` (required) — The text prompt to send
    * `system_prompt` — Optional system message
    * `provider` — "auto" for intelligent selection, or specific: "openai", "anthropic", "google", "ollama"
    * `model_preference` — Ordered list of preferred models
    * `max_tokens` — Maximum tokens in response (default: 1000)
    * `temperature` — Sampling temperature 0.0–2.0 (default: 0.7)
    * `fallback_enabled` — Enable fallback on failure (default: true)
    * `cost_limit_usd` — Maximum cost per request (default: 0.10)
    * `strategy` — Model selection strategy: "cheapest", "fastest", "smartest", "balanced"
  """

  use Lux.Prism,
    name: "LLM Provider Abstraction",
    description: "Universal LLM provider interface with automatic model selection, fallback handling, and cost monitoring",
    input_schema: %{
      type: :object,
      properties: %{
        prompt: %{
          type: :string,
          description: "The prompt to send to the LLM"
        },
        system_prompt: %{
          type: :string,
          description: "Optional system prompt for context setting"
        },
        provider: %{
          type: :string,
          description: "Specific provider to use, or auto for intelligent selection",
          enum: ["auto", "openai", "anthropic", "google", "ollama", "openrouter"],
          default: "auto"
        },
        model_preference: %{
          type: :array,
          description: "Ordered list of preferred models for auto selection",
          items: %{type: :string}
        },
        max_tokens: %{
          type: :integer,
          description: "Maximum tokens in response",
          default: 1000,
          minimum: 1,
          maximum: 128000
        },
        temperature: %{
          type: :number,
          description: "Sampling temperature (0.0 - 2.0)",
          default: 0.7,
          minimum: 0.0,
          maximum: 2.0
        },
        fallback_enabled: %{
          type: :boolean,
          description: "Enable fallback to next provider on failure",
          default: true
        },
        cost_limit_usd: %{
          type: :number,
          description: "Maximum cost per request in USD",
          default: 0.10
        },
        strategy: %{
          type: :string,
          description: "Model selection strategy",
          enum: ["cheapest", "fastest", "smartest", "balanced"],
          default: "balanced"
        }
      },
      required: ["prompt"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        response: %{type: :string},
        provider_used: %{type: :string},
        model_used: %{type: :string},
        tokens_used: %{type: :integer},
        cost_usd: %{type: :number},
        latency_ms: %{type: :integer},
        fallback_used: %{type: :boolean}
      },
      required: ["status", "response", "provider_used", "model_used"]
    }

  alias Lux.LLM.ProviderRegistry
  alias Lux.LLM.FallbackHandler
  alias Lux.LLM.ModelSelector
  alias Lux.LLM.CostTracker
  alias Lux.LLM.PerformanceMonitor

  require Logger

  @provider_map %{
    "openai" => :openai,
    "anthropic" => :anthropic,
    "google" => :google,
    "ollama" => :ollama,
    "openrouter" => :openrouter
  }

  @strategy_map %{
    "cheapest" => :cheapest,
    "fastest" => :fastest,
    "smartest" => :smartest,
    "balanced" => :balanced
  }

  def handler(input, _ctx) do
    prompt = input["prompt"]
    system_prompt = Map.get(input, "system_prompt")
    provider_name = Map.get(input, "provider", "auto")
    model_preference = Map.get(input, "model_preference", [])
    max_tokens = Map.get(input, "max_tokens", 1000)
    temperature = Map.get(input, "temperature", 0.7)
    fallback_enabled = Map.get(input, "fallback_enabled", true)
    cost_limit = Map.get(input, "cost_limit_usd", 0.10)
    strategy_name = Map.get(input, "strategy", "balanced")

    # Build full prompt with system message if provided
    full_prompt = if system_prompt do
      "System: #{system_prompt}\n\nUser: #{prompt}"
    else
      prompt
    end

    start_time = System.monotonic_time(:millisecond)

    result =
      cond do
        # Specific provider requested
        provider_name != "auto" ->
          call_specific_provider(provider_name, full_prompt, max_tokens, temperature, cost_limit, fallback_enabled)

        # Model preferences provided — use ModelSelector
        model_preference != [] ->
          strategy = Map.get(@strategy_map, strategy_name, :balanced)
          call_with_model_selection(full_prompt, model_preference, strategy, max_tokens, temperature, cost_limit, fallback_enabled)

        # Auto mode with strategy
        true ->
          strategy = Map.get(@strategy_map, strategy_name, :balanced)
          call_auto(full_prompt, strategy, max_tokens, temperature, cost_limit, fallback_enabled)
      end

    end_time = System.monotonic_time(:millisecond)
    latency_ms = end_time - start_time

    case result do
      {:ok, response, metadata} ->
        # Track cost and performance
        provider_id = metadata[:provider_used] || :unknown
        model_used = metadata[:model_used] || "unknown"

        # Estimate tokens from response
        tokens_used = estimate_tokens(response.content || "")
        cost_usd = CostTracker.estimate_cost(model_used, estimate_tokens(full_prompt), tokens_used)

        CostTracker.track(provider_id, model_used, estimate_tokens(full_prompt), tokens_used, cost_usd)
        PerformanceMonitor.record(provider_id, latency_ms, :ok, model_used)

        {:ok, %{
          "status" => "success",
          "response" => response.content || "",
          "provider_used" => Atom.to_string(provider_id),
          "model_used" => model_used,
          "tokens_used" => tokens_used,
          "cost_usd" => cost_usd,
          "latency_ms" => latency_ms,
          "fallback_used" => metadata[:fallback_used] || false
        }}

      {:error, reason, metadata} ->
        provider_id = metadata[:provider_used] || :unknown
        PerformanceMonitor.record(provider_id, latency_ms, :error, "unknown", reason)

        {:ok, %{
          "status" => "error",
          "response" => "",
          "provider_used" => Atom.to_string(provider_id),
          "model_used" => metadata[:model_used] || "unknown",
          "tokens_used" => 0,
          "cost_usd" => 0.0,
          "latency_ms" => latency_ms,
          "fallback_used" => metadata[:fallback_used] || false,
          "error" => reason
        }}

      {:error, reason} ->
        {:ok, %{
          "status" => "error",
          "response" => "",
          "provider_used" => "none",
          "model_used" => "unknown",
          "tokens_used" => 0,
          "cost_usd" => 0.0,
          "latency_ms" => latency_ms,
          "fallback_used" => false,
          "error" => to_string(reason)
        }}
    end
  end

  # Private helpers

  defp call_specific_provider(provider_name, prompt, max_tokens, temperature, cost_limit, fallback_enabled) do
    provider_id = Map.get(@provider_map, provider_name, String.to_atom(provider_name))

    case ProviderRegistry.get_provider(provider_id) do
      nil ->
        {:error, "provider_not_registered: #{provider_name}"}

      provider ->
        config = %{
          temperature: temperature,
          max_tokens: max_tokens
        }

        start = System.monotonic_time(:millisecond)

        case provider.module.call(prompt, [], config) do
          {:ok, response} ->
            ProviderRegistry.record_health(provider_id, :ok)
            {:ok, response, %{provider_used: provider_id, model_used: config[:model] || "default", fallback_used: false}}

          {:error, reason} ->
            ProviderRegistry.record_health(provider_id, :error, reason)
            if fallback_enabled do
              FallbackHandler.call(prompt, [],
                model: config[:model],
                cost_limit_usd: cost_limit,
                max_retries: 3
              )
            else
              {:error, reason, %{provider_used: provider_id, fallback_used: false}}
            end
        end
    end
  end

  defp call_with_model_selection(prompt, model_preference, strategy, max_tokens, temperature, cost_limit, fallback_enabled) do
    selection = ModelSelector.select(prompt,
      strategy: strategy,
      preference: model_preference,
      cost_limit: cost_limit,
      max_tokens: max_tokens
    )

    case selection do
      %{model: model, provider: provider_id} ->
        opts = [
          model: model,
          cost_limit_usd: cost_limit,
          temperature: temperature,
          max_tokens: max_tokens,
          max_retries: if(fallback_enabled, do: 3, else: 1)
        ]

        FallbackHandler.call(prompt, [], opts)

      nil ->
        {:error, "no_model_available_for_preferences"}
    end
  end

  defp call_auto(prompt, strategy, max_tokens, temperature, cost_limit, fallback_enabled) do
    selection = ModelSelector.select(prompt,
      strategy: strategy,
      cost_limit: cost_limit,
      max_tokens: max_tokens
    )

    case selection do
      %{model: model, provider: provider_id} ->
        opts = [
          model: model,
          cost_limit_usd: cost_limit,
          temperature: temperature,
          max_tokens: max_tokens,
          max_retries: if(fallback_enabled, do: 3, else: 1)
        ]

        FallbackHandler.call(prompt, [], opts)

      nil ->
        {:error, "no_provider_available"}
    end
  end

  defp estimate_tokens(text) when is_binary(text) do
    div(String.length(text), 4) + 1
  end

  defp estimate_tokens(_), do: 100
end
