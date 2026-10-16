defmodule Lux.LLM.Gateway do
  @moduledoc """
  Single entry point for LLM calls across providers.

  The gateway is the recommended way for agents to call language models: it
  wraps `Lux.LLM.Router` with application configuration so agents only need to
  state *what* they need (cheap, fast, tools) instead of *which* provider to use.

  ## Configuration

      config :lux, Lux.LLM.Gateway,
        default_requirements: %{quality: :balanced, prompt_tokens: 1_000},
        register: [
          {Lux.LLM.Anthropic, %{model: "claude-3-haiku-20240307"}},
          Lux.LLM.OpenAI
        ]

  ## Usage

      Lux.LLM.Gateway.call("Summarise the last 24h of trades", [], quality: :cheap)
      Lux.LLM.Gateway.call("Plan a trade", [MarketDataPrism], quality: :best)

      # telemetry snapshot
      Lux.LLM.Stats.snapshot()
      Lux.LLM.Cost.report()
  """

  alias Lux.LLM.Router

  @doc """
  Calls the best-matching provider for `prompt`.

  `tools` is the usual list of Prisms/Beams/Lenses. Options are merged over
  `config :lux, Lux.LLM.Gateway` and forwarded to `Lux.LLM.Router`, with
  any of `:quality`, `:prompt_tokens`, `:max_cost_usd`, `:providers`,
  `:max_attempts` and `:backoff_ms` being the useful ones.
  """
  @spec call(String.t(), [term()], keyword()) ::
          {:ok, Lux.LLM.Response.t()} | {:error, term()}
  def call(prompt, tools \\ [], opts \\ []) do
    explicit = opts |> Keyword.get(:requirements, []) |> Map.new()

    opts =
      Keyword.put(opts, :requirements, Map.merge(requirements(opts), explicit))

    Router.call(prompt, tools, opts)
  end

  @doc """
  Registers the providers listed in `config :lux, Lux.LLM.Gateway, :register`.

  Called by the application supervisor at boot; safe to call again to
  re-apply configuration changes at runtime.
  """
  @spec register_configured_providers() :: :ok
  def register_configured_providers do
    config = Application.get_env(:lux, __MODULE__, [])

    config
    |> Keyword.get(:register, [])
    |> Enum.each(fn
      {module, opts} -> Lux.LLM.Registry.register(module, Map.new(opts))
      module when is_atom(module) -> Lux.LLM.Registry.register(module)
    end)

    :ok
  end

  defp requirements(opts) do
    defaults = Application.get_env(:lux, __MODULE__, []) |> Keyword.get(:default_requirements, %{})

    overrides =
      opts
      |> Keyword.take([:quality, :prompt_tokens, :max_cost_usd, :max_latency_ms, :providers])
      |> Map.new()

    Map.merge(defaults, overrides)
  end
end
