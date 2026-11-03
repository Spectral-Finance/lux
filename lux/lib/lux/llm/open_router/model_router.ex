defmodule Lux.LLM.OpenRouter.ModelRouter do
  @moduledoc """
  Model selection, routing, fallback chains, and cost calculation for OpenRouter.

  OpenRouter provides access to dozens of underlying LLMs through unified IDs (e.g. `anthropic/claude-3.5-sonnet`,
  `openai/gpt-4o`, `meta-llama/llama-3.1-70b-instruct`). This module allows dynamic selection based on
  cost, speed, capability, or user-specified constraints.
  """

  require Logger

  @models_endpoint "https://openrouter.ai/api/v1/models"

  # Curated models with base specs (pricing per 1M tokens in USD)
  @curated_catalog %{
    "anthropic/claude-3.5-sonnet" => %{
      name: "Claude 3.5 Sonnet",
      tier: :smartest,
      context_length: 200_000,
      pricing: %{prompt: 3.0, completion: 15.0}, # $3 / $15 per 1M tokens
      supports_tools: true,
      supports_vision: true,
      latency_score: 75
    },
    "openai/gpt-4o" => %{
      name: "GPT-4o",
      tier: :smartest,
      context_length: 128_000,
      pricing: %{prompt: 2.5, completion: 10.0},
      supports_tools: true,
      supports_vision: true,
      latency_score: 85
    },
    "openai/gpt-4o-mini" => %{
      name: "GPT-4o Mini",
      tier: :balanced,
      context_length: 128_000,
      pricing: %{prompt: 0.15, completion: 0.6},
      supports_tools: true,
      supports_vision: true,
      latency_score: 95
    },
    "google/gemini-2.0-flash" => %{
      name: "Gemini 2.0 Flash",
      tier: :fastest,
      context_length: 1_000_000,
      pricing: %{prompt: 0.10, completion: 0.40},
      supports_tools: true,
      supports_vision: true,
      latency_score: 98
    },
    "meta-llama/llama-3.1-70b-instruct" => %{
      name: "Llama 3.1 70B Instruct",
      tier: :balanced,
      context_length: 131_072,
      pricing: %{prompt: 0.35, completion: 0.40},
      supports_tools: true,
      supports_vision: false,
      latency_score: 80
    },
    "meta-llama/llama-3.1-8b-instruct:free" => %{
      name: "Llama 3.1 8B Instruct (Free)",
      tier: :free,
      context_length: 131_072,
      pricing: %{prompt: 0.0, completion: 0.0},
      supports_tools: true,
      supports_vision: false,
      latency_score: 85
    },
    "deepseek/deepseek-chat" => %{
      name: "DeepSeek V3",
      tier: :cheapest,
      context_length: 64_000,
      pricing: %{prompt: 0.14, completion: 0.28},
      supports_tools: true,
      supports_vision: false,
      latency_score: 80
    },
    "qwen/qwen-2.5-72b-instruct" => %{
      name: "Qwen 2.5 72B Instruct",
      tier: :balanced,
      context_length: 128_000,
      pricing: %{prompt: 0.35, completion: 0.40},
      supports_tools: true,
      supports_vision: false,
      latency_score: 80
    }
  }

  @doc """
  Returns the static curated catalog of top OpenRouter models.
  """
  @spec curated_catalog() :: map()
  def curated_catalog, do: @curated_catalog

  @doc """
  Selects an optimal model based on given strategy and constraints.

  ## Options:
  - `:strategy`: `:smartest`, `:balanced`, `:fastest`, `:cheapest`, `:free` (default: `:balanced`)
  - `:min_context`: minimum required context window
  - `:tools_required`: boolean (default: false)
  - `:vision_required`: boolean (default: false)
  - `:max_prompt_price`: maximum price per 1M prompt tokens
  """
  @spec select_model(keyword()) :: String.t()
  def select_model(opts \\ []) do
    strategy = Keyword.get(opts, :strategy, :balanced)
    min_context = Keyword.get(opts, :min_context, 0)
    tools_required = Keyword.get(opts, :tools_required, false)
    vision_required = Keyword.get(opts, :vision_required, false)
    max_price = Keyword.get(opts, :max_prompt_price)

    candidates =
      @curated_catalog
      |> Enum.filter(fn {_id, meta} ->
        meets_context = meta.context_length >= min_context
        meets_tools = if tools_required, do: meta.supports_tools, else: true
        meets_vision = if vision_required, do: meta.supports_vision, else: true
        meets_price = if is_number(max_price), do: meta.pricing.prompt <= max_price, else: true

        meets_context and meets_tools and meets_vision and meets_price
      end)

    case strategy do
      :free ->
        case Enum.find(candidates, fn {_id, meta} -> meta.tier == :free end) do
          {id, _} -> id
          nil -> "meta-llama/llama-3.1-8b-instruct:free"
        end

      :cheapest ->
        candidates
        |> Enum.min_by(fn {_id, meta} -> meta.pricing.prompt + meta.pricing.completion end, fn ->
          {"deepseek/deepseek-chat", nil}
        end)
        |> elem(0)

      :fastest ->
        candidates
        |> Enum.max_by(fn {_id, meta} -> meta.latency_score end, fn ->
          {"google/gemini-2.0-flash", nil}
        end)
        |> elem(0)

      :smartest ->
        case Enum.find(candidates, fn {id, _} -> id == "anthropic/claude-3.5-sonnet" end) do
          {id, _} -> id
          nil -> "openai/gpt-4o"
        end

      :balanced ->
        case Enum.find(candidates, fn {id, _} -> id == "openai/gpt-4o-mini" end) do
          {id, _} -> id
          nil -> "meta-llama/llama-3.1-70b-instruct"
        end

      other_model when is_binary(other_model) ->
        other_model

      _ ->
        "openai/gpt-4o-mini"
    end
  end

  @doc """
  Builds a recommended fallback chain of models for OpenRouter's `models` array.
  If the primary model is busy or encounters rate limits, OpenRouter will automatically cascade to the next.
  """
  @spec build_fallback_chain(String.t(), list(String.t())) :: list(String.t())
  def build_fallback_chain(primary_model, extra_fallbacks \\ []) do
    defaults =
      case primary_model do
        "anthropic/claude-3.5-sonnet" ->
          ["openai/gpt-4o", "meta-llama/llama-3.1-70b-instruct", "openai/gpt-4o-mini"]

        "openai/gpt-4o" ->
          ["anthropic/claude-3.5-sonnet", "meta-llama/llama-3.1-70b-instruct", "openai/gpt-4o-mini"]

        "openai/gpt-4o-mini" ->
          ["google/gemini-2.0-flash", "meta-llama/llama-3.1-8b-instruct:free"]

        "google/gemini-2.0-flash" ->
          ["openai/gpt-4o-mini", "meta-llama/llama-3.1-8b-instruct:free"]

        _ ->
          ["openai/gpt-4o-mini", "meta-llama/llama-3.1-70b-instruct"]
      end

    ([primary_model | extra_fallbacks] ++ defaults)
    |> Enum.uniq()
  end

  @doc """
  Estimates the USD cost for a given model and token counts.
  Returns `%{prompt_cost: float(), completion_cost: float(), total_cost: float()}`.
  """
  @spec estimate_cost(String.t(), non_neg_integer(), non_neg_integer()) :: map()
  def estimate_cost(model_id, prompt_tokens, completion_tokens) do
    pricing =
      case Map.get(@curated_catalog, model_id) do
        %{pricing: p} -> p
        nil -> %{prompt: 1.0, completion: 2.0} # reasonable fallback assumption
      end

    # Prices are per 1,000,000 tokens
    prompt_cost = (prompt_tokens / 1_000_000.0) * pricing.prompt
    completion_cost = (completion_tokens / 1_000_000.0) * pricing.completion
    total_cost = Float.round(prompt_cost + completion_cost, 8)

    %{
      model: model_id,
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens,
      prompt_cost: Float.round(prompt_cost, 8),
      completion_cost: Float.round(completion_cost, 8),
      total_cost: total_cost
    }
  end

  @doc """
  Fetches live models from the OpenRouter API.
  """
  @spec fetch_remote_models(keyword()) :: {:ok, list(map())} | {:error, term()}
  def fetch_remote_models(opts \\ []) do
    endpoint = Keyword.get(opts, :endpoint, @models_endpoint)

    [
      url: endpoint,
      headers: [{"Content-Type", "application/json"}]
    ]
    |> Keyword.merge(opts)
    |> Req.new()
    |> Req.get()
    |> case do
      {:ok, %{status: 200, body: %{"data" => models}}} ->
        {:ok, models}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
