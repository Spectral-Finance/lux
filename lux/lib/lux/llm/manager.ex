defmodule Lux.LLM.Manager do
  @moduledoc """
  Unified entry point for all LLM operations in the Lux ecosystem.

  The Manager sits on top of the Registry, Router, and individual providers,
  providing a clean API for:

    - Sending prompts to the best available provider
    - Automatic fallback on failure
    - Cost tracking and budget enforcement
    - Provider and model discovery

  ## Usage

      # Simple completion (auto-selects best provider)
      Lux.LLM.Manager.chat("Hello, how are you?")

      # Chat with tools
      Lux.LLM.Manager.chat("What's the weather?", [weather_tool])

      # Chat with specific provider
      Lux.LLM.Manager.chat("Tell me a joke", [], provider: Lux.LLM.Anthropic)

      # Chat requiring vision capability
      Lux.LLM.Manager.chat("Describe this image", [], capability: :vision)

      # Chat with cost constraint
      Lux.LLM.Manager.chat("Hello", [], max_cost: 0.001)
  """

  @doc """
  Send a chat prompt to the LLM with automatic provider selection.

  ## Options

    - `:provider` - Specific provider module to use
    - `:model` - Specific model name to use
    - `:capability` - Required capability (e.g., `:vision`, `:tools`)
    - `:max_cost` - Maximum cost per 1k tokens
    - `:fallback` - Whether to try fallback providers on failure (default: true)
    - `:tags` - Required provider tags
    - Plus any provider-specific options

  Returns `{:ok, Lux.LLM.Response.t()}` or `{:error, term()}`.
  """
  @spec chat(String.t(), list(), keyword() | map()) ::
          {:ok, Lux.LLM.Response.t()} | {:error, term()}
  def chat(prompt, tools \\ [], options \\ [])

  def chat(prompt, tools, options) when is_list(options) do
    chat(prompt, tools, Map.new(options))
  end

  def chat(prompt, tools, options) when is_map(options) do
    with {:ok, {provider, _config}} <- Lux.LLM.Router.route(prompt, tools, options) do
      do_call(prompt, tools, options, provider)
    end
  end

  @doc """
  Send a chat with automatic fallback across providers.

  If the primary provider fails, the next suitable provider is tried
  automatically. Continues until a provider succeeds or all are exhausted.

  ## Options

    - `:fallback_providers` - Explicit list of providers to try in order
    - All options from `chat/3`

  Returns `{:ok, {provider_module, response}}` or `{:error, :all_providers_failed}`.
  """
  @spec chat_with_fallback(String.t(), list(), keyword() | map()) ::
          {:ok, {module(), Lux.LLM.Response.t()}} | {:error, :all_providers_failed}
  def chat_with_fallback(prompt, tools \\ [], options \\ [])

  def chat_with_fallback(prompt, tools, options) when is_list(options) do
    chat_with_fallback(prompt, tools, Map.new(options))
  end

  def chat_with_fallback(prompt, tools, options) do
    case Lux.LLM.Router.route_with_fallback(prompt, tools, options) do
      {:ok, {provider, result}} ->
        {:ok, {provider, result}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  List all registered providers and their basic info.
  """
  @spec list_providers() :: [Lux.LLM.Provider.provider_metadata()]
  def list_providers do
    Lux.LLM.Registry.all_providers()
  end

  @doc """
  List available models from all providers or a specific provider.
  """
  @spec list_models(module() | nil) :: [{module(), [String.t()]}]
  def list_models(provider \\ nil)

  def list_models(nil) do
    Lux.LLM.Registry.list_providers()
    |> Enum.map(fn provider ->
      case Lux.LLM.Registry.get_metadata(provider) do
        {:ok, metadata} -> {provider, Map.get(metadata, :models, [])}
        _ -> {provider, []}
      end
    end)
  end

  def list_models(provider) do
    case Lux.LLM.Registry.get_metadata(provider) do
      {:ok, metadata} -> [{provider, Map.get(metadata, :models, [])}]
      _ -> [{provider, []}]
    end
  end

  @doc """
  Get cost estimate for a specific model from a specific provider.
  """
  @spec estimate_cost(module(), String.t()) :: {:ok, Lux.LLM.Provider.cost_info()} | {:error, term()}
  def estimate_cost(provider, model) do
    if function_exported?(provider, :cost, 1) do
      provider.cost(model)
    else
      {:error, :cost_not_supported}
    end
  end

  @doc """
  Find providers that support a specific capability.
  """
  @spec find_by_capability(Lux.LLM.Provider.capability()) :: [module()]
  def find_by_capability(capability) do
    Lux.LLM.Registry.find_by_capability(capability)
  end

  # Private

  defp do_call(prompt, tools, options, provider) do
    # Merge in any model override from options
    call_opts =
      options
      |> Map.drop([:provider, :capability, :fallback, :max_cost, :tags, :fallback_providers])
      |> Map.put(:provider, provider)
      |> Map.to_list()

    # Try the call. If it fails and fallback is enabled, try fallback chain.
    case provider.call(prompt, tools, call_opts) do
      {:ok, _response} = success ->
        success

      {:error, reason} when is_map_key(options, :fallback) and options.fallback == false ->
        {:error, reason}

      {:error, _reason} ->
        # Try fallback if enabled
        fallback_opts = Map.drop(options, [:provider])
        chat_with_fallback(prompt, tools, fallback_opts)
    end
  end
end
