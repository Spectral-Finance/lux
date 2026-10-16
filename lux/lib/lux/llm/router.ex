defmodule Lux.LLM.Router do
  @moduledoc """
  Intelligent routing across the registered LLM providers.

  `call/3` ties the layer together:

    1. estimates the cost of the call and refuses it when the configured
       budget in `Lux.LLM.Cost` is exhausted (unless `force: true`),
    2. ranks the registered providers with `Lux.LLM.Selector`,
    3. tries them in order — skipping providers whose circuit breaker is open,
       retrying transient errors with exponential backoff,
    4. measures every attempt through `Lux.LLM.Stats` (telemetry + aggregates),
    5. records token usage and price through `Lux.LLM.Cost`,
    6. returns the first success, or the last error when every provider failed.

  ## Example

      Lux.LLM.Router.call("Summarise this transaction", [], quality: :cheap)
      #=> {:ok, %Lux.LLM.Response{}}

  """

  require Logger

  alias Lux.LLM.CircuitBreaker
  alias Lux.LLM.Cost
  alias Lux.LLM.Provider
  alias Lux.LLM.Selector
  alias Lux.LLM.Stats

  @default_max_attempts_per_provider 2
  @default_backoff_ms 250

  @type call_result :: {:ok, Lux.LLM.Response.t()} | {:error, term()}

  @doc """
  Routes a single call through the available providers.

  Options:

    * `:requirements` — map/keyword passed to `Lux.LLM.Selector`
      (`:prompt_tokens`, `:tools`, `:quality`, `:max_cost_usd`, ...)
    * `:providers` — restrict to an explicit allow-list of provider modules
    * `:max_attempts` — retries per provider for transient errors (default 2)
    * `:backoff_ms` — base backoff between retries (default 250)
    * `:budget_usd` — per-call ceiling; call fails fast when the cheapest
      registered provider would already price the call above it
    * `:force` — ignore the global budget (default `false`)
  """
  @spec call(String.t(), [term()], keyword()) :: call_result()
  def call(prompt, tools \\ [], opts \\ []) do
    opts = Keyword.validate!(opts, [:requirements, :providers, :max_attempts, :backoff_ms, :budget_usd, :force])
    requirements = Keyword.get(opts, :requirements, %{}) |> normalize_requirements(tools)
    force? = Keyword.get(opts, :force, false)
    max_attempts = Keyword.get(opts, :max_attempts, @default_max_attempts_per_provider)
    backoff_ms = Keyword.get(opts, :backoff_ms, @default_backoff_ms)
    allow_providers = Keyword.get(opts, :providers)

    with :ok <- check_budget(force?, Keyword.get(opts, :budget_usd), requirements) do
      candidates =
        Lux.LLM.Registry.available()
        |> then(&if(is_nil(allow_providers), do: &1, else: Enum.filter(&1, fn e -> e.module in allow_providers end)))
        |> Selector.rank(Map.put(requirements, :tools, tools))

      try_candidates(candidates, prompt, tools, opts, max_attempts, backoff_ms)
    end
  end

  # --- internals ------------------------------------------------------------

  defp normalize_requirements(req, tools) when is_list(req) do
    req = Map.new(req)
    Map.put_new(req, :tools, tools)
  end

  defp normalize_requirements(req, tools) when is_map(req) do
    Map.put_new(req, :tools, tools)
  end

  defp check_budget(true, _budget, _req), do: :ok

  defp check_budget(_force, budget, req) do
    prompt_tokens = Map.get(req, :prompt_tokens, 1_000)

    cond do
      Cost.exceeded?() -> {:error, :budget_exceeded}
      is_nil(budget) -> :ok
      estimate_call_cost(prompt_tokens) > budget -> {:error, :budget_exceeded}
      true -> :ok
    end
  end

  defp estimate_call_cost(prompt_tokens) do
    out_tokens = max(div(prompt_tokens, 4), 256)

    Lux.LLM.Registry.available()
    |> Enum.flat_map(& &1.meta.models)
    |> Enum.map(fn m ->
      m.input_cost_per_mtok * prompt_tokens / 1_000_000 +
        m.output_cost_per_mtok * out_tokens / 1_000_000
    end)
    |> Enum.min(fn -> 0.0 end)
  end

  defp try_candidates([], _prompt, _tools, _opts, _max, _backoff),
    do: {:error, :no_provider_available}

  defp try_candidates([entry | rest], prompt, tools, opts, max_attempts, backoff_ms) do
    module = entry.module
    model = entry.default_model

    cond do
      not CircuitBreaker.allow?(module) ->
        Logger.debug("lux llm router: skipping #{inspect(module)} (circuit open)")
        try_candidates(rest, prompt, tools, opts, max_attempts, backoff_ms)

      true ->
        case attempt(entry, prompt, tools, opts, max_attempts, backoff_ms) do
          {:ok, _} = ok ->
            CircuitBreaker.record_success(module)
            ok

          {:error, _} = error ->
            CircuitBreaker.record_failure(module)

            if Enum.empty?(rest) do
              error
            else
              try_candidates(rest, prompt, tools, opts, max_attempts, backoff_ms)
            end
        end
    end
  end

  defp attempt(entry, prompt, tools, opts, max_attempts, backoff_ms, attempt_no \\ 1) do
    module = entry.module
    config = entry.config || %{}
    model = Map.get(config, :model) || entry.default_model
    config = Map.put(config, :model, model)

    result =
      Stats.measure(Provider.meta(module).name, model, fn ->
        module.call(prompt, tools, config)
      end)

    case result do
      {:ok, response} ->
        record_usage(module, model, prompt, response)
        {:ok, response}

      {:error, reason} = error ->
        if retryable?(reason) and attempt_no < max_attempts do
          Process.sleep(backoff_ms * attempt_no)
          attempt(entry, prompt, tools, opts, max_attempts, backoff_ms, attempt_no + 1)
        else
          error
        end
    end
  end

  defp retryable?(:timeout), do: true
  defp retryable?(:econnrefused), do: true
  defp retryable?(:connect_timeout), do: true
  defp retryable?({status, _}) when status in [429, 500, 502, 503, 504], do: true
  defp retryable?(_), do: false

  defp record_usage(module, model, prompt, response) do
    usage = usage_from(response) || estimate(prompt)

    provider_name = module.meta().name
    Cost.record(provider_name, model, usage.input_tokens, usage.output_tokens)
  end

  defp usage_from(%{usage: %{input_tokens: i, output_tokens: o}})
       when is_integer(i) and is_integer(o) do
    %{input_tokens: i, output_tokens: o}
  end

  defp usage_from(_), do: nil

  defp estimate(prompt) do
    words = prompt |> String.split() |> length()
    %{input_tokens: max(div(words * 4, 3), 1), output_tokens: 512}
  end
end
