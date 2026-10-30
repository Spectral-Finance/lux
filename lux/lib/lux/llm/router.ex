defmodule Lux.LLM.Router do
  @moduledoc """
  Unified Provider Abstraction Layer for Lux.
  Provides intelligent provider routing, automatic model selection,
  smart fallback handling across providers, and performance telemetry.
  """

  @behaviour Lux.LLM

  alias Lux.LLM.Anthropic
  alias Lux.LLM.Mira
  alias Lux.LLM.Ollama
  alias Lux.LLM.OpenAI
  alias Lux.LLM.OpenRouter
  alias Lux.LLM.TogetherAI

  require Logger

  @default_providers %{
    openai: OpenAI,
    anthropic: Anthropic,
    together_ai: TogetherAI,
    ollama: Ollama,
    openrouter: OpenRouter,
    mira: Mira
  }

  defmodule Config do
    @moduledoc """
    Configuration for LLM Router.
    """
    @type strategy :: :smartest | :cheapest | :fastest | :local | :custom
    @type t :: %__MODULE__{
            strategy: strategy(),
            primary_provider: atom(),
            fallback_providers: [atom()],
            max_retries: integer(),
            provider_configs: map(),
            track_metrics: boolean()
          }

    defstruct strategy: :smartest,
              primary_provider: :openai,
              fallback_providers: [:together_ai],
              max_retries: 2,
              provider_configs: %{},
              track_metrics: true
  end

  @doc """
  Returns the current provider registry map.
  """
  def registry do
    Application.get_env(:lux, :llm_provider_registry, @default_providers)
  end

  @doc """
  Registers a new provider module under the given key.
  """
  def register_provider(key, module) when is_atom(key) and is_atom(module) do
    current = registry()
    updated = Map.put(current, key, module)
    Application.put_env(:lux, :llm_provider_registry, updated)
    {:ok, updated}
  end

  @doc """
  Resolves a provider module from its key or module name.
  """
  def resolve_provider(module) when is_atom(module) do
    case Map.get(registry(), module) do
      nil -> module
      resolved -> resolved
    end
  end

  @impl true
  def call(prompt, tools, config) do
    config =
      case config do
        %Config{} -> config
        opts when is_map(opts) -> struct(Config, opts)
        opts when is_list(opts) -> struct(Config, Map.new(opts))
        _ -> %Config{}
      end

    chain = build_provider_chain(config)
    execute_with_fallbacks(prompt, tools, chain, config, [])
  end

  @doc """
  Builds ordered list of providers according to the selection strategy.
  """
  def build_provider_chain(%Config{strategy: :local} = _config) do
    [:ollama]
  end

  def build_provider_chain(%Config{strategy: :cheapest} = config) do
    [:together_ai, :ollama, :openai]
    |> Enum.uniq()
    |> prioritize_primary(config.primary_provider)
  end

  def build_provider_chain(%Config{strategy: :fastest} = config) do
    [:together_ai, :openai, :anthropic]
    |> Enum.uniq()
    |> prioritize_primary(config.primary_provider)
  end

  def build_provider_chain(%Config{primary_provider: primary, fallback_providers: fallbacks}) do
    [primary | fallbacks]
    |> Enum.uniq()
  end

  defp prioritize_primary(chain, primary) when is_atom(primary) do
    [primary | List.delete(chain, primary)]
  end

  defp execute_with_fallbacks(_prompt, _tools, [], _config, errors) do
    Logger.error("All providers in LLM Router fallback chain failed: #{inspect(errors)}")
    {:error, {:all_providers_failed, Enum.reverse(errors)}}
  end

  defp execute_with_fallbacks(prompt, tools, [provider_key | rest], config, errors) do
    provider_mod = resolve_provider(provider_key)
    provider_config = Map.get(config.provider_configs, provider_key, %{})

    start_time = System.monotonic_time(:millisecond)

    case provider_mod.call(prompt, tools, provider_config) do
      {:ok, response} ->
        duration = System.monotonic_time(:millisecond) - start_time
        maybe_record_metrics(provider_key, :success, duration, response, config)
        {:ok, response}

      {:error, reason} ->
        duration = System.monotonic_time(:millisecond) - start_time
        Logger.warning("Provider #{inspect(provider_key)} failed with #{inspect(reason)}; attempting fallback. Elapsed: #{duration}ms")
        maybe_record_metrics(provider_key, :error, duration, reason, config)
        execute_with_fallbacks(prompt, tools, rest, config, [{provider_key, reason} | errors])
    end
  end

  defp maybe_record_metrics(provider, status, duration_ms, _data, %Config{track_metrics: true}) do
    :telemetry.execute(
      [:lux, :llm, :router],
      %{duration_ms: duration_ms},
      %{provider: provider, status: status}
    )
  rescue
    _ -> :ok
  end

  defp maybe_record_metrics(_provider, _status, _duration_ms, _data, _config), do: :ok
end
