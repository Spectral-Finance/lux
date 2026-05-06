defmodule Lux.LLM.Router do
  @moduledoc """
  Smart router for LLM provider selection, fallback handling, and request dispatch.

  The Router selects the best provider for a given request based on:
    - Required capabilities (tools, vision, streaming, etc.)
    - Cost constraints
    - Provider priority ordering
    - User-specified provider/model preference

  ## Usage

      # Route to best provider for vision task
      Lux.LLM.Router.route("Describe this image", tools, %{capability: :vision})

      # Route with explicit provider preference
      Lux.LLM.Router.route("Hello", [], %{provider: Lux.LLM.Anthropic})

      # Route with fallback chain
      Lux.LLM.Router.route_with_fallback("Hello", [], %{})
  """

  @doc """
  Route a request to the best provider for the given options.

  Options can include:
    - `:provider` - Explicit provider module
    - `:model` - Specific model name
    - `:capability` - Required capability (e.g., `:vision`, `:tools`)
    - `:max_cost` - Maximum cost per 1k tokens (input + output)
    - `:tags` - Required provider tags

  Returns `{:ok, {provider_module, config}}` or `{:error, :no_suitable_provider}`.
  """
  @spec route(String.t(), list(), keyword() | map()) ::
          {:ok, {module(), map()}} | {:error, :no_suitable_provider}
  def route(prompt, tools, options \\ [])

  def route(_prompt, _tools, options) when is_list(options) do
    options = Map.new(options)
    do_route(options)
  end

  def route(_prompt, _tools, options) when is_map(options) do
    do_route(options)
  end

  @doc """
  Route a request with explicit fallback chain.

  Tries each provider in order until one succeeds. If no provider is specified,
  uses the provider priority order from the Registry.

  Returns `{:ok, {provider_module, result}}` or `{:error, :all_providers_failed}`.
  """
  @spec route_with_fallback(String.t(), list(), keyword() | map()) ::
          {:ok, {module(), term()}} | {:error, :all_providers_failed}
  def route_with_fallback(prompt, tools, options \\ [])

  def route_with_fallback(prompt, tools, options) when is_list(options) do
    route_with_fallback(prompt, tools, Map.new(options))
  end

  def route_with_fallback(prompt, tools, options) do
    providers = resolve_provider_chain(options)

    try_providers(prompt, tools, options, providers)
  end

  @doc """
  Select the best provider for a given capability.

  Returns the provider module with the highest priority that supports the capability.
  """
  @spec select_for_capability(Lux.LLM.Provider.capability()) :: {:ok, module()} | {:error, :not_found}
  def select_for_capability(capability) do
    case Lux.LLM.Registry.find_by_capability(capability) do
      [] ->
        {:error, :not_found}

      providers ->
        providers
        |> Enum.sort_by(&provider_priority/1)
        |> List.first()
        |> then(&{:ok, &1})
    end
  end

  @doc """
  Get an ordered list of providers suitable for the given options.

  Returns providers sorted by priority (lowest number = highest priority).
  """
  @spec suitable_providers(keyword() | map()) :: [module()]
  def suitable_providers(options \\ [])

  def suitable_providers(options) when is_list(options) do
    suitable_providers(Map.new(options))
  end

  def suitable_providers(options) do
    providers = Lux.LLM.Registry.list_providers()

    providers
    |> Enum.filter(&provider_matches?(&1, options))
    |> Enum.sort_by(&provider_priority/1)
  end

  # Private

  defp do_route(options) do
    # Explicit provider wins
    if options[:provider] do
      provider = options[:provider]

      if Lux.LLM.Registry.registered?(provider) do
        {:ok, {provider, options}}
      else
        {:error, :no_suitable_provider}
      end
    else
      # Find best provider based on criteria
      providers = suitable_providers(options)

      case providers do
        [provider | _] ->
          {:ok, {provider, options}}

        [] ->
          {:error, :no_suitable_provider}
      end
    end
  end

  defp resolve_provider_chain(options) do
    cond do
      options[:provider] ->
        [options[:provider]]

      options[:fallback_providers] ->
        options[:fallback_providers]

      true ->
        suitable_providers(options)
    end
  end

  defp try_providers(_prompt, _tools, _options, []) do
    {:error, :all_providers_failed}
  end

  defp try_providers(prompt, tools, options, [provider | rest]) do
    merged_opts = Map.put(options, :provider, provider)

    case provider.call(prompt, tools, merged_opts) do
      {:ok, _result} = success ->
        success

      {:error, _reason} ->
        try_providers(prompt, tools, options, rest)
    end
  end

  defp provider_matches?(provider, options) do
    with {:ok, metadata} <- Lux.LLM.Registry.get_metadata(provider) do
      enabled? = Map.get(metadata, :enabled, true)
      capability_ok? = matches_capability?(metadata, options[:capability])
      tags_ok? = matches_tags?(metadata, options[:tags])
      cost_ok? = matches_cost?(metadata, options[:max_cost])

      enabled? && capability_ok? && tags_ok? && cost_ok?
    else
      _ -> false
    end
  end

  defp matches_capability?(_metadata, nil), do: true

  defp matches_capability?(metadata, capability) when is_atom(capability) do
    capability in Map.get(metadata, :capabilities, [])
  end

  defp matches_capability?(metadata, capabilities) when is_list(capabilities) do
    provider_caps = Map.get(metadata, :capabilities, [])
    Enum.all?(capabilities, &(&1 in provider_caps))
  end

  defp matches_tags?(_metadata, nil), do: true
  defp matches_tags?(_metadata, []), do: true

  defp matches_tags?(metadata, required_tags) when is_list(required_tags) do
    provider_tags = Map.get(metadata, :tags, [])
    Enum.any?(required_tags, &(&1 in provider_tags))
  end

  defp matches_cost?(_metadata, nil), do: true

  defp matches_cost?(metadata, max_cost) when is_number(max_cost) do
    input_cost = Map.get(metadata, :cost_per_1k_input_tokens, 0)
    output_cost = Map.get(metadata, :cost_per_1k_output_tokens, 0)
    input_cost + output_cost <= max_cost
  end

  defp provider_priority(provider) do
    case Lux.LLM.Registry.get_metadata(provider) do
      {:ok, metadata} -> Map.get(metadata, :priority, 999)
      _ -> 999
    end
  end
end
