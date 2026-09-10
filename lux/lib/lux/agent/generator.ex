defmodule Lux.Agent.Generator do
  @moduledoc """
  Generates Elixir agent modules from Config structs.
  """

  alias Lux.Agent.Config

  @doc """
  Generates an Elixir module from a Config struct.
  """
  @spec generate(Config.t()) :: {:ok, module()} | {:error, term()}
  def generate(%Config{} = config) do
    with {:ok, module_name} <- validate_module_name(config.module),
         {:ok, llm_provider} <- validate_llm_config(config.llm_config) do
      quoted =
        quote do
          use Lux.Agent,
            id: unquote(config.id),
            name: unquote(config.name),
            description: unquote(config.description),
            goal: unquote(config.goal),
            template: unquote(config.template),
            template_opts:
              Lux.Agent.Generator.atomize_keys(unquote(Macro.escape(config.template_opts))),
            prisms:
              Enum.map(
                unquote(Macro.escape(config.prisms)),
                &Lux.Agent.Generator.validate_module_name!/1
              ),
            beams:
              Enum.map(
                unquote(Macro.escape(config.beams)),
                &Lux.Agent.Generator.validate_module_name!/1
              ),
            lenses:
              Enum.map(
                unquote(Macro.escape(config.lenses)),
                &Lux.Agent.Generator.validate_module_name!/1
              ),
            signal_handlers: unquote(Macro.escape(config.signal_handlers)),
            llm_config: unquote(llm_provider)
        end

      Module.create(module_name, quoted, Macro.Env.location(__ENV__))
      {:ok, module_name}
    end
  end

  def validate_module_name!(name) do
    case validate_module_name(name) do
      {:ok, module_name} -> module_name
      {:error, error} -> raise error
    end
  end

  def validate_module_name(nil), do: {:error, :missing_module_name}

  def validate_module_name(name) when is_binary(name) do
    if String.starts_with?(name, "Elixir.") do
      {:ok, String.to_atom(name)}
    else
      {:ok, String.to_atom("Elixir." <> name)}
    end
  end

  def validate_module_name(name) when is_atom(name), do: {:ok, name}
  def validate_module_name(_), do: {:error, :invalid_module_name}

  def atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) ->
        {String.to_atom(key), atomize_keys(value)}

      {key, value} ->
        {key, atomize_keys(value)}
    end)
  end

  def atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  def atomize_keys(other), do: other

  @doc """
  Validates the LLM configuration and resolves the provider module.
  """
  @spec validate_llm_config(map()) :: {:ok, struct()} | {:error, term()}
  def validate_llm_config(%{} = config) do
    provider_name = Map.get(config, :provider, :default)
    model = Map.fetch!(config, :model)
    options = Map.get(config, :options, %{})

    case Lux.Agent.LLMProvider.Registry.get(provider_name) do
      nil ->
        {:error, {:unknown_provider, provider_name}}

      provider_module ->
        {:ok,
         %Lux.Agent.LLMProvider{
           provider: provider_module,
           model: model,
           options: options
         }}
    end
  end

  def validate_llm_config(_), do: {:error, :invalid_llm_config}
end

defmodule Lux.Agent.LLMProvider do
  @moduledoc """
  Behaviour and struct for LLM providers.
  """

  @callback call(String.t(), map()) :: {:ok, String.t()} | {:error, term()}
  @callback cost(String.t(), map()) :: non_neg_integer()
  @callback latency(String.t(), map()) :: non_neg_integer()

  defstruct provider: nil, model: nil, options: %{}
end

defmodule Lux.Agent.LLMProvider.Registry do
  @moduledoc """
  Registry for LLM providers.
  """

  use Agent

  @doc """
  Starts the registry agent.
  """
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
  Registers a provider module under a given name.
  """
  def register(provider_name, module) when is_atom(provider_name) and is_atom(module) do
    Agent.update(__MODULE__, &Map.put(&1, provider_name, module))
  end

  @doc """
  Retrieves a provider module by name.
  """
  def get(provider_name) when is_atom(provider_name) do
    Agent.get(__MODULE__, &Map.get(&1, provider_name))
  end

  @doc """
  Lists all registered provider names.
  """
  def list do
    Agent.get(__MODULE__, &Map.keys(&1))
  end
end

defmodule Lux.Agent.LLMProvider.Monitor do
  @moduledoc """
  Monitoring utilities for LLM providers.
  """

  @cost_table :llm_costs
  @latency_table :llm_latency

  @doc """
  Initializes ETS tables for cost and latency tracking.
  """
  def init do
    :ets.new(@cost_table, [:named_table, :public, read_concurrency: true])
    :ets.new(@latency_table, [:named_table, :public, read_concurrency: true])
  end

  @doc """
  Records cost for a provider and model.
  """
  def record_cost(provider, model, cost) when is_integer(cost) and cost >= 0 do
    key = {provider, model}
    :ets.insert(@cost_table, {key, cost})
  end

  @doc """
  Retrieves total cost for a provider and model.
  """
  def get_cost(provider, model) do
    key = {provider, model}
    case :ets.lookup(@cost_table, key) do
      [{^key, cost}] -> cost
      [] -> 0
    end
  end

  @doc """
  Records latency for a provider and model.
  """
  def record_latency(provider, model, latency) when is_integer(latency) and latency >= 0 do
    key = {provider, model}
    :ets.insert(@latency_table, {key, latency})
  end

  @doc """
  Retrieves average latency for a provider and model.
  """
  def get_latency(provider, model) do
    key = {provider, model}
    case :ets.lookup(@latency_table, key) do
      [{^key, latency}] -> latency
      [] -> 0
    end
  end
end

defmodule Lux.Agent.LLMProvider.Fallback do
  @moduledoc """
  Handles fallback logic for LLM provider calls.
  """

  @doc """
  Attempts to call the primary provider; on failure, falls back to the default provider.
  """
  def call_with_fallback(primary_provider, model, prompt, options) do
    case primary_provider.call(prompt, options) do
      {:ok, response} ->
        {:ok, response}

      {:error, _} ->
        default_provider = Lux.Agent.LLMProvider.Registry.get(:default)

        if default_provider do
          default_provider.call(prompt, options)
        else
          {:error, :no_fallback_available}
        end
    end
  end
end