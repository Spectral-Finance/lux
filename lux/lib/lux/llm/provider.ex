defmodule Lux.LLM.Provider do
  @moduledoc """
  Registry and manager for LLM providers.

  Provides a centralized way to discover, select, and call LLM providers
  at runtime. Each provider must implement the `Lux.LLM` behaviour.

  ## Configuration

  Providers are configured via the `:lux` application env under the `:providers` key.
  Each entry is a `{module, keyword}` tuple where the keyword list contains
  provider-specific options (model, priority, etc.).

      config :lux, :providers,
        openai: [module: Lux.LLM.OpenAI, model: "gpt-4o", priority: 1],
        anthropic: [module: Lux.LLM.Anthropic, model: "claude-3-opus", priority: 2],
        together_ai: [module: Lux.LLM.TogetherAI, model: "mistral-7b", priority: 3]

  ## Usage

      # Call a specific provider
      Lux.LLM.Provider.call(Lux.LLM.OpenAI, "Hello", [])

      # Call the default provider
      Lux.LLM.Provider.call("Hello", [])

      # List available providers
      Lux.LLM.Provider.providers()

      # Get the default provider module
      Lux.LLM.Provider.default_module()
  """

  @type provider_name :: atom()
  @type provider_entry :: {provider_name(), %{module: module(), options: map()}}
  @type prompt :: String.t()
  @type tools :: list()
  @type options :: map()

  @doc """
  Returns the list of registered provider names.
  """
  @spec providers() :: [provider_name()]
  def providers do
    Application.get_env(:lux, :providers, [])
    |> Enum.map(fn {name, _opts} -> name end)
  end

  @doc """
  Returns the list of registered provider modules.
  """
  @spec provider_modules() :: [module()]
  def provider_modules do
    providers()
    |> Enum.map(&provider_module/1)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Returns the module for a given provider name.
  """
  @spec provider_module(provider_name()) :: module() | nil
  def provider_module(name) do
    case Application.get_env(:lux, :providers, [])
         |> Keyword.get(name) do
      %{module: module} -> module
      _ -> nil
    end
  end

  @doc """
  Returns the options (model, priority, etc.) for a given provider name.
  """
  @spec provider_options(provider_name()) :: map()
  def provider_options(name) do
    case Application.get_env(:lux, :providers, [])
         |> Keyword.get(name) do
      %{options: opts} -> opts
      opts when is_list(opts) -> Map.new(opts)
      _ -> %{}
    end
  end

  @doc """
  Returns the default provider module.

  The default is determined by priority (lowest number = highest priority)
  among registered providers. Falls back to `Lux.LLM.@default_module` if
  no providers are registered.
  """
  @spec default_module() :: module()
  def default_module do
    case Application.get_env(:lux, :providers, []) do
      [] ->
        @fallback_module

      entries ->
        entries
        |> Enum.map(fn {name, opts} ->
          module =
            case opts do
              %{module: m} -> m
              _ -> provider_module(name)
            end

          priority =
            case opts do
              %{options: o} -> Map.get(o, :priority, 999)
              p when is_integer(p) -> p
              _ -> 999
            end

          {priority, module}
        end)
        |> Enum.sort()
        |> Enum.at(0)
        |> elem(1)
    end
  end

  @doc """
  Calls the specified provider (or the default) with the given prompt, tools, and options.

  ## Parameters
    - provider: Either a provider module, a provider name atom, or `nil` for the default.
    - prompt: The prompt string to send.
    - tools: List of tools (Beams, Prisms, Lenses).
    - options: Provider-specific options (model, temperature, etc.).

  ## Examples

      # Call default provider
      Lux.LLM.Provider.call("What is the weather?", [])

      # Call specific provider
      Lux.LLM.Provider.call(Lux.LLM.OpenAI, "Hello", [], %{model: "gpt-4"})

      # Call by provider name
      Lux.LLM.Provider.call(:openai, "Hello", [])
  """
  @spec call(prompt(), tools(), options()) :: {:ok, any()} | {:error, String.t()}
  def call(prompt, tools \\ [], options \\ %{})

  def call(prompt, tools, options) when is_binary(prompt) do
    module = default_module()
    do_call(module, prompt, tools, options)
  end

  def call(provider_name, prompt, tools, options) when is_atom(provider_name) do
    module = provider_module(provider_name) || raise ArgumentError, "Unknown provider: #{provider_name}"
    do_call(module, prompt, tools, options)
  end

  def call(module, prompt, tools, options) when is_atom(module) do
    do_call(module, prompt, tools, options)
  end

  defp do_call(module, prompt, tools, options) do
    provider_opts = Map.merge(provider_options_from_module(module), options)
    module.call(prompt, tools, provider_opts)
  end

  defp provider_options_from_module(module) do
    Application.get_env(:lux, module, [])
    |> Enum.into(%{})
  end

  @doc """
  Returns the fallback module used when no providers are registered.
  """
  @spec fallback_module() :: module()
  def fallback_module, do: @fallback_module

  @doc """
  Registers a new provider at runtime.

  This merges the provider into the runtime configuration so that
  subsequent calls to `providers/0` and `default_module/0` reflect
  the new registration.
  """
  @spec register(provider_name(), module(), map()) :: :ok
  def register(name, module, opts \\ %{}) do
    current = Application.get_env(:lux, :providers, [])
    new_entry = {name, Map.merge(%{module: module}, opts)}
    Application.put_env(:lux, :providers, Keyword.put(current, name, new_entry))
    :ok
  end

  @doc """
  Unregisters a provider by name.
  """
  @spec unregister(provider_name()) :: :ok
  def unregister(name) do
    current = Application.get_env(:lux, :providers, [])
    Application.put_env(:lux, :providers, Keyword.delete(current, name))
    :ok
  end

  @doc """
  Checks if a given provider name is registered.
  """
  @spec registered?(provider_name()) :: boolean()
  def registered?(name) do
    name in providers()
  end

  @doc """
  Lists all available models across all registered providers.
  """
  @spec available_models() :: [{provider_name(), [String.t()]}]
  def available_models do
    providers()
    |> Enum.map(fn name ->
      module = provider_module(name)
      models = fetch_models(module)
      {name, models}
    end)
  end

  defp fetch_module_from_env(module) when is_atom(module) do
    Application.get_env(:lux, module, [])
    |> Enum.into(%{})
    |> Map.get(:models, [])
  end

  defp fetch_models(nil), do: []

  defp fetch_models(module) do
    case Module.get_attribute(module, :__info__, :module) do
      _ ->
        Application.get_env(:lux, module, [])
        |> Enum.into(%{})
        |> Map.get(:models, [])
    rescue
      _ -> []
    end
  end

  @fallback_module Lux.LLM.OpenAI
end
