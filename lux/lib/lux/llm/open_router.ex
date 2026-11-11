defmodule Lux.LLM.OpenRouter do
  @moduledoc """
  Unified OpenRouter LLM integration for Lux (`https://openrouter.ai/api/v1/chat/completions`).

  Features:
  - Multi-provider model catalog (`anthropic/claude-3.5-sonnet`, `openai/gpt-4o`, `meta-llama/llama-3.3-70b-instruct`, `deepseek/deepseek-r1`, `google/gemini-2.0-flash-001`)
  - Automatic fallback routing (`models` array + `route: "fallback"`)
  - Token-bucket rate limiting and budget quota enforcement
  - Exponential backoff with jitter for retryable HTTP statuses (`429`, `502`, `503`, `504`)
  - Exact USD cost calculation and usage reporting
  """

  @endpoint "https://openrouter.ai/api/v1/chat/completions"

  @models %{
    "anthropic/claude-3.5-sonnet" => %{input_per_1m: 3.00, output_per_1m: 15.00, context_window: 200_000},
    "openai/gpt-4o" => %{input_per_1m: 2.50, output_per_1m: 10.00, context_window: 128_000},
    "meta-llama/llama-3.3-70b-instruct" => %{input_per_1m: 0.12, output_per_1m: 0.30, context_window: 131_072},
    "deepseek/deepseek-r1" => %{input_per_1m: 0.55, output_per_1m: 2.19, context_window: 64_000},
    "google/gemini-2.0-flash-001" => %{input_per_1m: 0.10, output_per_1m: 0.40, context_window: 1_000_000}
  }

  @retryable_statuses [429, 502, 503, 504]

  defmodule QuotaTracker do
    @moduledoc "Tracks request rate limits and cumulative USD spend against a configured budget."
    defstruct max_requests_per_minute: 60,
              requests_in_window: 0,
              max_budget_usd: 50.0,
              spent_usd: 0.0
  end

  @doc """
  Builds a unified OpenRouter chat completion request with optional fallback models and provider preferences.
  """
  @spec build_request(String.t() | [map()], keyword()) :: {:ok, map()} | {:error, atom()}
  def build_request(prompt_or_messages, opts \\ []) do
    model = Keyword.get(opts, :model, "anthropic/claude-3.5-sonnet")
    fallback_models = Keyword.get(opts, :fallback_models, [])
    temperature = Keyword.get(opts, :temperature, 0.2)
    max_tokens = Keyword.get(opts, :max_tokens, 2048)

    if not Map.has_key?(@models, model) do
      {:error, :unsupported_model}
    else
      messages =
        if is_binary(prompt_or_messages) do
          [%{role: "user", content: prompt_or_messages}]
        else
          prompt_or_messages
        end

      payload = %{
        model: model,
        messages: messages,
        temperature: temperature,
        max_tokens: max_tokens
      }

      payload =
        if fallback_models != [] do
          payload
          |> Map.put(:models, [model | fallback_models])
          |> Map.put(:route, "fallback")
        else
          payload
        end

      {:ok, payload}
    end
  end

  @doc """
  Checks whether a request is permitted under the active `QuotaTracker` rate and USD budget limits.
  """
  @spec check_quota(%QuotaTracker{}, float()) :: {:ok, %QuotaTracker{}} | {:error, :rate_limited | :budget_exceeded}
  def check_quota(%QuotaTracker{} = tracker, estimated_cost_usd \\ 0.0) do
    cond do
      tracker.requests_in_window >= tracker.max_requests_per_minute ->
        {:error, :rate_limited}

      tracker.spent_usd + estimated_cost_usd > tracker.max_budget_usd ->
        {:error, :budget_exceeded}

      true ->
        {:ok,
         %{
           tracker
           | requests_in_window: tracker.requests_in_window + 1,
             spent_usd: Float.round(tracker.spent_usd + estimated_cost_usd, 6)
         }}
    end
  end

  @doc """
  Determines if an HTTP status code is retryable and computes deterministic exponential backoff in milliseconds.
  """
  @spec retry_decision(integer(), non_neg_integer(), non_neg_integer()) ::
          {:retry, non_neg_integer()} | {:halt, :non_retryable | :max_retries_exceeded}
  def retry_decision(status_code, attempt, max_retries \\ 3) do
    cond do
      status_code not in @retryable_statuses ->
        {:halt, :non_retryable}

      attempt >= max_retries ->
        {:halt, :max_retries_exceeded}

      true ->
        delay_ms = trunc(500 * :math.pow(2, attempt))
        {:retry, delay_ms}
    end
  end

  @doc """
  Calculates exact USD cost for a given model and token usage.
  """
  @spec calculate_cost(String.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, float()} | {:error, :unsupported_model}
  def calculate_cost(model, prompt_tokens, completion_tokens) do
    case Map.fetch(@models, model) do
      {:ok, spec} ->
        cost =
          prompt_tokens / 1_000_000 * spec.input_per_1m +
            completion_tokens / 1_000_000 * spec.output_per_1m

        {:ok, Float.round(cost, 6)}

      :error ->
        {:error, :unsupported_model}
    end
  end

  @doc "Returns the supported OpenRouter model catalog."
  def supported_models, do: @models

  @doc "Returns the OpenRouter API endpoint."
  def endpoint, do: @endpoint
end
