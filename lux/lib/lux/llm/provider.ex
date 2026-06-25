defmodule Lux.LLM.Provider do
  @moduledoc """
  Universal provider interface for LLM providers.
  Defines the contract that all LLM providers must implement.
  """

  alias Lux.LLM.ProviderConfig

  @type model :: String.t()
  @type prompt :: String.t() | list()
  @type options :: keyword()
  @type response :: {:ok, map()} | {:error, term()}

  @callback available_models() :: [model()]
  @callback chat_completion(prompt(), options()) :: response()
  @callback stream_completion(prompt(), options()) :: Enumerable.t() | response()
  @callback count_tokens(prompt(), model()) :: non_neg_integer() | {:error, term()}
  @callback supports_model?(model()) :: boolean()

  @optional_callbacks [stream_completion: 2, count_tokens: 2]

  defmacro __using__(_opts) do
    quote do
      @behaviour Lux.LLM.Provider

      alias Lux.LLM.ProviderConfig

      def supports_model?(model) do
        model in available_models()
      end

      defoverridable supports_model?: 1
    end
  end

  @doc """
  Gets the default provider from application configuration.
  """
  def default_provider do
    case Application.get_env(:lux, :default_llm_provider) do
      nil -> raise "No default LLM provider configured. Set :default_llm_provider in :lux config."
      provider -> provider
    end
  end

  @doc """
  Lists all registered providers.
  """
  def list_providers do
    Lux.LLM.Registry.list_providers()
  end

  @doc """
  Gets a provider by name.
  """
  def get_provider(name) do
    Lux.LLM.Registry.get_provider(name)
  end

  @doc """
  Checks if a provider is registered.
  """
  def has_provider?(name) do
    Lux.LLM.Registry.has_provider?(name)
  end
end